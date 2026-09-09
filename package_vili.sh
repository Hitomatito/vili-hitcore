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

MODULES_FOUND=()
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    name="${rel##*/}"
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

echo "  ✓ ${#MODULES_FOUND[@]} módulos copiados"

if [ "${#MODULES_FOUND[@]}" -eq 0 ]; then
    echo "❌ Error: ningún módulo copiado"
    exit 1
fi

# ─── Metadata de módulos (modules.load/dep/softdep/alias) ───────
echo ""
echo "=== Generar metadata de módulos ==="

# modules.load: orden del build (mismo criterio que la referencia)
printf '%s\n' "${MODULES_FOUND[@]}" > "${MODS_DIR}/modules.load"
echo "  ✓ modules.load (${#MODULES_FOUND[@]} módulos)"

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

for required in "Image" "dtb" "dtbo.img" "anykernel.sh" "META-INF/com/google/android/update-binary" "modules/vendor/lib/modules/modules.load"; do
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