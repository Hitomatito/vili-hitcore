#!/bin/bash
# Script para generar defconfig de vili-hitcore
# Merge completo: gki_defconfig → lahaina_GKI → lahaina_QGKI → xiaomi_QGKI → vili_QGKI

set -euo pipefail

# ─── Detectar directorio del kernel ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR"
cd "$KERNEL_DIR" || { echo "❌ No se pudo entrar a $KERNEL_DIR"; exit 1; }

# ─── Verificar KernelSU-Next ────────────────────────────────────
if [ ! -f "KernelSU-Next/kernel/Makefile" ]; then
    echo "❌ KernelSU-Next no está inicializado"
    echo "   Ejecuta: git submodule update --init --recursive"
    exit 1
fi

# ─── Herramientas — Android Clang r522817 ───────────────────────
export PATH="/opt/kernel-tools/clang-r522817/bin:$PATH"
export LLVM=1
export LLVM_IAS=1

# ─── Variables de entorno ───────────────────────────────────────
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_TRIPLE=aarch64-linux-gnu-
export REAL_CC=clang
export CC=clang
export LD=ld.lld
export HOSTCC=clang
export HOSTLD=ld.lld
export HOSTAR=llvm-ar
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export TARGET_BUILD_VARIANT=user

# ─── Verificar toolchain ────────────────────────────────────────
echo "=== Verificar herramientas ==="
if ! command -v clang &>/dev/null; then
    echo "❌ clang no encontrado en PATH"
    echo "   Asegúrate de tener /opt/kernel-tools/clang-r522817/bin en PATH"
    exit 1
fi
echo "Clang: $(which clang) - $(clang --version | head -1)"
echo ""

# ─── Configurar paths de fragments ──────────────────────────────
CONFIGS_DIR="${KERNEL_DIR}/arch/${ARCH}/configs/vendor"
DEFCONFIG_NAME="lahaina-qgki_defconfig"
OUTPUT_DEFCONFIG="${CONFIGS_DIR}/${DEFCONFIG_NAME}"

# Base GKI defconfig
BASE_DEFCONFIG="${KERNEL_DIR}/arch/${ARCH}/configs/gki_defconfig"

# Qualcomm platform fragments
LAHAINA_GKI="${CONFIGS_DIR}/lahaina_GKI.config"
LAHAINA_QGKI="${CONFIGS_DIR}/lahaina_QGKI.config"
LAHAINA_DEBUG_FS="${CONFIGS_DIR}/debugfs.config"

# Device-specific fragments (orden de prioridad:越后越优先)
XIAOMI_QGKI="${CONFIGS_DIR}/xiaomi_QGKI.config"
VILI_QGKI="${CONFIGS_DIR}/vili_QGKI.config"

# ─── Verificar que los fragments existen ────────────────────────
echo "=== Verificar fragments ==="
for f in "$BASE_DEFCONFIG" "$LAHAINA_GKI" "$LAHAINA_QGKI" "$XIAOMI_QGKI" "$VILI_QGKI"; do
    if [ ! -f "$f" ]; then
        echo "❌ Fragment no encontrado: $f"
        exit 1
    fi
    echo "  ✓ $(basename "$f") ($(wc -l < "$f") líneas)"
done
echo ""

# ─── Generar fragment allyes de lahaina_GKI ─────────────────────
LAHAINA_GKI_ALLYES="${CONFIGS_DIR}/lahaina_ALLYES_GKI.config"
scripts/gki/fragment_allyesconfig.sh "$LAHAINA_GKI" "$LAHAINA_GKI_ALLYES"

# ─── Debug FS (solo user build) ─────────────────────────────────
DEBUG_FS_FRAG=""
if [ "${TARGET_BUILD_VARIANT}" = "user" ] && [ -f "$LAHAINA_DEBUG_FS" ]; then
    DEBUG_FS_FRAG="$LAHAINA_DEBUG_FS"
fi

# ─── Merge de fragments (orden: base → platform → device) ───────
# merge_config.sh aplica en orden: el último override los anteriores
echo "=== Generar defconfig ==="
echo "Plataforma: lahaina"
echo "Defconfig: ${DEFCONFIG_NAME}"
echo ""

MERGE_FRAGMENTS="$BASE_DEFCONFIG"
MERGE_FRAGMENTS+=" $LAHAINA_GKI_ALLYES"
MERGE_FRAGMENTS+=" $LAHAINA_QGKI"
[ -n "$DEBUG_FS_FRAG" ] && MERGE_FRAGMENTS+=" $DEBUG_FS_FRAG"
MERGE_FRAGMENTS+=" $XIAOMI_QGKI"
MERGE_FRAGMENTS+=" $VILI_QGKI"

echo "Fragments a mergear (orden de prioridad →):"
for frag in $MERGE_FRAGMENTS; do
    echo "  → $(basename "$frag")"
done
echo ""

scripts/kconfig/merge_config.sh $MERGE_FRAGMENTS

# ─── Verificar opciones duplicadas entre fragments ───────────────
echo ""
echo "=== Verificar opciones duplicadas ==="
DUPLICATES=$(grep -h '^CONFIG_' $MERGE_FRAGMENTS 2>/dev/null \
    | sed 's/=.*//' | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
    echo "⚠️  Opciones definidas en múltiples fragments (el último valor gana):"
    echo "$DUPLICATES" | while read -r opt; do
        echo "    $opt"
    done
else
    echo "  ✓ Sin opciones duplicadas entre fragments"
fi

# ─── Generar defconfig final ────────────────────────────────────
echo ""
echo "=== Generar savedefconfig ==="
make ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- \
    LLVM=1 LLVM_IAS=1 \
    HOSTCC=clang HOSTLD=ld.lld HOSTAR=llvm-ar \
    savedefconfig

mv defconfig "$OUTPUT_DEFCONFIG"

# ─── Limpiar archivos temporales ────────────────────────────────
rm -rf "$LAHAINA_GKI_ALLYES" .config include/config/ include/generated/ arch/$ARCH/include/generated/

# ─── Verificar resultado ────────────────────────────────────────
echo ""
echo "=== Verificar resultado ==="
if [ -f "$OUTPUT_DEFCONFIG" ]; then
    LINES=$(wc -l < "$OUTPUT_DEFCONFIG")
    echo "✅ defconfig generado exitosamente: ${DEFCONFIG_NAME}"
    echo "   Tamaño: ${LINES} líneas"
    echo "   Ubicación: ${OUTPUT_DEFCONFIG}"
else
    echo "❌ Error: defconfig no se generó"
    exit 1
fi
