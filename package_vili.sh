#!/bin/bash
# package_vili.sh — Empaquetado AnyKernel3 para vili-hitcore
# Estructura fiel al kernel de referencia (qgki por swiitchOFF):
#   Image, dtb, dtbo.img, anykernel.sh, META-INF/, tools/,
#   modules/vendor/lib/modules/*.ko + modules.{load,dep,softdep,alias}
# Uso: bash package_vili.sh [version]
# Ejemplo: bash package_vili.sh v20

set -euo pipefail

# ─── Configuración ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR"
VERSION="${1:-custom}"
ZIP_NAME="vili-hitcore-${VERSION}.zip"

OUT_DIR="${KERNEL_DIR}/out"
IMAGE_SRC="${OUT_DIR}/arch/arm64/boot/Image"
DTB_SRC="${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/lahaina-v2.1.dtb"
DTBO_SRC="${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/vili-sm8350-overlay.dtbo"
MODULES_ORDER="${OUT_DIR}/modules.order"

AK3_DIR="${KERNEL_DIR}/anykernel"

STAGING="${KERNEL_DIR}/out/anykernel-staging"
MODS_DIR="${STAGING}/modules/vendor/lib/modules"
ZIP_OUTPUT="${KERNEL_DIR}/out/${ZIP_NAME}"

export PATH="/opt/kernel-tools/clang-r522817/bin:$PATH"

# ─── Verificar prerequisitos ────────────────────────────────────
echo "=== Verificar prerequisitos ==="

for f in "$IMAGE_SRC" "$DTB_SRC" "$DTBO_SRC" "$MODULES_ORDER"; do
    if [ ! -f "$f" ]; then
        echo "❌ Falta: $f"
        echo "   Ejecuta primero: bash build_vili.sh all"
        exit 1
    fi
done
echo "  ✓ Image:        $(du -h "$IMAGE_SRC" | cut -f1)"
echo "  ✓ dtb:          $(du -h "$DTB_SRC" | cut -f1)"
echo "  ✓ dtbo:         $(du -h "$DTBO_SRC" | cut -f1)"

# ─── Crear staging ──────────────────────────────────────────────
echo ""
echo "=== Preparar empaquetado ==="
rm -rf "$STAGING"
mkdir -p "$MODS_DIR"
mkdir -p "${STAGING}/modules/system/lib/modules"

# ─── Copiar Image / dtb / anykernel framework ───────────────────
cp "$IMAGE_SRC" "${STAGING}/Image"
cp "$DTB_SRC" "${STAGING}/dtb"
echo "  ✓ Image y dtb copiados"

# ─── Generar dtbo.img (formato dt_table, 1 overlay) ─────────────
echo ""
echo "=== Generar dtbo.img ==="
python3 - "$DTBO_SRC" "${STAGING}/dtbo.img" <<'EOF'
import struct, sys

src, dst = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
size = len(data)
total = 32 + 32 + size
# header dt_table (big-endian, igual que mkdtimg)
hdr = struct.pack(">IIIIIIII",
    0xD7B7AB1E, total, 32, 32, 1, 32, 4096, 0)
# entry[0]
entry = struct.pack(">IIIIIIII", size, 64, 0, 0, 0, 0, 0, 0)
with open(dst, "wb") as f:
    f.write(hdr + entry + data)
print(f"  ✓ dtbo.img generado ({total} bytes, payload {size} bytes)")
EOF

# ─── Copiar módulos (todos los .ko del build) ───────────────────
echo ""
echo "=== Copiar módulos (order = modules.order) ==="

# Módulos built-in (=y) que NO deben empaquetarse — causan circular
# dependency o "Unknown symbol" si se copian como .ko al dispositivo.
# Verificar contra modules.builtin del build generado antes de agregar aquí.
EXCLUDE_MODULES=(
    hwid.ko
    msm_drm.ko
)

MODULES_FOUND=()
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    name="${rel##*/}"
    # Skip built-in modules
    if printf '%s\n' "${EXCLUDE_MODULES[@]}" | grep -qx "$name"; then
        echo "  ⏭️  $name — built-in (=y), omitido"
        continue
    fi
    mod="${OUT_DIR}/${rel}"
    if [ ! -f "$mod" ]; then
        # búsqueda de respaldo
        mod=$(find "$OUT_DIR" -name "$name" -not -path '*/anykernel-staging/*' 2>/dev/null | head -n1)
    fi
    if [ -z "${mod:-}" ] || [ ! -f "$mod" ]; then
        echo "  ⚠️  $name no encontrado — omitido"
        continue
    fi
    llvm-strip --strip-debug "$mod" -o "${MODS_DIR}/${name}"
    MODULES_FOUND+=("$name")
done < "$MODULES_ORDER"

echo "  ✓ ${#MODULES_FOUND[@]} módulos del kernel"

# ─── Copiar módulos vendor-only compatibles ─────────────────────
# Estos .ko no se construyen desde nuestro kernel pero son necesarios
# y son compatibles (CRC match). Se copian desde vendor_modules/
VENDOR_MODS_DIR="${KERNEL_DIR}/vendor_modules"
if [ -d "$VENDOR_MODS_DIR" ]; then
    echo ""
    echo "=== Copiar módulos vendor-only compatibles ==="
    for vko in "$VENDOR_MODS_DIR"/*.ko; do
        [ -f "$vko" ] || continue
        vname=$(basename "$vko")
        # skip si ya lo tenemos del build
        if printf '%s\n' "${MODULES_FOUND[@]}" | grep -qx "$vname"; then
            echo "  ⏭️  $vname — ya existe del build"
            continue
        fi
        llvm-strip --strip-debug "$vko" -o "${MODS_DIR}/${vname}"
        MODULES_FOUND+=("$vname")
        echo "  ✓ $vname (vendor-only)"
    done
fi

echo "  ✓ Total: ${#MODULES_FOUND[@]} módulos"

if [ "${#MODULES_FOUND[@]}" -eq 0 ]; then
    echo "❌ Error: ningún módulo copiado"
    exit 1
fi

# ─── Metadata de módulos (modules.dep/softdep/alias) ──────────
echo ""
echo "=== Generar metadata de módulos ==="

# modules.load is intentionally NOT generated — the stock ROM ships with
# an empty modules.load and vendor_modprobe.sh reads it at boot.  Our .ko
# files are deployed to /vendor/lib/modules/ and loaded on demand by
# request_module() or by init.target.rc after fs_ready.
VENDOR_LOAD_ORDER=(
    # Audio (dependencia estricta APR → Q6 → ADSP → platform → machine → codec)
    apr_dlkm.ko
    q6_dlkm.ko
    q6_notifier_dlkm.ko
    q6_pdr_dlkm.ko
    adsp_loader_dlkm.ko
    native_dlkm.ko
    platform_dlkm.ko
    machine_dlkm.ko
    bolero_cdc_dlkm.ko
    pinctrl_lpi_dlkm.ko
    pinctrl_wcd_dlkm.ko
    wcd_core_dlkm.ko
    wcd9xxx_dlkm.ko
    wcd937x_dlkm.ko
    wcd937x_slave_dlkm.ko
    wcd938x_dlkm.ko
    wcd938x_slave_dlkm.ko
    mbhc_dlkm.ko
    swr_dlkm.ko
    swr_ctrl_dlkm.ko
    swr_dmic_dlkm.ko
    rx_macro_dlkm.ko
    tx_macro_dlkm.ko
    va_macro_dlkm.ko
    wsa_macro_dlkm.ko
    wsa883x_dlkm.ko
    snd_event_dlkm.ko
    hdmi_dlkm.ko
    stub_dlkm.ko
    cs35l41_dlkm.ko
    # Cámara (msm_drm es built-in, se omite por EXCLUDE_MODULES)
    camera.ko
    # Hardware (hwid es built-in, se omite por EXCLUDE_MODULES)
    qti_battery_charger_main.ko
    leds-qti-flash.ko
    xiaomi_touch.ko
    fts_touch_spi.ko
    fpc1020_tee.ko
    goodix_ta.ko
    goodix_tee.ko
    mi_thermal_interface.ko
    ir-spi.ko
    # Conectividad (cnss2 =m — stock .ko replaced by our compiled version)
    cnss2.ko
    icnss2.ko
    wlan.ko
    # Misc
    stmvl53l5.ko
    mmhardware_others.ko
    mmhardware_sysfs_dlkm.ko
    qcom_edac.ko
    rmnet_core.ko
    rmnet_ctl.ko
    rmnet_offload.ko
    rmnet_shs.ko
    btpower.ko
    bt_fm_slim.ko
    slimbus.ko
    slimbus-ngd.ko
    rdbg.ko
    radio-i2c-rtc6226-qca.ko
    llcc_perfmon.ko
)
# NOTE: modules.load is intentionally NOT generated — the stock ROM ships
# with an empty modules.load, and vendor_modprobe.sh (stock vendor_boot
# ramdisk) reads it at boot.  Overwriting it with our custom list causes
# vendor_modprobe.sh to attempt loading modules that conflict with
# built-in symbols → bootloop.  Our .ko files are deployed to
# /vendor/lib/modules/ and loaded on demand by request_module() or by
# init.target.rc after fs_ready.

# modules.dep/softdep/alias vía depmod en árbol temporal
KREL=$(cat "${OUT_DIR}/include/config/kernel.release" 2>/dev/null || echo 5.4.302-hitcore)
TMPMODS="${STAGING}/lib/modules/${KREL}"
mkdir -p "$TMPMODS"
for name in "${MODULES_FOUND[@]}"; do
    cp "${MODS_DIR}/${name}" "$TMPMODS/"
done

if command -v depmod &>/dev/null; then
    depmod -b "${STAGING}" "${KREL}" 2>/dev/null || true
    # transformar rutas del árbol temporal → estilo vendor
    if [ -f "$TMPMODS/modules.dep" ]; then
        # rutas relativas de depmod → estilo vendor (/vendor/lib/modules/)
        awk -v p="/vendor/lib/modules/" '{
            out=""
            for (i=1;i<=NF;i++) {
                f=$i
                if (f ~ /\.ko(\:|$)/) {
                    sub(/\.ko$/, "", f); sub(/\.ko:$/, "", f)
                    f = p f ".ko"
                    if ($i ~ /:$/) f = f ":"
                }
                out = (i == 1) ? f : out " " f
            }
            print out
        }' "$TMPMODS/modules.dep" > "${MODS_DIR}/modules.dep"
        echo "  ✓ modules.dep"
        # Safety net: remove msm_drm.ko from modules.dep if present
        # (excluded by EXCLUDE_MODULES but depmod may pick up stale copies)
        sed -i 's| /vendor/lib/modules/msm_drm\.ko||g' "${MODS_DIR}/modules.dep"
        # Fix: cnss2.ko has implicit dependencies on QMI service modules that
        # depmod doesn't detect. Add them manually so vendor_modprobe.sh loads
        # them before cnss2.
        sed -i 's|^/vendor/lib/modules/cnss2\.ko:|/vendor/lib/modules/cnss2.ko: /vendor/lib/modules/wlan_firmware_service_v01.ko /vendor/lib/modules/device_management_service_v01.ko|' "${MODS_DIR}/modules.dep"
        echo "  ✓ modules.dep (QMI deps patched for cnss2)"
    fi
    [ -f "$TMPMODS/modules.softdep" ] && cp "$TMPMODS/modules.softdep" "${MODS_DIR}/modules.softdep" && echo "  ✓ modules.softdep"
    [ -f "$TMPMODS/modules.alias" ] && cp "$TMPMODS/modules.alias" "${MODS_DIR}/modules.alias" && echo "  ✓ modules.alias"
else
    echo "  ⚠️  depmod no disponible — modules.dep vacío"
    : > "${MODS_DIR}/modules.dep"
fi
rm -rf "${STAGING}/lib"

# ─── Copiar AnyKernel3 framework ────────────────────────────────
echo ""
echo "=== Copiar AnyKernel3 framework ==="
cp "${AK3_DIR}/anykernel.sh" "${STAGING}/"
cp -r "${AK3_DIR}/META-INF" "${STAGING}/"
cp -r "${AK3_DIR}/tools" "${STAGING}/"
echo "  ✓ anykernel.sh, META-INF, tools"

# ─── Copiar wifi-modules.sh + .rc ────────────────────────────────
WIFI_SCRIPT="${KERNEL_DIR}/modules/vendor/etc/init/wifi-modules.sh"
WIFI_RC="${KERNEL_DIR}/modules/vendor/etc/init/wifi-modules.rc"
if [ -f "$WIFI_SCRIPT" ]; then
    mkdir -p "${STAGING}/modules/vendor/etc/init"
    cp "$WIFI_SCRIPT" "${STAGING}/modules/vendor/etc/init/wifi-modules.sh"
    chmod 755 "${STAGING}/modules/vendor/etc/init/wifi-modules.sh"
    echo "  ✓ wifi-modules.sh"
fi
if [ -f "$WIFI_RC" ]; then
    mkdir -p "${STAGING}/modules/vendor/etc/init"
    cp "$WIFI_RC" "${STAGING}/modules/vendor/etc/init/wifi-modules.rc"
    echo "  ✓ wifi-modules.rc"
fi

# ─── Crear zip ──────────────────────────────────────────────────
echo ""
echo "=== Crear zip ==="
mkdir -p "$(dirname "$ZIP_OUTPUT")"
rm -f "$ZIP_OUTPUT"
cd "$STAGING"
zip -r9 "$ZIP_OUTPUT" . -x '*.git*'
cd "$KERNEL_DIR"

# ─── Verificar zip ──────────────────────────────────────────────
echo ""
echo "=== Verificar zip ==="

if ! unzip -t "$ZIP_OUTPUT" &>/dev/null; then
    echo "❌ Error: zip corrupto"
    exit 1
fi

ZIP_CONTENTS=$(unzip -l "$ZIP_OUTPUT" 2>/dev/null)

for required in "Image" "dtb" "dtbo.img" "anykernel.sh" "META-INF/com/google/android/update-binary"; do
    if echo "$ZIP_CONTENTS" | grep -q "$required"; then
        echo "  ✓ $required"
    else
        echo "  ❌ FALTA: $required"
        exit 1
    fi
done

MODULE_COUNT=$(echo "$ZIP_CONTENTS" | grep -c '\.ko$' || true)
echo "  ✓ ${MODULE_COUNT} módulos .ko en el zip"

# ─── Verificar resultado ────────────────────────────────────────
echo ""
echo "=== Resultado ==="
SIZE=$(du -h "$ZIP_OUTPUT" | cut -f1)
echo "✅ Zip creado y verificado exitosamente"
echo "   Archivo: ${ZIP_OUTPUT}"
echo "   Tamaño:  ${SIZE}"
echo ""
echo "Para flashear:"
echo "   adb sideload ${ZIP_OUTPUT}"