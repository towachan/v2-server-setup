#/bin/bash

nginx_crt_file_path=/etc/v2ray/v2ray.crt
nginx_crt_key_path=/etc/v2ray/v2ray.key

server_name=$(cat ~/domain)

~/.acme.sh/acme.sh --renew -d $server_name --ecc --force

~/.acme.sh/acme.sh --installcert -d $server_name --ecc \
    --fullchain-file $nginx_crt_file_path \
    --key-file $nginx_crt_key_path

systemctl force-reload nginx
systemctl restart nginx