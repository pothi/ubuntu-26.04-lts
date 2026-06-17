#!/usr/bin/env fish

# requirements
# multipass LTS server named - rr
set lts rr

set ver 1.2

#TODO: Display the time to execute the functions.

# changelog
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
set -x DEBIAN_FRONTEND noninteractive
set time_start
set time_end
set run_time

function manage-multipass --description 'Manage multipass servers'
    argparse 'c/create' 'd/delete' 'u/update' -- $argv
    or return

    if test (count $argv_opts) -eq 0
        echo Usage: manage-m.fish -c/--create -d/--delete
        return 0
    end

    if set -ql _flag_create
        __bootstrap
        __delete_test
        __update_lts
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

    if set -q _flag_update
        __bootstrap
        __update_lts
        __cleanup
        return 0
    end

end

function __bootstrap
    echo Script started on "$(date +%c)"
    echo
    set time_start (date +%s)
end

function __cleanup
    echo
    set time_end (date +%s)
    set run_time (math $time_end - $time_start)
    echo Execution time: $run_time seconds
    echo Script ended on "$(date +%c)"
    echo
end

function __create_test
    echo Current servers list...
    multipass list

    multipass list | grep -qw '^test'
    if test $status -ne 0
        multipass clone -n test $lts
        echo A test server is created from Resolute Raccoon.
        multipass start test
        echo Test server has been started.
        multipass set client.primary-name=test
        echo Test server is made as primary.
    else
        echo The test server exists.
    end
    echo
end

function __delete_test
    multipass set client.primary-name=$lts
    echo Resolute Raccoon is made as primary server.

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

function __update_lts
    multipass set client.primary-name=$lts
    echo Set Resolute Raccoon as primary server.
    echo 'Starting the (primary) server...'
    multipass start
    echo Refreshing apt cache...
    multipass exec $lts -- sudo apt-get update -qq
    echo 'Updating packages (if any)...'
    multipass exec $lts -- sudo apt-get upgrade -y -qq
    echo 'Removing packages (if any)...'
    multipass exec $lts -- sudo apt-get autoremove -y -qq
    multipass stop
    echo Stopped Resolute Raccoon server.
    echo
end

manage-multipass $argv 2>&1 | tee -a ~/log/multipass.log
