#!/bin/bash
# Auth: happylife
# Desc: v2ray installation script
# Plat: ubuntu 18.04+
# Eg  : bash v2ray_installation_vmess.sh "你的域名" [vless]

if [ -z "$1" ];then
	echo "域名不能为空"
	exit
fi


# 配置系统时区为东八区
rm -f /etc/localtime
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


# 使用ubuntu官方源安装nginx和依赖包并设置开机启动，关闭防火墙ufw
apt update
apt install nginx curl pwgen openssl netcat cron -y
systemctl enable nginx
systemctl start nginx
ufw disable


# 开始部署之前，我们先配置一下需要用到的参数，如下：
# "域名，端口，uuid，ws路径，ssl证书目录，nginx和v2ray配置文件目录"
# 1.设置你的解析好的域名
domainName="$1"
# 2.随机生成v2ray需要用到的服务端口
port="`shuf -i 20000-65000 -n 1`"
# 3.随机生成一个uuid
uuid="`uuidgen`"
# 4.随机生成一个websocket需要使用的path
path="/`pwgen -A0 6 8 | xargs |sed 's/ /\//g'`"
# 5.以时间为基准随机创建一个存放ssl证书的目录
ssl_dir="$(mkdir -pv "/usr/local/etc/v2ray/ssl/`date +"%F-%H-%M-%S"`" |awk -F"'" END'{print $2}')"
# 6.定义nginx和v2ray配置文件路径
nginxConfig="/etc/nginx/conf.d/v2ray.conf"
v2rayConfig="/usr/local/etc/v2ray/config.json"


# 使用v2ray官方命令安装v2ray并设置开机启动
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh
bash install-release.sh
bash install-dat-release.sh
systemctl enable v2ray


##安装acme,并申请加密证书
source ~/.bashrc
if nc -z localhost 443;then /etc/init.d/nginx stop;fi
if ! [ -d /root/.acme.sh ];then curl https://get.acme.sh | sh;fi
curl  https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$domainName" -k ec-256 --alpn
~/.acme.sh/acme.sh --installcert -d "$domainName" --fullchainpath $ssl_dir/v2ray.crt --keypath $ssl_dir/v2ray.key --ecc
chown www-data.www-data $ssl_dir/v2ray.*


## 把申请证书命令添加到计划任务
echo -n '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
(crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab


# 配置nginx【如下80服务块完全可以不需要】，执行如下命令即可添加nginx配置文件
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
            	proxy_set_header Host "'"$host"'";
            	proxy_set_header X-Real-IP "'"$remote_addr"'";
            	proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
	}

}
" > $nginxConfig


# 配置v2ray，执行如下命令即可添加v2ray配置文件
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
      "decryption":"none",
      "clients": [
        {
          "id": '"\"$uuid\""',
          "level": 1
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
    "settings": {
      "decryption":"none"
    }
  },
  "outboundDetour": [
    {
      "protocol": "blackhole",
      "settings": {
        "decryption":"none"
      },
      "tag": "blocked"
    }
  ], 
  "routing": {
    "strategy": "rules",
    "settings": {
      "decryption":"none",
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
' > $v2rayConfig


# 默认配置vmess协议，如果指定vless协议则配置vless协议
[ "vless" = "$2" ] && sed -i 's/vmess/vless/' $v2rayConfig


# 重启v2ray和nginx
systemctl restart v2ray
systemctl status -l v2ray
/usr/sbin/nginx -t && systemctl restart nginx


# 输出配置信息
echo
echo "域名: $domainName"
echo "端口: 443"
echo "UUID: $uuid"
[ "vless" = "$2" ] && echo "协议：vless" || echo "额外ID: 0"
echo "安全: tls"
echo "传输: websocket"
echo "路径: $path"
