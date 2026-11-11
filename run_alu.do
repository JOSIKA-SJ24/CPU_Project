# In the ModelSim Transcript at the project root, enter: do run_alu.do
quit -sim
# Use a separate ALU simulation library, preserving the original CPU work library.
if {![file isdirectory alu_work]} {vlib alu_work}
vmap alu_work alu_work
vlog -work alu_work rtl/alu.v tb/tb_alu.v
vsim -voptargs=+acc -wlf alu.wlf alu_work.tb_alu
add wave /tb_alu/a /tb_alu/b /tb_alu/op /tb_alu/y
add wave -radix decimal /tb_alu/tests /tb_alu/errors
run -all
