#/tool/cbar/apps_lipc24_64/icc/2012.06/bin/icc_shell

############################################################
# Create Milkyway Design Library
############################################################
create_mw_lib $my_mw_lib -open -technology $tech_file \
	-mw_reference_library "$mw_path/sc $mw_path/io $mw_path/ram16x128"

############################################################
# Load the netlist, constraints and controls.
############################################################
import_designs $verilog_file \
	-format verilog \
	-top $top_design

############################################################
# Load TLU+ files
############################################################
set_tlu_plus_files \
	-max_tluplus $tlup_max \
	-min_tluplus $tlup_min \
	-tech2itf_map  $tlup_map


############################################################
# Logic connect the PG
############################################################
derive_pg_connection -power_net VDD -power_pin VDD -ground_net VSS -ground_pin VSS
derive_pg_connection -power_net VDDO -power_pin VDDO -ground_net VSSO -ground_pin VSSO
derive_pg_connection -power_net VDDQ -power_pin VDDQ -ground_net VSSQ -ground_pin VSSQ
derive_pg_connection -power_net VDD -ground_net VSS -tie

read_sdc $sdc_file
