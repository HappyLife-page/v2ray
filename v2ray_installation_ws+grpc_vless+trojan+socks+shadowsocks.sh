#!/bin/bash
# Auth: happylife
# Desc: v2ray installation script
# 	ws+vless,ws+trojan,ws+socks,ws+shadowsocks
#	grpc+vless,grpc+trojan,grpc+socks,grpc+shadowsocks
# Plat: ubuntu 18.04+
# Eg  : bash v2ray_installation_ws+grpc_vless+trojan+socks+shadowsocks.sh "你的域名"

if [ -z "$1" ];then
	echo "域名不能为空"
	exit
fi

# 配置系统时区为东八区,并设置时间为24H制
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
if ! grep -q 'LC_TIME' /etc/default/locale;then echo 'LC_TIME=en_DK.UTF-8' >> /etc/default/locale;fi


# 更新Ubuntu官方源，使用ubuntu官方源安装nginx和依赖包并设置开机启动，关闭防火墙ufw
apt clean all && apt update
apt install nginx curl pwgen openssl netcat cron -y
systemctl enable nginx
ufw disable


# 开始部署之前，我们先配置一下需要用到的参数，如下：
# "域名，uuid，ws和grpc路径，domainSock目录，ssl证书目录"

# 1.设置你的解析好的域名
domainName="$1"

# 2.随机生成一个uuid
uuid="`uuidgen`"

# 3.分别随机生成socks和shadowsocks需要用到的服务端口
socks_ws_port="`shuf -i 20000-30000 -n 1`"
shadowsocks_ws_port="`shuf -i 30001-40000 -n 1`"
socks_grpc_port="`shuf -i 40001-50000 -n 1`"
shadowsocks_grpc_port="`shuf -i 50001-60000 -n 1`"

# 4.分别随机生成trojan,socks和shadowsocks用户密码
trojan_passwd="$(pwgen -1cnys -r "'\";:$\\" 16)"
socks_user="$(pwgen -1cns 9)"
socks_passwd="$(pwgen -1cnys -r "'\";:$\\" 16)"
shadowsocks_passwd="$(pwgen -1cnys -r "'\";:$\\" 16)"

# 5.使用WS配置vless,trojan,socks,shadowsocks协议
# 分别随机生成vless,trojan,socks,shadowsocks需要使用的ws的path
vless_ws_path="/`pwgen -csn 6 8 | xargs |sed 's/ /\//g'`"
trojan_ws_path="/`pwgen -csn 6 8 | xargs |sed 's/ /\//g'`"
socks_ws_path="/`pwgen -csn 6 8 | xargs |sed 's/ /\//g'`"
shadowsocks_ws_path="/`pwgen -csn 6 8 | xargs |sed 's/ /\//g'`"

# 6.使用gRPC配置vless,trojan,socks,shadowsocks协议
# 分别随机生成vless,trojan,socks,shadowsocks需要使用的grpc的path
vless_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
trojan_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
socks_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
shadowsocks_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"

# 7.创建需要用的domainSock目录,并授权nginx用户权限
domainSock_dir="/run/v2ray";! [ -d $domainSock_dir ] && mkdir -pv $domainSock_dir
chown www-data.www-data $domainSock_dir

# 8.定义需要用到的domainSock文件名
vless_ws_domainSock="${domainSock_dir}/vless_ws.sock"
trojan_ws_domainSock="${domainSock_dir}/trojan_ws.sock"
vless_grpc_domainSock="${domainSock_dir}/vless_grpc.sock"
trojan_grpc_domainSock="${domainSock_dir}/trojan_grpc.sock"

# 9.以时间为基准随机创建一个存放ssl证书的目录
ssl_dir="$(mkdir -pv "/etc/nginx/ssl/`date +"%F-%H-%M-%S"`" |awk -F"'" END'{print $2}')"

# 使用v2ray官方命令安装v2ray并修改用户为www-data和重新加载服务文件
# 1.官方命令安装v2ray
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh
bash install-release.sh
bash install-dat-release.sh
# 2.修改v2ray日志目录权限为www-data
chown -R www-data.www-data /var/log/v2ray
# 3.修改v2ray默认用户为www-data
sed -i '/User=nobody/cUser=www-data' /etc/systemd/system/v2ray.service
sed -i '/User=nobody/cUser=www-data' /etc/systemd/system/v2ray@.service
# 4.重新加载v2ray服务文件
systemctl daemon-reload


##安装acme,并申请加密证书
source ~/.bashrc
if nc -z localhost 443;then /etc/init.d/nginx stop;fi
if ! [ -d /root/.acme.sh ];then curl https://get.acme.sh | sh;fi
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$domainName" -k ec-256 --alpn
~/.acme.sh/acme.sh --installcert -d "$domainName" --fullchainpath $ssl_dir/v2ray.crt --keypath $ssl_dir/v2ray.key --ecc
chown www-data.www-data $ssl_dir/v2ray.*

## 把续签证书命令添加到计划任务
echo -n '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi


# 配置nginx【如下80服务块完全可以不需要】，执行如下命令即可添加nginx配置文件
echo "
server {
	listen 80;
	server_name "$domainName";
	return 301 https://"'$host'""'$request_uri'";
}
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name "$domainName";
	ssl_certificate $ssl_dir/v2ray.crt;
	ssl_certificate_key $ssl_dir/v2ray.key;
	ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
	ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
	root /usr/share/nginx/html;

	# ------------------- WS配置部分开始 -------------------
	location = "$vless_ws_path" {
		proxy_redirect off;
		proxy_pass http://unix:"${vless_ws_domainSock}";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
        	proxy_set_header Host "'"$host"'";
        	proxy_set_header X-Real-IP "'"$remote_addr"'";
        	proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}	
	
	location = "$trojan_ws_path" {
		proxy_redirect off;
		proxy_pass http://unix:"${trojan_ws_domainSock}";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	        proxy_set_header Host "'"$host"'";
	        proxy_set_header X-Real-IP "'"$remote_addr"'";
	        proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}	
	
	location = "$socks_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$socks_ws_port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	        proxy_set_header Host "'"$host"'";
	        proxy_set_header X-Real-IP "'"$remote_addr"'";
	        proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}
	
	location = "$shadowsocks_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$shadowsocks_ws_port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	        proxy_set_header Host "'"$host"'";
	        proxy_set_header X-Real-IP "'"$remote_addr"'";
	        proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";	
	}	
	# ------------------- WS配置部分结束 -------------------

	# ------------------ gRPC配置部分开始 ------------------
	location ^~ "/$vless_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://unix:"${vless_grpc_domainSock}";		
	}
	
	location ^~ "/$trojan_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://unix:"${trojan_grpc_domainSock}";	
	}	
	
	location ^~ "/$socks_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://127.0.0.1:"$socks_grpc_port";	
	}
	
	location ^~ "/$shadowsocks_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://127.0.0.1:"$shadowsocks_grpc_port";		
	}	
	# ------------------ gRPC配置部分结束 ------------------	

}
" > /etc/nginx/conf.d/v2ray.conf

# 配置v2ray，执行如下命令即可添加v2ray配置文件
echo '
{
  "log" : {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
	{
		"listen": '"\"${vless_ws_domainSock}\""',
		"protocol": "vless",
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
				"path": '"\"$vless_ws_path\""'
			}
		}
	},
	{
		"listen": '"\"$trojan_ws_domainSock\""',
		"protocol": "trojan",
		"settings": {
			"decryption":"none",		
			"clients": [
				{
					"password": '"\"$trojan_passwd\""',
					"email": "",
					"level": 0
				}
			],
			"udp": true
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$trojan_ws_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$socks_ws_port\""',
		"protocol": "socks",
		"settings": {
			"auth": "password",
			"accounts": [
				{
					"user": '"\"$socks_user\""',
					"pass": '"\"$socks_passwd\""'
				}
			],
			"level": 0,
			"udp": true
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$socks_ws_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$shadowsocks_ws_port\""',
		"protocol": "shadowsocks",
		"settings": {
			"decryption":"none",
			"email": "",
			"method": "AES-128-GCM",
			"password": '"\"$shadowsocks_passwd\""',
			"level": 0,
			"network": "tcp,udp",
			"ivCheck": false
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$shadowsocks_ws_path\""'
			}
		}
	},
  	{
		"listen": '"\"${vless_grpc_domainSock}\""',
		"protocol": "vless",
		"settings": {
			"decryption":"none",
			"clients": [
				{
				"id": '"\"$uuid\""',
				"level": 0
				}
			]
		},
		"streamSettings":{
			"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$vless_grpc_path\""'
			}
		}
	},
	{
		"listen": '"\"$trojan_grpc_domainSock\""',
		"protocol": "trojan",
		"settings": {
			"decryption":"none",
			"clients": [
				{
					"password": '"\"$trojan_passwd\""',
					"email": "",
					"level": 0
				}
			]
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$trojan_grpc_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$socks_grpc_port\""',
		"protocol": "socks",
		"settings": {
			"decryption":"none",
			"auth": "password",
			"accounts": [
				{
					"user": '"\"$socks_user\""',
					"pass": '"\"$socks_passwd\""'
				}
			],
			"level": 0,
			"udp": true
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$socks_grpc_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$shadowsocks_grpc_port\""',
		"protocol": "shadowsocks",
		"settings": {
			"decryption":"none",
			"email": "",
			"method": "AES-128-GCM",
			"password": '"\"$shadowsocks_passwd\""',
			"network": "tcp,udp",
			"ivCheck": false,
			"level": 0
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$shadowsocks_grpc_path\""'
			}
		}
	}	
  ],
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
      "domainStrategy": "IPIfNonMatch",
      "rules": [
        {
          "domain": [
              "geosite:cn"
          ],
          "outboundTag": "blocked",
          "type": "field"
        },      
        {
            "ip": [
                "geoip:cn"
            ],
            "outboundTag": "blocked",
            "type": "field"
        }
      ]
  },  
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
' > /usr/local/etc/v2ray/config.json

# 重启v2ray和nginx
systemctl restart v2ray
systemctl status v2ray
/usr/sbin/nginx -t && systemctl restart nginx


# 输出配置信息并保存到文件
v2ray_config_info="/root/v2ray_config.info"
echo "
----------- 所有连接方式统一域名和端口 -----------
域名	: $domainName
端口	: 443

------------- WS传输 ------------
-----------1. vless+ws -----------
协议	: vless
UUID	 : $uuid
路径	: $vless_ws_path

-----------2. trojan+ws -----------
协议	: trojan
密码	: $trojan_passwd
路径	: $trojan_ws_path

-----------3. socks+ws ------------
协议	: socks
用户	：$socks_user	
密码	: $socks_passwd
路径	: $socks_ws_path

-------- 4. shadowsocks+ws ---------
协议	: shadowsocks
密码	: $shadowsocks_passwd
加密	：AES-128-GCM
路径	: $shadowsocks_ws_path

------------ gRPC传输 -----------
------------5. vless+grpc -----------
协议	: vless
UUID	: $uuid
路径	: $vless_grpc_path
-----------6. trojan+grpc -----------
协议	: trojan
密码	: $trojan_passwd
路径	: $trojan_grpc_path
-----------7. socks+grpc ------------
协议	: socks
用户	：$socks_user
密码	: $socks_passwd
路径	: $socks_grpc_path
--------8. shadowsocks+grpc ---------
协议	: shadowsocks
密码	: $shadowsocks_passwd
加密	：AES-128-GCM
路径	: $shadowsocks_grpc_path
" | tee $v2ray_config_info
