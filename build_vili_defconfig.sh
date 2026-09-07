#!/bin/bash
# Script para generar defconfig de vili-hitcore

set -e

# Detectar directorio del kernel desde la ubicación del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR"
cd "$KERNEL_DIR" || { echo "❌ No se pudo entrar a $KERNEL_DIR"; exit 1; }

# Verificar que KernelSU-Next está inicializado
if [ ! -f "KernelSU-Next/kernel/Makefile" ]; then
    echo "❌ KernelSU-Next no está inicializado"
    echo "   Ejecuta: git submodule update --init --recursive"
    exit 1
fi

# Herramientas — Android Clang r522817
export PATH="/opt/kernel-tools/clang-r522817/bin:$PATH"
export LLVM=1
export LLVM_IAS=1

# Variables de entorno para generate_defconfig.sh
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_TRIPLE=aarch64-linux-gnu-
export REAL_CC=clang
export HOSTCC=clang
export HOSTLD=ld.lld
export HOSTAR=llvm-ar
export TARGET_BUILD_VARIANT=user

echo "=== Verificar herramientas ==="
if ! command -v clang &>/dev/null; then
    echo "❌ clang no encontrado en PATH"
    echo "   Asegúrate de tener /opt/kernel-tools/clang-r522817/bin en PATH"
    exit 1
fi
echo "Clang: $(which clang) - $(clang --version | head -1)"
echo ""

echo "=== Generar defconfig ==="
echo "Plataforma: lahaina"
echo "Defconfig: lahaina-qgki_defconfig"
echo ""

# Ejecutar script de generate_defconfig
bash scripts/gki/generate_defconfig.sh lahaina-qgki_defconfig

echo ""
echo "=== Verificar resultado ==="
if [ -f arch/arm64/configs/vendor/lahaina-qgki_defconfig ]; then
    echo "✅ defconfig generado exitosamente"
    echo "Tamaño: $(wc -l < arch/arm64/configs/vendor/lahaina-qgki_defconfig) líneas"
else
    echo "❌ Error: defconfig no se generó"
    exit 1
fi
