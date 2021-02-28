set_svf ../outputs/risc8.svf

analyze -f verilog -vcs "-f ../../rtl/syn.vf"
elaborate risc8

source syn.sdc
check_timing

set_fix_multiple_port_nets -all -buffer_constants

group_path -name INPUTS -from [all_inputs]
group_path -name OUTPUTS -to [all_outputs]
group_path -name COMB -from [all_inputs] -to [all_outputs]
group_path -name clk -weight 5 -critical_range 0.3

compile_ultra

change_name -rules verilog -hier

set_svf -off

report_qor > ../reports/syn.rpt
report_constraints -all_violators >> ../reports/syn.rpt
report_timing >> ../reports/syn.rpt

write_sdc ../outputs/syn.sdc
write -f verilog -output ../outputs/syn.gv
write -f ddc -output ../outputs/syn.ddc
