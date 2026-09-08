#!/bin/bash
# package_vili.sh — Empaquetado AnyKernel3 para vili-hitcore
# Uso: bash package_vili.sh [version]
# Ejemplo: bash package_vili.sh v14

set -e

# ─── Configuración ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR"
VERSION="${1:-custom}"
ZIP_NAME="vili-hitcore-${VERSION}.zip"

# Directorios de source (post-build)
IMAGE_SRC="${KERNEL_DIR}/arch/arm64/boot/Image"
OUT_DIR="${KERNEL_DIR}/out"

# AnyKernel3 template
AK3_DIR="${KERNEL_DIR}/anykernel"

# Output
STAGING="${KERNEL_DIR}/out/anykernel-staging"
ZIP_OUTPUT="${KERNEL_DIR}/out/${ZIP_NAME}"

# ─── Módulos esperados (orden de carga) ─────────────────────────
# El orden en modules.load es crítico para el audio y WiFi
MODULES=(
    adsp_loader_dlkm.ko
    apr_dlkm.ko
    q6_notifier_dlkm.ko
    q6_pdr_dlkm.ko
    snd_event_dlkm.ko
    mmhardware_sysfs_dlkm.ko
    wlan.ko
)

# ─── Dependencias entre módulos ─────────────────────────────────
MODULE_SOFTDEPS=(
    "softdep adsp_loader_dlkm: apr_dlkm q6_notifier_dlkm q6_pdr_dlkm mmhardware_sysfs_dlkm snd_event_dlkm"
    "softdep apr_dlkm: q6_notifier_dlkm q6_pdr_dlkm mmhardware_sysfs_dlkm snd_event_dlkm"
    "softdep q6_notifier_dlkm: q6_pdr_dlkm"
)

# ─── Verificar prerequisitos ────────────────────────────────────
echo "=== Verificar prerequisitos ==="

if [ ! -f "$IMAGE_SRC" ]; then
    echo "❌ Image no encontrado: $IMAGE_SRC"
    echo "   Ejecuta primero: bash build_vili.sh"
    exit 1
fi
echo "  ✓ Image: $(du -h "$IMAGE_SRC" | cut -f1)"

# Buscar .ko en out/ y techpack/
KERN_OUT_MODULES="${OUT_DIR}/lib/modules"
TECHPACK_MODULES="${KERNEL_DIR}/techpack"
DRIVERS_MODULES="${KERNEL_DIR}/drivers/staging/qcacld-3.0"

# ─── Crear staging directory ────────────────────────────────────
echo ""
echo "=== Preparar empaquetado ==="
rm -rf "$STAGING"
mkdir -p "${STAGING}/vendor_ramdisk/lib/modules"

# ─── Copiar Image ───────────────────────────────────────────────
cp "$IMAGE_SRC" "${STAGING}/Image"
echo "  ✓ Image copiado"

# ─── Copiar módulos .ko ─────────────────────────────────────────
echo ""
echo "=== Copiar módulos ==="
MODULES_FOUND=()

for mod in "${MODULES[@]}"; do
    FOUND=0

    # Buscar en out/lib/modules/
    if [ -f "${KERN_OUT_MODULES}/${mod}" ]; then
        cp "${KERN_OUT_MODULES}/${mod}" "${STAGING}/vendor_ramdisk/lib/modules/"
        MODULES_FOUND+=("$mod")
        echo "  ✓ $mod (out/lib/modules/)"
        FOUND=1
        continue
    fi

    # Buscar en techpack/
    if [ "$FOUND" -eq 0 ]; then
        while IFS= read -r -d '' f; do
            cp "$f" "${STAGING}/vendor_ramdisk/lib/modules/"
            MODULES_FOUND+=("$mod")
            echo "  ✓ $mod (techpack/)"
            FOUND=1
            break
        done < <(find "$TECHPACK_MODULES" -name "$mod" -print0 2>/dev/null)
    fi

    # Buscar en drivers/staging/qcacld-3.0/
    if [ "$FOUND" -eq 0 ] && [ -f "${DRIVERS_MODULES}/${mod}" ]; then
        cp "${DRIVERS_MODULES}/${mod}" "${STAGING}/vendor_ramdisk/lib/modules/"
        MODULES_FOUND+=("$mod")
        echo "  ✓ $mod (drivers/staging/qcacld-3.0/)"
        FOUND=1
    fi

    # Buscar en todo out/ recursivamente
    if [ "$FOUND" -eq 0 ]; then
        while IFS= read -r -d '' f; do
            cp "$f" "${STAGING}/vendor_ramdisk/lib/modules/"
            MODULES_FOUND+=("$mod")
            echo "  ✓ $mod (out/)"
            FOUND=1
            break
        done < <(find "$OUT_DIR" -name "$mod" -print0 2>/dev/null)
    fi

    if [ "$FOUND" -eq 0 ]; then
        echo "  ⚠️  $mod no encontrado — omitido"
    fi
done

# ─── Generar modules.load ───────────────────────────────────────
echo ""
echo "=== Generar metadata de módulos ==="
printf '%s\n' "${MODULES_FOUND[@]}" > "${STAGING}/vendor_ramdisk/lib/modules/modules.load"
echo "  ✓ modules.load (${#MODULES_FOUND[@]} módulos)"

# ─── Generar modules.softdep ────────────────────────────────────
printf '%s\n' "${MODULE_SOFTDEPS[@]}" > "${STAGING}/vendor_ramdisk/lib/modules/modules.softdep"
echo "  ✓ modules.softdep"

# ─── Generar modules.dep (placeholder — depmod real requiere kernel build dir)
# El kernel real ejecuta depmod contra el build tree. Para el zip usamos un
# depmod simplificado que las tools de AnyKernel3 pueden resolver.
: > "${STAGING}/vendor_ramdisk/lib/modules/modules.dep"
echo "  ✓ modules.dep (vacío — resuelto por AK3 en flash)"

# ─── Copiar AnyKernel3 framework ────────────────────────────────
echo ""
echo "=== Copiar AnyKernel3 framework ==="
cp "${AK3_DIR}/anykernel.sh" "${STAGING}/"
cp -r "${AK3_DIR}/META-INF" "${STAGING}/"
cp -r "${AK3_DIR}/tools" "${STAGING}/"
echo "  ✓ anykernel.sh, META-INF, tools"

# ─── Crear zip ──────────────────────────────────────────────────
echo ""
echo "=== Crear zip ==="
mkdir -p "$(dirname "$ZIP_OUTPUT")"
cd "$STAGING"
zip -r9 "$ZIP_OUTPUT" . -x '*.git*'
cd "$KERNEL_DIR"

# ─── Verificar resultado ────────────────────────────────────────
echo ""
echo "=== Resultado ==="
if [ -f "$ZIP_OUTPUT" ]; then
    SIZE=$(du -h "$ZIP_OUTPUT" | cut -f1)
    echo "✅ Zip creado exitosamente"
    echo "   Archivo: ${ZIP_OUTPUT}"
    echo "   Tamaño:  ${SIZE}"
    echo ""
    echo "Para flashear:"
    echo "   adb sideload ${ZIP_OUTPUT}"
else
    echo "❌ Error: no se creó el zip"
    exit 1
fi
