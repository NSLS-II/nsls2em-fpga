
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library desyrdl;
use desyrdl.common.all;
use desyrdl.pkg_pl_regs.all;

library xil_defaultlib;
use xil_defaultlib.xbpm_package.ALL;



entity ps_io is
  port (  
     pl_clock         : in std_logic;
     pl_reset         : in std_logic;
   
     m_axi4_m2s       : in t_pl_regs_m2s;
     m_axi4_s2m       : out t_pl_regs_s2m;   
     
--     adc_data        : in t_adc_raw;
--     sa_data         : in t_sa_data;
     
--	 reg_o_dsa       : out t_reg_o_dsa;
--	 reg_o_therm     : out t_reg_o_therm;
--	 reg_i_therm     : in  t_reg_i_therm;
--	 reg_o_pll       : out t_reg_o_pll;
--	 reg_i_pll       : in  t_reg_i_pll;
--	 reg_o_tbt       : out t_reg_o_tbt;	
--	 reg_o_adcfifo   : out t_reg_o_adc_fifo_rdout;
--	 reg_i_adcfifo   : in  t_reg_i_adc_fifo_rdout; 
--	 reg_o_tbtfifo   : out t_reg_o_tbt_fifo_rdout;
--	 reg_i_tbtfifo   : in  t_reg_i_tbt_fifo_rdout; 	
--	 reg_o_dma       : out t_reg_o_dma; 
--	 reg_i_dma       : in  t_reg_i_dma;
--	 reg_o_adc       : out t_reg_o_adc_cntrl;
--	 reg_i_adc       : in  t_reg_i_adc_status; 
--	 reg_o_evr       : out t_reg_o_evr;
--	 reg_i_evr       : in  t_reg_i_evr;
 
     fp_leds         : out std_logic_vector(7 downto 0)
  );
end ps_io;


architecture behv of ps_io is

  

  
  signal reg_i        : t_addrmap_pl_regs_in;
  signal reg_o        : t_addrmap_pl_regs_out;

  --attribute mark_debug     : string;
  --attribute mark_debug of reg_o: signal is "true";



begin

fp_leds <= reg_o.FP_LEDS.val.data;

--reg_o_therm.spi_we <= reg_o.therm_spi.data.swmod;
--reg_o_therm.spi_wdata <= reg_o.therm_spi.data.data;
--reg_o_therm.sel <= reg_o.therm_sel.data.data;
--reg_i.therm_spi.data.data <= 24d"0" & reg_i_therm.spi_rdata;


--reg_o_adc.spi_we <= reg_o.adc_spi.data.swmod; 
--reg_o_adc.spi_wdata <= reg_o.adc_spi.data.data; 
--reg_i.adc_spi.data.data <= reg_i_adc.spi_rdata;    
--reg_o_adc.idly_wval <= reg_o.adc_idlyval.data.data;  
--reg_o_adc.idly_wstr <= reg_o.adc_idlystr.data.data; 
--reg_o_adc.fco_dlystr <= reg_o.adc_mmcmdlystr.data.data;  
--reg_i.adc_idlychardval.data.data <= reg_i_adc.idlycha_rval;   
--reg_i.adc_idlychbrdval.data.data <= reg_i_adc.idlychb_rval; 
--reg_i.adc_idlychcrdval.data.data <= reg_i_adc.idlychc_rval; 
--reg_i.adc_idlychdrdval.data.data <= reg_i_adc.idlychd_rval; 


--reg_o_pll.str <= reg_o.pll_spi.data.swmod;                
--reg_o_pll.data <= reg_o.pll_spi.data.data;
--reg_i.pll_locked.data.data(0) <= reg_i_pll.locked;

--reg_o_dsa.str <= reg_o.dsa_spi.data.swmod;
--reg_o_dsa.data <= reg_o.dsa_spi.data.data;

--reg_i.adc_cha.data.data <= adc_data(0);
--reg_i.adc_chb.data.data <= adc_data(1);
--reg_i.adc_chc.data.data <= adc_data(2);
--reg_i.adc_chd.data.data <= adc_data(3);

--reg_o_tbt.kx <= reg_o.kx.data.data;
--reg_o_tbt.ky <= reg_o.ky.data.data;
--reg_o_tbt.cha_gain <= reg_o.cha_gain.data.data;
--reg_o_tbt.chb_gain <= reg_o.chb_gain.data.data;
--reg_o_tbt.chc_gain <= reg_o.chc_gain.data.data;
--reg_o_tbt.chd_gain <= reg_o.chd_gain.data.data;
--reg_o_tbt.xpos_offset <= reg_o.xpos_offset.data.data;
--reg_o_tbt.ypos_offset <= reg_o.ypos_offset.data.data;
--reg_o_tbt.gate_delay <= reg_o.gate_delay.data.data;
--reg_o_tbt.gate_width <= reg_o.gate_width.data.data;

--reg_o_adcfifo.enb <= reg_o.adcfifo_streamenb.data.swmod;
--reg_o_adcfifo.rst <= reg_o.adcfifo_reset.data.data(0);
--reg_o_adcfifo.rdstr <= reg_o.adcfifo_data.data.swacc;
--reg_i.adcfifo_rdcnt.data.data <= reg_i_adcfifo.rdcnt;
--reg_i.adcfifo_data.data.data <= reg_i_adcfifo.dout;

--reg_o_tbtfifo.enb <= reg_o.tbtfifo_streamenb.data.swmod;
--reg_o_tbtfifo.rst <= reg_o.tbtfifo_reset.data.data(0);
--reg_o_tbtfifo.rdstr <= reg_o.tbtfifo_data.data.swacc;
--reg_i.tbtfifo_rdcnt.data.data <= reg_i_tbtfifo.rdcnt;
--reg_i.tbtfifo_data.data.data <= reg_i_tbtfifo.dout;

--reg_o_dma.soft_trig <= reg_o.dma_soft_trig.data.data(0);
--reg_o_dma.trigsrc <= reg_o.dma_trigsrc.data.data(0);
--reg_o_dma.fifo_rst <= reg_o.dma_fifo_rst.data.data(0); 
--reg_o_dma.adc_enb <= reg_o.dma_adc_enb.data.data(0); 
--reg_o_dma.adc_len <= reg_o.dma_adc_len.data.data;
--reg_o_dma.tbt_enb <= reg_o.dma_tbt_enb.data.data(0); 
--reg_o_dma.tbt_len <= reg_o.dma_tbt_len.data.data;
--reg_o_dma.fa_enb <= reg_o.dma_fa_enb.data.data(0); 
--reg_o_dma.fa_len <= reg_o.dma_fa_len.data.data;

--reg_i.dma_trigcnt.data.data <= reg_i_dma.trig_cnt;
--reg_i.dma_status.data.data <= reg_i_dma.status; 

--reg_i.ts_ns.val.data <= reg_i_evr.ts_ns; --x"12345678";
--reg_i.ts_s.val.data <= reg_i_evr.ts_s; --x"deadbeef";
--reg_i.dma_ts_ns.val.data <= reg_i_dma.ts_ns; --x"0123face";
--reg_i.dma_ts_s.val.data <= reg_i_dma.ts_s; --x"ba5eba11";

--reg_o_evr.reset <= reg_o.evr_reset.data.data(0);
--reg_o_evr.dma_trigno <= reg_o.dma_trig_eventno.val.data;
--reg_o_evr.event_src_sel <= reg_o.event_src_sel.val.data(0);


--reg_i.sa_cnt.data.data <= sa_data.cnt;
--reg_i.sa_cha.data.data <= std_logic_vector(sa_data.cha_mag);
--reg_i.sa_chb.data.data <= std_logic_vector(sa_data.chb_mag);
--reg_i.sa_chc.data.data <= std_logic_vector(sa_data.chc_mag);
--reg_i.sa_chd.data.data <= std_logic_vector(sa_data.chd_mag);
--reg_i.sa_sum.data.data <= std_logic_vector(sa_data.sum);
--reg_i.sa_xpos.data.data <= std_logic_vector(sa_data.xpos);
--reg_i.sa_ypos.data.data <= std_logic_vector(sa_data.ypos);




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
