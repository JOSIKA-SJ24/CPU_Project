# From the project root, run: do run_b_tests.do. Check the ALU, decoder, original CPU and new instruction program in order.
quit -sim
if {![file isdirectory b_work]} {vlib b_work}
vmap b_work b_work
vlog -work b_work rtl/regfile.v rtl/alu.v rtl/control.v rtl/cpu.v tb/tb_alu.v tb/tb_control.v tb/tb_cpu.v tb/tb_cpu_alu_b.v
set b_errors 0
foreach b_top {tb_alu tb_control tb_cpu tb_cpu_alu_b} {
    vsim -voptargs=+acc -wlf ${b_top}_b.wlf b_work.$b_top
    add wave -r /$b_top/*
    run -all
    set b_current_errors [examine -radix decimal /$b_top/errors]
    incr b_errors $b_current_errors
    if {$b_top eq "tb_cpu_alu_b"} {
        if {[examine -radix unsigned /tb_cpu_alu_b/done] != 1} {incr b_errors}
    } else {
        quit -sim
    }
}
if {$b_errors != 0} {error "FAIL: B instruction suite, $b_errors errors"}
puts "PASS: all B instruction tests and original CPU regression."
