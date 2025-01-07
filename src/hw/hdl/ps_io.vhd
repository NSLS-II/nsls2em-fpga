
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library desyrdl;
use desyrdl.common.all;
use desyrdl.pkg_pl_regs.all;

library xil_defaultlib;
use xil_defaultlib.xbpm_package.ALL;



entity ps_io is
  generic (
    FPGA_VERSION        : in integer := 01
  );
  port (  
    pl_clock         : in std_logic;
    pl_reset         : in std_logic;
   
    m_axi4_m2s       : in t_pl_regs_m2s;
    m_axi4_s2m       : out t_pl_regs_s2m;   
     
    gpio_in          : in std_logic_vector(3 downto 0); 
	gpio_out         : out std_logic_vector(3 downto 0);    
	adc_testmode_enb : out std_logic;
	adc_testmode_rst : out std_logic;
	ps_leds          : out std_logic_vector(3 downto 0); 
	
	sa_divide        : out std_logic_vector(31 downto 0); 
    sa_irqenb        : out std_logic;  
    fa_divide        : out std_logic_vector(31 downto 0);
	mach_clk_sel     : out std_logic; 
	machclk_divide   : out std_logic_vector(7 downto 0);		
	fan_setspeed     : out std_logic_vector(5 downto 0); 
	fan_tachcnt      : in std_logic_vector(15 downto 0); 
	fan_status       : in std_logic_vector(7 downto 0); 
	sa_data          : in data_type; 
	sa_trignum       : in std_logic_vector(31 downto 0);      
	afe_cntrl_data   : out std_logic_vector(31 downto 0); 
	afe_cntrl_we     : out std_logic;	
	afe_gain         : out std_logic_vector(7 downto 0); 
	gtx_rst          : out std_logic_vector(7 downto 0);
	pos_params       : out pos_params_type;
	biasdac_data     : out std_logic_vector(31 downto 0);
    biasdac_we       : out std_logic;
    adc_raw          : in adc_raw_type;	
    evr_timestamp    : in std_logic_vector(63 downto 0);
    evr_timestamplat : in std_logic_vector(63 downto 0);
    evr_trignum      : out std_logic_vector(7 downto 0);
    evr_trigdly      : out std_logic_vector(31 downto 0);
   
    fdbkdac_data     : out std_logic_vector(31 downto 0);
    fdbkdac_we       : out std_logic;
    fdbkdac_opmode   : out std_logic;
    fdbkdac_ldac     : out std_logic;

    heatdac_data     : out std_logic_vector(31 downto 0);
    heatdac_we       : out std_logic;
    heatdac_ldac     : out std_logic;
   
    therm_wrdata     : out std_logic_vector(31 downto 0);
    therm_we         : out std_logic;
    therm_rddata     : in std_logic_vector(7 downto 0);
    ivt_regs         : in ivt_regs_type;
    
    soft_trig        : out std_logic; 
	trig_status      : in std_logic_vector(1 downto 0);
	trig_clear       : out std_logic;   
    
    fa_data_rdstr    : out std_logic;
    fa_data_dout     : in std_logic_vector(31 downto 0);
    fa_data_rdcnt    : in std_logic_vector(31 downto 0);
    fa_data_fiforst  : out std_logic;

    fa_rcvd_data_enb      : out std_logic;
    fa_rcvd_data_rdstr    : out std_logic;
    fa_rcvd_data_dout     : in std_logic_vector(31 downto 0);
    fa_rcvd_data_rdcnt    : in std_logic_vector(31 downto 0);
    fa_rcvd_data_fiforst  : out std_logic    
    
    
  );
end ps_io;


architecture behv of ps_io is

  

  
  signal reg_i        : t_addrmap_pl_regs_in;
  signal reg_o        : t_addrmap_pl_regs_out;

  attribute mark_debug     : string;
  attribute mark_debug of reg_o: signal is "true";



begin

reg_i.fpgaver.data.data <= std_logic_vector(to_unsigned(FPGA_VERSION,32));

reg_i.gpio_in.data.data <= gpio_in;

gpio_out <= reg_o.gpio_out.data.data;

adc_testmode_enb <= reg_o.adc_testmode.data.data(0);
adc_testmode_rst <= reg_o.adc_testmode.data.data(1);

ps_leds <= reg_o.fp_leds.data.data;

sa_divide <= reg_o.sa_divide.data.data; 
sa_irqenb <= reg_o.sa_irqenb.data.data(0);   
fa_divide <= reg_o.fa_divide.data.data;

mach_clk_sel <= reg_o.mach_clk_sel.data.data(0); 
machclk_divide <= reg_o.machclk_divide.data.data;
 		
fan_setspeed <= reg_o.fan_setspeed.data.data; 
reg_i.fan_tachcnt.data.data <= fan_tachcnt;  
reg_i.fan_status.data.data <= fan_status;  

reg_i.sa_trignum.data.data <= sa_data.trignum;

afe_cntrl_data <= reg_o.afe_cntrl.data.data;
afe_cntrl_we  <= reg_o.afe_cntrl.data.swmod; 	
afe_gain <= reg_o.afe_db_gain.data.data; 

gtx_rst <= reg_o.gtx_reset.data.data;

pos_params.kx <= reg_o.kx.data.data;
pos_params.ky <= reg_o.ky.data.data; 
pos_params.cha_offset <= reg_o.cha_offset.data.data;
pos_params.chb_offset <= reg_o.chb_offset.data.data;
pos_params.chc_offset <= reg_o.chc_offset.data.data;
pos_params.chd_offset <= reg_o.chd_offset.data.data;
pos_params.cha_gain <= reg_o.cha_gain.data.data;
pos_params.chb_gain <= reg_o.chb_gain.data.data;
pos_params.chc_gain <= reg_o.chc_gain.data.data;
pos_params.chd_gain <= reg_o.chd_gain.data.data;
pos_params.xpos_offset <= reg_o.xpos_offset.data.data;
pos_params.ypos_offset <= reg_o.ypos_offset.data.data;

biasdac_data <= reg_o.bias_dac.data.data;
biasdac_we <= reg_o.bias_dac.data.swmod;

reg_i.adc_raw_cha.data.data <= std_logic_vector(resize(signed(adc_raw(0)),32)); 
reg_i.adc_raw_chb.data.data <= std_logic_vector(resize(signed(adc_raw(1)),32));  
reg_i.adc_raw_chc.data.data <= std_logic_vector(resize(signed(adc_raw(2)),32)); 
reg_i.adc_raw_chd.data.data <= std_logic_vector(resize(signed(adc_raw(3)),32)); 
reg_i.adc_raw_che.data.data <= std_logic_vector(resize(signed(adc_raw(4)),32)); 
reg_i.adc_raw_chf.data.data <= std_logic_vector(resize(signed(adc_raw(5)),32)); 
reg_i.adc_raw_chg.data.data <= std_logic_vector(resize(signed(adc_raw(6)),32)); 
reg_i.adc_raw_chh.data.data <= std_logic_vector(resize(signed(adc_raw(7)),32)); 

reg_i.sa_cha.data.data <= sa_data.cha_mag;
reg_i.sa_chb.data.data <= sa_data.chb_mag;
reg_i.sa_chc.data.data <= sa_data.chc_mag;
reg_i.sa_chd.data.data <= sa_data.chd_mag;
reg_i.sa_sum.data.data <= sa_data.sum;
reg_i.sa_xpos.data.data <= sa_data.xpos;
reg_i.sa_ypos.data.data <= sa_data.ypos;

reg_i.ts_s.data.data <= evr_timestamp(63 downto 32);
reg_i.ts_ns.data.data <= evr_timestamp(31 downto 0);
reg_i.ts_s_trig.data.data <= evr_timestamplat(63 downto 32);
reg_i.ts_ns_trig.data.data <= evr_timestamplat(31 downto 0);

fdbkdac_data <= reg_o.fdbk_dac.data.data; 
fdbkdac_we <= reg_o.fdbk_dac.data.swmod; 
fdbkdac_opmode <= reg_o.fdbk_dac_opmode.data.data(0); 
fdbkdac_ldac <= reg_o.fdbk_dac_ldac.data.data(0); 

heatdac_data <= reg_o.heat_dac.data.data; 
heatdac_we <= reg_o.heat_dac.data.swmod; 
heatdac_ldac <= reg_o.heat_dac_ldac.data.data(0); 

therm_wrdata <= reg_o.thermistor.data.data; 
therm_we <= reg_o.thermistor.data.swmod; 
reg_i.thermistor.data.data <= 24d"0" & therm_rddata;

reg_i.temp0.data.data <= ivt_regs.temp0;
reg_i.temp1.data.data <= ivt_regs.temp2;
reg_i.vin.data.data <= ivt_regs.Vreg0;
reg_i.iin.data.data <= ivt_regs.Ireg0;


--reg_o_adcfifo.enb <= reg_o.adcfifo_streamenb.data.swmod;
fa_data_fiforst <= reg_o.fafifo_reset.data.data(0);
fa_data_rdstr <= reg_o.fafifo_data.data.swacc;
reg_i.fafifo_rdcnt.data.data <= fa_data_rdcnt;
reg_i.fafifo_data.data.data <= fa_data_dout;


fa_rcvd_data_enb <= reg_o.fafifo_rcvd_streamenb.data.data(0);
fa_rcvd_data_fiforst <= reg_o.fafifo_rcvd_reset.data.data(0);
fa_rcvd_data_rdstr <= reg_o.fafifo_rcvd_data.data.swacc;
reg_i.fafifo_rcvd_rdcnt.data.data <= fa_rcvd_data_rdcnt;
reg_i.fafifo_rcvd_data.data.data <= fa_rcvd_data_dout;

soft_trig <= reg_o.fa_softtrig.data.data(0); 
trig_clear <= reg_o.fa_trigclear.data.data(0);
reg_i.fa_trigstat.data.data <= trig_status;





regs: pl_regs
  port map (
    pi_clock => pl_clock, 
    pi_reset => pl_reset, 

    pi_s_top => m_axi4_m2s, 
    po_s_top => m_axi4_s2m, 
    -- to logic interface
    pi_addrmap => reg_i,  
    po_addrmap => reg_o
  );





end behv;
