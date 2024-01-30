#!/bin/bash

# 检测操作系统类型
OS_TYPE=$(awk -F= '/^ID=/ { print $2 }' /etc/os-release)

INSTALL_CMD=""
if [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "ubuntu" ]; then
    INSTALL_CMD="sudo apt-get"
    sudo apt-get update -y
elif [ "$OS_TYPE" = "centos" ] || [ "$OS_TYPE" = "fedora" ] || [ "$OS_TYPE" = "rhel" ]; then
    INSTALL_CMD="sudo yum"
    sudo dnf update -y
else
    echo "不支持的操作系统类型。"
    exit 1
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
    read -p "请输入用户名 (留空自动生成): " USERNAME
    read -sp "请输入密码 (留空自动生成): " PASSWORD
    echo

    # 如果用户名或密码为空，则生成随机的
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        generate_random_credentials
    fi

    # 更新系统包
    ${INSTALL_CMD} update

    # 检查并安装 Squid
    if ! command -v squid >/dev/null 2>&1; then
        ${INSTALL_CMD} install -y squid
    fi

    # 检查并安装 Apache 工具（用于生成密码文件）
    if ! command -v htpasswd >/dev/null 2>&1; then
        ${INSTALL_CMD} install -y httpd-tools
    fi

    # 检查并安装 fail2ban
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        ${INSTALL_CMD} install -y fail2ban
    fi

    # 备份原始 Squid 配置文件
    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.original

    # 创建密码文件并添加用户
    sudo htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

    # 创建新的 Squid 配置文件
    # ...（Squid 配置部分）

    # 重启 Squid 服务以应用配置
    sudo systemctl restart squid

    # 配置 fail2ban
    # ...（fail2ban 配置部分）

    # 重启 fail2ban 服务以应用配置
    sudo systemctl restart fail2ban

    echo "安装和配置完成。"

elif [ "$ACTION" == "2" ]; then
    # 卸载操作
    sudo systemctl stop squid
    sudo systemctl stop fail2ban
    ${INSTALL_CMD} remove --purge -y squid fail2ban
    echo "Squid 和 fail2ban 已卸载。"
else
    echo "无效的选择。"
fi
