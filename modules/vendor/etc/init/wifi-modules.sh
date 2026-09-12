#!/vendor/bin/sh
# wifi-modules.sh — Load WiFi modules at boot in dependency order.
# vendor_modprobe.sh (stock) explicitly skips cnss2 and qca_cld3_wlan.
# cnss2.ko is our compiled version (=m, matching kernel vermagic).
# icnss2.ko and wlan.ko are stock versions (loaded via MODULE_FORCE_LOAD).

LOG_TAG="wifi-modules"
log_info() { /system/bin/log -t "$LOG_TAG" -p i "$1"; }
log_err()  { /system/bin/log -t "$LOG_TAG" -p e "$1"; }

sleep 8

log_info "Loading WiFi modules..."

for m in \
    device_management_service_v01 \
    wlan_firmware_service_v01 \
    cnss2 \
    icnss2 \
    wlan \
    camera; do
    if [ -f "/vendor/lib/modules/${m}.ko" ]; then
        insmod "/vendor/lib/modules/${m}.ko" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_info "Loaded ${m}"
        else
            log_err "Failed to load ${m}"
        fi
    else
        log_err "Missing /vendor/lib/modules/${m}.ko"
    fi
done

sleep 2
if ip link show wlan0 >/dev/null 2>&1; then
    log_info "wlan0 interface ready"
else
    log_err "wlan0 not found after loading modules"
fi
