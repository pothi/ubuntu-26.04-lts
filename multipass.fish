#!/usr/bin/env fish

# requirements
# multipass LTS server named - rr
set lts rr

set ver 1.3

# changelog
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

set --local PATH ~/.local/bin ~/bin /usr/local/bin /usr/bin /sbin /bin
set time_start

function manage-multipass --description 'Manage multipass servers'
    argparse 'c/create' 'd/delete' 'u/update=' -- $argv
    or return

    if test (count $argv_opts) -eq 0
        echo "Usage: manage-multipass.fish -c/--create -d/--delete -u/--update="
        return 0
    end

    if set -ql _flag_create
        __bootstrap
        __delete_test
        __update_server $lts
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
    echo "Current servers list..."
    multipass list

    multipass list | grep -qw '^test'
    if test $status -ne 0
        multipass clone -n test $lts
        echo "A test server is created from Resolute Raccoon."
        multipass start test
        echo "Test server has been started."
        multipass set client.primary-name=test
        echo "Test server is made as primary."
    else
        echo "The test server does not exist." >&2
    end
    echo
end

function __delete_test
    multipass set client.primary-name=$lts
    echo "Resolute Raccoon is made as primary server."

    multipass list | grep -qw '^test'
    if test $status -eq 0
        echo "Hold on while deleting the test server..."
        multipass delete test
        echo "Test server is deleted."

        multipass purge
        echo "Purged unused resources."
    else
        echo "Test server does not exist."
    end

    echo "Current servers list..."
    multipass list
    echo
end

function __update_server --description "Updates server packages"
    if test (count $argv) -eq 0
        echo "Function Usage: __update_server <name>"
        return 1
    end

    set --local _server $argv[1]
    if test -z $_server
        set _server rr
    end

    if test $_server = '='
        set _server rr
    end

    multipass list | grep -qw "^$_server"
    if test $status -ne 0
        echo "The supplied server '$_server' is not found. So, it can not be updated." >&2
        exit
    end

    echo 'Starting the server Resolute Raccoon ...'
    multipass start $_server

    printf '\t%s\n' "Refreshing apt cache..."
    multipass exec $_server -- sudo apt-get update -qq

    printf '\t%s\n' 'Updating packages (if any)...'
    multipass exec $_server -- sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

    # Second pass catches packages that only become available after first update
    printf '\t%s\n' 'Running second upgrade pass (important for fresh clones)...'
    multipass exec $_server -- sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

    printf '\t%s\n' 'Removing unnecessary packages...'
    multipass exec $_server -- sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq

    multipass stop $_server
    echo "Stopped the server Resolute Raccoon"
    echo
end

manage-multipass $argv 2>&1 | tee -a ~/log/multipass.log
