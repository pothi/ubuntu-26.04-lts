#!/usr/bin/fish

set -l ver 1.0

set REDIS_CONF "/etc/redis/redis.conf"
set INCLUDE_LINE "include /etc/redis/conf.d/*.conf"
set redis_sysctl_file '/etc/sysctl.d/local-redis.conf'

# Verify root privileges
if not fish_is_root_user
    echo 'This script requires sudo / root privilege.' >&2
    exit 1
end

# Ensure the conf.d directory exists
mkdir -p /etc/redis/conf.d

# Check if the configuration file exists
if not test -f $REDIS_CONF
    echo "Error: $REDIS_CONF not found." >&2
    exit 1
end

# Check if the wildcard include line already exists in the file
if grep -Fxq "$INCLUDE_LINE" $REDIS_CONF
    echo "The wildcard include directive is already present in $REDIS_CONF. No changes made."
else
    echo "Appending wildcard include directive with a clean separator to $REDIS_CONF..."

    # Check the very last character of the file.
    # If the file already ends with an empty line (two consecutive newlines: \n\n),
    # we don't need to add another blank line.
    set -l last_two_bytes (tail -c 2 $REDIS_CONF | od -An -t x1 | string trim | string replace -a " " "")

    if test "$last_two_bytes" = "0a0a"
        # File already ends in a blank line, just append the directive
        set APPEND_BLOCK "$INCLUDE_LINE"
    else
        # File ends in text or a single newline; prepend a blank line for padding
        set APPEND_BLOCK "\n$INCLUDE_LINE"
    end

    # Append the block cleanly using printf to safely parse the explicit \n
    if printf "%b\n" "$APPEND_BLOCK" >> $REDIS_CONF
        echo "Successfully added the wildcard include path with a clean spacing separator."
        echo "You can now drop any *.conf files into /etc/redis/conf.d/ and restart Redis."
    else
        echo "Failed to update the file." >&2
        exit 1
    end
end

# To fix a warning in /var/log/redis/redis-server.log file
# WARNING Memory overcommit must be enabled! Without it, a background save or replication may fail under low memory condition. Being disabled, it can can also cause failures without low memory condition, see https://github.com/jemalloc/jemalloc/issues/1328. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.
# Also see: https://redis.io/docs/latest/operate/oss_and_stack/management/admin/
printf "vm.overcommit_memory = 1\n" > $redis_sysctl_file
# Load settings from the redis sysctl file
sysctl --quiet --load $redis_sysctl_file

# TODO: Configure memory and memory policy
# TODO: https://redis.io/tutorials/operate/redis-at-scale/talking-to-redis/#set-tcp-backlog
# TODO: Disable THB as mentioned at https://redis.io/docs/latest/operate/oss_and_stack/management/admin/#linux
# ref: https://github.com/pothi/wp-in-a-box/blob/main/scripts/redis.sh
# also see: https://github.com/pothi/wp-in-a-box/issues/51#issuecomment-343657080
