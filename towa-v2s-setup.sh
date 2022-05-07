#/bin/sh

port=$1
client_id=$2
path=$3
nginx_port=$4
server_name=$5
email=$6

v2_config_file="v2-ws-config.json.j2"
nginx_config_file="nginx.conf.j2"
raw_github_url="https://raw.githubusercontent.com/towachan/v2-server-setup/main"
nginx_crt_file=/etc/v2ray/v2ray.crt
nginx_crt_key=/etc/v2ray/v2ray.key

echo "Download and install v2ray..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

echo "Update geoip and geosite..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh)

echo "Download v2ray config file..."
curl -L $raw_github_url/$v2_config_file -o ~/$v2_config_file

echo "Update v2ray config file..."
sed -i "s/{{PORT}}/$port/g" ~/$v2_config_file
sed -i "s/{{CLIENT_ID}}/$client_id/g" ~/$v2_config_file
sed -i "s/{{PATH}}/$path/g" ~/$v2_config_file

echo "Copy v2ray config file to working path..."
cp ~/$v2_config_file /usr/local/etc/v2ray/config.json

echo "create /etc/v2ray"
mkdir -p /etc/v2ray

echo "Install acme..."
yum -y install socat 
curl  https://get.acme.sh | sh

echo "Register acme..."
acme.sh --register-account -m $email

echo "Create ssl cert..."
~/.acme.sh/acme.sh --issue -d $server_name --standalone --keylength ec-256 --force
~/.acme.sh/acme.sh --installcert -d $server_name --ecc \
    --fullchain-file $nginx_crt_file \
    --key-file $nginx_crt_key

echo "Install nginx..."
yum -y install nginx

echo "Download nginx config file..."
curl -L $raw_github_url/$v2_config_file -o ~/$nginx_config_file

echo "Update nginx config file"
sed -i "s/{{PORT}}/$nginx_port/g" ~/$nginx_config_file
sed -i "s/{{SERVER_NAME}}/$server_name/g" ~/$nginx_config_file
sed -i "s/{{CERT_PATH}}/$nginx_crt_file/g" ~/$nginx_config_file
sed -i "s/{{CERT_KEY_PATH}}/$nginx_crt_key/g" ~/$nginx_config_file
sed -i "s/{{PATH}}/$path/g" ~/$nginx_config_file
sed -i "s/{{PROXY_PORT}}/$port/g" ~/$nginx_config_file

cp ~/$nginx_config_file /etc/nginx/nginx.conf

echo "Set SELINUX premissive..."
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=permissive/g" /etc/selinux/config

echo "Open $nginx_port in firewall..."
firewall-cmd --add-port=$nginx_port/tcp --zone=public --permanent
systemctl reload firewalld.service
firewall-cmd --list-ports

echo "Start v2ray service..."
systemctl start v2ray
systemctl | grep v2ray

echo "Start nginx..."
systemctl force-reload nginx
systemctl restart nginx
systemctl | grep nginx