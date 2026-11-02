#!/bin/bash
cd /home/claude/royaume
for f in $(find scripts -name "*.gd"); do
  out=$(timeout 60 /home/claude/tools/Godot_v4.3-stable_linux.x86_64 --headless --path . --check-only --script $f < /dev/null 2>&1 | grep -E 'SCRIPT ERROR|Parse Error' -A1 | grep -v 'Failed to load' | head -4)
  [ -n "$out" ] && echo "== $f" && echo "$out"
done; echo checked
