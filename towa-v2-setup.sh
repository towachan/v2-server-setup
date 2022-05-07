#/bin/sh

port=$1
client_id=$2

v2_config_file="v2-kcp-config.json"
raw_github_url="https://raw.githubusercontent.com/towachan/v2-server-setup/main"

echo "Download and install v2ray..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

echo "Update geoip and geosite..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh)

echo "Download v2ray config file..."
curl -L $raw_github_url/$v2_config_file -o ~/$v2_config_file

echo "Update v2ray config file..."
sed -i "s/<PORT>/$1/g" ~/$v2_config_file
sed -i "s/<CLIENT_ID>/$2/g" ~/$v2_config_file

echo "Copy v2ray config file to working path..."
cp ~/$v2_config_file /usr/local/etc/v2ray/config.json

echo "Open $port in firewall"
firewall-cmd --add-port=$port/udp --zone=public --permanent
systemctl reload firewalld.service
firewall-cmd --list-ports

echo "Start v2ray service"
systemctl start v2ray
systemctl | grep v2ray