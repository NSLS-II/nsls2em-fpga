library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;



entity trig_cntrl is
  
  port (
    clk                 : in std_logic;
    reset               : in std_logic;
       
    mach_clk_sel        : in std_logic;
    soft_trig           : in std_logic;
    evr_trig            : in std_logic;
    trig_clear          : in std_logic;
    evr_timestamp       : in std_logic_vector(63 downto 0);
    
    evr_timestamplat    : out std_logic_vector(63 downto 0);   
    trig_status         : out std_logic_vector(1 downto 0);
    trig_active         : out std_logic
  );

end trig_cntrl;

architecture rtl of trig_cntrl is

   signal evr_trig_s2        : std_logic;
   signal evr_trig_s1        : std_logic;
   signal evr_trig_s         : std_logic;
   signal evr_trig_lat       : std_logic;
   signal soft_trig_lat      : std_logic;
   signal soft_trig_prev     : std_logic;
   signal trig_active_prev   : std_logic;
   signal trig_active_i      : std_logic;
   signal evr_trig_lat_valid : std_logic;
   
    attribute mark_debug                       : string;
    attribute mark_debug of trig_active        : signal is "true";
    attribute mark_debug of evr_trig_lat       : signal is "true";
    attribute mark_debug of evr_trig_lat_valid : signal is "true";
    attribute mark_debug of trig_status        : signal is "true";
    attribute mark_debug of trig_clear         : signal is "true";



begin  





--can only get evr_trig when mach_clk_sel is set to evr
-- if sfp is not connected get spurious triggers
evr_trig_lat_valid <= evr_trig_lat  when (mach_clk_sel = '1') else '0';


--psc_tx_wfm polls on these bits to start acquisition
trig_status <= evr_trig_lat_valid & soft_trig_lat;

--starts 10KHz data store to FIFO
trig_active_i <= evr_trig_lat_valid or soft_trig_lat;
trig_active <= trig_active_i;


--latch the timestamp on the rising edge of the trigger (either evr or soft)
process (clk, reset)
   begin
     if (reset = '1')   then
	     evr_timestamplat <= (others => '0');
     elsif (clk'event and clk = '1') then
         trig_active_prev <= trig_active_i;
         if (trig_active_prev = '0' and trig_active_i = '1') then
             evr_timestamplat <= evr_timestamp;
         end if;
     end if;
end process;



--synchronize the evr_trig signal to the sys_clk domain
process (clk, reset)
   begin
     if (reset = '1')   then
	     evr_trig_s2 <= '0';
	     evr_trig_s1 <= '0'; 
	     evr_trig_s  <= '0';
     elsif (clk'event and clk = '1') then
		 evr_trig_s2 <= evr_trig;
		 evr_trig_s1 <= evr_trig_s2;
		 evr_trig_s  <= evr_trig_s1;
     end if;
end process;



--latch the evr_trig signal (cleared by psc_txwfm when finished reading the data)
process (clk, reset)
   begin
     if (reset = '1')   then
         evr_trig_lat <= '0';
     elsif (clk'event and clk = '1') then
         if (evr_trig_s1 = '1' and evr_trig_s = '0') then
		     evr_trig_lat <= '1';
         end if;
         if (trig_clear = '1') then
             evr_trig_lat <= '0';
         end if;
     end if;
end process;

--latch the soft_trig signal (cleared by psc_txwfm when finished reading the data)
process (clk, reset)
   begin
     if (reset = '1')   then
         soft_trig_lat <= '0';
     elsif (clk'event and clk = '1') then
         soft_trig_prev <= soft_trig;
         if (soft_trig = '1' and soft_trig_prev = '0') then
		     soft_trig_lat <= '1';
         end if;
         if (trig_clear = '1') then
             soft_trig_lat <= '0';
         end if;
     end if;
end process;









  
end rtl;
