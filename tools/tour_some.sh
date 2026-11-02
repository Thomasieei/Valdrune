#!/bin/bash
# lance la tournée sur un sous-ensemble (filtre par sous-chaîne)
cd /home/claude/royaume
TMO=${TMO:-1500} tools/run.sh res://scenes/royaume.tscn --tour "$1" 2>&1 | grep -vE 'WARNING|inconsistent' > shots/tour_$1.log
