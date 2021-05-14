#!/bin/bash
# Auth: happylife
# Desc: v2ray installation script
# Plat: ubuntu 18.04+
# Eg  : bash v2ray_installation_vmess.sh "你的域名"

##安装依赖包
apt update
apt install curl pwgen openssl netcat cron socat -y

domainName="$1"
port="`shuf -i 20000-65000 -n 1`"
uuid="`uuidgen`"
path="/`pwgen -A0 6 8 | xargs |sed 's/ /\//g'`"

if [ -z "$domainName" ];then
	echo "域名不能为空"
	exit
fi


##配置系统时区为东八区
rm -rf /etc/localtime
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


##使用v2ray官方命令安装v2ray
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh

bash install-release.sh
bash install-dat-release.sh

systemctl enable v2ray


##安装nginx
apt install nginx -y
systemctl enable nginx
systemctl start nginx


##安装acme,并申请加密证书
ssl_dir="`mkdir -p /usr/local/etc/v2ray/ssl | awk -F"'" 'END{print $2}'`"
source ~/.bashrc
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d "$domainName" --alpn -k ec-256
~/.acme.sh/acme.sh --installcert -d "$domainName" --fullchainpath $ssl_dir/v2ray.crt --keypath $ssl_dir/v2ray.key --ecc
chown www-data.www-data $ssl_dir/v2ray.*


##创建WS路径,配置v2ray客户端时会用到[目录可以自定义]
mkdir -pv "$path" && chmod -R 644 "$path"


##配置nginx
echo "
server {
	listen 80;
	server_name "$domainName";
	return 301 https://"'$host'""'$request_uri'";

}

server {
	listen 443 ssl http2 default_server;
	listen [::]:443 ssl http2 default_server;
	server_name "$domainName";

	ssl_certificate $ssl_dir/v2ray.crt;
	ssl_certificate_key $ssl_dir/v2ray.key;
	ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
	ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;

	root /usr/share/nginx/html;
	
	location "$path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
		proxy_set_header Host "'"$http_host"'";
	}

}
" > /etc/nginx/conf.d/v2ray.conf

##配置v2ray
echo '
{
  "log" : {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbound": {
    "port": '$port',
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": '"\"$uuid\""',
          "level": 1,
          "alterId": 64
        }
      ]
    },
   "streamSettings":{
      "network": "ws",
      "wsSettings": {
           "path": '"\"$path\""'
      }
   }
  },
  "outbound": {
    "protocol": "freedom",
    "settings": {}
  },
  "outboundDetour": [
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "strategy": "rules",
    "settings": {
      "rules": [
        {
          "type": "field",
          "ip": [ "geoip:private" ],
          "outboundTag": "blocked"
        }
      ]
    }
  }
}
' > /usr/local/etc/v2ray/config.json

##重启v2ray和nginx
systemctl restart v2ray
systemctl status -l v2ray
/usr/sbin/nginx -t && systemctl restart nginx.service 

##输出配置信息
echo
echo "域名: $domainName"
echo "端口: 443"
echo "UUID: $uuid"
echo "额外ID: 64"
echo "路径: $path"
