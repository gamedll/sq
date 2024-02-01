#!/bin/bash
# Script to install Squid Proxy Server
# Author: 4298059@qq.com
# Date: 2024-01-31
# 检测操作系统类型
OS_TYPE=$(awk -F= '/^ID=/ { print $2 }' /etc/os-release)

INSTALL_CMD=""
if [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "ubuntu" ]; then
    INSTALL_CMD="sudo apt-get"
elif [ "$OS_TYPE" = "centos" ] || [ "$OS_TYPE" = "fedora" ] || [ "$OS_TYPE" = "rhel" ]; then
    INSTALL_CMD="sudo dnf"
else
    # 尝试检查 /etc/centos-release 文件来确定是否是 CentOS
    if [ -f /etc/centos-release ]; then
        OS_TYPE="centos"
        INSTALL_CMD="sudo dnf"
    else
        echo "不支持的操作系统类型。"
        exit 1
    fi
fi

# 生成随机用户名和密码的函数
generate_random_credentials() {
    local user_chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local pass_chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+'
    
    # 生成6位用户名
    USERNAME=$(for i in {1..6}; do echo -n "${user_chars:RANDOM%${#user_chars}:1}"; done)
    
    # 生成12位密码
    PASSWORD=$(for i in {1..12}; do echo -n "${pass_chars:RANDOM%${#pass_chars}:1}"; done)

    echo "生成的用户名: $USERNAME"
    echo "生成的密码: $PASSWORD"
}

echo "请输入您要执行的操作："
echo "1. 安装"
echo "2. 卸载"
read -p "选择操作（1 或 2）: " ACTION

if [ "$ACTION" == "1" ]; then
    # 用户输入用户名和密码
    read -p "请输入用户名: " USERNAME
    read -sp "请输入密码: " PASSWORD
    echo

    # 更新系统包
    sudo ${INSTALL_CMD} update -y

    # 检查并安装 Squid
    if ! command -v squid >/dev/null 2>&1; then
        sudo ${INSTALL_CMD} install -y squid
    fi

    # 检查并安装 Apache 工具（用于生成密码文件）
    if ! command -v htpasswd >/dev/null 2>&1; then
        if [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "ubuntu" ]; then
            sudo ${INSTALL_CMD} install -y apache2-utils
        elif [ "$OS_TYPE" = "centos" ] || [ "$OS_TYPE" = "fedora" ] || [ "$OS_TYPE" = "rhel" ]; then
            sudo ${INSTALL_CMD} install -y httpd-tools
        fi
    fi

    # 检查并安装 fail2ban
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        sudo ${INSTALL_CMD} install -y fail2ban
    fi

    # 备份原始 Squid 配置文件
    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.original

    # 创建密码文件并添加用户
    sudo htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

    # 创建新的 Squid 配置文件
    cat <<EOF | sudo tee /etc/squid/squid.conf
http_port 0.0.0.0:3128
acl all src 0.0.0.0/0.0.0.0                 #允许所有IP访问
acl manager proto http                 #manager url协议为http
acl localhost src 127.0.0.1/255.255.255.255  #允午本机IP
acl to_localhost dst 127.0.0.1                 #允午目的地址为本机IP
acl Safe_ports port 80                # 允许安全更新的端口为80
acl CONNECT method CONNECT        #请求方法以CONNECT
dns_v4_first on
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid proxy-caching web server
auth_param basic credentialsttl 2 hours
auth_param basic casesensitive off
acl authenticated proxy_auth REQUIRED
http_access allow all
http_reply_access allow all   
http_access allow authenticated
acl OverConnLimit maxconn 20        #限制每个IP最大允许16个连接，防止攻击
http_access deny OverConnLimit
#禁止从邻居服务器缓冲内发送和接收ICP请求.
icp_access deny all   
#允许直接更新请求
miss_access allow all               
ident_lookup_access deny all                                #禁止lookup检查DNS
http_port 8080 transparent                                #指定Squid监听浏览器客户请求的端口号。
max_open_disk_fds 0                                 #允许最大打开文件数量,0 无限制
minimum_object_size 1 KB                         #允午最小文件请求体大小
maximum_object_size 20 MB                 #允午最大文件请求体大小

cache_swap_low 90                            #最小允许使用swap 90%
cache_swap_high 95                            #最多允许使用swap 95%

ipcache_size 2048                                # IP 地址高速缓存大小 2M
ipcache_low 90                                #最小允许ipcache使用swap 90%
ipcache_high 95                                  #最大允许ipcache使用swap 90%

request_entities off                                        #禁止非http的标分准请求，防止攻击
header_access header allow all                        #允许所有的http报头
relaxed_header_parser on                                #不严格分析http报头.
client_lifetime 120 minute                                #最大客户连接时间 120分钟

acl baidu req_header User-Agent Baiduspider
http_access deny baidu

#限制同一IP客户端的最大连接数
acl OverConnLimit maxconn 128
http_access deny OverConnLimit

# 高匿名设置
forwarded_for delete
via off
request_header_access From deny all
request_header_access Server deny all
request_header_access WWW-Authenticate deny all
request_header_access Link deny all
request_header_access Cache-Control deny all
request_header_access Proxy-Connection deny all
request_header_access X-Cache deny all
request_header_access X-Cache-Lookup deny all
request_header_access Via deny all
request_header_access X-Forwarded-For deny all
request_header_access Pragma deny all
request_header_access Keep-Alive deny all
EOF

    # 重启 Squid 服务以应用配置
    sudo systemctl restart squid

    # 配置 fail2ban 以监控 Squid 的认证失败
    cat <<EOF | sudo tee /etc/fail2ban/jail.local
[squid]
enabled = true
filter = squid
action = iptables[name=Squid, port=3128, protocol=tcp]
logpath = /var/log/squid/access.log
maxretry = 10
bantime = 3600
EOF
    
    # 创建 fail2ban 的 Squid 过滤器
    cat <<EOF | sudo tee /etc/fail2ban/filter.d/squid.conf
[Definition]
failregex = ^.* \[squid.*\] .* 401 Unauthorized.*
ignoreregex =
EOF

    # 重启 fail2ban 服务以应用配置
    sudo systemctl restart fail2ban

    echo "安装和配置完成。"
elif [ "$ACTION" == "2" ]; then
    # 停止并卸载 Squid 和 fail2ban 服务
    sudo systemctl stop squid
    sudo systemctl stop fail2ban
    sudo apt-get remove --purge -y squid fail2ban
    echo "Squid 和 fail2ban 已卸载。"
else
    echo "无效的选择。"
fi
