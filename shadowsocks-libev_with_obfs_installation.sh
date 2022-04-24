#!/bin/bash
# Desc : ss-libev with obfs installation
# 	Ubuntu 18.04+
# Auth : Happylife


# 更新源
apt clean all && apt update

# 安装编译需要使用的依赖
apt install git vim gettext build-essential autoconf libtool libpcre3-dev libev-dev libc-ares-dev automake libmbedtls-dev libsodium-dev libssl-dev pwgen -y 

# ss安装包名
ss_name="shadowsocks-libev"

# 指定ss版本号
ss_version="3.3.5"

# ss完整包名(包名-版本号)
ss_fullName="${ss_name}-${ss_version}"

# 定义ss源码包下载路径
ss_sourcePath="/usr/local/src"

# 定义ss安装目录
ss_dir="/usr/local/${ss_fullNmae}"

# IP地址与随机生成服务端口和密码
ss_ip="$(curl ifconfig.me 2>/dev/null)"
ss_port="`shuf -i 2000-36000 -n 1`"
ss_password="$(pwgen -cny -r "\"\\;'\`" 26 1)"


# 下载shadowsocks-libev源码并解压
wget -c https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${ss_version}/${ss_fullName}.tar.gz -O - | tar xz -C "${ss_sourcePath}/"

# 配置shadowsocks-libev编译安装
cd "${ss_sourcePath}/${ss_fullName}" && ./configure --disable-documentation --prefix="${ss_dir}" && make && make install

# 下载simple-obfs插件
cd "${ss_sourcePath}" && git clone https://github.com/shadowsocks/simple-obfs.git

# 编译安装simple-obfs插件
cd simple-obfs && git submodule update --init --recursive && ./autogen.sh && ./configure --disable-documentation --prefix=/usr/local/simple-obfs && make && make install

# 添加obfs-server软链到ss-libev能从环境变量找到的地方
ln -s /usr/local/simple-obfs/bin/obfs-server /usr/local/bin/obfs-server


# 创建ss-libev目录与配置文件(仅支持IPv4的写法: "server":"0.0.0.0",)
mkdir /etc/shadowsocks-libev
echo '
{
    "server":["[::0]","0.0.0.0"],
    "server_port":'"${ss_port}"',
    "password":"'"${ss_password}"'",
    "timeout":300,
    "method":"chacha20-ietf-poly1305",
    "nameserver":"8.8.8.8",
    "fast_open":false,
    "mode":"tcp_and_udp",
    "plugin":"obfs-server",
    "plugin_opts":"obfs=http"
}
' > /etc/shadowsocks-libev/config.json


# 添加ss-libev服务管理文件
echo "
[Unit]
Description=Shadowsocks-libev
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=${ss_dir}/bin/ss-server -c /etc/shadowsocks-libev/config.json

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/shadowsocks-libev.service


# 加载ss-libev服务并添加开机启动
systemctl daemon-reload
systemctl enable shadowsocks-libev

# 启动ss-libev服务并查看服务状态
systemctl start shadowsocks-libev
systemctl status shadowsocks-libev

# 输出IP端口和密码
echo "
地址：$ss_ip
端口: $ss_port
密码: $ss_password
加密：chacha20-ietf-poly1305
插件：obfs-local
选项：obfs=http
"
