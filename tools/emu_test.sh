#!/bin/bash
# Scénario joué sur le téléphone émulé : lancement, marche, attaques, sorts, saut, esquive. Captures + journal.
set -x
mkdir -p emu
adb install -r out/test.apk
adb shell wm size > emu/screen.txt
adb logcat -c
adb shell monkey -p fr.thomas.studiolab -c android.intent.category.LAUNCHER 1
sleep 40
cap() { adb exec-out screencap -p > "emu/$1.png"; }
cap 01_lancement
# écran paysage 2400x1080 ; viewport Godot 1600x720 → facteur 1.5
J="300 870"
adb shell input swipe 300 870 300 560 5000 & sleep 3; cap 02_marche; wait
adb shell input swipe 300 870 600 870 4000 & sleep 2.5; cap 03_marche_droite; wait
for i in 1 2 3 4; do adb shell input tap 2190 870; sleep 0.4; done; cap 04_attaques
adb shell input tap 1942 937; sleep 1.2; cap 05_sort1_arret_temps
sleep 2.5; adb shell input tap 1965 723; sleep 1.0; cap 06_sort2_portail_ange
adb shell input tap 2133 585; sleep 0.8; cap 07_sort3_soin
adb shell input tap 2313 603; sleep 1.0; cap 08_sort4_lame
adb shell input tap 1747 987; sleep 0.4; cap 09_saut
adb shell input tap 1725 810; sleep 0.4; cap 10_esquive
adb shell input swipe 300 870 300 560 12000 & sleep 10; cap 11_place; wait
adb logcat -d > emu/logcat_full.txt
grep -iE "godot|SCRIPT ERROR|FATAL|crash|ANR" emu/logcat_full.txt | tail -400 > emu/logcat_godot.txt
adb shell dumpsys meminfo fr.thomas.studiolab | head -40 > emu/memoire.txt
adb shell pidof fr.thomas.studiolab > emu/pid.txt || echo "APP MORTE" > emu/pid.txt
true
