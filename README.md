# vili-hitcore

**Kernel QGKI personalizado para Xiaomi 11T Pro (vili / Snapdragon 888)**

Basado en [android_kernel_qcom_sm8350](https://github.com/xiaomi-lisa-devs/android_kernel_qcom_sm8350) (Linux 5.4.302). Construido con **Android Clang 18.0.1 (r522817)**.

---

## Tabla de contenido

- [Caracteristicas](#caracteristicas)
- [Capturas de pantalla](#capturas-de-pantalla)
- [Requisitos](#requisitos)
- [Instalacion](#instalacion)
- [Compilar desde el codigo fuente](#compilar-desde-el-codigo-fuente)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Cambios respecto al stock](#cambios-respecto-al-stock)
- [Solucion de problemas (FAQ)](#solucion-de-problemas-faq)
- [Sincronizar con upstream](#sincronizar-con-upstream)
- [Info del dispositivo](#info-del-dispositivo)
- [Creditos](#creditos)
- [Licencia](#licencia)

---

## Caracteristicas

### KernelSU-Next v3.2.0-legacy (Root)

Integracion completa de [KernelSU-Next](https://github.com/rifsxd/KernelSU-Next) en modo **MANUAL HOOK**. Este modo es mas estable que kprobes en kernels QGKI 5.4, y es el mismo que usa TitanicExtended.

- Hooks manuales en: `fs/exec.c`, `fs/read_write.c`, `fs/stat.c`, `fs/open.c`, `drivers/input/input.c`
- Soporte para modulos KernelSU (Magisk modules compatible)
- Manager APK descargable desde la app o desde GitHub Releases

### Compatibilidad con modulos stock

**CONFIG_MODVERSIONS=y** permite que los módulos stock del `vendor_boot` (battery, USB, WiFi, camera, audio) carguen sobre nuestro kernel custom sin necesidad de modificarlos.

- `same_magic()` en `kernel/module.c` ignora el prefijo de versión (`5.4.302-hitcore-vXX` vs `5.4.302-qgki`) cuando los módulos tienen CRCs
- `CONFIG_MODULE_FORCE_LOAD=y` permite cargar módulos stock que carecen de sección `__versions`
- No se requiere parchear módulos stock ni modificar el `vendor_ramdisk`

### WiFi completo (cnss2 + wlan)

Soporte WiFi completo con la cadena de dependencias: `wlan_firmware_service_v01.ko` → `device_management_service_v01.ko` → `cnss2.ko` → `icnss2.ko` → `wlan.ko`.

- `CONFIG_CNSS2=m` — modulo para compatible con stock
- `CONFIG_QCA_CLD_WLAN=m` — driver WiFi QCACLD 3.0
- `CONFIG_CLD_LL_CORE=m` — capa de enlace
- CBC (Cold Boot Calibration) deshabilitado en cnss2 para evitar rechazo de carga
- `modules.dep` parcheado con dependencias QMI implicitas de cnss2

### Camara

- `/dev/video0`, `/dev/video1`, `/dev/media0`, `/dev/media1` disponibles
- `camera.ko` cargado correctamente
- Soporte completo para el stack de camara Qualcomm (ISP, CamX)

### Seguridad

- **CFI_CLANG** (Control Flow Integrity) en modo enforcing — exporta `__cfi_slowpath` que los módulos vendor esperan
- **CFI_CLANG_SHADOW** habilitado
- **Shadow Call Stack** habilitado
- **CVE-2024-46693** parchado (UCSI glink)

### Compilacion optimizada

- **LTO_CLANG** (Link-Time Optimization) — optimización a nivel de enlace para mejor rendimiento
- **Android Clang 18.0.1 (r522817)** — toolchain oficial de Android
- Detección automática de RAM para limitar jobs y prevenir OOM durante LTO

### Modulos del kernel

El kernel construye ~91 módulos (.ko) que se instalan en `/vendor/lib/modules/`:

- **Audio**: apr_dlkm, q6_dlkm, bolero_cdc_dlkm, wcd937x/wcd938x, swr_ctrl_dlkm, snd_event_dlkm, hdmi_dlkm, cs35l41_dlkm, y más
- **Camara**: camera.ko
- **Conectividad**: cnss2.ko, icnss2.ko, wlan.ko, btpower.ko, bt_fm_slim.ko
- **Touch**: xiaomi_touch.ko, fts_touch_spi.ko
- **Fingerprint**: fpc1020_tee.ko, goodix_ta.ko, goodix_tee.ko
- **Thermal**: mi_thermal_interface.ko
- **Misc**: stmvl53l5.ko, ir-spi.ko, rmnet_*.ko, qcom_edac.ko

---

## Capturas de pantalla

> Las capturas de pantalla se agregarán pronto. Incluirán:
> - Aplicación KernelSU-Next gestionando permisos root
> - Perfiles de batería y rendimiento
> - WiFi y conectividad funcionando
> - Camara activa
> - Información del kernel en Settings > About Phone

---

## Requisitos

### Para usuarios (flashear el kernel)

- **Xiaomi 11T Pro** (vili) con **recovery stock** o **TWRP**
- **ADB** instalado en tu computadora
- **Slider A/B** (el dispositivo debe estar en un slot activo)
- **Sin desbloqueo de bootloader** requerido (flasheo vía adb sideload)

### Para desarrolladores (compilar desde codigo fuente)

- Linux (probado en CachyOS / Arch / Ubuntu)
- **Android Clang r522817** — [descargar](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/main/clang-r522817)
- **GCC cross-compiler**: `aarch64-linux-gnu`
- **Make**, **bc**, **flex**, **bison**, **libssl-dev**
- Al menos **16GB de RAM** (recomendado para LTO)

---

## Instalacion

### Paso 1: Descargar el kernel

Descarga la ultima version desde la seccion [Releases](https://github.com/Hitomatito/vili-hitcore/releases) de GitHub.

```bash
# O desde la linea de comandos:
wget https://github.com/Hitomatito/vili-hitcore/releases/latest/download/vili-hitcore-custom.zip
```

### Paso 2: Preparar el dispositivo

1. **Conectar el dispositivo via USB** y verificar la conexion:
   ```bash
   adb devices
   ```
   Deberia mostrar tu dispositivo con estado `device` o `sideload`.

2. **Reiniciar en recovery**:
   ```bash
   adb reboot recovery
   ```
   O manualmente: apaga el dispositivo, mantén **Power + Volume Up** hasta aparecer el logo de recovery.

### Paso 3: Flashear el kernel

Desde la computadora, ejecuta:
```bash
adb sideload vili-hitcore-custom.zip
```

En el dispositivo:
1. Selecciona **"Apply update from ADB"** (recovery stock) o **"Install"** (TWRP)
2. Espera a que el flasheo complete (aproximadamente 1-2 minutos)
3. Selecciona **"Reboot system now"**

### Paso 4: Instalar KernelSU-Next Manager

Despues del primer boot:

1. Descarga la APK de KernelSU-Next Manager desde la pagina de [releases](https://github.com/rifsxd/KernelSU-Next/releases)
2. Instala la APK:
   ```bash
   adb install KernelSU-Next-v*.apk
   ```
3. Abre la app — deberia mostrar **"KernelSU: Activado"** y la version del kernel
4. En la pestana **"Modules"** puedes instalar modulos compatibles con Magisk/KernelSU

### Paso 5: Verificar

Reinicia el dispositivo una vez mas:
```bash
adb reboot
```

Despues del boot, verifica:
```bash
# Verificar kernel
adb shell uname -r
# Salida esperada: 5.4.302-qgki

# Verificar root
adb shell su -c "id"
# Salida esperada: uid=0(root)

# Verificar WiFi
adb shell ip link show wlan0
# Deberia mostrar wlan0 UP

# Verificar camara
adb shell ls -la /dev/video0 /dev/media0
# Deberia mostrar ambos dispositivos
```

---

## Compilar desde el codigo fuente

### Clonar el repositorio

```bash
git clone git@github.com:Hitomatito/vili-hitcore.git
cd vili-hitcore
git submodule update --init --recursive
```

### Configurar el toolchain

Descarga [Android Clang r522817](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/main/clang-r522817) y extraelo a `/opt/kernel-tools/clang-r522817/`.

```bash
# Verificar que clang funciona
/opt/kernel-tools/clang-r522817/bin/clang --version
```

### Build completo (recomendado)

```bash
bash build_vili.sh all v31
```

Esto ejecuta automaticamente:
1. Genera el defconfig (merge: gki → lahaina_GKI → lahaina_QGKI → xiaomi_QGKI → vili_QGKI)
2. Compila el kernel + todos los modulos
3. Empaqueta el zip AnyKernel3

Output: `out/vili-hitcore-v31.zip`

### Build paso a paso

```bash
# Solo generar defconfig
bash build_vili.sh defconfig

# Solo compilar kernel + modulos
bash build_vili.sh build

# Solo empaquetar (requiere build previo)
bash build_vili.sh package v31

# Limpiar directorio out/
bash build_vili.sh clean
```

### Flashear tu build

```bash
adb reboot recovery
adb sideload out/vili-hitcore-v31.zip
```

---

## Estructura del proyecto

```
vili-hitcore/
├── build_vili.sh                    # Script maestro (defconfig + build + package)
├── build_vili_defconfig.sh          # Genera defconfig con merge de fragments
├── package_vili.sh                  # Empaquetado AnyKernel3 (Image + dtb + dtbo + modulos)
├── arch/arm64/configs/vendor/
│   ├── vili_QGKI.config            # Config especifica del dispositivo
│   ├── lahaina-qgki_defconfig      # Defconfig generado (merge final)
│   ├── lahaina_GKI.config          # Fragment Qualcomm GKI
│   ├── lahaina_QGKI.config         # Fragment Qualcomm QGKI
│   └── xiaomi_QGKI.config          # Fragment Xiaomi
├── anykernel/                       # Template AnyKernel3
│   ├── anykernel.sh                 # Script de flasheo
│   ├── META-INF/                    # Updater del recovery
│   └── tools/                       # ak3-core.sh, magiskboot, etc.
├── drivers/
│   ├── net/wireless/cnss2/          # Driver cnss2 (patches: CBC fix)
│   └── staging/qcacld-3.0/          # Driver WiFi QCACLD (patches: PLD fix)
├── fs/                              # KernelSU manual hooks
├── modules/
│   └── vendor/etc/init/
│       ├── wifi-modules.sh          # Script de carga WiFi + camara
│       └── wifi-modules.rc          # Init trigger
├── KernelSU-Next/                   # Submodule: KernelSU-Next v3.2.0-legacy
├── tools/
│   ├── diagnose_kernel_modules.sh   # Diagnostico completo del kernel
│   └── diag_kernel.sh               # Diagnostico kernel/KernelSU
└── out/                             # Build output (gitignored)
    ├── arch/arm64/boot/Image
    ├── arch/arm64/boot/dts/vendor/qcom/lahaina-v2.1.dtb
    ├── arch/arm64/boot/dts/vendor/qcom/vili-sm8350-overlay.dtbo
    └── vili-hitcore-vXX.zip
```

---

## Cambios respecto al stock

### Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `Kconfig` | Incluye `KernelSU-Next/kernel/Kconfig` |
| `Makefile` | Agrega `obj-$(CONFIG_KSU) += KernelSU-Next/kernel/` |
| `vili_QGKI.config` | `CNSS2=m`, `CLD_LL_CORE=m`, `MODULE_FORCE_LOAD=y`, `KSU_MANUAL_HOOK=y`, CFI enforcing |
| `lahaina-qgki_defconfig` | `MODULE_FORCE_LOAD=y`, `KSU_MANUAL_HOOK=y`, `CLD_LL_CORE=m` |
| `drivers/net/wireless/cnss2/main.c` | `cbc_enabled = false` (fix CBC rejection) |
| `drivers/staging/qcacld-3.0/core/pld/src/pld_common.c` | SNOC/SDIO/USB/IPCI failures non-fatal |
| `kernel/module.c` | `same_magic()` skips version prefix with FORCE_LOAD; duplicate symbol warning instead of fatal |
| `fs/exec.c`, `fs/read_write.c`, `fs/stat.c`, `fs/open.c` | KernelSU manual hook call sites |
| `drivers/input/input.c` | KernelSU input hook |
| `drivers/usb/typec/ucsi/ucsi_glink.c` | CVE-2024-46693 fix |

### Cambios en el build system

| Archivo | Cambio |
|---------|--------|
| `build_vili.sh` | Script maestro con deteccion automatica de RAM para LTO |
| `build_vili_defconfig.sh` | Merge completo de 5 fragments de config |
| `package_vili.sh` | EXCLUDE_MODULES (hwid, msm_drm), sed cnss2 deps, wifi-modules.sh/rc |
| `update-binary` | Instala modules.dep, wifi-modules.sh/rc; preserva contexto SELinux stock |
| `anykernel.sh` | Simplificado a flow estandar AK3 (do.systemless=0) |

### Modelo de carga de modulos

El `vendor_ramdisk` stock se conserva intacto. Los drivers de Xiaomi (battery, USB, WiFi, camera, audio) se cargan desde los modulos `.ko` que nuestro kernel compila e instala en `/vendor/lib/modules/`.

- `CONFIG_MODVERSIONS=y` permite que los modulos stock carguen porque el sufijo de vermagic es identico (`SMP preempt mod_unload modversions aarch64`)
- `CONFIG_MODULE_FORCE_LOAD=y` permite cargar modulos que carecen de seccion `__versions`
- El kernel autoloader (modprobe) resuelve dependencias via `modules.dep`
- `cnss2.ko` tiene dependencias QMI implicitas parcheadas en `modules.dep`

---

## Solucion de problemas (FAQ)

### El dispositivo hace bootloop despues de flashear

**Causa**: El kernel no puede cargar los modulos stock porque `modules.dep` no tiene las dependencias correctas, o `CONFIG_MODULE_FORCE_LOAD` no esta habilitado.

**Solucion**:
1. Entra a recovery (Power + Volume Up)
2. Flashea el zip de nuevo via adb sideload
3. Si persiste, restaura el boot stock desde recovery

### WiFi no conecta despues del boot

**Causa**: El modulo `cnss2.ko` no carga porque depende de `wlan_firmware_service_v01.ko` y `device_management_service_v01.ko`, que no estan en `modules.dep` stock.

**Solucion**: Nuestro kernel parchea `modules.dep` automaticamente durante el flasheo. Verifica:
```bash
adb shell su -c "cat /vendor/lib/modules/modules.dep | grep cnss2"
# Deberia mostrar las dependencias de cnss2
adb shell su -c "lsmod | grep wlan"
# Deberia mostrar wlan, cnss2, icnss2, etc.
```

### Camera no funciona

**Causa**: `camera.ko` no carga porque sus dependencias (`leds-qti-flash.ko`, `qti_battery_charger_main.ko`) no estan en el modulo。

**Solucion**: Nuestro kernel conserva las dependencias stock de camera en `modules.dep`. Verifica:
```bash
adb shell su -c "ls -la /dev/video0 /dev/media0"
adb shell su -c "lsmod | grep camera"
```

### KernelSU no activa root

**Causa**: KernelSU-Next no se integro correctamente durante el build.

**Solucion**:
1. Verifica que el submodule este inicializado: `git submodule update --init --recursive`
2. Verifica que `CONFIG_KSU=y` y `CONFIG_KSU_MANUAL_HOOK=y` esten en la config
3. Rebuild: `bash build_vili.sh all v31`
4. Reinstala el zip via adb sideload

### Modulos no cargan ("Unknown symbol")

**Causa**: Falta `CONFIG_MODULE_FORCE_LOAD=y` o `CONFIG_MODVERSIONS=y` en la config.

**Solucion**: Verifica que ambas opciones esten habilitadas en `vili_QGKI.config`:
```
CONFIG_MODVERSIONS=y
CONFIG_MODULE_FORCE_LOAD=y
```

### Errores "exports duplicate symbol"

**Causa**: Un modulo intenta exportar un simbolo que ya existe en el kernel.

**Solucion**: Con `CONFIG_MODULE_FORCE_LOAD=y`, estos errores se convierten en warnings (no fatales). El modulo carga de todas formas.

### El script wifi-modules.sh no se ejecuta al boot

**Causa**: El trigger `on property:sys.boot_completed=1` en el `.rc` puede no dispararse a tiempo.

**Solucion**: Verifica que el script exista y tenga permisos:
```bash
adb shell su -c "ls -la /vendor/etc/init/wifi-modules.sh"
adb shell su -c "sh /vendor/etc/init/wifi-modules.sh"
# Si funciona manualmente, el problema es el trigger de init
```

### El dispositivo no inicia despues del flash

**Solucion de emergencia**:
1. Manten **Power + Volume Up** para entrar a recovery
2. Selecciona "Wipe data/factory reset" (esto NO borra tu data, solo resetea el boot)
3. Reinicia

---

## Sincronizar con upstream

```bash
git remote add upstream https://github.com/xiaomi-lisa-devs/android_kernel_qcom_sm8350.git
git fetch upstream
git merge upstream/lineage-23.2
```

---

## Info del dispositivo

| | |
|---|---|
| Dispositivo | Xiaomi 11T Pro |
| Codename | vili |
| SoC | Snapdragon 888 (SM8350) |
| Kernel | Linux 5.4.302 |
| Slot | A/B |
| Android | 13 (BP4A.251205.006) |

---

## Creditos

- [xiaomi-lisa-devs](https://github.com/xiaomi-lisa-devs) — fuente base del kernel
- [swiitchOFF](https://xda-developers.com) — kernel de referencia `qgki-vili-20260903` (arquitectura de flasheo + DTB/DTBO)
- [rifsxd/KernelSU-Next](https://github.com/rifsxd/KernelSU-Next) — integracion de KernelSU
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) — framework de empaquetado flashable
- [Google](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/) — Android Clang r522817
- [Qualcomm](https://source.codeaurora.org/quic/kernel/) — kernel base SM8350 / techpack audio

---

## Licencia

GPL-2.0 (Linux kernel)
