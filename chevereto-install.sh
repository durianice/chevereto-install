#!/bin/bash、

welcome() {
    echo '                              '
    echo '                              '
    echo '  ____            _    _      '
    echo ' / ___|___   ___ | | _(_) ___ '
    echo '| |   / _ \ / _ \| |/ / |/ _ \'
    echo '| |__| (_) | (_) |   <| |  __/'
    echo ' \____\___/ \___/|_|\_\_|\___|'
    echo '                              '
    echo '                              '
}

work_dir=/opt/chevereto
install_tools() {
    echo "开始安装必要工具..."
    sudo apt-get install -y make unzip curl git lsof
    if [ $? -ne 0 ]; then
        echo "必要工具安装失败，请检查网络或手动安装！"
        exit 0
    fi
    echo "工具安装完成！"
}

clone_docker_project() {
    mkdir -p ${work_dir}
    cd ${work_dir}
    echo "克隆 Docker 项目..."
    git clone https://github.com/chevereto/docker.git
    cd docker
    echo "克隆完成！"
}

setup_cron_job() {
    echo "设置系统任务的后台作业..."
    make cron
    echo "后台作业设置完成！"
}

final_port=443
setup_https_proxy() {
    echo "正在设置 NGINX 的 HTTPS 代理..."
    read -p "请输入映射端口（默认宿主机 80）: " http_port
    if [ ! -z "$http_port" ]; then
        check_port $http_port
        sed -i "s/--publish 80:80/--publish $http_port:80/g" Makefile
    fi
    read -p "请输入映射端口（默认宿主机 443）: " https_port
    if [ ! -z "$https_port" ]; then
        check_port $https_port
        sed -i "s/--publish 443:443/--publish $https_port:443/g" Makefile
        final_port=$https_port
    fi
    read -p "请输入您的邮箱: " email_https
    make proxy EMAIL_HTTPS=$email_https
    echo "HTTPS 代理设置完成！"
}

set_namespace() {
    echo "设置您的网站名称..."
    read -p "请输入您的网站名称（小写字母数字字符、连字符和下划线，并且以字母或数字开头）: " namespace
    if [ -z "$namespace" ]; then
        echo "网站名称不能为空！"
        exit 0
    fi
    if [ -f "${work_dir}/docker/namespace/$namespace" ]; then
        echo "网站已存在！"
        exit 0
    fi
    read -p "请输入您的主机名（解析到当前VPS的域名如：aaa.bbb.com）: " hostname
    if [ -z "$hostname" ]; then
        echo "主机名不能为空！"
        exit 0
    fi
    make namespace NAMESPACE=$namespace HOSTNAME=$hostname
    echo "网站名称设置完成！$namespace"
}

build_chevereto_image() {
    echo "请稍等，正在构建 Chevereto 镜像..."
    make image LICENSE=$chevereto_license
    echo "Chevereto 镜像构建完成！"
}

spawn_chevereto_site() {
    echo "正在生成 Chevereto 网站..."
    if [ ! -z "$chevereto_license" ]; then
        make spawn NAMESPACE=$namespace
    else
        make spawn NAMESPACE=$namespace EDITION=free
    fi
    echo "Chevereto 网站生成完成！"
    echo "请打开浏览器访问：https://$hostname:$final_port"
}

remove_namespace() {
    namespace_select
    read -rp "确认是否删除，数据不可恢复！如需删除请按Y，按其他键则退出 [Y/N]: " yn
    if [[ $yn =~ "Y"|"y" ]]; then
        backup_data $namespace_seleted
        echo "正在删除 $namespace_seleted 网站及数据..."
        cd ${work_dir}/docker
        make destroy NAMESPACE=$namespace_seleted
        docker network rm ${namespace_seleted}_chevereto_chevereto
        echo "$namespace_seleted 删除完成！"
    else
        exit 1
    fi
}

check_port(){
    port=$1
    
    echo "正在检测 $port 端口是否占用..."
    sleep 1
    
    if [[  $(lsof -i:"$port" | grep -i -c "listen") -eq 0 ]]; then
        echo "检测到目前 $port 端口未被占用"
        sleep 1
    else
        echo "检测到目前 $port 端口被其他程序被占用，以下为占用程序信息"
        lsof -i:"$port"
        read -rp "如需结束占用进程请按Y，按其他键则退出 [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            lsof -i:"$port" | awk '{print $2}' | grep -v "PID" | xargs kill -9
            sleep 1
        else
            exit 1
        fi
    fi
}

namespace_seleted=""
namespace_select() {
    cd ${work_dir}/docker
    ls namespace
    read -p "请输入您的网站名称: " namespace
    if [ -z "$namespace" ]; then
        echo "网站名称不能为空！"
        exit 0
    fi
    if [ ! -f "namespace/$namespace" ]; then
        echo "网站不存在！"
        exit 0
    fi
    namespace_seleted=$namespace
}

log() {
    service="php"
    cd ${work_dir}/docker
    namespace_select
    PS3='请选择要查看的服务: '
    options=("网页" "数据库" "退出")
    select opt in "${options[@]}"
    do
        case $opt in
            "网页")
                service="php"
                break
                ;;
            "数据库")
                service="database"
                break
                ;;
            "退出")
                break
                ;;
            *) 
                echo "无效选项 $REPLY"
                exit 0
                ;;
        esac
    done
    make log NAMESPACE=$namespace_seleted SERVICE=$service
}

nginx_proxy_manage() {
    cd ${work_dir}/docker
    PS3='请选择要执行的操作: '
    options=("查看" "重装" "卸载" "退出")
    select opt in "${options[@]}"
    do
        case $opt in
            "查看")
                make proxy--view
                break
                ;;
            "重装")
                setup_https_proxy
                break
                ;;
            "卸载")
                make proxy--remove
                docker network rm nginx-proxy
                break
                ;;
            "退出")
                break
                ;;
            *) 
                echo "无效选项 $REPLY"
                exit 0
                ;;
        esac
    done
}

backup_data() {
    echo "正在备份数据..."
    namespace=$1
    path=/var/lib/docker/volumes/${namespace}_chevereto_storage
    # 如果没有安装 zip 则进行安装
    if [ ! -x "$(command -v zip)" ]; then
        sudo apt-get install -y zip
    fi
    # 打包数据
    zip -r ${namespace}_chevereto_storage.zip $path
    mkdir -p /root/chevereto_back
    cp ${namespace}_chevereto_storage.zip /root/chevereto_back
    if [ $? -ne 0 ]; then
        echo "数据备份失败！"
        exit 0
    fi
    echo "数据备份完成！备份路径 /root/chevereto_back/${namespace}_chevereto_storage.zip"
}

main() {
    welcome
    PS3='请选择您要执行的操作: '
    options=("安装" "添加网站" "Nginx Proxy" "查看日志" "删除网站" "退出")
    select opt in "${options[@]}"
    do
        case $opt in
            "安装")
                install_tools
                clone_docker_project
                setup_cron_job
                setup_https_proxy
                read -p "如果您有 Chevereto 许可证，请输入（否则留空）: " chevereto_license
                if [ ! -z "$chevereto_license" ]; then
                    build_chevereto_image
                fi
                set_namespace
                spawn_chevereto_site
                break
                ;;
            "添加网站")
                set_namespace
                spawn_chevereto_site
                break
                ;;
            "Nginx Proxy")
                nginx_proxy_manage
                break
                ;;
            "查看日志")
                log
                break
                ;;
            "删除网站")
                remove_namespace
                break
                ;;
            "退出")
                break
                ;;
            *) 
                echo "无效选项 $REPLY"
                exit 0
                ;;
        esac
    done
}

main
