#!/bin/zsh
# Runs the in-app self-test. Exit code 0 when every check passed. Reads settings, never changes them.
set -u
/Applications/MenuBarManager.app/Contents/MacOS/MenuBarManager --selftest
