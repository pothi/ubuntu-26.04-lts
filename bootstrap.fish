#!/usr/bin/env fish

# bootstrap a Ubuntu Resolute Raccoon (26.04) server

set ver 1.1

# changelog
# version: 1.1
#   - date: 2026-03-30
#   - add MySQL
#   - install base packages

# functions {{{
if not type -q check_status
    function check_status -a return_value error_message
        if test $return_value -ne 0
            echo $error_message
            exit $return_value
        end
    end
end

if not type -q ensure_pkg
    function ensure_pkg -a pkg_name
        dpkg-query -W -f='${Status}' $pkg_name 2>/dev/null | grep -q "ok installed"
        if test $status -ne 0
            apt-get -qq install $pkg_name &> /dev/null
            check_status $status 'Could not install $pkg_name'
        end
    end
end

function install_base_packages
    set -l pkg_list curl \
    dnsutils \
    fail2ban \
    git \
    memcached \
    powermgmt-base \
    software-properties-common \
    sudo \
    unzip \
    wget

    echo 'The following packages will be installed (if not installed)'
    echo $pkg_list

    echo Installed packages...
    for pkg_name in $pkg_list
        ensure_pkg $pkg_name
        printf '%s ' $pkg_name
    end
    echo;echo
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
    printf '%-72s' 'Refreshing APT cache...'
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
        printf '%-72s' 'Downloading a function script to manage swap... '
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

printf '%-72s' "Installing mysql (if not installed)..."
ensure_pkg mysql-server
echo done.
echo

install_base_packages

# vim:foldmethod=marker
