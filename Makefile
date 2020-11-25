# Use local tools
#GHDL      = ghdl
#GHDLSYNTH = ghdl.so
#YOSYS     = yosys
#NEXTPNR   = nextpnr-ecp5
#ECPPACK   = ecppack
#OPENOCD    = openocd

# Use Docker images
DOCKER=docker
#DOCKER=podman
#
PWD = $(shell pwd)
DOCKERARGS = run --rm -v $(PWD):/src -w /src
#
GHDL      = $(DOCKER) $(DOCKERARGS) hdlc/ghdl:yosys ghdl
GHDLSYNTH = ghdl
YOSYS     = $(DOCKER) $(DOCKERARGS) hdlc/ghdl:yosys yosys
NEXTPNR   = $(DOCKER) $(DOCKERARGS) hdlc/nextpnr:ecp5 nextpnr-ecp5
ECPPACK   = $(DOCKER) $(DOCKERARGS) hdlc/prjtrellis ecppack
OPENOCD   = $(DOCKER) $(DOCKERARGS) --device /dev/bus/usb hdlc/prog openocd


# OrangeCrab with ECP85
#GHDLARGS=-gCLK_FREQUENCY=50000000
#LPF=constraints/orange-crab.lpf
#PACKAGE=CSFBGA285
#NEXTPNR_FLAGS=--um5g-85k --freq 50
#OPENOCD_JTAG_CONFIG=openocd/olimex-arm-usb-tiny-h.cfg
#OPENOCD_DEVICE_CONFIG=openocd/LFE5UM5G-85F.cfg

# ECP5-EVN
GHDL_GENERICS=-gCLK_FREQUENCY=12000000
LPF=constraints/ecp5-evn.lpf
PACKAGE=CABGA381
NEXTPNR_FLAGS=--um5g-85k --freq 12
OPENOCD_JTAG_CONFIG=openocd/ecp5-evn.cfg
OPENOCD_DEVICE_CONFIG=openocd/LFE5UM5G-25F.cfg

# ECP5-HUB75B
# GHDL_GENERICS=-gCLK_FREQUENCY=25000000
# LPF=constraints/ecp5-hub75b.lpf
# PACKAGE=CABGA381
# NEXTPNR_FLAGS=--25k --freq 25
# OPENOCD_JTAG_CONFIG=openocd/ft232.cfg
# OPENOCD_DEVICE_CONFIG=openocd/LFE5UM5G-25F.cfg

all: vhdl_blink.bit

vhdl_blink.json: vhdl_blink.vhdl
	$(GHDL) -a --std=08 $<
	$(YOSYS) -m $(GHDLSYNTH) -p "ghdl --std=08 $(GHDL_GENERICS) toplevel; synth_ecp5 -json $@"

vhdl_blink_out.config: vhdl_blink.json $(LPF)
	$(NEXTPNR) --json $< --lpf $(LPF) --textcfg $@ $(NEXTPNR_FLAGS) --package $(PACKAGE)

vhdl_blink.bit: vhdl_blink_out.config
	$(ECPPACK) --svf vhdl_blink.svf $< $@

vhdl_blink.svf: vhdl_blink.bit

prog: vhdl_blink.svf
	$(OPENOCD) -f $(OPENOCD_JTAG_CONFIG) -f $(OPENOCD_DEVICE_CONFIG) -c "transport select jtag; init; svf $<; exit"

clean:
	@rm -f work-obj08.cf *.bit *.json *.svf *.config

.PHONY: clean prog
.PRECIOUS: vhdl_blink.json vhdl_blink_out.config vhdl_blink.bit
