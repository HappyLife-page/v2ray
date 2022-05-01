#!/bin/bash
# Auth: happylife
# Desc: v2ray&wordperss installation script
# Plat: ubuntu 18.04 20.04
# Eg  : bash v2ray_wordpress_installation.sh "你的域名" [vless]

if [ -z "$1" ];then
	echo "域名不能为空"
	exit
fi


# 配置系统时区为东八区
rm -f /etc/localtime
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


# 使用ubuntu官方源安装nginx,php,mysql和依赖包，关闭防火墙ufw
apt update
apt install nginx curl pwgen openssl netcat cron php php-fpm php-opcache php-mysql php-gd php-xmlrpc php-imagick php-mbstring php-zip php-json php-mbstring php-curl php-xml mariadb-server memcached php-memcached php-memcache expect -y
ufw disable


# 开始部署之前，我们先配置一下需要用到的参数，如下：
# "v2ray域名，端口，uuid，ws路径，ssl证书目录，nginx和v2ray配置文件目录"
# 1.设置你的解析好的域名
domainName="$1"

# 2.随机生成v2ray需要用到的服务端口
v2rayPort="`shuf -i 20000-65000 -n 1`"

# 3.随机生成一个uuid
uuid="`uuidgen`"

# 4.随机生成并创建一个websocket需要使用的目录path
v2ray_ws_path="$(mkdir -pv "/`pwgen -A0 6 8 | xargs |sed 's/ /\//g'`" |awk -F"'" END'{print $2}')"

# 5.以时间为基准随机创建一个存放ssl证书的目录
v2ray_ssl_dir="$(mkdir -pv "/usr/local/etc/v2ray/ssl/`date +"%F-%H-%M-%S"`" |awk -F"'" END'{print $2}')"

# 6.定义nginx和v2ray配置文件路径
nginxV2rayWordpressConf="/etc/nginx/conf.d/v2ray.conf"
v2rayConfig="/usr/local/etc/v2ray/config.json"

# 7.如果是重新部署，就删除旧的ws路径目录
[ -f "$v2rayConfig" ] && awk -F'/' '/"path"/{print "/"$2}' $v2rayConfig |xargs rm -rf {} \;

# 配置MySQL和wordpress(以下简称wp)需要用的参数，如下：
#1.随机生成MySQL的root用户密码
mysql_root_pwd="`pwgen 8 1`"

#2.随机生成wp用户名
wp_user_name="`pwgen -0 8 1`"

#3.随机生成wp密码
wp_user_pwd="$(pwgen -cny -r "\"\\;'\`" 26 1)"

#4.随机生成wp数据库名
wp_db_name="`pwgen -A0 9 1`"

#5.随机生成并创建wp源码目录
wp_code_dir="$(mkdir -pv "/`pwgen -A0 8 3 | xargs |sed 's/ /\//g'`" |awk -F"'" END'{print $2}')"


# 使用v2ray官方命令安装v2ray并设置开机启动
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh
bash install-release.sh
bash install-dat-release.sh
systemctl enable v2ray


##安装acme,并申请加密证书
source ~/.bashrc
if nc -z localhost 443;then /etc/init.d/nginx stop;fi
! [ -f ~/.acme.sh/acme.sh ] && curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$domainName" --alpn -k ec-256
~/.acme.sh/acme.sh --installcert -d "$domainName" --fullchainpath $v2ray_ssl_dir/v2ray.crt --keypath $v2ray_ssl_dir/v2ray.key --ecc
chown www-data.www-data $v2ray_ssl_dir/v2ray.*


## 把申请证书命令添加到计划任务
echo -n '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
(crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab


# 执行mysql_secure_installation命令优化MySQL配置
# 包括设置root密码,移除匿名用户,禁用root账户远程登陆,删除测试库,和重载权限表使优化生效
/usr/bin/expect <<-EOCCCCCC
spawn /usr/bin/mysql_secure_installation
expect "Enter current password for root (enter for none):"
send "\r"
expect "Set root password? "
send "Y\r"
expect "New password: "
send "${mysql_root_pwd}\r"
expect "Re-enter new password: "
send "${mysql_root_pwd}\r"
expect "Remove anonymous users?"
send "Y\r"
expect "Disallow root login remotely?"
send "Y\r"
expect "Remove test database and access to it?"
send "Y\r"
expect "Reload privilege tables now?"
send "Y\r"
expect eocccccc;
EOCCCCCC


# 下载wp,创建wp库,设置wp用户名和密码并设置访问权限
#1.下载wp最新源码,并解压到wp目录
curl https://wordpress.org/latest.tar.gz | tar xz -C ${wp_code_dir}
#2.授权nginx用户访问wp源码目录
chown -R www-data.www-data ${wp_code_dir}
#3.创建wp库,给wp设置MySQL用户名和密码并授予访问权限
mysql -uroot -p${mysql_root_pwd} <<-EOC
#3.1 创建wp数据库
create database ${wp_db_name};
#3.2 创建wp用户并设置密码
create user ${wp_user_name}@'localhost' identified by "${wp_user_pwd}";
#3.3 授权wp用户访问wp库
grant all privileges on ${wp_db_name}.* to ${wp_user_name}@'localhost';
#3.4 刷新权限使其生效
flush privileges;
EOC


# 配置nginx，执行如下命令即可添加nginx配置文件
echo "
server {
	listen 80;
	server_name "$domainName";
	return 301 https://"'$host$request_uri'";
}
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name "$domainName";
	ssl_certificate $v2ray_ssl_dir/v2ray.crt;
	ssl_certificate_key $v2ray_ssl_dir/v2ray.key;
	ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
	ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
	
	root ${wp_code_dir}/wordpress;
	index index.php;

# ---------------v2ray config beginning--------------- #	
	location "$v2ray_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$v2rayPort";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
            	proxy_set_header Host "'"$host"'";
            	proxy_set_header X-Real-IP "'"$remote_addr"'";
            	proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
	}
# ------------------v2ray config end------------------ #	

# -------------wordpress config beginning------------- #	
	"'location / {
           try_files $uri $uri/ /index.php$is_args$args;
    }
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
    location = /xmlrpc.php {
        deny all;
        access_log off;
    }
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    location ~ /\. {
        deny all;
    }
    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }
    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }'"	
# ---------------wordpress config end--------------- #	
}
" > $nginxV2rayWordpressConf


# 配置v2ray，执行如下命令即可添加v2ray配置文件
echo '
{
  "log" : {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbound": {
    "port": '$v2rayPort',
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
           "path": '"\"$v2ray_ws_path\""'
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


# 配置php启动相关文件
ln -s /run/php/php*.sock /run/php/php-fpm.sock

# 删除apache并清理其依赖包
/etc/init.d/apache2 stop
apt purge apache2 -y && apt autoremove -y

# 启动php,v2ray和nginx [mysql服务默认已启动,不要随意重启]
/etc/init.d/php-fpm start
systemctl restart v2ray
systemctl status -l v2ray
/usr/sbin/nginx -t && systemctl restart nginx


# 输出配置信息并保存到文件
# 输出v2ray配置信息
v2ray_wp_ins_info="/root/v2ray_wp_installation_info.txt"
> $v2ray_wp_ins_info
echo "
----------v2ray配置信息----------
域名: $domainName
端口: 443
UUID: $uuid
安全: tls
传输: websocket
路径: $v2ray_ws_path
" | tee -a $v2ray_wp_ins_info
[ "vless" = "$2" ] && echo "协议：vless" | tee -a $v2ray_wp_ins_info || echo "额外ID: 0" | tee -a $v2ray_wp_ins_info

# 输出wp配置信息
echo "
----------wordpress配置信息----------
你的域名	   : $domainName
MySQL root密码 : $mysql_root_pwd
wp库名	     : $wp_db_name
wp用户名	    : $wp_user_name
wp密码	     : $wp_user_pwd
wp源码目录     : $wp_code_dir
" | tee -a $v2ray_wp_ins_info
