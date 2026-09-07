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
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3) (for packaging)

## Quick Start

### 1. Clone

```bash
git clone git@github.com:Hitomatito/vili-hitcore.git
cd vili-hitcore
```

No submodules needed — everything is included.

### 2. Set up toolchain

Download [Android Clang r522817](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/main/clang-r522817) and extract to `/opt/kernel-tools/clang-r522817/`.

```bash
export PATH=/opt/kernel-tools/clang-r522817/bin:$PATH
```

### 3. Build

```bash
# Generate defconfig
bash build_vili_defconfig.sh

# Build kernel + modules
make ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 -j$(nproc) Image modules
```

Output:
- `arch/arm64/boot/Image` — kernel image
- `techpack/audio/**/*.ko` — audio modules
- `drivers/staging/qcacld-3.0/wlan.ko` — WiFi module

### 4. Package flashable zip

Set up an [AnyKernel3](https://github.com/osm0sis/AnyKernel3) directory:

```
AnyKernel3/
├── Image                              # from arch/arm64/boot/Image
├── anykernel.sh
├── tools/
├── bin/
└── vendor_ramdisk/lib/modules/        # compiled .ko files
    ├── adsp_loader_dlkm.ko
    ├── apr_dlkm.ko
    ├── q6_notifier_dlkm.ko
    ├── q6_pdr_dlkm.ko
    ├── snd_event_dlkm.ko
    ├── mmhardware_sysfs_dlkm.ko
    ├── wlan.ko
    ├── modules.load
    ├── modules.dep
    └── modules.softdep
```

```bash
zip -r9 vili-hitcore-vXX.zip AnyKernel3/
```

### 5. Flash

```bash
adb sideload vili-hitcore-vXX.zip
```

Requires stock recovery or TWRP. Device must be in A/B slot.

## What changed from stock

Modifications on top of the original kernel source:

| File | Change |
|------|--------|
| `Kconfig` | Sources `KernelSU-Next/kernel/Kconfig` |
| `Makefile` | Adds `obj-$(CONFIG_KSU) += KernelSU-Next/kernel/` |
| `kernel/module.c` | Vermagic matching for stock module compatibility |
| `drivers/usb/typec/ucsi/ucsi_glink.c` | CVE-2024-46693 fix |
| `arch/arm64/configs/vendor/lahaina-qgki_defconfig` | Enabled KSU, LTO_CLANG, CFI_CLANG, audio modules |

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
