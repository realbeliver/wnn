# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= nvc
SRC_DIR = $(PWD)/../src


ifneq ($(GATES),yes)

# RTL simulation:
SIM=ghdl
SIM_BUILD				= sim_build/rtl
COMPILE_ARGS := --std=08
GHDL_ARGS +=--std=08
SIM_ARGS += --fst=tb.fst
TOPLEVEL_LANG = vhdl
VHDL_SOURCES += $(SRC_DIR)/tt_um_jpigdon_gps_accelerator_top.vhdl
VHDL_SOURCES += $(SRC_DIR)/gold_code_gen.vhdl
VHDL_SOURCES += $(SRC_DIR)/bidir_complex_nco_1b.vhdl
VHDL_SOURCES += $(SRC_DIR)/biphase_accu_and_dump.vhdl
VHDL_SOURCES += $(SRC_DIR)/single_complex_correlator_channel.vhdl
VHDL_SOURCES += $(SRC_DIR)/acq_complex_correlator_channel.vhdl
VHDL_SOURCES += $(SRC_DIR)/track_complex_correlator_channel.vhdl
VHDL_SOURCES += $(SRC_DIR)/acquisition_mgmt_sm.vhdl
VHDL_SOURCES += $(SRC_DIR)/track_mgmt_sm.vhdl
VHDL_SOURCES += $(SRC_DIR)/master_timing.vhdl
VHDL_SOURCES += $(SRC_DIR)/acq_and_track_subsystem.vhdl
VHDL_SOURCES += $(SRC_DIR)/bit_syncronizer.vhdl
VHDL_SOURCES += $(SRC_DIR)/control_system.vhdl
VHDL_SOURCES += $(SRC_DIR)/spi_control_if.vhdl
#TOPLEVEL = acq_and_track_subsystem
#MODULE = test_acq_and_track_subsystem
#TOPLEVEL = control_system
#MODULE = test_control_system
TOPLEVEL = tt_um_jpigdon_gps_accelerator_top
COCOTB_TEST_MODULES = test_um_system

else

# Gate level simulation:
SIM=icarus
FST=-fst
TOPLEVEL_LANG = verilog
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += ${PDK_ROOT}/ciel/gf180mcu/versions/54435919abffb937387ec956209f9cf5fd2dfbee/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v
VERILOG_SOURCES += ${PDK_ROOT}/ciel/gf180mcu/versions/54435919abffb937387ec956209f9cf5fd2dfbee/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/gf180mcu_fd_sc_mcu7t5v0.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

COMPILE_ARGS 		+= -I$(SRC_DIR)
TOPLEVEL = tt_um_jpigdon_gps_accelerator_top
#MODULE = test_um_system
COCOTB_TEST_MODULES = test_um_system
endif

# Allow sharing configuration between design and testbench via `include`:

# Include the testbench sources:
#TOPLEVEL = gold_code_gen
#MODULE = test_gold_code
#TOPLEVEL = bidir_complex_nco_1b

#TOPLEVEL = tt_um_jpigdon_gps_accelerator_top
#MODULE = test_um_system

# List test modules to run, separated by commas and without the .py suffix:
#COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
