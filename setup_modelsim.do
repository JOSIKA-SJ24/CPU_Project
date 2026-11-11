# Run from the repository root: do setup_modelsim.do
# Creates the local project only when it does not already exist.
if {[file exists CPU_Project.mpf]} {
    project open CPU_Project.mpf
} else {
    project new [pwd] CPU_Project work
    project addfile rtl/regfile.v
    project addfile rtl/alu.v
    project addfile rtl/control.v
    project addfile rtl/cpu.v
    project addfile tb/tb_cpu.v
}
project compileall
