cmd_arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb := mkdir -p arch/arm64/boot/dts/vendor/qcom/ ; clang -E -Wp,-MMD,arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.d.pre.tmp -nostdinc -I./scripts/dtc/include-prefixes -undef -D__DTS__ -x assembler-with-cpp -o arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.dts.tmp arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dts ; ./scripts/dtc/dtc -O dtb -o arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb -b 0 -iarch/arm64/boot/dts/vendor/qcom/ -i./scripts/dtc/include-prefixes -@ -q -Wno-unit_address_vs_reg -Wno-simple_bus_reg -Wno-unit_address_format -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-simple_bus_reg -Wno-unique_unit_address -Wno-pci_device_reg  -d arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.d.dtc.tmp arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.dts.tmp ; cat arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.d.pre.tmp arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.d.dtc.tmp > arch/arm64/boot/dts/vendor/qcom/.yupik-rumi.dtb.d

source_arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb := arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dts

deps_arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb := \
  arch/arm64/boot/dts/vendor/qcom/yupik.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,aop-qmp.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,camcc-yupik.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,dispcc-yupik.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,gcc-yupik.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,gpucc-yupik.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,rpmh.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,videocc-yupik.h \
  scripts/dtc/include-prefixes/dt-bindings/interconnect/qcom,epss-l3.h \
  scripts/dtc/include-prefixes/dt-bindings/interconnect/qcom,icc.h \
  scripts/dtc/include-prefixes/dt-bindings/interconnect/qcom,yupik.h \
  scripts/dtc/include-prefixes/dt-bindings/interrupt-controller/arm-gic.h \
  scripts/dtc/include-prefixes/dt-bindings/interrupt-controller/irq.h \
  scripts/dtc/include-prefixes/dt-bindings/soc/qcom,ipcc.h \
  scripts/dtc/include-prefixes/dt-bindings/soc/qcom,dcc_v2.h \
  scripts/dtc/include-prefixes/dt-bindings/soc/qcom,rpmh-rsc.h \
  scripts/dtc/include-prefixes/dt-bindings/spmi/spmi.h \
  scripts/dtc/include-prefixes/dt-bindings/gpio/gpio.h \
  scripts/dtc/include-prefixes/dt-bindings/regulator/qcom,rpmh-regulator-levels.h \
  arch/arm64/boot/dts/vendor/qcom/shima-gdsc.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-coresight.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-pinctrl.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-pm.dtsi \
  arch/arm64/boot/dts/vendor/qcom/ipcc-test-yupik.dtsi \
  arch/arm64/boot/dts/vendor/qcom/ipcc-test.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-regulators.dtsi \
  arch/arm64/boot/dts/vendor/qcom/display/yupik-sde.dtsi \
  arch/arm64/boot/dts/vendor/qcom/display/yupik-sde-common.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/clock/mdss-5nm-pll-clk.h \
  arch/arm64/boot/dts/vendor/qcom/yupik-pcie.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-vidc.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-usb.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/phy/qcom,yupik-qmp-usb3.h \
  arch/arm64/boot/dts/vendor/qcom/yupik-ion.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/arm/msm/msm_ion_ids.h \
  arch/arm64/boot/dts/vendor/qcom/msm-arm-smmu-yupik.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-qupv3.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-audio.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,audio-ext-clk.h \
  arch/arm64/boot/dts/vendor/qcom/msm-audio-lpass.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-lpi.dtsi \
  arch/arm64/boot/dts/vendor/qcom/camera/yupik-camera.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/msm/msm-camera.h \
  arch/arm64/boot/dts/vendor/qcom/msm-rdbg.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-gpu.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-thermal.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/thermal/thermal_qti.h \
  scripts/dtc/include-prefixes/dt-bindings/thermal/thermal.h \
  arch/arm64/boot/dts/vendor/qcom/lahaina-thermal-modem.dtsi \
  arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtsi \

arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb: $(deps_arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb)

$(deps_arch/arm64/boot/dts/vendor/qcom/yupik-rumi.dtb):
