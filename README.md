# 一分钟v2ray：vmess+websocket+tls+nginx
# 一分钟xray：vless+tcp+xtls+nginx
# v2ray/xray 一键安装，只需30s

解析好域名

v2ray安装：
1. 执行curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s "你的解析好的域名" "22222-55555之间的一个五位数"
2. EG： curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/v2ray_installation_vmess.sh | bash -s kty.v2ray.one 33299

xray安装：
1. 执行curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/xray_installation_vless_xtls.sh | bash -s "你的解析好的域名"
2. EG： curl -s https://raw.githubusercontent.com/HappyLife-page/v2ray/main/xray_installation_vless_xtls.sh | bash -s kty.v2ray.one

vultr 5美元机器只需要不到30s部署完成

你完全不需要任何干预，一键执行脚本稍等片刻就好

================================ 详细配置说明如下 ================================

1. v2ray安装：  nginx+websocket+tls+vmess

nginx做前端代理，根据域名和websocket路径，分发请求到v2ray服务，或默认的nginx站点目录/usr/share/nginx/html，不对你现有的nginx web服务产生影响

该方案不影响nginx作为前端代理和web服务的性能，v2ray只是其一个后端服务，类似PHP或Java

你可以很愉快的玩耍你自己的站点，如wordpress

---------------------- v2ray配置文件一览： ----------------------

v2ray配置文件路径： /usr/local/etc/v2ray/config.json

nginx配置文件路径： /etc/nginx/conf.d/v2ray.conf


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


2. xray安装： nginx+tcp+xtls+vless

nginx做前端代理，分发443端口到xray，回落到nginx默认站点目录/usr/share/nginx/html，但需要你了解nginx端口复用才能灵活配置你自己其他的站点（不建议使用回落方式作为你的其他站点）

该方案不影响nginx作为前端代理和web服务的性能，xray只是其一个后端服务，类似PHP或Java

你可以很愉快的玩耍你自己的站点，如wordpress

---------------------- xray配置文件一览： ----------------------

xray配置文件路径： /usr/local/etc/xray/config.json

nginx配置文件路径： /etc/nginx/conf.d/xray.conf
                   /etc/nginx/modules-enabled/stream.conf
