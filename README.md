# vili-hitcore

Custom QGKI kernel for **Xiaomi 11T Pro (vili / SM8350)**.

Based on [android_kernel_qcom_sm8350](https://github.com/xiaomi-lisa-devs/android_kernel_qcom_sm8350) (Linux 5.4.302).

## Features

- **KernelSU-Next v3.2.0-legacy** (kprobe mode) — root access
- **CVE-2024-46693** fix (UCSI glink)
- **LTO_CLANG** + **CFI_CLANG** (permissive)
- **CONFIG_MODVERSIONS=y** — vermagic compatible con los módulos stock
  del `vendor_boot` (battery, USB, WiFi, camera) sin parchear el kernel
- Audio techpack modules (adsp, apr, q6, snd_event)
- WiFi (wlan.ko / qcacld-3.0)
- DTB/DTBO propios: `lahaina-v2.1.dtb` + `dtbo.img` byte-idénticos al
  kernel de referencia (swiitchOFF / qgki), flasheados vía vendor_boot
- Built with **Android Clang 18.0.1 (r522817)**

## Requirements

- Linux (tested on CachyOS / Arch)
- Android Clang toolchain: `r522817`
- GCC cross-compiler: `aarch64-linux-gnu`

## Quick Start

### 1. Clone

```bash
git clone git@github.com:Hitomatito/vili-hitcore.git
cd vili-hitcore
git submodule update --init --recursive
```

### 2. Set up toolchain

Download [Android Clang r522817](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/main/clang-r522817) and extract to `/opt/kernel-tools/clang-r522817/`.

### 3. Build (todo en uno)

```bash
bash build_vili.sh all v15
```

Esto ejecuta automáticamente:
1. Genera el defconfig (merge completo: gki → lahaina_GKI → lahaina_QGKI → xiaomi_QGKI → vili_QGKI)
2. Compila el kernel + módulos
3. Empaqueta el zip AnyKernel3

Output: `out/vili-hitcore-v15.zip`

### 4. Build paso a paso (opcional)

```bash
# Solo defconfig
bash build_vili.sh defconfig

# Solo compilar
bash build_vili.sh build

# Solo empaquetar (requiere build previo)
bash build_vili.sh package v15
```

### 5. Flash

```bash
adb sideload out/vili-hitcore-vXX.zip
```

Requires stock recovery or TWRP. Device must be in A/B slot.

## Build structure

```
vili-hitcore/
├── build_vili.sh              # Script maestro (defconfig + build + package)
├── build_vili_defconfig.sh    # Genera defconfig con merge completo
├── package_vili.sh            # Empaquetado AnyKernel3 (Image + dtb + dtbo.img + 90 .ko)
├── arch/arm64/configs/vendor/ # Fragmentos de config (vili_QGKI.config, ...)
├── anykernel/                 # Template AnyKernel3 (committeado)
│   ├── anykernel.sh
│   ├── META-INF/
│   └── tools/
└── out/                      # Build output (gitignored)
    ├── arch/arm64/boot/Image
    ├── arch/arm64/boot/dts/vendor/qcom/lahaina-v2.1.dtb
    ├── arch/arm64/boot/dts/vendor/qcom/vili-sm8350-overlay.dtbo
    ├── modules.order         # Orden de carga de módulos
    └── vili-hitcore-vXX.zip
```

## What changed from stock

Modifications on top of the original kernel source:

| File | Change |
|------|--------|
| `Kconfig` | Sources `KernelSU-Next/kernel/Kconfig` |
| `Makefile` | Adds `obj-$(CONFIG_KSU) += KernelSU-Next/kernel/` |
| `arch/arm64/configs/vendor/vili_QGKI.config` | `CONFIG_MODVERSIONS=y` (compat vermagic con stock) |
| `drivers/usb/typec/ucsi/ucsi_glink.c` | CVE-2024-46693 fix |
| `build_vili_defconfig.sh` | Full defconfig merge with device-specific configs |
| `scripts/gki/envsetup.sh` | Fixed quoting and error handling |

Los drivers (battery, USB, WiFi, camera) los cargan los **módulos stock del
`vendor_boot` del dispositivo** (no se flashean): el kernel activa
`CONFIG_MODVERSIONS=y` y como el sufijo de vermagic es idéntico
(`SMP preempt mod_unload modversions aarch64`), `same_magic()` en
`kernel/module.c` iguala los módulos saltándose el prefijo de versión
(`5.4.302-hitcore-vXX` vs `5.4.302-qgki`) porque llevan CRCs.

## Flash anatomy (zip)

```
vili-hitcore-vXX.zip
├── Image              # Kernel con MODVERSIONS=y
├── dtb                # lahaina-v2.1.dtb (flasheado a vendor_boot)
├── dtbo.img           # dt_table → vili-sm8350-overlay.dtbo (flasheado a dtbo)
├── anykernel.sh       # boot + vendor_boot (do.systemless=0)
├── META-INF/          # updater
├── tools/             # ak3-core.sh, magiskboot, ...
└── modules/vendor/lib/modules/   # 90 módulos del build
    ├── *.ko
    ├── modules.load   # orden de carga
    ├── modules.dep
    ├── modules.softdep
    └── modules.alias
```

El `vendor_ramdisk` stock se conserva intacto (se reemplaza solo el `dtb`
en el `vendor_boot`), de modo que los drivers native de Xiaomi cargan sobre
el kernel custom.

## Syncing with upstream

```bash
git remote add upstream https://github.com/xiaomi-lisa-devs/android_kernel_qcom_sm8350.git
git fetch upstream
git merge upstream/lineage-23.2
```

## Device info

| | |
|---|---|
| Device | Xiaomi 11T Pro |
| Codename | vili |
| SoC | Snapdragon 888 (SM8350) |
| Kernel | Linux 5.4.302 |
| Slot | A/B |

## Credits

- [xiaomi-lisa-devs](https://github.com/xiaomi-lisa-devs) — base kernel source
- [swiitchOFF](https://xda-developers.com) — kernel de referencia `qgki-vili-20260903` (arquitectura de flasheo + DTB/DTBO)
- [rifsxd/KernelSU-Next](https://github.com/rifsxd/KernelSU-Next) — KernelSU integration
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) — flashable zip packaging

## License

GPL-2.0 (Linux kernel)
