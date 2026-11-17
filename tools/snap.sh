#!/bin/zsh
# Snapshots of every Settings pane, Help and About in light and dark. Reads settings, never changes them.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=settings,help,about tools/snap.sh
set -u
app=/Applications/MenuBarManager.app/Contents/MacOS/MenuBarManager
shots=/tmp/MenuBarManager-shots
rm -rf $shots
APP_SNAPSHOT=$shots $app
