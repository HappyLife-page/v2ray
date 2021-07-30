# v2ray纯净安装，基于手动纯净部署命令的整理，内容一目了然。你可以理解为你手动执行时的每一个复制粘贴和修改文件的命令的合集，批处理而已
# 一分钟v2ray：vmess+websocket+tls+nginx
# 一分钟v2ray：vless+websocket+tls+nginx
# v2ray 一键安装，只需30s

解析好域名

vmess安装：

终端执行命令 curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s "你的解析好的域名"
# EG：
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s kty.v2ray.one

# ------------------------------------------------------------------------------------------------------------------------------------

vless安装：

终端执行命令 curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vless.sh | bash -s "你的解析好的域名"
# EG：
curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vless.sh | bash -s kty.v2ray.one

vultr 5美元机器只需要不到30s部署完成【https://www.vultr.com/?ref=8773909】

你完全不需要任何干预，一键执行脚本稍等片刻就好

######################################### 详细配置说明如下 #########################################

nginx做前端代理，根据域名和websocket路径，分发请求到v2ray服务，或默认的nginx站点目录/usr/share/nginx/html，不对你现有的nginx web服务产生影响

该方案不影响nginx作为前端代理和web服务的性能，v2ray只是其一个后端服务，类似PHP或Java

你可以很愉快的玩耍你自己的站点，如wordpress

---------------------- 配置文件一览： ----------------------

v2ray配置文件路径： /usr/local/etc/v2ray/config.json

nginx配置文件路径： /etc/nginx/conf.d/v2ray.conf
