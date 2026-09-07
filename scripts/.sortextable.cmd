cmd_scripts/sortextable := clang -Wp,-MMD,scripts/.sortextable.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89     -I./tools/include -I./tools/include   -o scripts/sortextable scripts/sortextable.c   

source_scripts/sortextable := scripts/sortextable.c

deps_scripts/sortextable := \
  tools/include/tools/be_byteshift.h \
  tools/include/tools/le_byteshift.h \
  scripts/sortextable.h \

scripts/sortextable: $(deps_scripts/sortextable)

$(deps_scripts/sortextable):
