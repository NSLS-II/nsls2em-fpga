library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

entity ada4350_spi is 
  port (
   clk             : in  std_logic;                    
   reset  	       : in  std_logic;                     
   we		       : in  std_logic;
   wrdata	       : in  std_logic_vector(3 downto 0);

   sclk            : out std_logic;                   
   sdin            : out std_logic;
   cs              : out std_logic;
   lat             : out std_logic             
  );    
end ada4350_spi;

architecture behv of ada4350_spi is

  type     state_type is (IDLE, CLKP1, CLKP2, SETCS); 
  signal   state            : state_type;
  signal   sys_clk          : std_logic;                                                                              
  signal   treg             : std_logic_vector(23 downto 0);                                                                                                                                    
  signal   bcnt             : integer range 0 to 24;          
  signal   xfer_done        : std_logic;                      
   
  signal clk_cnt            : std_logic_vector(7 downto 0);  
 
  signal we_lat				: std_logic;
  signal we_lat_clr			: std_logic;
  
  signal spi_data			: std_logic_vector(23 downto 0);
  signal ldac_fpga          : std_logic;
  signal adc2dacch          : std_logic_vector(1 downto 0);
  
 --   --debug signals (connect to ila)
--    attribute mark_debug                 : string;
--    attribute mark_debug of sys_clk         : signal is "true";   
--    attribute mark_debug of state           : signal is "true";
--    attribute mark_debug of sclk            : signal is "true";
--    attribute mark_debug of sdin            : signal is "true";
--    attribute mark_debug of cs              : signal is "true";    
--    attribute mark_debug of lat             : signal is "true";
--    attribute mark_debug of spi_data        : signal is "true";
--    attribute mark_debug of we              : signal is "true";
--    attribute mark_debug of wrdata          : signal is "true";

   
  
begin  



-- initiate spi command on we input
process (clk, reset)
   begin
     if (reset = '1') or (we_lat_clr = '1')  then
	     spi_data <= (others => '0');
	     we_lat <= '0';
     elsif (clk'event and clk = '1') then
		   if (we = '1') then
		       case wrdata is
		          when x"0"   => spi_data <= x"002820";   -- +/- 10 mA
		          when x"1"   => spi_data <= x"002410";   -- +/- 1 mA
		          when x"2"   => spi_data <= x"002208";   -- +/- 100 uA
		          when x"3"   => spi_data <= x"002104";   -- +/- 10 uA
		          when x"4"   => spi_data <= x"002082";   -- +/- 1 uA
		          when x"5"   => spi_data <= x"002041";   -- +/- 100 nA
		          when others => spi_data <= x"002820";  -- +/- 10 mA
		       end case;
	           we_lat <= '1';
	    	end if;
     end if;
end process;


-- spi transfer
process (sys_clk, reset)
  begin  
    if (reset = '1') then           
      sclk <= '0';
      cs  <= '1';
      lat <= '0';
	  sdin <= '0';
      treg <= (others => '0');
      bcnt <= 24;
      xfer_done <= '0';
	  we_lat_clr <= '0';
      state <= IDLE;

    elsif (sys_clk'event and sys_clk = '1') then  
      case state is
        when IDLE =>     
           sclk  <= '0';
           cs <= '1';
           lat <= '0';
           sdin <= '0';
           xfer_done <= '0';
           we_lat_clr <= '0';
           if (we_lat = '1') then
                cs <= '0';
                treg <= spi_data;  
                bcnt <= 23;      
                state <= CLKP1;
           end if;
   
 
        when CLKP1 =>     
			sclk  <= '1';
            state <= CLKP2;
			treg <= treg(22 downto 0) & '0';
            sdin <= treg(23);

        when CLKP2 =>     
           sclk <= '0';
           if (bcnt = 0) then
			   xfer_done <= '1';
               we_lat_clr <= '1';				
               state <= SETCS;
           else
               bcnt <= bcnt - 1;
               state <= CLKP1;
		   end if;
 
        when SETCS => 
            cs <= '1';
            sdin <= '0';
            state <= idle;      
    
        when others =>
            state <= IDLE;
      end case;
    end if;
  end process;




--generate sys clk for spi from 100Mhz clock
--sys_clk <= clk_cnt(4);
sysclk_bufg_inst : BUFG  port map (O => sys_clk, I => clk_cnt(1));

clkdivide : process(clk, reset)
  begin
     if (reset = '1') then  
       clk_cnt <= (others => '0');
    elsif (clk'event AND clk = '1') then  
		 	 clk_cnt <= clk_cnt + 1; 
    end if;
end process; 




end behv;
