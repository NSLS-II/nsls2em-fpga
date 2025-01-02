##################################################################
# CHECK VIVADO VERSION
##################################################################

set scripts_vivado_version 2022.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
  catch {common::send_msg_id "IPS_TCL-100" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_ip_tcl to create an updated script."}
  return 1
}

##################################################################
# START
##################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source dds_simadc.tcl
# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
  create_project vivado vivado -part xc7z030sbg485-1
  set_property target_language VHDL [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:dds_compiler:6.0 }
  set list_ips_missing ""
  common::send_msg_id "IPS_TCL-1001" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

  foreach ip_vlnv $list_check_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    lappend list_ips_missing $ip_vlnv
    }
  }

  if { $list_ips_missing ne "" } {
    catch {common::send_msg_id "IPS_TCL-105" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
    set bCheckIPsPassed 0
  }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "IPS_TCL-102" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 1
}

##################################################################
# CREATE IP dds_simadc
##################################################################

set dds_simadc [create_ip -name dds_compiler -vendor xilinx.com -library ip -version 6.0 -module_name dds_simadc]

# User Parameters
set_property -dict [list \
  CONFIG.DATA_Has_TLAST {Not_Required} \
  CONFIG.DDS_Clock_Rate {.378545} \
  CONFIG.Frequency_Resolution {0.4} \
  CONFIG.Has_Phase_Out {true} \
  CONFIG.Latency {7} \
  CONFIG.M_DATA_Has_TUSER {Not_Required} \
  CONFIG.Noise_Shaping {None} \
  CONFIG.Output_Frequency1 {0} \
  CONFIG.Output_Selection {Sine_and_Cosine} \
  CONFIG.Output_Width {16} \
  CONFIG.PINC1 {10000} \
  CONFIG.Parameter_Entry {Hardware_Parameters} \
  CONFIG.PartsPresent {Phase_Generator_and_SIN_COS_LUT} \
  CONFIG.Phase_Increment {Programmable} \
  CONFIG.Phase_Width {32} \
  CONFIG.Phase_offset {None} \
  CONFIG.S_PHASE_Has_TUSER {Not_Required} \
  CONFIG.Spurious_Free_Dynamic_Range {90} \
] [get_ips dds_simadc]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $dds_simadc

##################################################################

