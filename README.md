# v2ray纯净安装（及shadowsocks纯净安装），基于手动纯净部署命令的整理，内容一目了然。你可以理解为你手动执行时的每一个复制粘贴和修改文件的命令的合集，批处理而已
# 一分钟v2ray：vmess+websocket+tls+nginx
# 一分钟v2ray：vless+websocket+tls+nginx
# v2ray 一键安装，只需30s

解析好域名

# vmess安装：

终端执行命令: curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s "你的解析好的域名"
# EG：
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s kty.v2ray.one

# ---------------------------------------------------------------------

# vless安装：

终端执行命令: curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vless.sh | bash -s "你的解析好的域名"
或: 
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s "你的解析好的域名" vless
# EG：
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vless.sh | bash -s kty.v2ray.one

或

curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s kty.v2ray.one vless

vultr 6美元机器只需要不到30s部署完成【https://www.vultr.com/?ref=8773909】

你完全不需要任何干预，一键执行脚本稍等片刻就好

######################################### 详细配置说明如下 #########################################

nginx做前端代理，根据域名和websocket路径，分发请求到v2ray服务，或默认的nginx站点目录/usr/share/nginx/html，不对你现有的nginx web服务产生影响

该方案不影响nginx作为前端代理和web服务的性能，v2ray只是其一个后端服务，类似PHP或Java

你可以很愉快的玩耍你自己的站点，如wordpress

---------------------- 配置文件一览： ----------------------

v2ray配置文件路径： /usr/local/etc/v2ray/config.json

nginx配置文件路径： /etc/nginx/conf.d/v2ray.conf


# # shadowsocks部署 shadowsocks-libev with obfs
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/shadowsocks-libev_with_obfs_installation.sh | bash

# # v2ray&wordpress安装部署
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_wordpress_installation.sh | bash -s "你的解析好的域名" [vless]
# EG:
#安装v2ray vmess协议 和 wordpress:

curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_wordpress_installation.sh | bash -s "www.v2ray.one"

#安装v2ray vless协议 和 wordpress:

curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_wordpress_installation.sh | bash -s "www.v2ray.one" vless

## 客户端配置
# 客户端下载： https://github.com/2dust/v2rayN/releases  选择最新稳定版下载
# 如：
# https://github.com/HappyLife-page/v2ray/issues/2#issuecomment-955123386
