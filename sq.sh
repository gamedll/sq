#!/bin/bash

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
    sudo apt-get update

    # 检查并安装 Squid
    if ! command -v squid >/dev/null 2>&1; then
        sudo apt-get install -y squid
    fi

    # 检查并安装 Apache 工具（用于生成密码文件）
    if ! command -v htpasswd >/dev/null 2>&1; then
        sudo apt-get install -y apache2-utils
    fi

    # 检查并安装 fail2ban
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        sudo apt-get install -y fail2ban
    fi

    # 备份原始 Squid 配置文件
    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.original

    # 创建密码文件并添加用户
    sudo htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

    # 创建新的 Squid 配置文件
    cat <<EOF | sudo tee /etc/squid/squid.conf
http_port 62300
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid proxy-caching web server
auth_param basic credentialsttl 2 hours
auth_param basic casesensitive off
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

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

    # 配置 fail2ban
    # ...（fail2ban 配置代码部分与之前相同）

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
