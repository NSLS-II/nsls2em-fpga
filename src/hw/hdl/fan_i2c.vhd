----------------------------------------------------------------------------------
-- Company: BNL
-- Engineer: Chris Danneil
-- 
-- Create Date: 08/31/2020 02:10:09 PM
-- Design Name: 
-- Module Name: fan_i2c - rtl
-- Project Name: Electrometer
-- Target Devices: 
-- Tool Versions: 
-- Description: Fan control for electrometer 
--              controls PN: LTC1695
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity fan_i2c is
    Port ( clk : in STD_LOGIC; --125mhz
           reset : in STD_LOGIC;
           tach : in STD_LOGIC;
           scl : out STD_LOGIC;
           sda : inout STD_LOGIC;
           speed : in std_logic_vector( 5 downto 0);
           OCF : out std_logic; --Over Current Fault
           THE : out std_logic; --Thermal Shutdown
           i2c_good : out std_logic;
           tach_count : out std_logic_vector(15 downto 0)
           );
end fan_i2c;

architecture rtl of fan_i2c is

type state_type is (IDLE, START, CLKP1, CLKP2, CLKP3, CLKP4, STOP1, STOP2);
type mode_type is (READ, WRITE);
signal state : state_type;
signal mode : mode_type;
signal tachcount : integer RANGE 255 downto 0;
signal prev_tach : std_logic;
signal write_trig : std_logic;
signal read_trig : std_logic;
signal write_trig_clr : std_logic;
signal read_trig_clr : std_logic;
signal speed_i : std_logic_vector (7 downto 0);
signal i2c_clk : std_logic;
signal read_clk : std_logic;
signal prev_read_clk : std_logic;
signal clk_cnt : std_logic_vector (23 downto 0);
signal data_register : std_logic_vector (17 downto 0); --x"E8" & speed 
signal bitcount : integer range 31 downto 0;
signal ack : std_logic; -- detect ack from i2c bus
signal check : std_logic; -- check read reply

begin

tach_cnt : process (clk)
  begin
    if rising_edge (clk) then
        if reset = '1' then
            prev_tach <= '0';
            tachcount <= 0;
            tach_count <= (others => '0');
        else
            prev_tach <= tach;
            prev_read_clk <= read_clk;
            if (prev_tach = '0' and tach = '1') then
                tachcount <= tachcount + 1;
            end if;
            if  (prev_read_clk = '0' and read_clk = '1') then
                tach_count <= std_logic_vector(resize(to_unsigned(tachcount,9)*358,16)); --multiplier for RPM on 100mhz system
                tachcount <= 0;
            end if;
        end if;
    end if;
end process;

writetrig : process (read_clk)
  begin
      if falling_edge (read_clk) then
          if reset = '1' then
              speed_i <= (others => '0');
              write_trig <= '0';
          elsif (write_trig_clr = '1') then
              write_trig <= '0';
          else
              speed_i <= '0' & '0' & speed;
              write_trig <= '1';
          end if;
      end if; 
end process;

readtrig : process (read_clk)
  begin
      if rising_edge (read_clk) then
          if reset = '1' then
              read_trig <= '0';
          elsif (read_trig_clr = '1') then
              read_trig <= '0';
          else
              read_trig <='1';
          end if;
      end if;
end process;

i2c : process (i2c_clk) 
begin
    if rising_edge(i2c_clk) then  
        if (reset = '1') then          
            scl  <= '1';
            sda <= '1';
            OCF <= '0';
            THE <= '0';
            data_register  <= (others => '0');
            bitcount  <= 18;
            read_trig_clr <= '0';
            write_trig_clr <= '0';
            state <= IDLE;
        else
          case state is
            when IDLE =>    
                scl  <= '1';
                sda  <= '1';            
                bitcount <= 18;
                
                if (write_trig_clr = '0' and write_trig = '1') then
                    data_register <= x"E8" & '1' & speed_i & '1';
                    sda <= '0'; --start bit
                    state <= START;
                    mode <= WRITE;
                elsif (write_trig_clr = '1' and write_trig = '0') then
                    write_trig_clr <= '0';
                end if;
                
                if (read_trig_clr = '0' and read_trig = '1') then
                    data_register <= x"E9" & '1' & x"FF" & '1';
                    sda <= '0'; --start bit     
                    state <= START;
                    mode <= READ;
                elsif (read_trig_clr = '1' and read_trig = '0') then
                    read_trig_clr <= '0';
                end if;
                
            when START => --delay -- START bit was configured when leaving IDLE
                state <= CLKP1;	
               
            when CLKP1 =>     -- CLKP1 clock phase low
                scl  <= '0';
                state <= CLKP2;
                
                if data_register(17) = '0' then
                    sda <= '0';
                else 
                    sda <= 'Z';
                end if;
                
                data_register <= data_register(16 downto 0) & '1';
                
            when CLKP2 => --delay
                state <= CLKP3;	
                         
            when CLKP3 => --set scl
                scl <= '1';
                state <= CLKP4;	         
                         
            when CLKP4 => -- read responce
    
                if (bitcount = 0) then            
                   state <= STOP1;
                else
                   bitcount <= bitcount - 1;
                   state <= CLKP1;
                end if;
                
                case mode is
                    when WRITE =>
                        if (bitcount = 1) then -- or bitcount = 0) then
                            if sda = '0' then
                                ack <= '1';
                            else
                                ack <= '0';
                            end if;
                        end if;
                
                    when READ =>
                        if (bitcount = 8) then -- over current fault
                            if sda = '1' then
                                OCF <= '1';
                            else
                                OCF <= '0';
                            end if;
                        elsif (bitcount = 7) then -- thermal fault
                            if sda = '1' then
                                THE <= '1';
                            else
                                THE <= '0';
                            end if;
                        elsif (bitcount = 3)  then -- check for zero in reply
                            if sda = '0' then
                                check <= '1';
                            else
                                check <= '0';
                            end if;
                        end if;
                end case;
    
           when STOP1 => -- configure STOP bit
               scl <= '1';
               sda <= '0';
               read_trig_clr <= '1';
               write_trig_clr <= '1';
               state <= STOP2;
               
           when STOP2 => --delay
               state <= IDLE;	
               
           when others =>
               state <= IDLE;
          end case;
        end if;
    end if;
      
end process;

i2c_readback : process (clk)
  begin
    if rising_edge (clk) then
        if reset = '1' then
            i2c_good <= '0';
        else
            i2c_good <= ack and check;
        end if;
    end if;
end process;

--for tach calculation:
--check rate is clk/2^24
-- ~7.45 hz for 125mhz clk and ~5.96hz for 100mhz clk 
-- to get rpm for 100mhz system multiply by 358 (357.628)
-- to get rpm for 125mhz system multiply by 447 (447.035)

sysclk_bufg_inst1 : BUFG  port map (O => i2c_clk, I => clk_cnt(8)); -- 244,141 hz (4 clocks per bit)
sysclk_bufg_inst2 : BUFG  port map (O => read_clk, I => clk_cnt(23)); -- 7.45 hz (actual trigger rate is 3.725 hz for the i2c since the logic skips every other trigger)

clkdivide : process(clk, reset)
begin
   if (reset = '1') then  
     clk_cnt <= (others => '0');
  elsif rising_edge(clk) then  
            clk_cnt <= std_logic_vector(unsigned(clk_cnt) + 1); 
  end if;
end process; 

end rtl;
