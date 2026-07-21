#!/usr/bin/env fish

set user_timezone UTC

# bootstrap a Ubuntu Resolute Raccoon (26.04) server

set ver 1.4

# functions {{{
if not type -q check_status
    function check_status -a return_value error_message
        if test $return_value -ne 0
            printf '\n%s\n' "$error_message"
            exit $return_value
        end
    end
end

function iAPT -a package
    if not dpkg-query -W -f='${Status}' $package 2>/dev/null | grep -q "ok installed"
        printf '%-66s' "Installing '$package' ..."
        DEBIAN_FRONTEND=noninteractive apt-get -qq install $package > /dev/null 2> /dev/null
        echo done.
    end
end

function install_base_packages
    set -l pkg_list awscli \
        curl \
        dnsutils \
        fail2ban \
        git \
        kitty-terminfo \
        memcached \
        mycli \
        powermgmt-base \
        dma bsd-mailx \
        software-properties-common \
        sudo \
        unzip \
        wget

    # Conditionally add packages only on minimized Ubuntu images
    if test -f /usr/bin/unminimize
        set -a pkg_list cron net-tools vim
    end
    # echo Base packages List... $pkg_list

    # === Filter out already installed packages ===
    set -l to_install
    for pkg_name in $pkg_list
        # if not dpkg-query -W -f='${Status}' $pkg_name 2>/dev/null | string match -q "install ok installed"
        if not dpkg-query -W -f='${Status}' $pkg_name 2>/dev/null | grep -q "ok installed"
            set -a to_install $pkg_name
        end
    end

    set -l pkg_list $to_install

    if test -n "$pkg_list"
        echo Base packages List... $pkg_list

        printf '%s' "Installed packages... "
        for pkg_name in $pkg_list
            DEBIAN_FRONTEND=noninteractive apt-get -qq install $pkg_name > /dev/null 2> /dev/null
            check_status $status "Error: Could not install $pkg_name"
            printf '%s ' $pkg_name
        end
        echo;echo
    end
end

function install_php_fpm_package
    set -l VER
    if test (count $argv) -eq 1
        set VER $argv[1]
    else
        set VER $php_ver
    end
    # echo "PHP VERSION: $VER"

    set -l pkg_list \
        php$VER-common \
        php$VER-mysql \
        php$VER-gd \
        php$VER-cli \
        php$VER-xml \
        php$VER-mbstring \
        php$VER-soap \
        php$VER-curl \
        php$VER-zip \
        php$VER-bcmath \
        php$VER-intl \
        php$VER-imagick \
        php$VER-fpm

    # keep a single whitespace while removing others
    # set pkg_list (string replace -ra '\s+' ' ' $pkg_list)
    # echo PHP-FPM packages List... $pkg_list
    # exit

    if not dpkg-query -W -f='${Status}' php$VER-fpm 2>/dev/null | grep -q "ok installed"
        echo Installing php-fpm... it may take an average of 30 seconds...
        set -l start_time (date +%s)
        DEBIAN_FRONTEND=noninteractive apt-get -qq install $pkg_list >/dev/null
        echo "(php-fpm) Installation Time: $(math $(date +%s) - $start_time) seconds."
        echo;echo
        # else
        # echo PHP-FPM is already installed.
        # apt-get -qq remove $pkg_list
    end

end
# }}}

fish_is_root_user; or check_status 1 'This script requires root privilege.'

# set debug to non-empty value to enable tracing and/or debugging
set debug
set fish_trace $debug

set -x DEBIAN_FRONTEND noninteractive
set -x PATH /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin
test -d /snap/bin; and set -a PATH /snap/bin # applicable only on Ubuntu

# default PHP version in Ubuntu 26.04 (Resolute Raccoon)
set php_ver 8.5

# update apt cache if it wasn't updated in the last hour.
if test -z "$(find /var/cache/apt/pkgcache.bin -mmin -60)"
    printf '%-66s' 'Refreshing APT cache...'
    apt-get update -qq &>/dev/null
    check_status $status 'Could not refresh apt cache.'
    echo done.
else
    echo APT cache was refreshed less than an hour ago.
end
echo

# configure apt timeout
echo 'Acquire::http::timeout "20";' > /etc/apt/apt.conf.d/90-timeout.conf
echo 'Acquire::https::timeout "20";' >> /etc/apt/apt.conf.d/90-timeout.conf

# Swap

free | awk '/^Swap:/ {exit !$2}'
if test $status -eq 0
    echo Swap already exists.
else
    set -l func_path /etc/fish/functions
    if not test -f $func_path/manage-swap.fish
        printf '%-66s' 'Downloading a function script to manage swap... '
        curl -sSL --output-dir $func_path -O https://github.com/pothi/wp-box/raw/refs/heads/main/func/manage-swap.fish
        check_status $status 'Could not download swap.fish'
        echo done.
        echo manage-swap.fish is downloaded to $func_path
    else
        echo manage-swap.fish file already exists at $func_path
    end

    manage-swap -c 1
end
echo

install_base_packages

iAPT mysql-server
iAPT nginx
# install certbot (if nginx is found)

install_php_fpm_package $php_ver

set -l LOAD_ENV /etc/fish/functions/load_env.fish
if not test -f $LOAD_ENV
    curl -sSL https://github.com/pothi/snippets/raw/refs/heads/main/fish/functions/load_env.fish > $LOAD_ENV
    source $LOAD_ENV
end

if test -f ~/.env
    if type -q load_env
        load_env ~/.env
    else
        echo "'load_env' function doesn't exist."
    end
    # echo CERTBOT Account Email: $CERTBOT_ACCOUNT_EMAIL
    # echo Alert Email: $ALERT_EMAIL
end

# TODO: Configure nginx (from pothi/wordpress-nginx)
# TODO: Configure php-fpm
# TODO: Install certbot if nginx is present

# Configure VIM
if not test -f ~/.config/vim/vimrc
    curl -s https://codeberg.org/pothi/vim/raw/branch/main/vimrc-manager.fish | fish
end

# changelog
# 1.6
#   - date: 2026-07-21
#   - change name from envsource to load_env
# 1.5
#   - date: 2026-07-08
#   - install php-fpm packages
#   - configure vim only once
#   - configure envsource function
# 1.4
#   - date: 2026-07-03
#   - add cron, net-tools and vim on minimal server package
#   - install mysql-server and nginx
#   - configure VIM
#   - improve and use iAPT function
#   - better output
# 1.3
#   - date: 2026-06-08
#   - add awscli
#   - fix package name
#   - improve formatting
# version: 1.2
#   - date: 2026-06-04
#   - add packages for local email
# version: 1.1
#   - date: 2026-03-30
#   - add MySQL
#   - install base packages
