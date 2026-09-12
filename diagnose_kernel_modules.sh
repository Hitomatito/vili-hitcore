#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════════
# diagnose_kernel_modules.sh — vili-hitcore FULL Kernel Diagnostic
# Xiaomi 11T Pro (vili) — Snapdragon 888 (SM8350)
# Run: su -c sh /sdcard/diagnose_kernel_modules.sh
# Output: /sdcard/vili_hitcore_diagnostic_*.txt
# ═══════════════════════════════════════════════════════════════════

OUT="/sdcard/vili_hitcore_diagnostic_$(date +%Y%m%d_%H%M%S).txt"
MODDIR="/vendor/lib/modules"
TMP="/tmp/vili_diag"
rm -rf "$TMP"
mkdir -p "$TMP"

w()  { echo "$1" >> "$OUT"; }
ww() { echo "  $1" >> "$OUT"; }
hr() { w ""; w "────────────────────────────────────────────────────────"; }

# mksh-safe grep count helper (grep -c returns exit 1 on 0 matches)
gc() { local n; n=$(grep -c "$@" 2>/dev/null); echo "${n:-0}"; }
gci() { local n; n=$(grep -ci "$@" 2>/dev/null); echo "${n:-0}"; }
lc() { local n; n=$(logcat -d 2>/dev/null | grep -c "$@" 2>/dev/null); echo "${n:-0}"; }

# Pre-collect data
DMESG="$TMP/dmesg.txt"
dmesg > "$DMESG" 2>/dev/null
cat /proc/modules > "$TMP/modules.txt"
cat "$MODDIR/modules.dep" > "$TMP/modules.dep" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
w "╔════════════════════════════════════════════════════════════════╗"
w "║  vili-hitcore FULL Kernel Diagnostic Report                  ║"
w "║  $(date)                                     ║"
w "╚════════════════════════════════════════════════════════════════╝"

# ═══════════════════════════════════════════════════════════════════
# 1. SYSTEM INFO
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  1. SYSTEM INFORMATION"
w "══════════════════════════════════════════════════════════════════"
w ""
w "  Kernel:    $(uname -r)"
w "  Version:   $(uname -v | head -c 80)"
w "  Arch:      $(uname -m)"
w "  SELinux:   $(getenforce 2>/dev/null || echo 'N/A')"
w "  Android:   $(getprop ro.build.version.release 2>/dev/null)"
w "  SDK:       $(getprop ro.build.version.sdk 2>/dev/null)"
w "  Device:    $(getprop ro.product.device 2>/dev/null)"
w "  Model:     $(getprop ro.product.model 2>/dev/null)"
w "  Board:     $(getprop ro.board.platform 2>/dev/null)"
w "  Build:     $(getprop ro.build.display.id 2>/dev/null)"
w "  Root:      KSU $(ksud --version 2>/dev/null || echo '?')"
w "  Uptime:    $(cat /proc/uptime | awk '{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60);printf "%dd %dh %dm",d,h,m}')"

# Summary counts
TOTAL_DMESG=$(wc -l < "$DMESG")
SELINUX_COUNT=$(gc "type=1400" "$DMESG")
ERROR_COUNT=$(gci "error|fail" "$DMESG")
WARN_COUNT=$(gci "warn" "$DMESG")
CRASH_COUNT=$(lc "Fatal signal")
TOMBSTONE_COUNT=$(ls /data/tombstones/*.pb 2>/dev/null | wc -l)
TOMBSTONE_COUNT=${TOMBSTONE_COUNT:-0}

w ""
w "  ┌──────────────────────────────────────────────┐"
w "  │ DMESG TOTAL LINES:    $TOTAL_DMESG"
w "  │ SELinux denials:      $SELINUX_COUNT"
w "  │ Error/Fail messages:  $ERROR_COUNT"
w "  │ Warning messages:     $WARN_COUNT"
w "  │ Native crashes:       $CRASH_COUNT"
w "  │ Tombstones:           $TOMBSTONE_COUNT"
w "  └──────────────────────────────────────────────┘"
hr

# ═══════════════════════════════════════════════════════════════════
# 2. KERNEL CONFIG
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  2. KERNEL MODULE CONFIG"
w "══════════════════════════════════════════════════════════════════"
w ""
zcat /proc/config.gz > "$TMP/config.txt" 2>/dev/null

for key in MODULES MODULE_FORCE_LOAD MODULE_FORCE_UNLOAD DRM DRM_MSM \
           WLAN WLAN_QCA_CLD3 ICNSS2 QCA_CLD_WLAN \
           TOUCHSCREEN_ST_FTS_V521 TOUCHSCREEN_XIAOMI_TOUCHFEATURE \
           FINGERPRINT_GOODIX_TA FINGERPRINT_FPC_TEE \
           MI_THERMAL_INTERFACE MEDIA_CAMERA_SUPPORT \
           IR_SPI STMVL53L5; do
    val=$(grep "^CONFIG_${key}=" "$TMP/config.txt" 2>/dev/null)
    [ -z "$val" ] && continue
    case "$val" in
        *=y) ww "  ✓ $val (built-in)" ;;
        *=m) ww "  ○ $val (module)" ;;
        *=n) ww "  ✗ $val (disabled)" ;;
    esac
done
hr

# ═══════════════════════════════════════════════════════════════════
# 3. MODULE INVENTORY
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  3. MODULE INVENTORY"
w "══════════════════════════════════════════════════════════════════"
w ""

TOTAL_KO=$(ls "$MODDIR"/*.ko 2>/dev/null | wc -l)
TOTAL_LOADED=$(wc -l < "$TMP/modules.txt")
w "  .ko files in /vendor/lib/modules/: $TOTAL_KO"
w "  Modules in /proc/modules:          $TOTAL_LOADED"
w ""

LOADED_LIST="$TMP/loaded.txt"
awk '{print $1}' "$TMP/modules.txt" | sort > "$LOADED_LIST"

> "$TMP/vendor_ko.txt"
for f in "$MODDIR"/*.ko; do
    [ -f "$f" ] && basename "$f" .ko >> "$TMP/vendor_ko.txt"
done

BUILTIN_VENDOR="$TMP/builtin_vendor.txt"
NOTLOADED_LIST="$TMP/notloaded.txt"
STATUS_FILE="$TMP/all_status.txt"
> "$STATUS_FILE"
> "$BUILTIN_VENDOR"
> "$NOTLOADED_LIST"
TOTAL_BUILTIN=0
TOTAL_NOTLOADED=0

while IFS= read -r name; do
    ko_file="$MODDIR/${name}.ko"
    if grep -qx "$name" "$LOADED_LIST" 2>/dev/null; then
        echo "LOADED $name" >> "$STATUS_FILE"
    elif [ -d "/sys/module/$name" ] && ! grep -qx "$name" "$LOADED_LIST" 2>/dev/null; then
        echo "BUILTIN $name" >> "$STATUS_FILE"
        echo "$name" >> "$BUILTIN_VENDOR"
        TOTAL_BUILTIN=$((TOTAL_BUILTIN + 1))
    elif [ -f "$ko_file" ]; then
        echo "NOTLOADED $name" >> "$STATUS_FILE"
        echo "$name" >> "$NOTLOADED_LIST"
        TOTAL_NOTLOADED=$((TOTAL_NOTLOADED + 1))
    fi
done < "$TMP/vendor_ko.txt"

LOADED_COUNT=$(gc "^LOADED" "$STATUS_FILE")

w "  ┌─────────────────────────────────────────────────────────┐"
w "  │ Summary                                                 │"
w "  ├─────────────────────────────────────────────────────────┤"
w "  │  Loaded (Live):          $LOADED_COUNT / $TOTAL_KO"
w "  │  Built-in (=y):          $TOTAL_BUILTIN / $TOTAL_KO"
w "  │  NOT loaded:             $TOTAL_NOTLOADED / $TOTAL_KO"
w "  └─────────────────────────────────────────────────────────┘"
w ""

if [ "$TOTAL_BUILTIN" -gt 0 ]; then
    w "  ╔═════════════════════════════════════════════════════════╗"
    w "  ║ BUILT-IN VENDOR MODULES (=y) — .ko exists but won't   ║"
    w "  ║ load as module; will BLOCK dependent modules in dep   ║"
    w "  ╚═════════════════════════════════════════════════════════╝"
    while IFS= read -r name; do
        [ -f "$MODDIR/${name}.ko" ] && ww "  ✗ $name  →  BUILT-IN + .ko EXISTS"
    done < "$BUILTIN_VENDOR"
    w ""
fi

if [ "$TOTAL_NOTLOADED" -gt 0 ]; then
    w "  ╔═════════════════════════════════════════════════════════╗"
    w "  ║ NOT LOADED MODULES (.ko exists, module inactive)        ║"
    w "  ╚═════════════════════════════════════════════════════════╝"
    while IFS= read -r name; do
        deps=$(grep "^${MODDIR}/${name}.ko:" "$TMP/modules.dep" 2>/dev/null | sed "s|^${MODDIR}/${name}.ko:||" | sed "s|${MODDIR}/||g;s|\.ko||g;s|\.ko:||g")
        if [ -n "$deps" ]; then
            missing=""
            for d in $deps; do
                if ! grep -qx "$d" "$LOADED_LIST" 2>/dev/null && [ ! -d "/sys/module/$d" ] 2>/dev/null; then
                    missing="$missing $d"
                fi
            done
            if [ -n "$missing" ]; then
                ww "  ✗ $name  →  blocked by:$missing"
            else
                ww "  ⚠ $name  →  deps OK but not loaded"
            fi
        else
            ww "  ⚠ $name  →  no deps, reason unknown"
        fi
    done < "$NOTLOADED_LIST"
fi
hr

# ═══════════════════════════════════════════════════════════════════
# 4. DEPENDENCY CHAIN CONFLICTS
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  4. DEPENDENCY CHAIN CONFLICTS"
w "══════════════════════════════════════════════════════════════════"
w ""

CONFLICTS=0
while IFS= read -r bimod; do
    refs=$(grep "${bimod}.ko" "$TMP/modules.dep" 2>/dev/null | awk -F: '{print $1}' | sed "s|${MODDIR}/||;s|\.ko||")
    if [ -n "$refs" ]; then
        ww "  ✗ $bimod.ko (BUILT-IN)"
        for ref in $refs; do
            ww "    ↳ blocks: $ref"
        done
        CONFLICTS=$((CONFLICTS + 1))
    fi
done < "$BUILTIN_VENDOR"

if [ "$CONFLICTS" -eq 0 ]; then
    ww "  ✓ No dependency conflicts"
else
    w ""
    ww "  → $CONFLICTS built-in modules block others from loading"
fi
hr

# ═══════════════════════════════════════════════════════════════════
# 5. ALL DMESG ERRORS BY SUBSYSTEM
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  5. DMESG ERRORS BY SUBSYSTEM"
w "══════════════════════════════════════════════════════════════════"
w ""

# ── 5a. SELinux ──
w "  ── 5a. SELinux Denials ──"
w ""
if [ "$SELINUX_COUNT" -gt 0 ]; then
    SEL_DOMAINS=$(grep "type=1400" "$DMESG" 2>/dev/null | sed -n 's/.*scontext=u:r:\([^:]*\):.*/\1/p' | sort -u)
    DOM_COUNT=$(echo "$SEL_DOMAINS" | grep -c . 2>/dev/null)
    DOM_COUNT=${DOM_COUNT:-0}
    ww "  ✗ $SELINUX_COUNT SELinux denials from $DOM_COUNT unique source domains:"
    for dom in $SEL_DOMAINS; do
        dom_count=$(gc "scontext=u:r:${dom}:" "$DMESG")
        tclass=$(grep "scontext=u:r:${dom}:" "$DMESG" 2>/dev/null | sed -n 's/.*tclass=\([^ ]*\).*/\1/p' | sort -u | tr '\n' ',' | sed 's/,$//')
        ww "    $dom ($dom_count denials) → $tclass"
    done
    w ""
    ww "  Unique denials:"
    grep "type=1400" "$DMESG" 2>/dev/null | sed 's/.*avc:/avc:/' | sort -u | head -15 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ No SELinux denials"
fi
w ""

# ── 5b. Module loading ──
w "  ── 5b. Module Loading Errors ──"
w ""
MOD_FAIL=$(gci "module.*fail|module.*error|modprobe.*fail|insmod.*fail|exports duplicate" "$DMESG")
if [ "$MOD_FAIL" -gt 0 ]; then
    ww "  ✗ $MOD_FAIL module loading errors:"
    grep -iE "module.*fail|module.*error|modprobe.*fail|insmod.*fail|exports duplicate" "$DMESG" 2>/dev/null | sed 's/.*\] //' | sort -u | head -10 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ No module loading errors"
fi
w ""

# ── 5c. Camera subsystem ──
w "  ── 5c. Camera Subsystem ──"
w ""
CAM_ERR_DMSG=$(gci "cam_isp_err|cam_cpas_err|cam_isp.*fail|CSL.*fail|ISP.*fail|icp.*fail" "$DMESG")
CAM_FATAL=$(gci "CamX.*FATAL|camera.*abort|camera.*SIGABRT" "$DMESG")
CAM_LOGCAT_ERR=$(lc "CamX.*ERROR")
CAM_SEL=$(gc "avc.*denied.*hal_camera" "$DMESG")
if [ "$CAM_ERR_DMSG" -gt 0 ] || [ "$CAM_FATAL" -gt 0 ] || [ "$CAM_SEL" -gt 0 ] || [ "$CAM_LOGCAT_ERR" -gt 0 ]; then
    [ "$CAM_ERR_DMSG" -gt 0 ] && ww "  ✗ Camera driver errors (dmesg): $CAM_ERR_DMSG"
    [ "$CAM_FATAL" -gt 0 ] && ww "  ✗ Camera FATAL/ABORT (dmesg): $CAM_FATAL"
    [ "$CAM_LOGCAT_ERR" -gt 0 ] && ww "  ✗ CamX ERROR (logcat): $CAM_LOGCAT_ERR"
    [ "$CAM_SEL" -gt 0 ] && ww "  ✗ SELinux denials (camera HAL): $CAM_SEL"
    grep -iE "CamX.*ERROR|CSL.*fail|ISP.*fail" "$DMESG" 2>/dev/null | sed 's/.*\] //' | sort -u | head -5 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ Camera: CLEAN"
fi

for node in /dev/video0 /dev/video1 /dev/media0 /dev/media1; do
    [ -c "$node" ] && ww "  ✓ $node" || ww "  ✗ $node MISSING"
done

CAM_PID=$(pidof vendor.camera-provider-2-4 2>/dev/null)
[ -n "$CAM_PID" ] && ww "  ✓ Camera HAL running (pid=$CAM_PID)" || ww "  ✗ Camera HAL NOT running"
w ""

ww "  Firmware:"
for fw in CAMERA_ICP.elf CAMERA_ICP_170.elf; do
    [ -f "/vendor/firmware/$fw" ] && ww "    ✓ $fw" || ww "    ✗ $fw MISSING"
done

ISP_ERR=$(gci "cam_isp.*bind.*fail|ISP.*Mem Allocation|cam_cpas.*fail" "$DMESG")
[ "$ISP_ERR" -gt 0 ] && ww "  ✗ ISP init errors: $ISP_ERR"

TRACEFS_ERR=$(gc "Could not create tracefs" "$DMESG")
[ "$TRACEFS_ERR" -gt 0 ] && ww "  ✗ tracefs creation failures: $TRACEFS_ERR"
w ""

# ── 5d. WiFi / WLAN ──
w "  ── 5d. WiFi / WLAN ──"
w ""
WLAN_HAL=$(gc "Wifi HAL start failed" "$DMESG")
WLAN_ERR=$(gci "wlan.*fail|wifi.*fail|cnss.*fail|icnss.*fail" "$DMESG")
if [ "$WLAN_HAL" -gt 0 ] || [ "$WLAN_ERR" -gt 0 ]; then
    [ "$WLAN_HAL" -gt 0 ] && ww "  ✗ WiFi HAL start failures: $WLAN_HAL"
    [ "$WLAN_ERR" -gt 0 ] && ww "  ✗ WiFi driver errors: $WLAN_ERR"
else
    ww "  ✓ WiFi: CLEAN"
fi
for m in wlan icnss2 cnss2; do
    grep -q "^$m " "$TMP/modules.txt" 2>/dev/null && ww "  ✓ $m.ko: LOADED" || ww "  ✗ $m.ko: NOT LOADED"
done
w ""

# ── 5e. Audio ──
w "  ── 5e. Audio Subsystem ──"
w ""
AUDIO_MODS="apr_dlkm q6_dlkm q6_notifier_dlkm q6_pdr_dlkm adsp_loader_dlkm native_dlkm platform_dlkm bolero_cdc_dlkm pinctrl_lpi_dlkm pinctrl_wcd_dlkm wcd_core_dlkm wcd9xxx_dlkm wcd937x_dlkm wcd938x_dlkm swr_dlkm swr_ctrl_dlkm rx_macro_dlkm tx_macro_dlkm va_macro_dlkm wsa_macro_dlkm wsa883x_dlkm snd_event_dlkm hdmi_dlkm stub_dlkm cs35l41_dlkm"
A_LOADED=0; A_TOTAL=0; A_MISSING=""
for m in $AUDIO_MODS; do
    A_TOTAL=$((A_TOTAL + 1))
    grep -q "^$m " "$TMP/modules.txt" 2>/dev/null && A_LOADED=$((A_LOADED + 1)) || A_MISSING="$A_MISSING $m"
done
ww "  Audio modules: $A_LOADED / $A_TOTAL loaded"
[ -n "$A_MISSING" ] && ww "  ✗ Missing:$A_MISSING"

ACDB_ERR=$(gci "ACDB.*fail|ACDB_CMD.*Returned|cal_block not found|afe.*cal.*fail|send_afe_cal_type.*fail" "$DMESG")
[ "$ACDB_ERR" -gt 0 ] && ww "  ✗ ACDB calibration errors (dmesg): $ACDB_ERR"

ACDB_LOG=$(logcat -d 2>/dev/null | grep -ciE "ACDB.*Error|acdb.*fail" 2>/dev/null)
ACDB_LOG=${ACDB_LOG:-0}
[ "$ACDB_LOG" -gt 0 ] && ww "  ✗ ACDB errors (logcat): $ACDB_LOG"

SND_PCM_ERR=$(gc "snd_pcm_hw_constraint_integer failed" "$DMESG")
[ "$SND_PCM_ERR" -gt 0 ] && ww "  ⚠ snd_pcm_hw_constraint_integer failed: $SND_PCM_ERR times"
w ""

# ── 5f. Touch / Fingerprint ──
w "  ── 5f. Touch / Fingerprint ──"
w ""
for m in fts_touch_spi xiaomi_touch fpc1020_tee goodix_ta goodix_tee ir_spi; do
    if grep -q "^$m " "$TMP/modules.txt" 2>/dev/null; then
        ww "  ✓ $m: LOADED"
    elif [ -d "/sys/module/$m" ] 2>/dev/null; then
        ww "  ✓ $m: BUILT-IN"
    elif [ -f "$MODDIR/${m}.ko" ] 2>/dev/null; then
        ww "  ✗ $m: NOT LOADED"
    else
        ww "  ⚠ $m: not available"
    fi
done
w ""

# ── 5g. Thermal ──
w "  ── 5g. Thermal ──"
w ""
if [ -d "/sys/module/mi_thermal_interface" ] 2>/dev/null; then
    ww "  ✓ mi_thermal_interface: BUILT-IN"
elif grep -q "^mi_thermal_interface " "$TMP/modules.txt" 2>/dev/null; then
    ww "  ✓ mi_thermal_interface: LOADED"
elif [ -f "$MODDIR/mi_thermal_interface.ko" ] 2>/dev/null; then
    ww "  ✗ mi_thermal_interface: NOT LOADED"
fi
THERMAL_ERR=$(gci "thermal.*throttl|thermal.*shutdown|thermal.*trip|overheat" "$DMESG")
[ "$THERMAL_ERR" -gt 0 ] && ww "  ✗ Thermal events: $THERMAL_ERR" || ww "  ✓ Thermal: CLEAN"
w ""

# ── 5h. Storage / UFS ──
w "  ── 5h. Storage / UFS / Block ──"
w ""
STORAGE_ERR=$(gci "ufshcd.*err|ufshcd.*fail|ufshcd.*timeout|mmc.*err|mmc.*fail|block.*err|i2c.*err|scsi.*err" "$DMESG")
[ "$STORAGE_ERR" -gt 0 ] && ww "  ✗ Storage errors: $STORAGE_ERR" || ww "  ✓ Storage: CLEAN"
w ""

# ── 5i. Power / Battery ──
w "  ── 5i. Power / Battery ──"
w ""
CHG_INFO=$(gc "BATTERY_CHG" "$DMESG")
[ "$CHG_INFO" -gt 0 ] && ww "  ℹ Battery charger info: $CHG_INFO messages (normal)"
PWR_ERR=$(gci "power.*fail|regulator.*fail|pmic.*err|vreg.*fail|ldo.*fail" "$DMESG")
[ "$PWR_ERR" -gt 0 ] && ww "  ✗ Power/regulator errors: $PWR_ERR" || ww "  ✓ Power: CLEAN"
w ""

# ── 5j. Display / DRM ──
w "  ── 5j. Display / DRM ──"
w ""
DRM_ERR=$(gci "drm.*err|drm.*fail|sde.*err|dsi.*err|panel.*err|mdss.*err" "$DMESG")
[ "$DRM_ERR" -gt 0 ] && ww "  ✗ Display errors: $DRM_ERR" || ww "  ✓ Display: CLEAN"
w ""

# ── 5k. Firmware loading ──
w "  ── 5k. Firmware Loading ──"
w ""
FW_ERR=$(gci "firmware.*fail|firmware.*error|Direct firmware load.*failed" "$DMESG")
if [ "$FW_ERR" -gt 0 ]; then
    ww "  ✗ Firmware loading errors: $FW_ERR"
    grep -iE "firmware.*fail|Direct firmware load.*failed" "$DMESG" 2>/dev/null | sed 's/.*\] //' | sort -u | head -5 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ Firmware: CLEAN"
fi
w ""

# ── 5l. IPC / Binder / Service ──
w "  ── 5l. IPC / Binder / Service Manager ──"
w ""
SVC_ERR=$(gci "servicemanager.*Could not find|vintf.*error|binder.*fail" "$DMESG")
if [ "$SVC_ERR" -gt 0 ]; then
    ww "  ✗ Service Manager errors: $SVC_ERR"
    grep -iE "servicemanager.*Could not find" "$DMESG" 2>/dev/null | sed 's/.*\] //' | sort -u | head -5 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ IPC/Services: CLEAN"
fi
w ""

# ── 5m. Kernel panics / oops / call traces ──
w "  ── 5m. Kernel Panics / Oops / Call Traces ──"
w ""
PANIC=$(gci "kernel panic|oops|BUG:|Call trace|Unable to handle|watchdog" "$DMESG")
if [ "$PANIC" -gt 0 ]; then
    ww "  ✗ CRITICAL: $PANIC kernel panic/oops/trace events!"
    grep -iE "kernel panic|oops|BUG:|Call trace|Unable to handle" "$DMESG" 2>/dev/null | sed 's/.*\] //' | head -10 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ No kernel panics/oops"
fi
w ""

# ── 5n. Native crashes ──
w "  ── 5n. Native Crashes / Tombstones ──"
w ""
CRASH_PROCS=$(logcat -d 2>/dev/null | grep "Fatal signal" | sed 's/.*in tid [0-9]* (//' | sed 's/).*//' | sort -u 2>/dev/null)
CRASH_N=$(lc "Fatal signal")
if [ "$CRASH_N" -gt 0 ]; then
    ww "  ✗ $CRASH_N native crashes:"
    for proc in $CRASH_PROCS; do
        pc=$(logcat -d 2>/dev/null | grep "Fatal signal" | grep -c "$proc" 2>/dev/null)
        pc=${pc:-0}
        ww "    $proc: $pc crashes"
    done
    TS_COUNT=$(ls /data/tombstones/*.pb 2>/dev/null | wc -l)
    TS_COUNT=${TS_COUNT:-0}
    [ "$TS_COUNT" -gt 0 ] && ww "  ✗ $TS_COUNT tombstone files"
else
    ww "  ✓ No native crashes"
fi
w ""

# ── 5o. VINTF manifest ──
w "  ── 5o. VINTF Manifest Issues ──"
w ""
VINTF_ERR=$(gci "VINTF manifest" "$DMESG")
if [ "$VINTF_ERR" -gt 0 ]; then
    ww "  ✗ $VINTF_ERR VINTF manifest issues"
    grep -i "VINTF manifest" "$DMESG" 2>/dev/null | sed 's/.*\] //' | sort -u | head -5 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ VINTF: CLEAN"
fi
hr

# ═══════════════════════════════════════════════════════════════════
# 6. MODULE LOADING MECHANISM
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  6. MODULE LOADING MECHANISM"
w "══════════════════════════════════════════════════════════════════"
w ""

VMOD_LIST=$(/vendor/bin/modprobe -d /vendor/lib/modules/ -l 2>/dev/null)
VMOD_COUNT=$(echo "$VMOD_LIST" | grep -c . 2>/dev/null)
VMOD_COUNT=${VMOD_COUNT:-0}
ww "  [1] vendor_modprobe.sh"
ww "      Modules in modprobe list: $VMOD_COUNT"
ww "      Explicitly SKIPPED: qca_cld3_wlan, cnss2"

BUILTIN_IN_MODPROBE=""
for m in $VMOD_LIST; do
    if [ -d "/sys/module/$m" ] 2>/dev/null && ! grep -q "^$m " "$TMP/modules.txt" 2>/dev/null; then
        BUILTIN_IN_MODPROBE="$BUILTIN_IN_MODPROBE $m"
    fi
done
if [ -n "$BUILTIN_IN_MODPROBE" ]; then
    ww "      ⚠ Built-in in modprobe list (will fail):$BUILTIN_IN_MODPROBE"
else
    ww "      ✓ No built-in conflicts in modprobe list"
fi
w ""

KSU_MOD="/data/adb/modules/vili-hitcore"
ww "  [2] KernelSU Module"
if [ -d "$KSU_MOD" ] 2>/dev/null; then
    ww "      dir: $KSU_MOD"
    [ -f "$KSU_MOD/module.prop" ] && ww "      ✓ module.prop"
    [ -f "$KSU_MOD/sepolicy.rule" ] && ww "      ✓ sepolicy.rule"
    [ -d "$KSU_MOD/post-fs-data.d" ] && ww "      ✓ post-fs-data.d/"
    [ -d "$KSU_MOD/service.d" ] && ww "      ✓ service.d/"
else
    ww "      ✗ Module dir NOT found"
fi

SCRIPT_RAN=$(gc "vili-modules" "$DMESG")
[ "$SCRIPT_RAN" -gt 0 ] && ww "      ✓ Script ran ($SCRIPT_RAN log entries)" || ww "      ⚠ Script never ran (post-fs-data.d may not execute)"
w ""

if [ -f "$MODDIR/modules.load" ]; then
    ML_COUNT=$(wc -l < "$MODDIR/modules.load")
    [ "$ML_COUNT" -eq 0 ] && ww "  [3] modules.load: EMPTY" || ww "  [3] modules.load: $ML_COUNT entries"
else
    ww "  [3] modules.load: DOES NOT EXIST"
fi
hr

# ═══════════════════════════════════════════════════════════════════
# 7. MODPROBE DRY-RUN
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  7. MODPROBE DRY-RUN — Dependency Tree"
w "══════════════════════════════════════════════════════════════════"
w ""

trace_deps() {
    mod="$1"
    indent="$2"
    visited="$3"
    case " $visited " in
        *" $mod "*) ww "$(printf '%*s' $((indent*2)) '')└── $mod → CIRCULAR"; return ;;
    esac
    visited="$visited $mod"

    pad=""
    i=0
    while [ "$i" -lt "$indent" ]; do pad="${pad}  "; i=$((i + 1)); done

    ko="$MODDIR/${mod}.ko"
    deps=$(grep "^${MODDIR}/${mod}.ko:" "$TMP/modules.dep" 2>/dev/null | sed "s|^${MODDIR}/${mod}.ko:||" | sed "s|${MODDIR}/||g;s|\.ko||g;s|\.ko:||g")

    if [ -d "/sys/module/$mod" ] 2>/dev/null && ! grep -q "^${mod} " "$TMP/modules.txt" 2>/dev/null; then
        ww "${pad}├── ${mod} → BUILT-IN (insmod FAILS)"
    elif grep -q "^${mod} " "$TMP/modules.txt" 2>/dev/null; then
        ww "${pad}├── ${mod} → LOADED ✓"
    elif [ -f "$ko" ] 2>/dev/null; then
        ww "${pad}├── ${mod} → NOT-LOADED"
    else
        ww "${pad}├── ${mod} → MISSING"
    fi

    for d in $deps; do trace_deps "$d" $((indent + 1)) "$visited"; done
}

for critical_mod in camera wlan icnss2; do
    ww "  modprobe $critical_mod:"
    trace_deps "$critical_mod" 2 ""
    w ""
done
hr

# ═══════════════════════════════════════════════════════════════════
# 8. LOGCAT CRASH ANALYSIS
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  8. LOGCAT CRASH ANALYSIS (last 1000 lines)"
w "══════════════════════════════════════════════════════════════════"
w ""

CRASH_LINES=$(logcat -d -t 1000 2>/dev/null | grep -iE "Fatal signal|FATAL EXCEPTION|AndroidRuntime.*Error|am_crash" 2>/dev/null)
if [ -n "$CRASH_LINES" ]; then
    ww "  Crashes found:"
    echo "$CRASH_LINES" | head -15 | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ No crashes in recent logcat"
fi
w ""

SVC_DIED=$(logcat -d -t 1000 2>/dev/null | grep -iE "Service.*died|process.*died|killed" 2>/dev/null | grep -v "WebViewLoader\|ContentCapture\|ActivityManager" | head -10)
if [ -n "$SVC_DIED" ]; then
    ww "  Service/process deaths:"
    echo "$SVC_DIED" | sed 's/^/    /' >> "$OUT"
else
    ww "  ✓ No unexpected service deaths"
fi
hr

# ═══════════════════════════════════════════════════════════════════
# 9. DMESG ERROR FREQUENCY TABLE
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  9. DMESG ERROR FREQUENCY (top 20 unique messages)"
w "══════════════════════════════════════════════════════════════════"
w ""
grep -iE "error|fail|warn|denied|bug|fault|timeout" "$DMESG" 2>/dev/null \
    | grep -v "type=1400" \
    | sed 's/.*\] //' \
    | sed 's/^ *//' \
    | sed 's/[0-9]\{4,\}/N/g' \
    | sort | uniq -c | sort -rn | head -20 \
    | sed 's/^/    /' >> "$OUT"
w ""
hr

# ═══════════════════════════════════════════════════════════════════
# 10. DIAGNOSIS SUMMARY
# ═══════════════════════════════════════════════════════════════════
w ""
w "══════════════════════════════════════════════════════════════════"
w "  10. COMPLETE DIAGNOSIS"
w "══════════════════════════════════════════════════════════════════"
w ""
w "  ERRORS FOUND:"
w ""

ISSUES=0
[ "$TOTAL_BUILTIN" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] Built-in vs Module Conflict ($TOTAL_BUILTIN built-in modules block others)"
[ "$TOTAL_NOTLOADED" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] $TOTAL_NOTLOADED vendor modules not loaded"
[ "$SELINUX_COUNT" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] SELinux: $SELINUX_COUNT denials"
[ "$CAM_ERR_DMSG" -gt 0 ] || [ "$CAM_FATAL" -gt 0 ] || [ "$CAM_LOGCAT_ERR" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] Camera: driver errors + HAL crashes"
[ "$WLAN_HAL" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] WiFi: HAL failed $WLAN_HAL times"
[ "$ACDB_ERR" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] Audio: ACDB calibration errors ($ACDB_ERR)"
[ "$CRASH_N" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] Native crashes: $CRASH_N (tombstones: $TOMBSTONE_COUNT)"
[ "$VINTF_ERR" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] VINTF manifest issues: $VINTF_ERR"
[ "$TRACEFS_ERR" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] tracefs creation failures: $TRACEFS_ERR"
[ "$FW_ERR" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] Firmware loading errors: $FW_ERR"
[ "$SND_PCM_ERR" -gt 0 ] && ISSUES=$((ISSUES+1)) && ww "  [$ISSUES] snd_pcm_hw_constraint_integer failed: $SND_PCM_ERR"

w ""
w "  TOTAL ISSUES: $ISSUES"
w ""

if [ "$ISSUES" -eq 0 ]; then
    w "  ✓ KERNEL IS CLEAN — NO ERRORS FOUND"
else
    w "  RECOMMENDED FIXES:"
    w ""
    ww "  1. Remove built-in refs from /vendor/lib/modules/modules.dep:"
    while IFS= read -r bm; do
        ww "     sed -i 's| /vendor/lib/modules/${bm}.ko||g' /vendor/lib/modules/modules.dep"
    done < "$BUILTIN_VENDOR"
    w ""
    ww "  2. Don't ship .ko files for modules compiled as =y in defconfig"
    ww "  3. Add wlan/cnss2 to vendor_modprobe.sh load list"
    ww "  4. Add SELinux sepolicy rules for missing domain permissions"
    ww "  5. Fix ACDB calibration data to match kernel audio topology"
    ww "  6. Investigate camera ISP memory allocation failure"
fi
w ""

w "╔════════════════════════════════════════════════════════════════╗"
w "║  Report saved to: $OUT"
w "╚════════════════════════════════════════════════════════════════╝"

echo ""
echo "Report saved to: $OUT"
echo ""
echo "Issues found: $ISSUES"
