#!/bin/bash
# usage: run.sh <src_dir> <work_dir> <out_dir>
SRC=$1; W=$2; OUT=$3; mkdir -p "$W" "$OUT"
for f in "$SRC"/*.part00; do b=$(basename "$f" .part00); cat "$SRC/$b".part* > "$SRC/$b"; done
xtract(){ # recursive extraction of zip/rar inside dir
  for i in 1 2 3; do
    find "$1" -type f \( -iname '*.zip' -o -iname '*.rar' -o -iname '*.7z' \) | while read -r z; do
      d="${z%.*}_x"; [ -d "$d" ] && continue; mkdir -p "$d"
      case "${z,,}" in *.zip) unzip -oq "$z" -d "$d" || 7z x -y -o"$d" "$z" >/dev/null;; *) unrar x -o+ -inul "$z" "$d/" || 7z x -y -o"$d" "$z" >/dev/null;; esac
    done
  done
}
grep -v '^#' assets.txt | while read -r id kind cap tex nrm; do
  [ -z "$id" ] && continue
  if [ -n "$ONLY" ] && ! echo " $ONLY " | grep -q " $id "; then continue; fi
  d="$W/$id"; mkdir -p "$d"
  if [ -f "$SRC/$id.glb" ]; then cp "$SRC/$id.glb" "$d/"; elif [ -f "$SRC/$id.zip" ]; then unzip -oq "$SRC/$id.zip" -d "$d"; else echo "MISSING $id"; continue; fi
  xtract "$d"
  k=$kind; [ "$kind" = kit ] && k=kit
  timeout 900 blender -b --factory-startup -P process.py -- "$d" "$OUT" "$id" "$k" "$cap" "$tex" "${nrm:-0}" > "$OUT/$id.log" 2>&1
  grep "^REPORT" "$OUT/$id.log" | sed "s/^REPORT //" >> "$OUT/report.jsonl"
  grep -q "^REPORT" "$OUT/$id.log" || echo "{\"id\":\"$id\",\"error\":\"crash\",\"tail\":$(tail -c 400 "$OUT/$id.log" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}" >> "$OUT/report.jsonl"
  echo "done $id"; rm -rf "$d"
done
