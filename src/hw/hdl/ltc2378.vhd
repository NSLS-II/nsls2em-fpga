--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.NUMERIC_STD.all;
--library unisim;
--use unisim.all;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


library UNISIM;
use UNISIM.VComponents.all;



entity ltc2378 is
  generic (
    SIM_MODE            : integer := 0
  );
  port(
     clk				: in std_logic;
     adc_clk            : in std_logic;
     reset              : in std_logic;

	 testmode_enb	    : in std_logic;
	 testmode_rst       : in std_logic;
 
	 adc_sdo	  	    : in std_logic;
	 adc_busy           : in std_logic;
	 adc_cnv			: out std_logic;
	 adc_sck			: out std_logic;
	 adc_sdi            : out std_logic;

	 adc_data			: out std_logic_vector(19 downto 0);
     adc_data_valid     : out std_logic
     
    );

end ltc2378;


architecture behv of ltc2378 is


  type  state_type is (IDLE, CONVERT, ACQUIRE, LATCHDATA);  
  signal state :  state_type;
  signal adc_buf	   : std_logic_vector(19 downto 0);
  signal adc_latbuf     : std_logic_vector(19 downto 0);
  signal bitnum         : INTEGER RANGE 0 TO 31;  
  signal tst_pat        : std_logic_vector(19 downto 0);
  signal adc_valid      : std_logic;
  signal sck_enb        : std_logic;
  signal sck_enbne      : std_logic;
  signal adc_busy_s1    : std_logic;
  signal adc_busy_s     : std_logic;
  signal sys_clk        : std_logic;
 
  signal clk_cnt        : std_logic_vector(3 downto 0);

   
   
  attribute mark_debug                  : string;
  attribute mark_debug of state: signal is "true";
  attribute mark_debug of adc_busy: signal is "true";
  attribute mark_debug of adc_busy_s: signal is "true";
  attribute mark_debug of bitnum: signal is "true";   
  attribute mark_debug of adc_buf: signal is "true";
  attribute mark_debug of sck_enbne: signal is "true";
  attribute mark_debug of adc_sdo: signal is "true";
  attribute mark_debug of adc_cnv: signal is "true";
  attribute mark_debug of adc_sck: signal is "true"; 
  attribute mark_debug of adc_sdi: signal is "true"; 
  attribute mark_debug of adc_data: signal is "true";
  attribute mark_debug of adc_data_valid: signal is "true";
 

begin
  
 
  adc_cnv <= adc_clk;
  adc_sdi <= '1';
  adc_sck <=  sys_clk when (sck_enbne = '1') else '0';
  --adc_sck  <= NOT adc_sckn;
  

adcdata_syn: if (SIM_MODE = 0) generate
  adc_data <= adc_latbuf when testmode_enb = '0' else tst_pat;
end generate;

adcdata_sim: if (SIM_MODE = 1) generate
  adc_data <= std_logic_vector(to_signed(-23456, adc_data'length)); 
end generate;

  
  
  adc_data_valid <= adc_valid;


  sync_busy : process (sys_clk,reset)
  begin
    if (reset = '1') then
       adc_busy_s1 <= '0';
       adc_busy_s  <= '0';
    elsif (sys_clk'event AND sys_clk = '0') then
       adc_busy_s1 <= adc_busy;
       adc_busy_s  <= adc_busy_s1;
    end if;
  end process;


  acquire_negedge : process (sys_clk,reset)
  begin
    if (reset = '1') then
       sck_enbne <= '0';
    elsif (sys_clk'event AND sys_clk = '0') then
       if (sck_enb = '1') then
           sck_enbne <= '1';
       else
           sck_enbne <= '0';
       end if;
    end if;
  end process;


  gen_adcsigs : process (sys_clk,reset)
  begin	
	if (reset = '1') then
		adc_buf <= (others => '0');
		state <= idle;
		tst_pat <= (others => '0');
		adc_valid <= '0';
		tst_pat <= (others => '0');
		sck_enb <= '0';
		adc_latbuf <= (others => '0');
		
	elsif (sys_clk'event AND sys_clk = '1') then
		case state is 
			when IDLE => 
			    adc_valid <= '0';
				if (adc_busy_s = '1') then
				    adc_buf <= (others => '0');
					state <= convert;
					bitnum  <= 0;
				elsif (testmode_rst = '1') then
					tst_pat <= (others => '0');
				end if;
				
			when CONVERT => 
				if (adc_busy_s = '0') then
					sck_enb <= '1'; 
					state <= acquire;
				end if;
				
			when ACQUIRE =>	
                bitnum <= bitnum + 1;
				adc_buf <= adc_buf(18 downto 0) & adc_sdo;
				if (bitnum = 19) then
					sck_enb <= '0';	
				    adc_valid <= '1';
					tst_pat <= tst_pat + 1;				
					state <= latchdata;
				end if;

            when LATCHDATA =>
                 adc_latbuf <= adc_buf;
                 state <= idle;


		
		end case;
	end if;
end process;
		
 
 
sys_clk_bufg_inst : BUFG  port map (O => sys_clk, I => clk_cnt(1));

clkdivide : process(clk, reset)
  begin
     if (reset = '1') then  
       clk_cnt <= (others => '0');
    elsif (clk'event AND clk = '1') then  
		 	 clk_cnt <= clk_cnt + 1; 
    end if;
end process;  



end behv;
