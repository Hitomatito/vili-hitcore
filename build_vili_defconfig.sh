#!/bin/bash
# Script adaptado para generar defconfig de vili

set -e

# Directorio del kernel
KERNEL_DIR=/home/james/Proyectos/kernel_xiaomi_sm8350
cd "$KERNEL_DIR"

# Herramientas
export PATH="/opt/kernel-tools/clang-r416183b/bin:/opt/kernel-tools/gcc-arm/bin:$PATH"

# Variables de entorno para generate_defconfig.sh
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_TRIPLE=aarch64-linux-gnu-
export REAL_CC=clang
export HOSTCC=gcc
export HOSTLD=ld
export HOSTAR=ar
export TARGET_BUILD_VARIANT=user

echo "=== Verificar herramientas ==="
echo "Clang: $(which clang) - $(clang --version | head -1)"
echo "GCC: $(which aarch64-linux-gnu-gcc) - $(aarch64-linux-gnu-gcc --version | head -1)"
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
