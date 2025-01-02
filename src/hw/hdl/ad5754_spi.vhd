library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.xbpm_package.ALL;


entity ad5754_spi is  
  port (
   clk             : in  std_logic;                    
   reset  	       : in  std_logic;                     
   we		       : in  std_logic;
   wrdata	       : in  std_logic_vector(31 downto 0);
   opmode          : in  std_logic;
   ldac_ps         : in  std_logic;
   adc_raw         : in  adc_raw_type;
   adc_data_valid  : in  std_logic;

   sclk            : out std_logic;                   
   din 	           : out std_logic;
   sync            : out std_logic;
   ldac            : out std_logic;
   clrn            : out std_logic;
   bin2s           : out std_logic                 
  );    
end ad5754_spi;

architecture rtl of ad5754_spi is

  type     state_type is (IDLE, CLKP1, CLKP2, SETSYNC); 
  signal   state            : state_type;
  signal   sys_clk          : std_logic;                                                                              
  signal   treg             : std_logic_vector(23 downto 0);                                                                                                                                    
  signal   bcnt             : integer range 0 to 24;          
  signal   xfer_done        : std_logic;                      
   
  signal clk_cnt            : std_logic_vector(3 downto 0);
  signal clk_enb            : std_logic;  
 
  signal we_lat				: std_logic;
  signal we_lat_clr			: std_logic;
  
  signal spi_data			: std_logic_vector(23 downto 0);
  signal ldac_fpga          : std_logic;
  signal adc2dacch          : std_logic_vector(1 downto 0);
  
 --   --debug signals (connect to ila)
    attribute mark_debug                 : string;
--    attribute mark_debug of adc_data_valid  : signal is "true";
--    attribute mark_debug of opmode          : signal is "true"; 
    attribute mark_debug of clk_cnt         : signal is "true";
    attribute mark_debug of sys_clk         : signal is "true";   
    attribute mark_debug of we              : signal is "true";
    attribute mark_debug of we_lat          : signal is "true";
    attribute mark_debug of we_lat_clr      : signal is "true";
    attribute mark_debug of ldac_ps         : signal is "true";
    attribute mark_debug of state           : signal is "true";
    attribute mark_debug of sclk            : signal is "true";
    attribute mark_debug of din             : signal is "true";
    attribute mark_debug of sync            : signal is "true";    
    attribute mark_debug of ldac            : signal is "true";
--    attribute mark_debug of adc2dacch       : signal is "true";
--    attribute mark_debug of treg            : signal is "true";
     
  
begin  

bin2s <= '0';   --selects 2's complement output

ldac <= ldac_ps when (opmode = '0') else '0';


-- initiate spi command on we input
process (clk, reset)
   begin
     if (reset = '1') or (we_lat_clr = '1')  then
	     spi_data <= (others => '0');
	     we_lat <= '0';
     elsif (clk'event and clk = '1') then
		   if (we = '1') then
	           we_lat <= '1';
			   spi_data <= wrdata(23 downto 0);
	    	end if;
     end if;
end process;


-- spi transfer
process (clk, reset)
  begin  -- process spiStateProc
    if (reset = '1') then  
      clrn <= '0';               
      sclk <= '0';
      sync  <= '1';
      ldac_fpga <= '1';
	  din <= '0';
      treg <= (others => '0');
      bcnt <= 24;
      xfer_done <= '0';
	  we_lat_clr <= '0';
	  adc2dacch <= "00";
      state <= IDLE;

    elsif (rising_edge(clk)) then  
      if (clk_enb = '1') then
        case state is
          when IDLE =>    
           clrn  <= '1'; 
           sclk  <= '0';
           sync  <= '1';
           xfer_done <= '0';
           we_lat_clr <= '0';
           if (opmode = '0') and (we_lat = '1') then
                sync <= '0';
                treg <= spi_data;   --Bit 23  22     21-19       18-16         15-0
                bcnt <= 23;         --   R/W,  0   3-bit reg, 3-bit address, 16-bit data
                state <= CLKP1;
           end if;
           if (opmode = '1') and (adc_data_valid = '1') then
                sync <= '0';
                case adc2dacch is
                   when "00" =>  treg <= x"00" & adc_raw(0)(19 downto 4);  
                   when "01" =>  treg <= x"01" & adc_raw(1)(19 downto 4);
                   when "10" =>  treg <= x"02" & adc_raw(2)(19 downto 4);
                   when "11" =>  treg <= x"03" & adc_raw(3)(19 downto 4);
                   when others => treg <= (others => '0');
                end case;
                adc2dacch <= adc2dacch + 1;
                bcnt <= 23;         --   R/W,  0   3-bit reg, 3-bit address, 16-bit data
                state <= CLKP1;
           end if;

           

          when CLKP1 =>     -- CLKP1 clock phase LOW
			sclk  <= '1';
            state <= CLKP2;
			treg <= treg(22 downto 0) & '0';
            din <= treg(23);

          when CLKP2 =>     -- CLKP1 clock phase 2
           sclk <= '0';
           if (bcnt = 0) then
			   xfer_done <= '1';
               we_lat_clr <= '1';				
               state <= SETSYNC;
           else
               bcnt <= bcnt - 1;
               state <= CLKP1;
		   end if;
 
          when SETSYNC => 
            sync <= '1';
            din <= '0';
            state <= idle;      
    
          when others =>
            state <= idle;
            
            
        end case;
      end if;
    end if;
  end process;





--generate sys clk for spi from 100Mhz clock
--sys_clk <= clk_cnt(4);
--sysclk_bufg_inst : BUFG  port map (O => sys_clk, I => clk_cnt(1));

clkdivide : process(clk, reset)
  begin
     if (rising_edge(clk)) then
       if (reset = '1') then  
          clk_cnt <= (others => '0');
          clk_enb <= '0';
       else
          clk_cnt <= clk_cnt + 1;
          if (clk_cnt = 4d"3") then  
             clk_cnt <= 4d"0";
		 	 clk_enb <= '1';
		  else 	 
		 	 clk_enb <= '0'; 
		  end if;
	   end if;
    end if;
end process; 










  
end rtl;
