-- Stream10kdata.vhd
--
--  This module will average the frev adc data and then buffer in a fifo to be readout by the iobus
--
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.xbpm_package.ALL;


entity calcpos is
  generic (
    SIM_MODE            : integer := 0
  );
  port(
     sys_clk            : in std_logic;
     mach_clk           : in std_logic;
     reset              : in std_logic;
     pos_params         : in pos_params_type;
     trig               : in std_logic;  
     divide             : in std_logic_vector(31 downto 0);
     adc_raw            : in adc_raw_type;
     data               : out data_type  
    );

end calcpos;
  

architecture behv of calcpos is


component div_gen IS
  port (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tdata : IN std_logic_vector(31 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tdata : IN std_logic_vector(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT std_logic_vector(63 DOWNTO 0)
  );
end component;

component div_gen_mag IS
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(71 DOWNTO 0)
  );
END component;


component dds_simadc IS
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_phase_tvalid : OUT STD_LOGIC;
    m_axis_phase_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END component;







    type ADC_SUM_TYPE is array(0 to NUM_ADCS-1) of signed(39 downto 0);
    type ADC_RAW_TYPE is array(0 to NUM_ADCS-1) of std_logic_vector(19 downto 0);
    type ADC_RAW_SE_TYPE is array(0 to NUM_ADCS-1) of signed(31 downto 0);    
    type ADC_AVE_TYPE is array(0 to NUM_ADCS-1) of std_logic_vector(39 downto 0);    
    
    
    signal cnt       : unsigned(31 downto 0) := 32d"0";
    signal trignum   : std_logic_vector(31 downto 0) := 32d"0";
    

    signal adc_raw_se   : adc_raw_se_type;
    signal adc_sum      : adc_sum_type;
    signal adc_lat      : adc_sum_type;
    signal adc_data     : adc_sum_type;
    
    signal adca_raw_wgain : signed(47 downto 0);
    signal adcb_raw_wgain : signed(47 downto 0);   
    signal adcc_raw_wgain : signed(47 downto 0); 
    signal adcd_raw_wgain : signed(47 downto 0);  
    
    signal adca_corr      : signed(31 downto 0);
    signal adcb_corr      : signed(31 downto 0);
    signal adcc_corr      : signed(31 downto 0);
    signal adcd_corr      : signed(31 downto 0);  
      
    signal cha_mag      : signed(31 downto 0);
    signal cha_magfull  : std_logic_vector(71 downto 0);
    signal chb_mag      : signed(31 downto 0);
    signal chb_magfull  : std_logic_vector(71 downto 0);    
    signal chc_mag      : signed(31 downto 0);
    signal chc_magfull  : std_logic_vector(71 downto 0);    
    signal chd_mag      : signed(31 downto 0);
    signal chd_magfull  : std_logic_vector(71 downto 0);    
    

    signal sum          : signed(31 downto 0);
    signal xnum         : signed(31 downto 0);
    signal ynum         : signed(31 downto 0);
    signal xpos_nm64    : signed(63 downto 0);
    signal ypos_nm64    : signed(63 downto 0);
    signal xfract       : signed(31 downto 0);
    signal yfract       : signed(31 downto 0);
    signal xquotient    : signed(31 downto 0);
    signal yquotient    : signed(31 downto 0);   
    signal xnumer       : std_logic_vector(31 downto 0);
    signal ynumer       : std_logic_vector(31 downto 0);
    signal denom        : std_logic_vector(31 downto 0);
    signal xdiv_data    : std_logic_vector(63 downto 0);
    signal ydiv_data    : std_logic_vector(63 downto 0);
    signal xpos_nm      : signed(31 downto 0);
    signal ypos_nm      : signed(31 downto 0);
    
    signal pos_done     : std_logic;
    signal trig_prev    : std_logic;
    signal trig_dlyd    : std_logic;
    signal data_rdy     : std_logic;
    signal calc_pos     : std_logic;
    signal calc_mag     : std_logic;
    
    signal xsat_pos     : std_logic;
    signal xsat_neg     : std_logic; 
    signal ysat_pos     : std_logic;
    signal ysat_neg     : std_logic;  
    
    signal dds_out      : std_logic_vector(31 downto 0);
    signal dds_sine     : std_logic_vector(15 downto 0);
    signal dds_cos      : std_logic_vector(15 downto 0);   
    
    signal dds_xpos48   : signed(47 downto 0);
    signal dds_ypos48   : signed(47 downto 0);
    signal dds_xpos     : std_logic_vector(31 downto 0);
    signal dds_ypos     : std_logic_vector(31 downto 0);



     
   attribute mark_debug     : string;
   attribute mark_debug of trig: signal is "true";
   attribute mark_debug of cnt: signal is "true";
   attribute mark_debug of trig_dlyd: signal is "true";
   attribute mark_debug of data_rdy: signal is "true";
   attribute mark_debug of calc_mag: signal is "true";
   attribute mark_debug of calc_pos: signal is "true";   
   attribute mark_debug of pos_done: signal is "true";
      
   attribute mark_debug of mach_clk: signal is "true";
   attribute mark_debug of adc_raw: signal is "true";
   attribute mark_debug of adc_raw_se: signal is "true";
   attribute mark_debug of adca_raw_wgain: signal is "true";
   attribute mark_debug of adcb_raw_wgain: signal is "true";
   attribute mark_debug of adcc_raw_wgain: signal is "true";
   attribute mark_debug of adcd_raw_wgain: signal is "true";
   attribute mark_debug of adca_corr: signal is "true";
   attribute mark_debug of adcb_corr: signal is "true";
   attribute mark_debug of adcc_corr: signal is "true";
   attribute mark_debug of adcd_corr: signal is "true";
   attribute mark_debug of cha_mag: signal is "true";
   attribute mark_debug of chb_mag: signal is "true";
   attribute mark_debug of chc_mag: signal is "true";
   attribute mark_debug of chd_mag: signal is "true";
   attribute mark_debug of ynum: signal is "true";
   attribute mark_debug of xnum: signal is "true";
   attribute mark_debug of sum: signal is "true";
   attribute mark_debug of xpos_nm: signal is "true";
   attribute mark_debug of ypos_nm: signal is "true";
   
   attribute mark_debug of dds_xpos: signal is "true";
   attribute mark_debug of dds_ypos: signal is "true";


begin
  


-- for simulations
adcdata_sim: if (SIM_MODE = 1) generate
  adc_raw_se(0) <= to_signed(1000, adc_raw_se(0)'length);
  adc_raw_se(1) <= to_signed(100, adc_raw_se(1)'length);
  adc_raw_se(2) <= to_signed(200, adc_raw_se(2)'length);
  adc_raw_se(3) <= to_signed(-280, adc_raw_se(3)'length);  
  
  adc_raw_se(4) <= to_signed(0, adc_raw_se(4)'length);
  adc_raw_se(5) <= to_signed(0, adc_raw_se(5)'length);
  adc_raw_se(6) <= to_signed(0, adc_raw_se(6)'length);
  adc_raw_se(7) <= to_signed(0, adc_raw_se(7)'length);   
end generate;
 
 
-- sign extend the inputs
adcdata_syn: if (SIM_MODE = 0) generate
  gen_se: for i in 0 to NUM_ADCS-1 generate
    --adc_raw_se(i) <= signed((31 downto 20 => adc_raw(i)(19)) & adc_raw(i));
    adc_raw_se(i) <= resize(signed(adc_raw(i)),32);
    
  end generate;
end generate;


--gain and offset correction for the 4 current inputs
adca_raw_wgain <= signed(adc_raw_se(0)) * signed(pos_params.cha_gain);
adcb_raw_wgain <= signed(adc_raw_se(1)) * signed(pos_params.chb_gain);
adcc_raw_wgain <= signed(adc_raw_se(2)) * signed(pos_params.chc_gain);
adcd_raw_wgain <= signed(adc_raw_se(3)) * signed(pos_params.chd_gain);    


--gain is 1/2^15, remove bit growth.
adca_corr <= adca_raw_wgain(46 downto 15) - signed(pos_params.cha_offset);
adcb_corr <= adcb_raw_wgain(46 downto 15) - signed(pos_params.chb_offset);
adcc_corr <= adcc_raw_wgain(46 downto 15) - signed(pos_params.chc_offset);
adcd_corr <= adcd_raw_wgain(46 downto 15) - signed(pos_params.chd_offset);


-- put into final array for accumulation
adc_data(0) <= resize(adca_corr,40);
adc_data(1) <= resize(adcb_corr,40);
adc_data(2) <= resize(adcc_corr,40);
adc_data(3) <= resize(adcd_corr,40);
adc_data(4) <= resize(signed(adc_raw_se(4)),40);
adc_data(5) <= resize(signed(adc_raw_se(5)),40);
adc_data(6) <= resize(signed(adc_raw_se(6)),40);
adc_data(7) <= resize(signed(adc_raw_se(7)),40);




--accumulate samples
process(reset, mach_clk)
  begin
    if (reset = '1') then
      cnt <= (others => '0');  
      trignum <= (others => '0');
      for i in 0 to NUM_ADCS-1 loop    
        adc_sum(i) <= (others => '0');
        adc_lat(i) <= (others => '0'); 
      end loop;    
    else if (rising_edge(mach_clk)) then
      cnt <= cnt + 1;    
      for i in 0 to NUM_ADCS-1 loop    
        adc_sum(i) <= adc_data(i) + adc_sum(i);     
      end loop;          
        
      if (trig = '1') then
        trignum <= trignum + 1;
        cnt <= (others => '0');
        for i in 0 to NUM_ADCS-1 loop
          adc_lat(i) <= adc_sum(i);
          adc_sum(i) <= adc_data(i); --(others => '0');
        end loop;
      end if;
    end if;    
               
   end if;       
end process;






--calculate position from 4 current inputs
--easiest: shift right by 5 is same as divide by 2^5
--cha_mag <= shift_right(signed(adc_lat(0)),5);
--chb_mag <= shift_right(signed(adc_lat(1)),5); 
--chc_mag <= shift_right(signed(adc_lat(2)),5); 
--chd_mag <= shift_right(signed(adc_lat(3)),5); 

--future: can do scaling with a multiply instead of division
-- 1/32*2^16 = 2048
--cha_mag2full <= signed(adc_lat(0))*signed(to_signed(2048,16));
--cha_mag2 <= cha_mag2full(47 downto 16);

--can to scaling with actual divider too.
--division operation takes 68 sys_clk cycles (0.68us)
cha_mag <= signed(cha_magfull(63 downto 32));
cha_mag_div: div_gen_mag
  port map(
    aclk => sys_clk, 
    s_axis_divisor_tvalid => calc_mag,
    s_axis_divisor_tdata => divide, 
    s_axis_dividend_tvalid => calc_mag, 
    s_axis_dividend_tdata => std_logic_vector(adc_lat(0)), 
    m_axis_dout_tvalid => calc_pos,  
    m_axis_dout_tdata => cha_magfull  
  );

chb_mag <= signed(chb_magfull(63 downto 32));
chb_mag_div: div_gen_mag
  port map(
    aclk => sys_clk, 
    s_axis_divisor_tvalid => calc_mag,
    s_axis_divisor_tdata => divide, 
    s_axis_dividend_tvalid => calc_mag, 
    s_axis_dividend_tdata => std_logic_vector(adc_lat(1)), 
    m_axis_dout_tvalid => open,   
    m_axis_dout_tdata => chb_magfull   
  );

chc_mag <= signed(chc_magfull(63 downto 32));
chc_mag_div: div_gen_mag
  port map(
    aclk => sys_clk, 
    s_axis_divisor_tvalid => calc_mag,
    s_axis_divisor_tdata => divide, 
    s_axis_dividend_tvalid => calc_mag, 
    s_axis_dividend_tdata => std_logic_vector(adc_lat(2)), 
    m_axis_dout_tvalid => open,   
    m_axis_dout_tdata => chc_magfull   
  );

chd_mag <= signed(chd_magfull(63 downto 32));
chd_mag_div: div_gen_mag
  port map(
    aclk => sys_clk, 
    s_axis_divisor_tvalid => calc_mag,
    s_axis_divisor_tdata => divide, 
    s_axis_dividend_tvalid => calc_mag, 
    s_axis_dividend_tdata => std_logic_vector(adc_lat(3)), 
    m_axis_dout_tvalid => open,   
    m_axis_dout_tdata => chd_magfull   
  );


ynum <= (cha_mag + chb_mag) - (chc_mag + chd_mag);
xnum <= (cha_mag + chd_mag) - (chb_mag + chc_mag);
sum <= cha_mag + chb_mag + chc_mag + chd_mag;
  

xnumer <= std_logic_vector(xnum);
ynumer <= std_logic_vector(ynum);
denom <= std_logic_vector(sum);



-- check if result from divide is saturated
-- saturated if quotient is nonzero.
xquotient <= signed(xdiv_data(63 downto 32));
xfract <= signed(xdiv_data(31 downto 0));
process (sys_clk) 
begin
  if (rising_edge(sys_clk)) then
    if (xquotient > 32d"0") then
       -- set position to kx
       xsat_pos <= '1';
       xpos_nm <= signed(pos_params.kx);
    elsif (xquotient < 32d"0") then
       -- set position to -kx
       xsat_neg <= '1';
       xpos_nm <= resize(signed(pos_params.kx) * to_signed(-1,1),32);
    else
       -- not saturated
       xpos_nm64 <= xfract * signed(pos_params.kx);
       xpos_nm <= xpos_nm64(62 downto 31) + signed(pos_params.xpos_offset); 
       xsat_pos <= '0';
       xsat_neg <= '0';
    end if;
  end if;
end process;


-- check if result from divide is saturated
-- saturated if quotient is nonzero.
yquotient <= signed(ydiv_data(63 downto 32));
yfract <= signed(ydiv_data(31 downto 0));
process (sys_clk) 
begin
  if (rising_edge(sys_clk)) then
    if (yquotient > 32d"0") then
       -- set position to kx
       ysat_pos <= '1';
       ypos_nm <= signed(pos_params.ky);
    elsif (yquotient < 32d"0") then
       -- set position to -kx
       ysat_neg <= '1';
       ypos_nm <= resize(signed(pos_params.ky) * to_signed(-1,1),32);
    else
       -- not saturated
       ypos_nm64 <= yfract * signed(pos_params.ky);
       ypos_nm <= ypos_nm64(62 downto 31) + signed(pos_params.ypos_offset); 
       ysat_pos <= '0';
       ysat_neg <= '0';
    end if;
  end if;
end process;




--start the position calculation 1 mach_clock tick after tenkhz_trig
--adc_lat values are then stable
process (mach_clk)
begin
  if (rising_edge(mach_clk)) then
     trig_dlyd <= trig;
     data_rdy <= trig_dlyd;
  end if;
end process;


process (sys_clk)
begin
  if (rising_edge(sys_clk)) then
     trig_prev <= trig_dlyd;
     if (trig_dlyd = '1') and (trig_prev = '0') then
        calc_mag <= '1';
     else 
        calc_mag <= '0';
     end if;
  end if;
end process;



--division operation takes 68 sys_clk cycles (0.68us)
xpos_div: div_gen
  port map(
    aclk => sys_clk, 
    s_axis_divisor_tvalid => calc_pos, 
    s_axis_divisor_tdata => denom, 
    s_axis_dividend_tvalid => calc_pos, 
    s_axis_dividend_tdata => xnumer, 
    m_axis_dout_tvalid => pos_done, 
    m_axis_dout_tdata => xdiv_data
  );



ypos_div: div_gen
  port map(
    aclk => sys_clk, 
    s_axis_divisor_tvalid => calc_pos, 
    s_axis_divisor_tdata => denom, 
    s_axis_dividend_tvalid => calc_pos, 
    s_axis_dividend_tdata => ynumer, 
    m_axis_dout_tvalid => open, 
    m_axis_dout_tdata => ydiv_data
  );






dds_sine <= dds_out(31 downto 16);
dds_cos  <= dds_out(15 downto 0);

dds_xpos48 <= signed(pos_params.kx) * signed(dds_sine);
dds_ypos48 <= signed(pos_params.ky) * signed(dds_cos);

dds_xpos <= std_logic_vector(dds_xpos48(47 downto 16));
dds_ypos <= std_logic_vector(dds_ypos48(47 downto 16));


sim_pos: dds_simadc 
  port map (
    aclk => mach_clk,
    s_axis_config_tvalid => '1', 
    s_axis_config_tdata => pos_params.dds_freq, 
    m_axis_data_tvalid => open, 
    m_axis_data_tdata => dds_out, 
    m_axis_phase_tvalid => open, 
    m_axis_phase_tdata => open
  );




-- write to final record.
data.data_rdy <= pos_done;
process (sys_clk)
begin
  if (pos_done = '1') then
    data.trignum <= trignum;
    data.cha_mag <= std_logic_vector(cha_mag);
    data.chb_mag <= std_logic_vector(chb_mag);
    data.chc_mag <= std_logic_vector(chc_mag);
    data.chd_mag <= std_logic_vector(chd_mag);
    data.sum <= std_logic_vector(sum);
    data.xpos <= std_logic_vector(xpos_nm) when pos_params.pos_simreal = '0' else dds_xpos;
    data.ypos <= std_logic_vector(ypos_nm) when pos_params.pos_simreal = '0' else dds_ypos;
    data.che_mag <= std_logic_vector(adc_lat(4)(31 downto 0));
    data.chf_mag <= std_logic_vector(adc_lat(5)(31 downto 0));
    data.chg_mag <= std_logic_vector(adc_lat(6)(31 downto 0));
    data.chh_mag <= std_logic_vector(adc_lat(7)(31 downto 0));
  end if;
end process;





















end behv;


