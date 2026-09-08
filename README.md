# vili-hitcore

Custom QGKI kernel for **Xiaomi 11T Pro (vili / SM8350)**.

Based on [android_kernel_qcom_sm8350](https://github.com/xiaomi-lisa-devs/android_kernel_qcom_sm8350) (Linux 5.4.302).

## Features

- **KernelSU-Next v3.2.0-legacy** (kprobe mode) — root access
- **CVE-2024-46693** fix (UCSI glink)
- **LTO_CLANG** + **CFI_CLANG** (permissive)
- Audio techpack modules (adsp, apr, q6, snd_event)
- WiFi (wlan.ko / qcacld-3.0)
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
├── package_vili.sh            # Empaquetado AnyKernel3
├── anykernel/                 # Template AnyKernel3 (committeado)
│   ├── anykernel.sh
│   ├── META-INF/
│   └── tools/
└── out/                      # Build output (gitignored)
    ├── arch/arm64/boot/Image
    ├── lib/modules/*.ko
    └── vili-hitcore-vXX.zip
```

## What changed from stock

Modifications on top of the original kernel source:

| File | Change |
|------|--------|
| `Kconfig` | Sources `KernelSU-Next/kernel/Kconfig` |
| `Makefile` | Adds `obj-$(CONFIG_KSU) += KernelSU-Next/kernel/` |
| `kernel/module.c` | Vermagic matching for stock module compatibility |
| `drivers/usb/typec/ucsi/ucsi_glink.c` | CVE-2024-46693 fix |
| `build_vili_defconfig.sh` | Full defconfig merge with device-specific configs |
| `scripts/gki/envsetup.sh` | Fixed quoting and error handling |

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
- [rifsxd/KernelSU-Next](https://github.com/rifsxd/KernelSU-Next) — KernelSU integration
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) — flashable zip packaging

## License

GPL-2.0 (Linux kernel)
