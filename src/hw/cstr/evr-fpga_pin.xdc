
 
create_clock -period 3.2 [get_ports gtx_evr_refclk_p]
create_clock -period 8.0 [get_ports gtx_fofb_refclk_p]


#MGTREFCLK1 - U18  (312.5MHz)
set_property LOC V5 [get_ports  gtx_evr_refclk_n ] 
set_property LOC U5 [get_ports  gtx_evr_refclk_p ]


#MGTREFCLK0 - U17  (125MHz)
set_property LOC V9 [get_ports  gtx_fofb_refclk_n ] 
set_property LOC U9 [get_ports  gtx_fofb_refclk_p ]

#
 
################################# mgt wrapper constraints #####################

##---------- Set placement for gt0_gtx_wrapper_i/GTXE2_CHANNEL ------

set_property LOC GTXE2_CHANNEL_X0Y3 [get_cells evr/evr_gtx_init_i/U0/evr_gtx_i/gt0_evr_gtx_i/gtxe2_i]

set_property LOC GTXE2_CHANNEL_X0Y0 [get_cells fofb/fofb_gtx_init_i/U0/fofb_gtx_i/gt0_fofb_gtx_i/gtxe2_i]

