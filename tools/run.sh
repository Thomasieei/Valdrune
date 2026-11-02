#!/bin/bash
# usage: tools/run.sh res://scenes/x.tscn [args...]
cd /home/claude/royaume
SCENE=$1; shift
timeout ${TMO:-300} xvfb-run -a -s "-screen 0 1280x720x24" /home/claude/tools/Godot_v4.3-stable_linux.x86_64 --path . --resolution 1280x720 "$SCENE" -- "$@" < /dev/null 2>&1 | grep -vE '^\s+at: |ALSA|audio|dummy driver|Unreferenced static' 
