#!/usr/bin/env fish

# Multipass manager
# Requirements: a server with the name rr

set ver 1.0

# changelog
# version: 1.0
#   - date: 2026-03-30
#   - create a test server automatically
#   - add a log file

set --local PATH ~/.local/bin ~/bin /usr/local/bin /usr/bin /sbin /bin
set -x DEBIAN_FRONTEND noninteractive
set time_start
set time_end
set run_time

test -d ~/log; or mkdir -p ~/log

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
        __update_rr
        __create_test
        __cleanup
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
        __update_rr
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
        multipass clone -n test rr
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
    multipass list | grep -qw '^test'
    if test $status -eq 0
        echo Hold on while deleting the test server...
        multipass delete test
        echo Test server is deleted.
    else
        echo Test server does not exist.
    end

    multipass purge
    echo Purged unused resources.
    multipass set client.primary-name=rr
    echo Resolute Raccoon is made as primary server.

    echo Current servers list...
    multipass list
    echo
end

function __update_rr
    multipass set client.primary-name=rr
    echo Set Resolute Raccoon as primary server.
    echo Starting the server...
    multipass start
    echo Refreshing apt cache...
    multipass exec rr -- sudo apt-get update -qq
    echo 'Updating packages (if any)...'
    multipass exec rr -- sudo apt-get upgrade -y -qq
    echo 'Removing packages (if any)...'
    multipass exec rr -- sudo apt-get autoremove -y -qq
    multipass stop
    echo Stoppeg Resolute Raccoon server.
    echo
end

manage-multipass $argv 2>&1 | tee -a ~/log/multipass.log
