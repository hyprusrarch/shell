#!/bin/sh
u=$(find /sys/class/drm -name mem_info_vram_used 2>/dev/null | head -n 1)
if [ -n "$u" ]; then
    t="${u%used}total"
    printf 'AMD: %s/%s MiB\n' "$(( $(cat "$u") / 1048576 ))" "$(( $(cat "$t") / 1048576 ))"
elif command -v nvidia-smi >/dev/null 2>&1; then
    nv=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,nounits,noheader 2>/dev/null)
    if [ -n "$nv" ]; then printf 'NVIDIA: %s / %s MiB\n' "${nv%,*}" "${nv#*,}"; else printf 'NVIDIA: N/A\n'; fi
else
    printf 'No GPU\n'
fi
