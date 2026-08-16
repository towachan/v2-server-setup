#/bin/bash

NAME=$1
DOMAIN_1=$2
DOMAIN_2=$3
email=$4
cf_key=$5
ssh_port=${6:-22}

# Validate required inputs
if [[ -z "$NAME" || -z "$DOMAIN_1" || -z "$DOMAIN_2" || -z "$email" || -z "$cf_key" ]]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <NAME> <DOMAIN_1> <DOMAIN_2> <email> <cf_key> [ssh_port]"
    exit 1
fi

render_template_vars() {
    local src="$1"
    local dst="${2:-$src}"
    local tmp line token var value

    [[ -f "$src" ]] || {
        echo "Template file not found: $src" >&2
        return 1
    }

    tmp=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        while [[ "$line" =~ \$\{[A-Za-z_][A-Za-z0-9_]*\} ]]; do
            token="${BASH_REMATCH[0]}"
            var="${token#\$\{}"
            var="${var%\}}"

            if [[ -n "${!var+x}" ]]; then
                value="${!var}"
                line="${line//"$token"/"$value"}"
            else
                line="${line//"$token"/}"
            fi
        done

        printf '%s\n' "$line" >> "$tmp"
    done < "$src"

    mv "$tmp" "$dst"
}

timedatectl set-timezone Asia/Hong_Kong

# install
sudo apt update
sudo apt install curl wget vim unzip ca-certificates gnupg lsb-release openssl socat ufw nginx -y

sudo systemctl enable --now nginx
sudo rm -f /etc/nginx/sites-enabled/default

sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# var setup
NOBODY_GROUP=$(id -gn nobody)
CDN_DOMAIN="${NAME}.${DOMAIN_1}"
REALITY_DOMAIN="${NAME}.${DOMAIN_2}"

UUID_1=$(xray uuid)
UUID_2=$(xray uuid)
KEY_OUTPUT=$(xray x25519 2>&1)

PRIVATE_KEY=$(echo "$KEY_OUTPUT" | awk 'tolower($0) ~ /private/ { print $NF; exit }')
PUBLIC_KEY=$(echo "$KEY_OUTPUT"  | awk 'tolower($0) ~ /public/  { print $NF; exit }')

SHORT_ID=$(openssl rand -hex 8)
XHTTP_PATH="/$(xray uuid)"

VLESSENC_OUTPUT=$(xray vlessenc 2>&1)
VLESS_ENC=$(echo "$VLESSENC_OUTPUT" | awk -F'"' '/ML-KEM/{found=1} found && /"encryption"/{print $4; exit}')
VLESS_DEC=$(echo "$VLESSENC_OUTPUT" | awk -F'"' '/ML-KEM/{found=1} found && /"decryption"/{print $4; exit}')

HOST_IP=$(hostname -I | cut -d' ' -f1)

# nginx config
mkdir -p /var/www/dist
curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o /var/www/dist/index.html https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_index.html

mkdir -p ~/tmpl

curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/tmpl/tmpl_nginx.conf https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_nginx.conf

render_template_vars ~/tmpl/tmpl_nginx.conf /etc/nginx/nginx.conf

nginx -t

# ACME
CERT_FILE="/etc/ssl/nginx/fullchain.cer"
KEY_FILE="/etc/ssl/nginx/private.key"

if [[ -s "$CERT_FILE" && -s "$KEY_FILE" ]]; then
    echo "TLS certificate and key already exist, skipping ACME issue"
else
    mkdir -p /etc/ssl/nginx
    curl https://get.acme.sh | sh -s email=$email

    export CF_Key=$cf_key
    export CF_Email=$email

    ~/.acme.sh/acme.sh --issue -d ${CDN_DOMAIN} -d ${REALITY_DOMAIN} --dns dns_cf --keylength ec-256 --force
    ~/.acme.sh/acme.sh --installcert -d ${CDN_DOMAIN} --ecc \
        --fullchain-file "$CERT_FILE" \
        --key-file "$KEY_FILE" \
        --reloadcmd     "systemctl reload nginx"
fi

curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/log-clean.sh https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/log-clean.sh
chmod +x ~/log-clean.sh
echo "0 0 * * * ~/log-clean.sh > /dev/null" > ~/cronjob
crontab ~/cronjob
crontab -l

# xray config
curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/tmpl/tmpl_xray_config.json https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_xray_config.json
render_template_vars ~/tmpl/tmpl_xray_config.json /usr/local/etc/xray/config.json

sudo xray run -test -config /usr/local/etc/xray/config.json
sudo systemctl enable --now xray
sudo systemctl restart xray

# client config
mkdir -p ~/client-configs
curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/client-configs/tmpl_mode3_client-config.json https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_mode3_client-config.json
curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/client-configs/tmpl_mode4_client-config.json https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_mode4_client-config.json
curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/client-configs/tmpl_mode5_client-config.json https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_mode5_client-config.json
curl -L --fail --retry 3 -H 'Cache-Control: no-cache, no-store, must-revalidate' -H 'Pragma: no-cache' -H 'Expires: 0' -o ~/client-configs/tmpl_mihomo_config.json https://raw.githubusercontent.com/towachan/v2-server-setup/refs/heads/main/xray/tmpl/tmpl_mihomo_config.json

render_template_vars ~/client-configs/tmpl_mode3_client-config.json ~/client-configs/mode3_client-config.json
render_template_vars ~/client-configs/tmpl_mode4_client-config.json ~/client-configs/mode4_client-config.json
render_template_vars ~/client-configs/tmpl_mode5_client-config.json ~/client-configs/mode5_client-config.json
render_template_vars ~/client-configs/tmpl_mihomo_config.json ~/client-configs/mihomo_config.json

# enable ufw
ufw allow ${ssh_port}
ufw allow 443
echo "y" | sudo ufw enable

echo echo "======================Setup completed======================"
echo "cache rule"
echo "  (http.host eq \"${CDN_DOMAIN}\") or (http.request.uri.path contains \"${XHTTP_PATH}\")"
