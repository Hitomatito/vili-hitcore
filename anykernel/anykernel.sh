### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=QGKI Kernel for Xiaomi 11T Pro (vili)
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=vili
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# Set BLOCK before sourcing — ak3-core.sh calls setup_ak() on source
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install (kernel + ramdisk)
dump_boot;
write_boot;

reset_ak;

# vendor_boot install (dtb + módulos)
BLOCK=vendor_boot;
IS_SLOT_DEVICE=1;
setup_ak;
split_boot;

# Unpack stock vendor_ramdisk and replace modules
cd $SPLITIMG;
for cpio in vendor_ramdisk/*.cpio; do
  [ -f "$cpio" ] && unpack_vendorrd $cpio;
done;
cd $AKHOME;

for vndrdir in $VENDORRD/*/; do
  if [ -d "$vndrdir/lib/modules" ]; then
    cp -af $AKHOME/vendor_ramdisk/lib/modules/*.ko "$vndrdir/lib/modules/";
    cp -af $AKHOME/vendor_ramdisk/lib/modules/modules.load "$vndrdir/lib/modules/";
    cp -af $AKHOME/vendor_ramdisk/lib/modules/modules.dep "$vndrdir/lib/modules/";
    cp -af $AKHOME/vendor_ramdisk/lib/modules/modules.softdep "$vndrdir/lib/modules/";
  fi;
done;

flash_boot;
## end boot install
