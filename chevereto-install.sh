#!/bin/bash

install_tools() {
    echo "开始安装必要工具..."
    sudo apt-get install -y make unzip curl git
    echo "工具安装完成！"
}

clone_docker_project() {
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

setup_https_proxy() {
    echo "正在设置 NGINX 的 HTTPS 代理..."
    read -p "请输入您的邮箱以进行 HTTPS 设置: " email_https
    make proxy EMAIL_HTTPS=$email_https
    echo "HTTPS 代理设置完成！"
}

set_namespace() {
    echo "设置您的项目的命名空间..."
    read -p "请输入您的命名空间: " namespace
    read -p "请输入您的主机名: " hostname
    make namespace NAMESPACE=$namespace HOSTNAME=$hostname
    echo "命名空间设置完成！"
    return $namespace
}

build_chevereto_image() {
    echo "请稍等，正在构建 Chevereto 镜像..."
    make image LICENSE=$chevereto_license
    echo "Chevereto 镜像构建完成！"
}

spawn_chevereto_site() {
    echo "正在生成 Chevereto 网站..."
    namespace=$(set_namespace)
    if [ ! -z "$chevereto_license" ]; then
        make spawn NAMESPACE=$namespace
    else
        make spawn NAMESPACE=$namespace EDITION=free
    fi
    echo "Chevereto 网站生成完成！"
}


main() {
    PS3='请选择您要执行的操作: '
    options=("安装" "增加命名空间" "退出")
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
                spawn_chevereto_site
                break
                ;;
            "增加命名空间")
                set_namespace
                break
                ;;
            "退出")
                break
                ;;
            *) echo "无效选项 $REPLY";;
        esac
    done
}

main
