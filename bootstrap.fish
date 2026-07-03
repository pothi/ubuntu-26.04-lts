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

# TODO: Configure nginx (from pothi/wordpress-nginx)
# TOOD: Install php-fpm

# Configure VIM
curl -s https://codeberg.org/pothi/vim/raw/branch/main/vimrc-manager.fish | fish

# changelog
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

# vim:foldmethod=marker
