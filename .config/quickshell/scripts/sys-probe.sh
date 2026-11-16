#!/bin/sh
tp=
for p in /sys/class/thermal/thermal_zone*/temp; do
    [ -f "$p" ] || continue
    t=$(cat "${p%temp}type" 2>/dev/null)
    case "$t" in x86_pkg_temp|cpu-thermal|coretemp) tp=$p; break ;; esac
done
printf 'TEMP|%s\n' "$tp"
if [ -d /sys/class/power_supply/BAT0 ]; then printf 'BAT|1\n'; else printf 'BAT|0\n'; fi
