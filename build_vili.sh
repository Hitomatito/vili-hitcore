#!/bin/bash
# build_vili.sh — Build maestro para vili-hitcore
# Uso: bash build_vili.sh [defconfig|build|package|all] [version]
#
# Ejemplos:
#   bash build_vili.sh all              # Build completo
#   bash build_vili.sh all v15          # Build completo con version tag
#   bash build_vili.sh defconfig        # Solo generar defconfig
#   bash build_vili.sh build            # Solo compilar kernel + módulos
#   bash build_vili.sh package v14      # Solo empaquetar (requiere build previo)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ACTION="${1:-all}"
VERSION="${2:-custom}"

# ─── Herramientas ───────────────────────────────────────────────
export PATH="/opt/kernel-tools/clang-r522817/bin:$PATH"
export LLVM=1
export LLVM_IAS=1
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

NPROC=$(nproc 2>/dev/null || echo 4)
OUT_DIR="${SCRIPT_DIR}/out"
DEFCONFIG="lahaina-qgki_defconfig"

# ─── Verificar toolchain ────────────────────────────────────────
if ! command -v clang &>/dev/null; then
    echo "❌ clang no encontrado en PATH"
    echo "   Asegúrate de tener /opt/kernel-tools/clang-r522817/bin en PATH"
    exit 1
fi

# ─── Verificar KernelSU-Next ────────────────────────────────────
if [ ! -f "KernelSU-Next/kernel/Makefile" ]; then
    echo "❌ KernelSU-Next no está inicializado"
    echo "   Ejecuta: git submodule update --init --recursive"
    exit 1
fi

# ─── Funciones ──────────────────────────────────────────────────
do_defconfig() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  Paso 1/3: Generar defconfig             ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    bash build_vili_defconfig.sh

    if [ ! -f "arch/arm64/configs/vendor/${DEFCONFIG}" ]; then
        echo "❌ Falló la generación de defconfig"
        exit 1
    fi
    echo ""
}

do_build() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  Paso 2/3: Compilar kernel + módulos     ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # Cargar defconfig
    make O="${OUT_DIR}" ARCH=arm64 "${DEFCONFIG}"

    # Compilar
    make O="${OUT_DIR}" \
        ARCH=arm64 \
        CC=clang \
        CROSS_COMPILE=aarch64-linux-gnu- \
        LLVM=1 \
        LLVM_IAS=1 \
        HOSTCC=clang \
        HOSTLD=ld.lld \
        HOSTAR=llvm-ar \
        -j"${NPROC}" \
        Image modules

    # Verificar outputs
    if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
        echo "❌ No se generó Image"
        exit 1
    fi

    echo ""
    echo "✅ Build completado"
    echo "   Image: $(du -h "${OUT_DIR}/arch/arm64/boot/Image" | cut -f1)"
    echo "   Módulos: $(find "${OUT_DIR}" -name "*.ko" 2>/dev/null | wc -l) encontrados"
    echo ""
}

do_package() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  Paso 3/3: Empaquetar AnyKernel3         ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # Ajustar rutas para package_vili.sh (usa out/ directamente)
    bash package_vili.sh "$VERSION"
}

# ─── Ejecutar ───────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "  vili-hitcore build — ${ACTION}"
echo "  Clang: $(clang --version | head -1)"
echo "  Jobs: ${NPROC}"
echo "═══════════════════════════════════════════"
echo ""

case "$ACTION" in
    defconfig)
        do_defconfig
        ;;
    build)
        do_build
        ;;
    package)
        do_package
        ;;
    all)
        do_defconfig
        do_build
        do_package
        ;;
    *)
        echo "❌ Acción desconocida: $ACTION"
        echo "   Uso: $0 [defconfig|build|package|all] [version]"
        exit 1
        ;;
esac

echo "═══════════════════════════════════════════"
echo "  ✅ ${ACTION} completado"
echo "═══════════════════════════════════════════"
