#!/usr/bin/env fish

# requirements
# multipass LTS server named - rr (Resolute Raccoon)
set lts_abbr rr
set lts_name 'Resolute Raccoon'

set ver 1.7

# {{{ changelog
# 1.7
#   - date: 2026-08-04
#   - fix for hanging for needrestart
# 1.5
#   - date: 2026-07-17
#   - stop LTS server (if running)
#   - fix double-upgrade issue
#   - improve variable names and output info
# 1.4
#   - date: 2026-07-03
#   - rename create to clone
#   - clone process doesn't include updating $lts_abbr server
# 1.3
#   - date: 2026-06-27
#   - double upgrade pass for fresh clones
#   - better DEBIAN_FRONTEND handling inside multipass exec
#   - keep real warnings visible
#   - improve logging / output.
# 1.2
#   - date: 2026-06-08
#   - fix formatting.
# 1.1
#   - date: 2026-06-07
#   - better flow of commands.
# 1.0
#   - date: 2026-03-30
#   - create a test server automatically
#   - add a log file
# }}}

set --local PATH ~/.local/bin ~/bin /usr/local/bin /usr/bin /sbin /bin
set time_start

function manage-multipass --description 'Manage multipass servers'
    argparse 'c/clone' 'd/delete' 'u/update=' -- $argv
    or return

    if test (count $argv_opts) -eq 0
        echo "Usage: manage-multipass.fish -c/--clone -d/--delete -u/--update="
        return 0
    end

    if set -ql _flag_clone
        __bootstrap
        __delete_test
        __create_test
        __cleanup
        osascript -e 'display notification "Bootstrap completed!" with title "Multipass manager"' 2>/dev/null
        return 0
    end

    if set -ql _flag_delete
        __bootstrap
        __delete_test
        __cleanup
        return 0
    end

    if set -ql _flag_update
        __bootstrap
        # echo Update flag is set.
        # echo "Update flag value: '$_flag_update'"
        __update_server $_flag_update
        __cleanup
        return 0
    end
end

function __bootstrap
    echo "Script started on $(date +%c)"
    echo
    set time_start (date +%s)
end

function __cleanup
    echo
    set -l time_end (date +%s)
    set -l run_time (math $time_end - $time_start)
    echo "Execution time: $run_time seconds"
    echo "Script ended on $(date +%c)"
    echo
end

function __create_test
    multipass list | grep -qw '^test'
    if test $status -ne 0
        multipass stop $lts_abbr
        echo "$lts_name is stopped (if running)"

        multipass clone -n test $lts_abbr
        echo A test server is cloned from $lts_name
        multipass start test
        echo "Test server is started."
        multipass set client.primary-name=test
        echo "Test server is made as primary."
    else
        echo "The test server already exists." >&2
    end

    echo "Current servers list..."
    multipass list
    echo
end

function __delete_test
    multipass set client.primary-name=$lts_abbr
    echo $lts_name is made as primary server.

    multipass list | grep -qw '^test'
    if test $status -eq 0
        echo Hold on while deleting the test server...
        multipass delete test
        echo Test server is deleted.

        multipass purge
        echo Purged unused resources.
    else
        echo Test server does not exist.
    end

    echo Current servers list...
    multipass list
    echo
end

function __update_server --description "Updates server packages"
    if test (count $argv) -eq 0
        echo "Function Usage: __update_server <name>"
        return 1
    end

    set --local _server_abbr $argv[1]
    set --local _server_name
    if test -z $_server_abbr
        set _server_abbr rr
    end

    if test $_server_abbr = '='
        set _server_abbr rr
    end

    if test $_server_abbr = "rr"
        set _server_name 'Resolute Raccoon'
    end

    multipass list | grep -qw "^$_server_abbr"
    if test $status -ne 0
        echo "The supplied server '$_server_abbr' is not found. So, it can not be updated." >&2
        exit
    end

    echo "Starting the server $_server_name"
    multipass start $_server_abbr

    printf '\t%s\n' "Refreshing apt cache..."
    multipass exec $_server_abbr -- sudo apt-get update -qq

    printf '\t%s\n' 'Applying upgrades (including phased and kernel packages)...'
    multipass exec $_server_abbr -- sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 UCF_FORCE_CONFFOLD=1 \
        apt-get dist-upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" >/dev/null

    printf '\t%s\n' 'Removing unnecessary packages...'
    multipass exec $_server_abbr -- sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 UCF_FORCE_CONFFOLD=1 \
        apt-get autoremove -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" >/dev/null

    multipass stop $_server_abbr
    echo "Stopped the server $_server_name"
    echo
end

manage-multipass $argv 2>&1 | tee -a ~/log/multipass.log

# vim:foldmethod=marker
