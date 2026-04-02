# Ubuntu 26.04 LTS

Scripts for Ubuntu 26.04 LTS named Resolute Raccoon

## Multipass Manager

Requirements:

A server with the name rr.

One-time setup:

Create a new server with the command...

`multipass launch --bridged --name rr resolute`

From here, you may use multipass.fish to create a test server based on `rr`.

You may use multipass.fish script to auto-update every day via cron.

The basic idea is to keep the core serever untouched, but to use a `test` server for development.

## Bootstrap Script

To install MySQL, PHP, web server (Nginx or Caddy) and configure some basics such as slow log.
