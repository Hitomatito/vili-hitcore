### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=QGKI Kernel for Xiaomi 11T Pro (vili) — hitcore
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=vili
device.name2=milahaina
device.name3=Xiaomi 11T Pro
supported.versions=11.0-17.0
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
# boot shell variables
BLOCK=auto;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install — standard AnyKernel3 flow: dump_boot replaces kernel, write_boot repacks with magiskboot
dump_boot;

write_boot;
# end boot install

# flash dtbo partition
flash_generic dtbo;

# Modules are installed by do_modules() in update-binary (direct push to
# /vendor/lib/modules/).

ui_print "- Done!";
## end install
