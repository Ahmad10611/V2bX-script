#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}خطا:${plain} باید با کاربر root این اسکریپت را اجرا کنید!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
    echo -e "${red}اسکریپت در حال حاضر از سیستم alpine پشتیبانی نمی‌کند!${plain}\n" && exit 1
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}نسخه سیستم عامل شناسایی نشد، لطفا با نویسنده اسکریپت تماس بگیرید!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}شناسایی معماری ناموفق بود، استفاده از معماری پیش‌فرض: ${arch}${plain}"
fi

echo "معماری: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "این نرم‌افزار از سیستم 32 بیتی (x86) پشتیبانی نمی‌کند، لطفا از سیستم 64 بیتی (x86_64) استفاده کنید. اگر شناسایی اشتباه است، با نویسنده تماس بگیرید."
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}لطفا از CentOS 7 یا نسخه‌های بالاتر استفاده کنید!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}توجه: CentOS 7 از پروتکل‌های hysteria1/2 پشتیبانی نمی‌کند!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}لطفا از Ubuntu 16 یا نسخه‌های بالاتر استفاده کنید!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}لطفا از Debian 8 یا نسخه‌های بالاتر استفاده کنید!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
        yum install ca-certificates wget -y
        update-ca-trust force-enable
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
        apt-get install ca-certificates wget -y
        update-ca-certificates
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/V2bX.service ]]; then
        return 2
    fi
    temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_V2bX() {
    if [[ -e /usr/local/V2bX/ ]]; then
        rm -rf /usr/local/V2bX/
    fi

    mkdir /usr/local/V2bX/ -p
    cd /usr/local/V2bX/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/Ahmad10611/V2bX/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}شناسایی نسخه V2bX ناموفق بود، ممکن است از محدودیت API Github عبور کرده باشید، لطفا بعدا دوباره تلاش کنید، یا به صورت دستی نسخه V2bX را نصب کنید${plain}"
            exit 1
        fi
        echo -e "نسخه جدید V2bX شناسایی شد: ${last_version}، نصب آغاز شد"
        wget -q -N --no-check-certificate -O /usr/local/V2bX/V2bX-linux.zip https://github.com/Ahmad10611/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}دانلود V2bX ناموفق بود، لطفا مطمئن شوید که سرور شما قادر به دانلود فایل‌های Github است${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Ahmad10611/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"
        echo -e "نصب V2bX $1 آغاز شد"
        wget -q -N --no-check-certificate -O /usr/local/V2bX/V2bX-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}دانلود V2bX $1 ناموفق بود، لطفا مطمئن شوید که این نسخه وجود دارد${plain}"
            exit 1
        fi
    fi

    unzip V2bX-linux.zip
    rm V2bX-linux.zip -f
    chmod +x V2bX
    mkdir /etc/V2bX/ -p
    rm /etc/systemd/system/V2bX.service -f
    file="https://github.com/Ahmad10611/V2bX-script/raw/master/V2bX.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/V2bX.service ${file}
    #cp -f V2bX.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop V2bX
    systemctl enable V2bX
    echo -e "${green}V2bX ${last_version}${plain} نصب شد، تنظیم شد برای شروع به کار در هنگام روشن شدن سیستم"
    cp geoip.dat /etc/V2bX/
    cp geosite.dat /etc/V2bX/

    if [[ ! -f /etc/V2bX/config.json ]]; then
        cp config.json /etc/V2bX/
        echo -e ""
        echo -e "نصب جدید، لطفا ابتدا آموزش را مشاهده کنید: https://v2bx.v-50.me/ و موارد ضروری را پیکربندی کنید"
        first_install=true
    else
        systemctl start V2bX
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}V2bX با موفقیت راه‌اندازی شد${plain}"
        else
            echo -e "${red}V2bX ممکن است راه‌اندازی نشود، لطفا بعدا با استفاده از V2bX log اطلاعات لاگ را مشاهده کنید، اگر نمی‌تواند راه‌اندازی شود، ممکن است فرمت پیکربندی تغییر کرده باشد، لطفا به ویکی مراجعه کنید: https://github.com/V2bX-project/V2bX/wiki${plain}"
        fi
        first_install=false
    fi

    if [[ ! -f /etc/V2bX/dns.json ]]; then
        cp dns.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/route.json ]]; then
        cp route.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/V2bX/
    fi
    curl -o /usr/bin/V2bX -Ls https://raw.githubusercontent.com/Ahmad10611/V2bX-script/master/V2bX.sh
    chmod +x /usr/bin/V2bX
    if [ ! -L /usr/bin/v2bx ]; then
        ln -s /usr/bin/V2bX /usr/bin/v2bx
        chmod +x /usr/bin/v2bx
    fi
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "نحوه استفاده از اسکریپت مدیریت V2bX (سازگار با استفاده از V2bX، حساس به حروف بزرگ و کوچک نیست): "
    echo "------------------------------------------"
    echo "V2bX              - نمایش منوی مدیریت (ویژگی‌های بیشتر)"
    echo "V2bX start        - شروع V2bX"
    echo "V2bX stop         - متوقف کردن V2bX"
    echo "V2bX restart      - راه‌اندازی مجدد V2bX"
    echo "V2bX status       - مشاهده وضعیت V2bX"
    echo "V2bX enable       - تنظیم V2bX برای شروع به کار هنگام روشن شدن سیستم"
    echo "V2bX disable      - لغو تنظیم شروع به کار V2bX هنگام روشن شدن سیستم"
    echo "V2bX log          - مشاهده لاگ‌های V2bX"
    echo "V2bX x25519       - تولید کلید x25519"
    echo "V2bX generate     - تولید فایل پیکربندی V2bX"
    echo "V2bX update       - به‌روزرسانی V2bX"
    echo "V2bX update x.x.x - به‌روزرسانی V2bX به نسخه مشخص"
    echo "V2bX install      - نصب V2bX"
    echo "V2bX uninstall    - حذف V2bX"
    echo "V2bX version      - مشاهده نسخه V2bX"
    echo "------------------------------------------"
    # پرسش نصب اولیه در مورد تولید فایل پیکربندی
    if [[ $first_install == true ]]; then
        read -rp "شناسایی شد که اولین نصب V2bX شما است، آیا می‌خواهید به طور خودکار فایل پیکربندی را تولید کنید؟ (y/n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            curl -o ./initconfig.sh -Ls https://raw.githubusercontent.com/Ahmad10611/V2bX-script/master/initconfig.sh
            source initconfig.sh
            rm initconfig.sh -f
            generate_config_file
        fi
    fi
}

echo -e "${green}شروع نصب${plain}"
install_base
install_V2bX $1
