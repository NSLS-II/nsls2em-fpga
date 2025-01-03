
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
 
 library desyrdl;
use desyrdl.common.all;
use desyrdl.pkg_pl_regs.all;

library xil_defaultlib;
use xil_defaultlib.xbpm_package.ALL;
 

--library work;
--use work.xbpm_package.ALL;


entity top is
generic(
    FPGA_VERSION			: integer := 14;
    SIM_MODE				: integer := 0
    );
  port (
    ddr_addr                : inout std_logic_vector ( 14 downto 0 );
    ddr_ba                  : inout std_logic_vector ( 2 downto 0 );
    ddr_cas_n               : inout std_logic;
    ddr_ck_n                : inout std_logic;
    ddr_ck_p                : inout std_logic;
    ddr_cke                 : inout std_logic;
    ddr_cs_n                : inout std_logic;
    ddr_dm                  : inout std_logic_vector ( 3 downto 0 );
    ddr_dq                  : inout std_logic_vector ( 31 downto 0 );
    ddr_dqs_n               : inout std_logic_vector ( 3 downto 0 );
    ddr_dqs_p               : inout std_logic_vector ( 3 downto 0 );
    ddr_odt                 : inout std_logic;
    ddr_ras_n               : inout std_logic;
    ddr_reset_n             : inout std_logic;
    ddr_we_n                : inout std_logic;
    fixed_io_ddr_vrn        : inout std_logic;
    fixed_io_ddr_vrp        : inout std_logic;
    fixed_io_mio            : inout std_logic_vector ( 53 downto 0 );
    fixed_io_ps_clk         : inout std_logic;
    fixed_io_ps_porb        : inout std_logic;
    fixed_io_ps_srstb       : inout std_logic;
    
    adc_sck                 : out std_logic_vector(NUM_ADCS-1 downto 0);
    adc_cnv                 : out std_logic_vector(NUM_ADCS-1 downto 0);
    adc_busy                : in std_logic_vector(NUM_ADCS-1 downto 0);
    adc_sdo                 : in std_logic_vector(NUM_ADCS-1 downto 0); 
    afe_lat                 : out std_logic_vector(3 downto 0);
    afe_cs                  : out std_logic_vector(3 downto 0);
    afe_sck                 : out std_logic_vector(3 downto 0);
    afe_sdi                 : out std_logic_vector(3 downto 0);
    afe_gain                : out std_logic_vector(7 downto 0);
          
    -- Bias DAC (AD5060)
    biasdac_sclk             : out std_logic;
    biasdac_din              : out std_logic;
    biasdac_sync             : out std_logic;   
         
    --sfp I/O
    sfp_sck                 : inout std_logic_vector(1 downto 0);
    sfp_sda                 : inout std_logic_vector(1 downto 0);
       
     -- FOFB transceiver
    gtx_fofb_refclk_p        : in std_logic;
    gtx_fofb_refclk_n        : in std_logic;
    gtx_fofb_rx_p            : in std_logic;
    gtx_fofb_rx_n            : in std_logic;
    gtx_fofb_tx_p            : out std_logic;
    gtx_fofb_tx_n            : out std_logic;   
       
    -- Embedded Event Receiver
    gtx_evr_refclk_p        : in std_logic;
    gtx_evr_refclk_n        : in std_logic;
    gtx_evr_rx_p            : in std_logic;
    gtx_evr_rx_n            : in std_logic;
    
    -- Motor Control DAC (AD5754)
    fdbkdac_syncn           : out std_logic;
    fdbkdac_sclk            : out std_logic;  
    fdbkdac_sdin            : out std_logic;
    fdbkdac_sdo             : in std_logic; 
    fdbkdac_ldacn           : out std_logic;
    fdbkdac_clrn            : out std_logic;  
    fdbkdac_bin2s           : out std_logic; 
    
    -- Thermistor Readback (LT2986)
    therm_sclk              : out std_logic;
    therm_sdo               : in std_logic;
    therm_sdi               : out std_logic;
    therm_csn               : out std_logic;
    therm_rstn              : out std_logic;
    
    -- Temperature Control DAC (AD5754)
    heatdac_syncn           : out std_logic;
    heatdac_sclk            : out std_logic;  
    heatdac_sdin            : out std_logic;
    heatdac_sdo             : in std_logic; 
    heatdac_ldacn           : out std_logic;
    heatdac_clrn            : out std_logic;  
    heatdac_bin2s           : out std_logic; 
      
    -- Debug header
    dbg                     : out std_logic_vector(9 downto 0);
    
    -- GPIO
    gpio_in                 : in std_logic_vector(3 downto 0);
    gpio_out                : out std_logic_vector(3 downto 0);

    -- fan control
    fan_tach                : in std_logic;
    fan_i2c_sda             : inout std_logic;
    fan_i2c_scl             : out std_logic;
    
    -- Current, voltage and temperature i2c
    ivt_i2c_sda             : inout std_logic;
    ivt_i2c_scl             : out std_logic;

    --  LED's
    fp_leds                 : out std_logic_vector(3 downto 0)

  );
end top;


architecture behv of top is

   signal pl_clk0               : std_logic;
   signal fpga_clk              : std_logic;
   signal mach_clk              : std_logic;   
   signal gtx_evr_refclk        : std_logic;
   signal gtx_fofb_refclk       : std_logic;
   signal pl_resetn             : std_logic;
   signal pl_reset              : std_logic;
   signal gtx_rst               : std_logic_vector(7 downto 0);
   
   signal m_axi4_m2s            : t_pl_regs_m2s;
   signal m_axi4_s2m            : t_pl_regs_s2m;
   
   signal ps_leds               : std_logic_vector(3 downto 0);
      
   signal soft_trig             : std_logic;

   signal adc_testmode_enb      : std_logic;
   signal adc_testmode_rst      : std_logic;
   signal adc_data_valid        : std_logic_vector(NUM_ADCS-1 downto 0);  
   signal adc_raw               : adc_raw_type; 

   signal ivt_regs              : ivt_regs_type;
   
   signal sa_data               : data_type;
   signal sa_trignum            : std_logic_vector(31 downto 0);     
   signal sa_cnt                : std_logic_vector(31 downto 0);
   signal sa_divide             : std_logic_vector(31 downto 0);
   signal sa_irqenb             : std_logic;
   signal sa_irq                : std_logic;  
   signal sa_trig               : std_logic; 
     
   signal fa_data               : data_type;
   signal fa_divide             : std_logic_vector(31 downto 0);   
   signal fa_trig               : std_logic;
    
   signal fa_data_rdstr         : std_logic;
   signal fa_data_dout          : std_logic_vector(31 downto 0);
   signal fa_data_rdcnt         : std_logic_vector(31 downto 0);
   signal fa_data_fiforst       : std_logic;

   signal fa_rcvd_data_enb      : std_logic;
   signal fa_rcvd_data_rdstr    : std_logic;
   signal fa_rcvd_data_dout     : std_logic_vector(31 downto 0);
   signal fa_rcvd_data_rdcnt    : std_logic_vector(31 downto 0);
   signal fa_rcvd_data_fiforst  : std_logic;

   signal biasdac_data          : std_logic_vector(31 downto 0);
   signal biasdac_we            : std_logic;

   signal fdbkdac_data          : std_logic_vector(31 downto 0);
   signal fdbkdac_we            : std_logic;
   signal fdbkdac_opmode        : std_logic;
   signal fdbkdac_ldac_ps       : std_logic;

   signal heatdac_data          : std_logic_vector(31 downto 0);
   signal heatdac_we            : std_logic;
   signal heatdac_ldac_ps       : std_logic;
   
   signal therm_wrdata          : std_logic_vector(31 downto 0);
   signal therm_we              : std_logic;
   signal therm_rddata          : std_logic_vector(7 downto 0);
   
   signal pos_params            : pos_params_type;
   
   signal sa_trig_stretch       : std_logic;
   signal evr_gps_trig_stretch  : std_logic;
   signal evr_usrtrig_stretch   : std_logic;
   
   signal mach_clk_sel          : std_logic;
   signal machclk_divide        : std_logic_vector(7 downto 0);
 
   signal trig_clear            : std_logic;
   signal trig_status           : std_logic_vector(1 downto 0);
   signal trig_active           : std_logic;

   signal evr_dbg               : std_logic_vector(19 downto 0);
   signal evr_tbt_trig          : std_logic;
   signal evr_fa_trig           : std_logic;
   signal evr_sa_trig           : std_logic;
   signal evr_usr_trig          : std_logic;
   signal evr_dma_trig          : std_logic;
   signal evr_gps_trig          : std_logic;
   signal evr_timestamp         : std_logic_vector(63 downto 0);
   signal evr_timestamplat      : std_logic_vector(63 downto 0);
   signal evr_trignum           : std_logic_vector(7 downto 0);
   signal evr_trigdly           : std_logic_vector(31 downto 0);
   signal evr_rcvd_clk          : std_logic;
   
   signal fofb_rcvd_clk         : std_logic;
   signal fofb_rcvd_data        : std_logic_vector(31 downto 0);
   signal fofb_rcvd_val         : std_logic;
   
   signal fofb_txusr_clk        : std_logic;
   signal fofb_txactive         : std_logic;
   
   signal afe_sck_i             : std_logic;
   signal afe_sdi_i             : std_logic;
   signal afe_cs_i              : std_logic;
   signal afe_lat_i             : std_logic;
   signal afe_cntrl_we          : std_logic;
   signal afe_cntrl_data        : std_logic_vector(31 downto 0);
   
   signal fan_tachcnt           : std_logic_vector(15 downto 0);
   signal fan_status            : std_logic_vector(7 downto 0);
   signal fan_setspeed          : std_logic_vector(5 downto 0);



  

   --debug signals (connect to ila)
   attribute mark_debug                 : string;
   attribute mark_debug of adc_cnv     : signal is "true";
   attribute mark_debug of adc_sck     : signal is "true";
   attribute mark_debug of adc_busy    : signal is "true";
   attribute mark_debug of adc_sdo     : signal is "true";      
   attribute mark_debug of adc_raw     : signal is "true";   
   attribute mark_debug of mach_clk   : signal is "true";    
   
   attribute mark_debug of afe_sck: signal is "true";
   attribute mark_debug of afe_sdi: signal is "true";
   attribute mark_debug of afe_cs: signal is "true";
   attribute mark_debug of afe_lat: signal is "true";

begin




dbg(0) <= mach_clk; 
dbg(1) <= fa_trig; 
dbg(2) <= fofb_txactive; 
dbg(3) <= fa_data.data_rdy; 
dbg(4) <= pl_clk0; 
dbg(5) <= fofb_txusr_clk; 
dbg(6) <= fdbkdac_sclk; 
dbg(7) <= evr_fa_trig;  
dbg(8) <= evr_sa_trig; 

fp_leds(0) <= ps_leds(0);  
fp_leds(1) <= trig_active;    
fp_leds(2) <= sa_trig_stretch;  
fp_leds(3) <= evr_gps_trig_stretch;    

pl_reset <= not pl_resetn; 

-- generate interrupt
sa_irq <= sa_trig when (sa_irqenb = '1') else '0';




--gtx refclk for EVR
evr_refclk : IBUFDS_GTE2  
  port map (
    O => gtx_evr_refclk, 
    ODIV2 => open,
    CEB => 	'0',
    I => gtx_evr_refclk_p,
    IB => gtx_evr_refclk_n
);

--gtx refclk for FOFB
fofb_refclk : IBUFDS_GTE2  
  port map (
    O => gtx_fofb_refclk, 
    ODIV2 => open,
    CEB => 	'0',
    I => gtx_fofb_refclk_p,
    IB => gtx_fofb_refclk_n
);



gen_fegain: for i in 0 to 3 generate
begin
fegain: entity work.ada4350_spi 
  port map (
    clk => pl_clk0,                     
    reset => pl_reset,                      
    we => afe_cntrl_we,
    wrdata => afe_cntrl_data(i*8+3 downto i*8),
    sclk => afe_sck(i),                    
    sdin => afe_sdi(i), 
    cs => afe_cs(i), 
    lat => afe_lat(i)           
  );    
end generate;



gen_adcs : for i in 0 to NUM_ADCS-1 generate
begin
readadc : entity work.ltc2378 
  generic map (
    SIM_MODE => SIM_MODE)
  port map(
    clk	=> pl_clk0, 
    adc_clk => mach_clk, 
    reset => pl_reset, 
	testmode_enb => adc_testmode_enb,
	testmode_rst => adc_testmode_rst,    
	adc_sdo => adc_sdo(i), 
	adc_busy => adc_busy(i), 
	adc_cnv => adc_cnv(i), 
	adc_sck => adc_sck(i), 
	adc_sdi => open,
	adc_data => adc_raw(i), 
    adc_data_valid => adc_data_valid(i) 
);
end generate;



--embedded event receiver
evr: entity work.evr_top 
  port map(
    sys_clk => pl_clk0,
    sys_rst => pl_reset,
    gtx_reset => gtx_rst,
    gtx_refclk => gtx_evr_refclk, 
    rx_p => gtx_evr_rx_p,
    rx_n => gtx_evr_rx_n,
    trignum => evr_trignum,  
    trigdly => (x"00000001"),   
    tbt_trig => evr_tbt_trig, 
    fa_trig => evr_fa_trig, 
    sa_trig => evr_sa_trig, 
    usr_trig => evr_usr_trig, 
    gps_trig => evr_gps_trig, 
    timestamp => evr_timestamp,  
    evr_rcvd_clk => evr_rcvd_clk,
    dbg => evr_dbg  
);	

--fofb gtx interface
fofb: entity work.fofb_top 
  port map(
    sys_clk => pl_clk0, 
    sys_rst => pl_reset, 
    gtx_reset => gtx_rst,
    gtx_refclk => gtx_evr_refclk, 	 -- 125 MHz reference clock
    fa_data => fa_data, 
    tx_p => gtx_fofb_tx_p, 
    tx_n => gtx_fofb_tx_n, 
    rx_p => gtx_fofb_rx_p, 
    rx_n => gtx_fofb_rx_n, 
    fofb_rcvd_clk => fofb_rcvd_clk, 
    fofb_rcvd_data => fofb_rcvd_data, 
    fofb_rcvd_val => fofb_rcvd_val,    
    fofb_txactive => fofb_txactive,
    fofb_txusr_clk => fofb_txusr_clk  
);

stream_rcvd_fa:  entity work.stream_rcvd_fa_data
  port map(
    sys_clk => pl_clk0, 
    fa_rcvd_clk =>  fofb_rcvd_clk, 
    reset => pl_reset, 
    fa_data => fofb_rcvd_data,
    fa_data_val => fofb_rcvd_val, 
    fa_data_enb =>  fa_rcvd_data_enb, 
    fa_data_fiforst => fa_rcvd_data_fiforst, 
	fifo_rdstr => fa_rcvd_data_rdstr, 
	fifo_dout => fa_rcvd_data_dout, 
	fifo_rdcnt => fa_rcvd_data_rdcnt    
);





clk_logic:  entity work.clk_cntrl
  port map(
    clk => pl_clk0, 
    reset => pl_reset,  
    mach_clk_sel => mach_clk_sel,
    machclk_divide => machclk_divide,
    fa_divide => fa_divide, 
    sa_divide => sa_divide,     
    evr_tbtclk => evr_tbt_trig,
    evr_fatrig => evr_fa_trig,
    evr_satrig => evr_sa_trig,
    mach_clk => mach_clk,
    fa_trig => fa_trig,
    sa_trig => sa_trig
);


trig_logic : entity work.trig_cntrl
  port map(
    clk => pl_clk0, 
    reset => pl_reset, 
    mach_clk_sel => mach_clk_sel,     
    trig_clear => trig_clear,    
    soft_trig => soft_trig,
    evr_trig => evr_usr_trig,
    evr_timestamp => evr_timestamp, 
    evr_timestamplat => evr_timestamplat,
    trig_status => trig_status,
    trig_active => trig_active
 );


fa_poscalc: entity work.calcpos
  generic map (
    SIM_MODE => SIM_MODE)
  port map(
     sys_clk => pl_clk0, 
     mach_clk => mach_clk, 
     reset => pl_reset,  
     pos_params => pos_params,
     trig => fa_trig,
     divide => fa_divide,   
     adc_raw => adc_raw,
     data => fa_data    
    );


stream_fa : entity work.stream_fa_data
  port map(
    mach_clk => mach_clk, 
    sys_clk => pl_clk0, 
    reset => pl_reset,   
    fa_data => fa_data, 
    fa_data_enb => trig_active, 
    fa_data_fiforst => fa_data_fiforst,
    adc_raw => adc_raw,
	evr_timestamp => evr_timestamp,	 
	fifo_rdstr => fa_data_rdstr, 
	fifo_dout => fa_data_dout, 
	fifo_rdcnt => fa_data_rdcnt	 	    
);


sa_poscalc: entity work.calcpos
  generic map (
    SIM_MODE => SIM_MODE)
  port map(
     sys_clk => pl_clk0,
     mach_clk => mach_clk, 
     reset => pl_reset, 
     pos_params => pos_params,
     trig => sa_trig,
     divide => sa_divide,   
     adc_raw => adc_raw,
     data => sa_data    
    );


bias_cntrl : entity work.ad5060_spi  
  port map(
    clk => pl_clk0,                     
    reset => pl_reset,                     
    we => biasdac_we,
    wrdata => biasdac_data,
    sclk => biasdac_sclk,                    
    din => biasdac_din,
    sync => biasdac_sync                 
);   


fdbk_cntrl :  entity work.ad5754_spi
  port map (
    clk => pl_clk0,                     
    reset => pl_reset,                      
    we => fdbkdac_we, 
    wrdata => fdbkdac_data, 
    opmode => fdbkdac_opmode,
    ldac_ps => fdbkdac_ldac_ps,
    adc_raw => adc_raw,
    adc_data_valid => adc_data_valid(0),
    sclk => fdbkdac_sclk,                    
    din => fdbkdac_sdin, 
    sync => fdbkdac_syncn,
    ldac => fdbkdac_ldacn,
    clrn => fdbkdac_clrn,
    bin2s => fdbkdac_bin2s                  
 );    


heat_cntrl :  entity work.ad5754_spi
  port map (
    clk => pl_clk0,                     
    reset => pl_reset,                      
    we => heatdac_we, 
    wrdata => heatdac_data, 
    opmode => '0', 
    ldac_ps => heatdac_ldac_ps,
    adc_raw => adc_raw,
    adc_data_valid => adc_data_valid(0),
    sclk => heatdac_sclk,                    
    din => heatdac_sdin, 
    sync => heatdac_syncn,
    ldac => heatdac_ldacn,
    clrn => heatdac_clrn,
    bin2s => heatdac_bin2s                  
 );    


therm_rdbk: entity work.ltc2986_spi 
  port map (
    clk => pl_clk0,                     
    reset => pl_reset,                      
    we => therm_we, 
    wrdata => therm_wrdata,
    rddata => therm_rddata, 
    csn => therm_csn, 
    sck => therm_sclk,                    
    sdi => therm_sdi, 
    sdo => therm_sdo,
    rstn => therm_rstn             
  );    



fan_ctrl: entity work.fan_i2c 
  port map ( 
    clk => pl_clk0, 
    reset => pl_reset, 
    tach => fan_tach, 
    scl => fan_i2c_scl, 
    sda => fan_i2c_sda, 
    speed => fan_setspeed,
    OCF => fan_status(0), 
    THE => fan_status(1), 
    i2c_good => fan_status(2), 
    tach_count => fan_tachcnt
);



ivt_i2c : entity work.qafe_monitors
  port map(
	clock => pl_clk0,  
	reset => pl_reset, 
	scl => ivt_i2c_scl, 
	sda => ivt_i2c_sda,
	registers => ivt_regs  
);    


ps_pl: entity work.ps_io
  generic map (
    FPGA_VERSION => FPGA_VERSION
    )
  port map (
    pl_clock => pl_clk0, 
    pl_reset => pl_reset, 
    m_axi4_m2s => m_axi4_m2s, 
    m_axi4_s2m => m_axi4_s2m, 
 	gpio_in => gpio_in,
	gpio_out => gpio_out,   
	adc_testmode_enb => adc_testmode_enb,
	adc_testmode_rst => adc_testmode_rst, 
	ps_leds => ps_leds,
  	sa_divide => sa_divide, 
    sa_irqenb => sa_irqenb, 
    fa_divide => fa_divide,
	mach_clk_sel => mach_clk_sel,
	machclk_divide => machclk_divide,		
	fan_setspeed => fan_setspeed,
	fan_tachcnt => fan_tachcnt,
	fan_status => fan_status,
    sa_data => sa_data,
    sa_trignum => sa_trignum,       
	afe_cntrl_data => afe_cntrl_data,
	afe_cntrl_we => afe_cntrl_we,	
	afe_gain => afe_gain,
	gtx_rst => gtx_rst,	
	pos_params => pos_params,	 
	biasdac_data => biasdac_data, 
    biasdac_we => biasdac_we, 
	adc_raw => adc_raw,
 	evr_timestamp => evr_timestamp,
	evr_timestamplat => evr_timestamplat,           		
	evr_trignum => evr_trignum,
	evr_trigdly => evr_trigdly,	
 	fdbkdac_data => fdbkdac_data, 
    fdbkdac_we => fdbkdac_we,                
    fdbkdac_ldac => fdbkdac_ldac_ps, 
    fdbkdac_opmode => fdbkdac_opmode,    
	heatdac_data => heatdac_data, 
    heatdac_we => heatdac_we,                
    heatdac_ldac => heatdac_ldac_ps,     
    therm_wrdata => therm_wrdata, 
	therm_we => therm_we, 
	therm_rddata => therm_rddata,  
	ivt_regs => ivt_regs,
	            
	soft_trig => soft_trig,
	trig_status => trig_status,
	trig_clear => trig_clear,  
	
    fa_rcvd_data_enb => fa_rcvd_data_enb,  
   	fa_rcvd_data_fiforst => fa_rcvd_data_fiforst,     
    fa_rcvd_data_rdstr => fa_rcvd_data_rdstr, 
    fa_rcvd_data_dout => fa_rcvd_data_dout, 
    fa_rcvd_data_rdcnt => fa_rcvd_data_rdcnt,
    	        	 	     
   	fa_data_fiforst => fa_data_fiforst,     
    fa_data_rdstr => fa_data_rdstr, 
    fa_data_dout => fa_data_dout, 
    fa_data_rdcnt => fa_data_rdcnt
	            
  );

 
 
  


sys: component system
  port map (
    ddr_addr(14 downto 0) => ddr_addr(14 downto 0),
    ddr_ba(2 downto 0) => ddr_ba(2 downto 0),
    ddr_cas_n => ddr_cas_n,
    ddr_ck_n => ddr_ck_n,
    ddr_ck_p => ddr_ck_p,
    ddr_cke => ddr_cke,
    ddr_cs_n => ddr_cs_n,
    ddr_dm(3 downto 0) => ddr_dm(3 downto 0),
    ddr_dq(31 downto 0) => ddr_dq(31 downto 0),
    ddr_dqs_n(3 downto 0) => ddr_dqs_n(3 downto 0),
    ddr_dqs_p(3 downto 0) => ddr_dqs_p(3 downto 0),
    ddr_odt => ddr_odt,
    ddr_ras_n => ddr_ras_n,
    ddr_reset_n => ddr_reset_n,
    ddr_we_n  => ddr_we_n,
    fixed_io_ddr_vrn => fixed_io_ddr_vrn,
    fixed_io_ddr_vrp => fixed_io_ddr_vrp,
    fixed_io_mio(53 downto 0) => fixed_io_mio(53 downto 0),
    fixed_io_ps_clk => fixed_io_ps_clk,
    fixed_io_ps_porb => fixed_io_ps_porb,
    fixed_io_ps_srstb => fixed_io_ps_srstb,

    pl_clk0 => pl_clk0,
    pl_resetn => pl_resetn,  
    m_axi_araddr => m_axi4_m2s.araddr, 
    m_axi_arprot => m_axi4_m2s.arprot,
    m_axi_arready => m_axi4_s2m.arready,
    m_axi_arvalid => m_axi4_m2s.arvalid,
    m_axi_awaddr => m_axi4_m2s.awaddr,
    m_axi_awprot => m_axi4_m2s.awprot,
    m_axi_awready => m_axi4_s2m.awready,
    m_axi_awvalid => m_axi4_m2s.awvalid,
    m_axi_bready => m_axi4_m2s.bready,
    m_axi_bresp => m_axi4_s2m.bresp,
    m_axi_bvalid => m_axi4_s2m.bvalid,
    m_axi_rdata => m_axi4_s2m.rdata,
    m_axi_rready => m_axi4_m2s.rready,
    m_axi_rresp => m_axi4_s2m.rresp,
    m_axi_rvalid => m_axi4_s2m.rvalid,
    m_axi_wdata => m_axi4_m2s.wdata,
    m_axi_wready => m_axi4_s2m.wready,
    m_axi_wstrb => m_axi4_m2s.wstrb,
    m_axi_wvalid => m_axi4_m2s.wvalid  
  );




stretch_1 : entity work.stretch
  port map (
	clk => pl_clk0,
	reset => pl_reset, 
	sig_in => sa_trig, 
	len => 1000000, -- ~25ms;
	sig_out => sa_trig_stretch
);	  	


stretch_2 : entity work.stretch
  port map (
	clk  => pl_clk0,
	reset => pl_reset, 
	sig_in => evr_gps_trig, 
	len => 1000000, -- ~25ms;
	sig_out => evr_gps_trig_stretch
);	  	 
 
 
stretch_3 : entity work.stretch
  port map (
    clk => pl_clk0,
    reset => pl_reset, 
    sig_in => evr_usr_trig, 
    len => 1000000, -- ~25ms;
    sig_out => evr_usrtrig_stretch
 );           
 
    
    
end behv;
