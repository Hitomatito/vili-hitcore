#!/bin/bash
# build_vili.sh — Build maestro para vili-hitcore
# Uso: bash build_vili.sh [all|defconfig|build|package|clean] [version]
#
# Ejemplos:
#   bash build_vili.sh all              # Build completo
#   bash build_vili.sh all v15          # Build completo con version tag
#   bash build_vili.sh defconfig        # Solo generar defconfig
#   bash build_vili.sh build            # Solo compilar kernel + módulos
#   bash build_vili.sh package v14      # Solo empaquetar (requiere build previo)
#   bash build_vili.sh clean            # Limpiar directorio out/

set -euo pipefail

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

OUT_DIR="${SCRIPT_DIR}/out"
DEFCONFIG="lahaina-qgki_defconfig"
LOG_DIR="${SCRIPT_DIR}/out/logs"
BUILD_LOG="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"

# LOCALVERSION: inyectar versión en el kernel (ej: -hitcore-v15)
if [ "$VERSION" != "custom" ]; then
    LOCALVERSION="-hitcore-${VERSION}"
else
    LOCALVERSION=""
fi

# ─── NPROC: limitar para LTO (ThinLTO usa ~1.5GB por job) ──────
# Detectar RAM disponible y limitar jobs para no causar OOM
detect_nproc() {
    local total_cores
    total_cores=$(nproc 2>/dev/null || echo 4)

    # Detectar RAM en KB
    local ram_kb
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    local ram_gb=$(( ram_kb / 1024 / 1024 ))

    # ThinLTO usa ~1.5GB por job — limitar a 70% de RAM disponible
    local max_jobs_lto
    if [ "$ram_gb" -gt 0 ]; then
        max_jobs_lto=$(( (ram_gb * 70 / 100) * 10 / 15 ))  # ram_gb * 0.7 / 1.5
    else
        max_jobs_lto="$total_cores"
    fi

    # Usar el menor entre cores disponibles y límite LTO
    local jobs="$total_cores"
    if [ "$max_jobs_lto" -lt "$total_cores" ]; then
        jobs="$max_jobs_lto"
        echo "⚠️  RAM limitada (${ram_gb}GB) — reduciendo jobs a ${jobs} para LTO" >&2
    fi

    # Mínimo 1 job
    [ "$jobs" -lt 1 ] && jobs=1
    echo "$jobs"
}

NPROC=$(detect_nproc)

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

# ─── Logging ────────────────────────────────────────────────────
setup_logging() {
    mkdir -p "$LOG_DIR"
    # Teed output: pantalla + archivo de log
    exec > >(tee -a "$BUILD_LOG") 2>&1
    echo "=== Build log: ${BUILD_LOG} ==="
    echo "=== Fecha: $(date) ==="
    echo ""
}

# ─── Funciones ──────────────────────────────────────────────────
do_clean() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  Limpiar directorio out/                 ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    if [ -d "$OUT_DIR" ]; then
        local size
        size=$(du -sh "$OUT_DIR" | cut -f1)
        rm -rf "$OUT_DIR"
        echo "✅ Eliminado: out/ (${size})"
    else
        echo "ℹ️  out/ no existe, nada que limpiar"
    fi
    echo ""
}

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

    # Cargar defconfig (está en vendor/)
    cp "arch/arm64/configs/vendor/${DEFCONFIG}" "arch/arm64/configs/${DEFCONFIG}"
    make O="${OUT_DIR}" ARCH=arm64 "${DEFCONFIG}"
    rm -f "arch/arm64/configs/${DEFCONFIG}"

    # Inyectar LOCALVERSION si se especificó versión
    if [ -n "$LOCALVERSION" ]; then
        echo "  LOCALVERSION=${LOCALVERSION}"
        scripts/config --file "${OUT_DIR}/.config" --set-str LOCALVERSION "${LOCALVERSION}"
        make O="${OUT_DIR}" ARCH=arm64 olddefconfig
    fi

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
        Image modules dtbs

    # Verificar outputs
    if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
        echo "❌ No se generó Image"
        exit 1
    fi

    echo ""
    echo "✅ Build completado"
    echo "   Image: $(du -h "${OUT_DIR}/arch/arm64/boot/Image" | cut -f1)"
    echo "   Módulos: $(find "${OUT_DIR}" -name "*.ko" 2>/dev/null | wc -l) encontrados"
    echo "   dtb: $(du -h "${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/lahaina-v2.1.dtb" 2>/dev/null | cut -f1 || echo 'NO GENERADO')"
    echo "   dtbo: $(du -h "${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/vili-sm8350-overlay.dtbo" 2>/dev/null | cut -f1 || echo 'NO GENERADO')"
    echo ""
}

do_package() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  Paso 3/3: Empaquetar AnyKernel3         ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    bash package_vili.sh "$VERSION"
}

# ─── Ejecutar ───────────────────────────────────────────────────
# Logging solo para build completo (all) o build单独
if [[ "$ACTION" == "all" || "$ACTION" == "build" ]]; then
    setup_logging
fi

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
    clean)
        do_clean
        ;;
    all)
        do_defconfig
        do_build
        do_package
        ;;
    *)
        echo "❌ Acción desconocida: $ACTION"
        echo "   Uso: $0 [all|defconfig|build|package|clean] [version]"
        exit 1
        ;;
esac

echo "═══════════════════════════════════════════"
echo "  ✅ ${ACTION} completado"
if [[ "$ACTION" == "all" || "$ACTION" == "build" ]]; then
    echo "  📋 Log: ${BUILD_LOG}"
fi
echo "═══════════════════════════════════════════"
