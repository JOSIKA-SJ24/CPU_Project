# Run from the repository root: do run_modelsim.do
# End the previous simulation before recompiling modified source files.
quit -sim
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -work work rtl/regfile.v rtl/alu.v rtl/control.v rtl/cpu.v tb/tb_cpu.v
vsim -voptargs=+acc work.tb_cpu
add wave -r /tb_cpu/*
run -all
