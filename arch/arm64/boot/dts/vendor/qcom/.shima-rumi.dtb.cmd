cmd_arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb := mkdir -p arch/arm64/boot/dts/vendor/qcom/ ; clang -E -Wp,-MMD,arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.d.pre.tmp -nostdinc -I./scripts/dtc/include-prefixes -undef -D__DTS__ -x assembler-with-cpp -o arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.dts.tmp arch/arm64/boot/dts/vendor/qcom/shima-rumi.dts ; ./scripts/dtc/dtc -O dtb -o arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb -b 0 -iarch/arm64/boot/dts/vendor/qcom/ -i./scripts/dtc/include-prefixes -@ -q -Wno-unit_address_vs_reg -Wno-simple_bus_reg -Wno-unit_address_format -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-simple_bus_reg -Wno-unique_unit_address -Wno-pci_device_reg  -d arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.d.dtc.tmp arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.dts.tmp ; cat arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.d.pre.tmp arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.d.dtc.tmp > arch/arm64/boot/dts/vendor/qcom/.shima-rumi.dtb.d

source_arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb := arch/arm64/boot/dts/vendor/qcom/shima-rumi.dts

deps_arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb := \
  arch/arm64/boot/dts/vendor/qcom/shima.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,aop-qmp.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,camcc-shima.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,dispcc-shima.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,gcc-shima.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,gpucc-shima.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,rpmh.h \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,videocc-shima.h \
  scripts/dtc/include-prefixes/dt-bindings/interconnect/qcom,epss-l3.h \
  scripts/dtc/include-prefixes/dt-bindings/interconnect/qcom,icc.h \
  scripts/dtc/include-prefixes/dt-bindings/interconnect/qcom,shima.h \
  scripts/dtc/include-prefixes/dt-bindings/interrupt-controller/arm-gic.h \
  scripts/dtc/include-prefixes/dt-bindings/interrupt-controller/irq.h \
  scripts/dtc/include-prefixes/dt-bindings/soc/qcom,ipcc.h \
  scripts/dtc/include-prefixes/dt-bindings/soc/qcom,rpmh-rsc.h \
  scripts/dtc/include-prefixes/dt-bindings/spmi/spmi.h \
  scripts/dtc/include-prefixes/dt-bindings/gpio/gpio.h \
  scripts/dtc/include-prefixes/dt-bindings/regulator/qcom,rpmh-regulator-levels.h \
  arch/arm64/boot/dts/vendor/qcom/shima-pinctrl.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-pm.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-regulators.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-qupv3.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-gdsc.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-ion.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/arm/msm/msm_ion_ids.h \
  arch/arm64/boot/dts/vendor/qcom/shima-usb.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/phy/qcom,shima-qmp-usb3.h \
  arch/arm64/boot/dts/vendor/qcom/shima-pcie.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-coresight.dtsi \
  arch/arm64/boot/dts/vendor/qcom/ipcc-test-shima.dtsi \
  arch/arm64/boot/dts/vendor/qcom/ipcc-test.dtsi \
  arch/arm64/boot/dts/vendor/qcom/msm-arm-smmu-shima.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-vidc.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-cvp.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-gpu.dtsi \
  arch/arm64/boot/dts/vendor/qcom/display/shima-sde.dtsi \
  arch/arm64/boot/dts/vendor/qcom/display/shima-sde-common.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/clock/mdss-5nm-pll-clk.h \
  arch/arm64/boot/dts/vendor/qcom/shima-audio.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/clock/qcom,audio-ext-clk.h \
  arch/arm64/boot/dts/vendor/qcom/msm-audio-lpass.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-lpi.dtsi \
  arch/arm64/boot/dts/vendor/qcom/shima-thermal.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/thermal/thermal_qti.h \
  scripts/dtc/include-prefixes/dt-bindings/thermal/thermal.h \
  arch/arm64/boot/dts/vendor/qcom/lahaina-thermal-modem.dtsi \
  arch/arm64/boot/dts/vendor/qcom/msm-rdbg.dtsi \
  arch/arm64/boot/dts/vendor/qcom/camera/shima-camera.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/msm/msm-camera.h \
  arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtsi \

arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb: $(deps_arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb)

$(deps_arch/arm64/boot/dts/vendor/qcom/shima-rumi.dtb):
