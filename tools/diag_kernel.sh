#!/system/bin/sh
#===============================================================================
#  vili-hitcore — Diagnóstico de kernel y KernelSU
#  Uso:            sh diag_kernel.sh [salida.txt]
#  Requiere:       Termux (o adb shell), root opcional (mejora el reporte)
#  Salida:         /sdcard/Download/kernel_diag_<fecha>.txt  (+ stdout si no)
#  Diseñado para:  Xiaomi 11T Pro (vili) — SM8350 — kernel 5.4.302-hitcore
#===============================================================================

#--- Detección de entorno -----------------------------------------------------
HAVE_BUSYBOX=0
command -v busybox >/dev/null 2>&1 && HAVE_BUSYBOX=1

#--- Helpers: lectura segura (nunca corta la ejecución) -----------------------
read_file() {   # read_file <ruta> [fallback_msg]
    if [ -r "$1" ] 2>/dev/null; then
        cat "$1" 2>/dev/null
    else
        echo "${2:-N/D}"
    fi
}

read_via_root() { # read_via_root <ruta> [fallback_msg]
    [ "$HAVE_ROOT" = "yes" ] || { echo "${2:-N/D (sin root)}"; return 0; }
    ROOT_EXE su -c "cat '$1'" 2>/dev/null || echo "${2:-N/D}"
}

dir_list() { # dir_list <path> [fallback]
    if [ -d "$1" ] 2>/dev/null; then
        ls "$1" 2>/dev/null
    else
        echo "${2:-N/D}"
    fi
}

#--- Detección de root ---------------------------------------------------------
HAVE_ROOT=no
if command -v su >/dev/null 2>&1; then
    if su -c 'id -u' 2>/dev/null | grep -q '^0$'; then
        HAVE_ROOT=yes
    fi
fi

#--- Variables globales --------------------------------------------------------
KREL=$(uname -r 2>/dev/null || echo "kernel")
KNAME=$(echo "$KREL" | sed 's/^[0-9.]*[_-]*//; s/[^A-Za-z0-9_]/_/g; s/_$//; s/^_//')
[ -z "$KNAME" ] && KNAME="kernel"
KNAME=$(echo "$KNAME" | tr 'A-Z' 'a-z')
OUT="${1}"
if [ -z "$OUT" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo diag)
    OUT="/sdcard/Download/${KNAME}_diag_${STAMP}.txt"
    # Fallback si /sdcard/Download no es escribible (Termux sin permiso storage)
    if ! touch "$OUT" 2>/dev/null; then
        OUT="./${KNAME}_diag_${STAMP}.txt"
        touch "$OUT" 2>/dev/null || OUT=""
    fi
else
    : > "$OUT" 2>/dev/null || OUT=""
fi
LOG_OUT="$OUT"
emit() {   # emit <sección|texto>  → texto al stdout y al archivo si escribible
    if [ -n "$LOG_OUT" ]; then echo "$1" >> "$LOG_OUT" 2>/dev/null; fi
    echo "$1"
}
sep()  { emit "─────────────────────────────────────────────────────────────────"; }
hdr()  { emit ""; emit "═══ $1 ═══"; }

#===============================================================================
emit "╔═══════════════════════════════════════════════════════════════════════╗"
emit "║        vili-hitcore — Diagnóstico de kernel / KernelSU                ║"
emit "╚═══════════════════════════════════════════════════════════════════════╝"
emit "Fecha y hora:      $(date 2>/dev/null || echo N/D)"
emit "Reporte destino:   ${LOG_OUT:-stdout}"
emit "Kernel detectado:  ${KREL} (→ nombre base: ${KNAME})"
sep

# 1) Identificación del kernel --------------------------------------------------
hdr "1. Identificación del kernel"
emit "uname -a:         $(uname -a 2>/dev/null || echo N/D)"
emit "uname -r:         $(uname -r 2>/dev/null || echo N/D)"
emit "uname -v:         $(uname -v 2>/dev/null || echo N/D)"
emit "osrelease:        $(read_file /proc/sys/kernel/osrelease 'N/D')"
emit "version:          $(read_file /proc/version 'N/D')"
emit "build.config:     $(read_via_root '/proc/cmdline' 'N/D (sin root)')"
sep

# 2) cmdline completo (requiere root, fallback a fragmentos) --------------------
hdr "2. Parámetros de arranque (cmdline)"
if [ "$HAVE_ROOT" = "yes" ]; then
    CMD=$(su -c 'cat /proc/cmdline' 2>/dev/null)
    emit "cmdline: ${CMD:-N/D}"
    # extraer androidboot.* en pares
    echo "$CMD" | tr ' ' '\n' 2>/dev/null | grep '^androidboot\.' 2>/dev/null | while IFS= read -r kv; do
        k=${kv%%=*}; v=${kv#*=}
        emit "  ${k} = ${v}"
    done
else
    emit "cmdline: N/D — root no disponible"
    emit "ro.boot.hardware:          $(getprop ro.boot.hardware 2>/dev/null || echo N/D)"
    emit "ro.boot.verifiedbootstate: $(getprop ro.boot.verifiedbootstate 2>/dev/null || echo N/D)"
fi
sep

# 3) SELinux y seguridad ---------------------------------------------------------
hdr "3. SELinux / seguridad"
emit "getenforce:       $(getenforce 2>/dev/null || echo N/D)"
emit "enforce (sysfs):  $(read_file /sys/fs/selinux/enforce 'N/D')"
emit "policyvers:       $(read_file /sys/fs/selinux/policyvers 'N/D')"
emit "androidboot.slot: $(getprop ro.boot.slot 2>/dev/null || echo N/D)"
emit "build.type:       $(getprop ro.build.type 2>/dev/null || echo N/D)"
emit "boot verified:    $(getprop ro.boot.flash.locked 2>/dev/null || getprop ro.boot.verifiedbootstate 2>/dev/null || echo N/D)"
sep

# 4) CPU ------------------------------------------------------------------------
hdr "4. CPU"
CPU0=$(read_file /proc/cpuinfo 'N/D')
emit "cores:            $(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo N/D)"
emit "model (CPU0):     $(echo "$CPU0" | grep -m1 'model name' | cut -d: -f2- | tr -d ' ' | head -c 80)"
emit "features (CPU0):  $(echo "$CPU0" | grep -m1 'Features' | cut -d: -f2- | tr -s ' ' | head -c 200)"
emit "bogomips:         $(grep -m1 BogoMIPS /proc/cpuinfo 2>/dev/null | cut -d: -f2- )"
renderer=$(getprop ro.hardware.egl 2>/dev/null); [ -n "$renderer" ] && emit "EGL (GPU):        $renderer"
sep

# 5) Memoria y swap --------------------------------------------------------------
hdr "5. Memoria"
emit "MemTotal:         $(grep -m1 MemTotal /proc/meminfo 2>/dev/null | tr -s ' ')"
emit "MemFree:          $(grep -m1 MemFree /proc/meminfo 2>/dev/null | tr -s ' ')"
emit "MemAvailable:     $(grep -m1 MemAvailable /proc/meminfo 2>/dev/null | tr -s ' ')"
emit "SwapTotal:        $(grep -m1 SwapTotal /proc/meminfo 2>/dev/null | tr -s ' ')"
emit "SwapFree:         $(grep -m1 SwapFree /proc/meminfo 2>/dev/null | tr -s ' ')"
sep

# 6) Uptime / boot ---------------------------------------------------------------
hdr "6. Uptime y estado de boot"
UP=$(read_file /proc/uptime 'N/D')
emit "uptime (s):       $UP"
if [ -n "$UP" ] && [ "$UP" != "N/D" ]; then
    upt=$(echo "$UP" | awk '{print int($1)}')
    idt=$(echo "$UP" | awk '{print int($2)}')
    emit "  - horas:         $((upt/3600))h $(((upt%3600)/60))m"
    emit "  - idle:          ${idt}s"
fi
emit "sys.boot_completed: $(getprop sys.boot_completed 2>/dev/null || echo N/D)"
emit "init.svc.bootanim:  $(getprop init.svc.bootanim 2>/dev/null || echo N/D)"
sep

# 7) Módulos cargados (via /proc/modules y /sys/module) ----------------------------
hdr "7. Módulos del kernel"
if [ "$HAVE_ROOT" = "yes" ]; then
    MODL=$(su -c 'cat /proc/modules 2>/dev/null' )
else
    MODL=  # QGKI: /proc/modules puede requerir root; si no hay root queda vacío
fi
if [ -n "$MODL" ]; then
    CNT=$(echo "$MODL" | grep -c '')
    emit "Módulos en /proc/modules ($CNT):"
    emit "$MODL"
else
    emit "/proc/modules: sin datos (QGKI requiere root, puede estar restringido)"
fi
emit ""
CNTSYS=$(ls /sys/module 2>/dev/null | wc -l)
emit "Total dirs en /sys/module: ${CNTSYS:-N/D}"
sep

# 8) Controladores críticos (DLKM) ------------------------------------------------
hdr "8. Controladores críticos (DLKM stock esperados)"
exp_drivers="wlan icnss2 icnss cnss2 cnss camera apr_dlkm qti_battery qti_glink
 mmrm rmnet_ctl rmnet_offload rmnet_shs swr_ctrl_dlkm tx_macro_dlkm va_macro_dlkm
 adsp_loader_dlkm bolero_cdc_dlkm cs35l41_dlkm bt_fm_slim btpower"
for d in $exp_drivers; do
    if [ -d "/sys/module/$d" ] 2>/dev/null; then
        if [ "$HAVE_ROOT" = "yes" ]; then
            init=$(su -c "cat /sys/module/$d/initstate" 2>/dev/null)
            refc=$(su -c "cat /sys/module/$d/refcnt" 2>/dev/null)
        else
            init=$(cat /sys/module/$d/initstate 2>/dev/null)
            refc=$(cat /sys/module/$d/refcnt 2>/dev/null)
        fi
        emit "  [CARGADO  ] ${d}  (initstate=${init:-?} refcnt=${refc:-?})"
    else
        emit "  [ausente  ] ${d}"
    fi
done
sep

# 8b) Errores de carga de módulos (clave para v21 + DLKM stock) --------------------
hdr "8b. Errores de carga de módulos / símbolos (dmesg)"
if [ "$HAVE_ROOT" = "yes" ]; then
    su -c 'dmesg' 2>/dev/null | grep -iE "disagrees about version|Unknown symbol|no symbol version|version magic|module.*fail|failed to load|init_module" \
        | tail -20 | while IFS= read -r l; do emit "  $l"; done
    emit "  (fin de la lista)"
else
    emit "root no disponible"
fi
sep

# 9) KernelSU ----------------------------------------------------------------------
hdr "9. KernelSU / ksud"
if [ "$HAVE_ROOT" = "yes" ]; then
emit "ksud binario:     $(su -c 'ls -la /data/adb/ksu/bin/ksud' 2>/dev/null | awk '{print $5}' | head -c 20) bytes en /data/adb/ksu/bin/"
emit "ksud dir:         $(su -c 'ls /data/adb/ksu/bin' 2>/dev/null | tr '\n' ' ')"
emit "ksud versión:     $(su -c '/data/adb/ksu/bin/ksud -V' 2>/dev/null || echo N/D)"
emit "proc /proc/ksud:  $(su -c 'ls /proc/ksud 2>/dev/null' || echo 'no expuesto')"
emit "versión ksud:     $(su -c 'cat /proc/ksud/version 2>/dev/null' || echo N/D)"
    # muestras de dmesg de KSU
    emit ""
    emit "— dmesg KernelSU (últimas 8):"
    su -c 'dmesg 2>/dev/null' | grep -iE 'KernelSU|ksu' | tail -8 | while IFS= read -r l; do
        emit "    $l"
    done
else
    emit "root no disponible — sección parcial"
fi
PMLIST=$(su -c 'pm list packages' 2>/dev/null || pm list packages 2>/dev/null)
emit "manager: $(echo "$PMLIST" | grep -iE 'me.weishu|kernelsu' | sed 's/package://')"
sep

# 10) Firmware / versiones Qualcomm ------------------------------------------------
hdr "10. Firmware y componentes"
emit "boot.adsp:        $(read_file /sys/kernel/boot_adsp/0 2>/dev/null || read_file /sys/kernel/boot_adsp 'N/D')"
emit "boot.cdsp:        $(read_via_root '/sys/kernel/boot_cdsp/0' 'N/D')"
emit "boot.slpi:        $(read_via_root '/sys/kernel/boot_slpi/0' 'N/D')"
emit "androidboot.hwc:  $(getprop ro.boot.hwc 2>/dev/null || echo N/D)"
emit "androidboot.hwlevel: $(getprop ro.boot.hwlevel 2>/dev/null || echo N/D)"
emit "androidboot.hwversion: $(getprop ro.boot.hwversion 2>/dev/null || echo N/D)"
sep

# 11) Particiones y block devices --------------------------------------------------
hdr "11. Block devices (root)" 
if [ "$HAVE_ROOT" = "yes" ]; then
    su -c 'ls -l /dev/block/by-name 2>/dev/null' | grep -iE 'boot|dtb|vendor|super|system|odm|recovery|init_boot' | while IFS= read -r l; do
        emit "  $l"
    done
else
    emit "root no disponible"
fi
sep

# 12) dmesg — errores/resumen (root) ------------------------------------------------
hdr "12. dmesg — resumen (root)"
if [ "$HAVE_ROOT" = "yes" ]; then
    DMESG=$(su -c 'dmesg 2>/dev/null')
    emit "Líneas totales:  $(echo "$DMESG" | wc -l)"
    emit ""
    emit "— presencias clave:"
    emit "  modprobe:    $(echo "$DMESG" | grep -ciE 'modprobe|init_module|load_module|loading module')"
    emit "  firmware:    $(echo "$DMESG" | grep -ciE 'firmware')"
    emit "  panic/oops:  $(echo "$DMESG" | grep -ciE 'panic|oops|BUG:|KASAN|watchdog')"
    emit "  kmalloc:     $(echo "$DMESG" | grep -ciE 'allocation failure|out of memory')"
    emit "  vmscan:      $(echo "$DMESG" | grep -ciE 'vmscan')"
    emit "  WARNING/error: $(echo "$DMESG" | grep -ciE 'WARNING:|kernel BUG|Call trace')"
    emit ""
    emit "— últimas 15 líneas de dmesg:"
    echo "$DMESG" | tail -15 | while IFS= read -r l; do emit "    $l"; done
else
    emit "root no disponible"
fi
sep

# 13) Propiedades útiles ------------------------------------------------------------
hdr "13. Propiedades (getprop) de interés"
for p in ro.product.model ro.build.version.release ro.build.version.sdk \
         ro.build.version.security_patch ro.boot.hardware.platform ro.soc.model \
         ro.hardware.egl ro.build.fingerprint ro.build.version.incremental \
         ro.vendor.qti.vendor.pkg ro.boot.selinux sys.usb.config init.svc.thermal-engine; do
    emit "  ${p} = $(getprop "$p" 2>/dev/null || echo N/D)"
done
sep

# 14) Conclusión rápida ---------------------------------------------------------------
hdr "14. Indicadores rápidos"
emit "Root disponible:          ${HAVE_ROOT}"
ENF=$(cat /sys/fs/selinux/enforce 2>/dev/null)
if [ "$ENF" = "1" ]; then emit "SELinux enforcing:        yes"; else emit "SELinux enforcing:        no"; fi
for d in wlan icnss2 qti_battery camera; do
    if [ -d "/sys/module/$d" ]; then
        emit "Driver $d cargado:        SI"
    else
        emit "Driver $d cargado:        NO (o no requerido todavía)"
    fi
done
emit ""
emit "═ Fin del reporte ═"
[ -n "$LOG_OUT" ] && emit "Archivo guardado en: $LOG_OUT"
exit 0