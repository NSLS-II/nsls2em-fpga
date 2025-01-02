----------------------------------------------------------------------------------
-- Company: BNL
-- Engineer: Chris Danneil
-- 
-- Create Date: 10/08/2020 10:01:18 AM
-- Design Name: 
-- Module Name: qafe_monitors - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Configuration and readback for the ADT74X0 and INA226 monitor chips
--              on the Quad AFE and temperature control daughterboards.
--              This can be configured to handle any arrangement of I2C devices.
--              Update rate is 1.5hz
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package afe_i2c_types is
    constant nine_pad : std_logic_vector(8 downto 0) := (others => '0');
    constant eighteen_pad : std_logic_vector(17 downto 0) := (others => '0');
    constant adt7410_config : std_logic_vector(18 downto 0) := '1' & x"03" & '1' & x"80" & '1';
    constant adt7410_pntr : std_logic_vector(18 downto 0) := '1' & x"00" & '1' & x"00" & '1';
    constant read_word : std_logic_vector(18 downto 0) := '1' & x"FF" & '0' & x"FF" & '1';
    constant ina226_config : std_logic_vector(27 downto 0) := '1' & x"00" & '1' & x"41" & '1' & x"27" & '1';
    constant ina226_cal : std_logic_vector(27 downto 0) := '1' & x"05" & '1' & x"08" & '1' & x"00" & '1';
    constant ina226_Vreg : std_logic_vector(9 downto 0) := '1' & x"02" & '1';
    constant ina226_Ireg : std_logic_vector(9 downto 0) := '1' & x"04" & '1';
    constant ARRAY_SIZE : integer := 61;
    constant DATA_SIZE  : integer := 36;
    type idata_type is array(0 to ARRAY_SIZE-1) of std_logic_vector(DATA_SIZE-1 downto 0);
    type size_type is array(0 to ARRAY_SIZE-1) of integer range 0 to 63;
    
--    type afe_regs_type is record
--        temp0 : std_logic_vector(15 downto 0);
--        temp1 : std_logic_vector(15 downto 0);
--        temp2 : std_logic_vector(15 downto 0);
--        temp3 : std_logic_vector(15 downto 0);
--        Vreg0 : std_logic_vector(15 downto 0);
--        Vreg1 : std_logic_vector(15 downto 0);
--        Vreg2 : std_logic_vector(15 downto 0);
--        Vreg3 : std_logic_vector(15 downto 0);
--        Vreg4 : std_logic_vector(15 downto 0);
--        Vreg5 : std_logic_vector(15 downto 0);
--        Vreg6 : std_logic_vector(15 downto 0);
--        Vreg7 : std_logic_vector(15 downto 0);
--        Ireg0 : std_logic_vector(15 downto 0);
--        Ireg1 : std_logic_vector(15 downto 0);
--        Ireg2 : std_logic_vector(15 downto 0);
--        Ireg3 : std_logic_vector(15 downto 0);
--        Ireg4 : std_logic_vector(15 downto 0);
--        Ireg5 : std_logic_vector(15 downto 0);
--        Ireg6 : std_logic_vector(15 downto 0);
--        Ireg7 : std_logic_vector(15 downto 0);
--    end record afe_regs_type;

end package afe_i2c_types;

use work.afe_i2c_types.all;

library work;
use work.xbpm_package.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity qafe_monitors is
    generic (    -- the idea here is to list the entire data transaction so the processes can be much simpler
                 -- adt7410 write address byte x90, x92, x94, x96 - read address byte x91, x93, x95, x97
                 -- ina226 write address byte x80, x82 ...x9e - read address byte x81, x83 ...x9f be careful not to overlap with adt7410s
                 -- originally written for 4 adt and 8 ina chips
        i2c_data : idata_type := ((others => '0'), --zero pad makes math easier
                                 nine_pad & x"90" & adt7410_config, nine_pad & x"92" & adt7410_config,
                                 nine_pad & x"94" & adt7410_config, nine_pad & x"96" & adt7410_config, -- adt7410 config 27 bit
                                 nine_pad & x"90" & adt7410_pntr, nine_pad & x"92" & adt7410_pntr,
                                 nine_pad & x"94" & adt7410_pntr, nine_pad & x"96" & adt7410_pntr, -- adt7410 address pointer 27 bit
                                 x"80" & ina226_config, x"82" & ina226_config, x"84" & ina226_config, 
                                 x"86" & ina226_config, x"88" & ina226_config, x"8a" & ina226_config, 
                                 x"8c" & ina226_config, x"8e" & ina226_config, -- ina226 config 36 bit
                                 x"80" & ina226_cal, x"82" & ina226_cal, x"84" & ina226_cal, 
                                 x"86" & ina226_cal, x"88" & ina226_cal, x"8a" & ina226_cal, 
                                 x"8c" & ina226_cal, x"8e" & ina226_cal, -- ina226 calibration 36 bit
                                 nine_pad & x"91" & read_word, nine_pad & x"93" & read_word,
                                 nine_pad & x"95" & read_word, nine_pad & x"97" & read_word, -- adt7410 read 27 bit
                                 eighteen_pad & x"80" & ina226_Vreg, eighteen_pad & x"82" & ina226_Vreg, eighteen_pad & x"84" & ina226_Vreg, 
                                 eighteen_pad & x"86" & ina226_Vreg, eighteen_pad & x"88" & ina226_Vreg, eighteen_pad & x"8a" & ina226_Vreg, 
                                 eighteen_pad & x"8c" & ina226_Vreg, eighteen_pad & x"8e" & ina226_Vreg, -- ina226 set to read Vreg 18 bit
                                 nine_pad & x"81" & read_word, nine_pad & x"83" & read_word, nine_pad & x"85" & read_word, 
                                 nine_pad & x"87" & read_word, nine_pad & x"89" & read_word, nine_pad & x"8b" & read_word, 
                                 nine_pad & x"8d" & read_word, nine_pad & x"8f" & read_word, -- ina226 read Vreg 27 bit
                                 eighteen_pad & x"80" & ina226_Ireg, eighteen_pad & x"82" & ina226_Ireg, eighteen_pad & x"84" & ina226_Ireg, 
                                 eighteen_pad & x"86" & ina226_Ireg, eighteen_pad & x"88" & ina226_Ireg, eighteen_pad & x"8a" & ina226_Ireg, 
                                 eighteen_pad & x"8c" & ina226_Ireg, eighteen_pad & x"8e" & ina226_Ireg, -- ina226 set to read Ireg 18 bit
                                 nine_pad & x"81" & read_word, nine_pad & x"83" & read_word, nine_pad & x"85" & read_word, 
                                 nine_pad & x"87" & read_word, nine_pad & x"89" & read_word, nine_pad & x"8b" & read_word, 
                                 nine_pad & x"8d" & read_word, nine_pad & x"8f" & read_word -- ina226 read Ireg 27 bit
                                 
                                 );
                 -- this tells the i2c process how many bits to send
        i2c_size : size_type := (0, -- zero pad makes math easier
                                 27,27,27,27, -- adt7410 config 27 bit
                                 27,27,27,27, -- adt7410 address pointer 27 bit
                                 36,36,36,36,36,36,36,36, -- ina226 config 36 bit
                                 36,36,36,36,36,36,36,36, -- ina226 cal 36 bit
                                 27,27,27,27, -- adt7410 read 27 bit
                                 18,18,18,18,18,18,18,18, -- ina226 Vreg 18 bit
                                 27,27,27,27,27,27,27,27, -- ina226 read 27 bit         
                                 18,18,18,18,18,18,18,18, -- ina226 Ireg 18 bit
                                 27,27,27,27,27,27,27,27) -- ina226 read 27 bit                          
                                 );
            
    Port ( 
           clock : in STD_LOGIC;
           reset : in STD_LOGIC;
           scl : out STD_LOGIC;
           sda : inout STD_LOGIC;
           registers : out ivt_regs_type
           );
           
end qafe_monitors;

architecture rtl of qafe_monitors is

  type     i2c_state_type is (IDLE, START, CLK_P1, CLK_P2, CLK_P3, CLK_P4, STOP_P1, STOP_P2, STOP_P3, STOP_P4);                          
  type     data_state_type is (IDLE, CONFIG, READ, WAITING);
                     
  signal   i2c_state    : i2c_state_type;
  signal   data_state   : data_state_type;
  
  signal   sys_clk      : std_logic;                      -- system clock to operate i2c logic    
  signal   i2c_clk      : std_logic;                      -- system clock to operate i2c logic    
             
  signal   treg         : std_logic_vector(35 downto 0);  -- transfer register,                                                             
  signal   rreg         : std_logic_vector(35 downto 0);  -- receiver register                                                     
  signal   bcnt         : integer range 0 to 127;          -- transfer size
  signal   bit_count    : integer range 0 to 127;          -- transfer counter
  signal   step_count   : integer range 0 to 127;          -- transfer event
    
  signal   int_scl		: std_logic;
  signal   int_sda		: std_logic;  
  signal   strobe		: std_logic;
  
  signal   clkcnt 		: std_logic_vector(31 downto 0);
  
  signal   addr			: std_logic_vector(1 downto 0);  
  signal   dlytime      : std_logic_vector(7 downto 0);
  signal   readtemp     : std_logic;
  signal   i2c_ready    : std_logic;
  signal   i2c_trig     : std_logic;
  
  
    --debug signals (connect to ila)
   attribute mark_debug                 : string;
   attribute mark_debug of step_count     : signal is "true";
   attribute mark_debug of int_scl        : signal is "true";
   attribute mark_debug of int_sda        : signal is "true";
   attribute mark_debug of rreg           : signal is "true";
  
  
begin

clkgen: process(clock)
begin
    if rising_edge(clock) then
        if (reset = '1') then
            clkcnt <= (others => '0');
	    else
		    clkcnt <= std_logic_vector(resize(unsigned(clkcnt) + 1,32));
        end if;
    end if;
end process clkgen;	

--I2C pins
scl <= int_scl;
sda <= int_sda when (int_sda = '0') else 'Z';

--clock control
sys_clk <= clkcnt(6);
sys_clk_bufg_inst : BUFG  port map (O => i2c_clk, I => sys_clk);
strobe <= '1' when (clkcnt(25 downto 10) = x"FFFF") else '0';  --640ms update
--strobe <= '1' when (clkcnt(15 downto 0) = x"FFFF") else '0';  --640ms update


--data control
data_con: process(clock)
begin
    if rising_edge(clock) then
        if (reset = '1') then
           bcnt <= 0;
           treg <= (others => '0');
           data_state <= IDLE;
           i2c_trig <= '0';
           step_count <= 0;
        elsif (i2c_ready = '1') then
            case data_state is
                when IDLE =>
                    data_state <= CONFIG;
                when CONFIG =>
                    if (i2c_trig = '0') then
                        if step_count < 24 then
                            treg <= i2c_data(step_count);
                            bcnt <= i2c_size(step_count);
                            step_count <= step_count + 1;
                            i2c_trig <= '1';
                        else
                            data_state <= READ;
                            --step_count <= 24;
                        end if;
                    end if;
                when READ =>
                    if i2c_trig = '0' then
                        if (step_count < 61) then
                            case step_count is -- use step count to choose register to update
                                when 25 =>
                                    registers.temp0 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 26 =>
                                    registers.temp1 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 27 =>
                                    registers.temp2 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 28 =>
                                    registers.temp3 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 37 =>
                                    registers.Vreg0 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 38 =>
                                    registers.Vreg1 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 39 =>
                                    registers.Vreg2 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 40 =>
                                    registers.Vreg3 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 41 =>
                                    registers.Vreg4 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 42 =>
                                    registers.Vreg5 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 43 =>
                                    registers.Vreg6 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 44 =>
                                    registers.Vreg7 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 53 =>
                                    registers.Ireg0 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 54 =>
                                    registers.Ireg1 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 55 =>
                                    registers.Ireg2 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 56 =>
                                    registers.Ireg3 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 57 =>
                                    registers.Ireg4 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 58 =>
                                    registers.Ireg5 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when 59 =>
                                    registers.Ireg6 <= rreg (17 downto 10) & rreg(8 downto 1); 
                                when 60 =>
                                    registers.Ireg7 <= rreg (17 downto 10) & rreg(8 downto 1);
                                when others =>
                                    null;
                            end case;
                            if (step_count /= 60) then
                                treg <= i2c_data(step_count + 1); 
                                bcnt <= i2c_size(step_count + 1);
                                step_count <= step_count + 1;
                                i2c_trig <= '1';
                            else
                                data_state <= WAITING;
                            end if;
                        else
                            data_state <= WAITING;
                        end if;
                    end if;
                when WAITING =>
                    if (strobe = '1') then
                        data_state <= READ;
                        step_count <= 24;
                    end if;
                when others =>
                    data_state <= IDLE;
            end case;
        else
            i2c_trig <= '0';
        end if;
    end if;
end process data_con;

i2c_con: process(i2c_clk) -- using 4 phase clocking P1 = scl low, P2 = data set, P3 = scl high, P4 = data read (START and STOP are different)
begin
    if rising_edge(i2c_clk) then
        if (reset = '1') then
            i2c_ready <= '0';
            rreg <= (others => '0');
            int_scl <= '1';
            int_sda <= '1';
            i2c_state <= IDLE;
        else
            case i2c_state is
                when IDLE =>
                    if (i2c_trig = '1') then
                        rreg <= (others => '0');
                        i2c_ready <= '0';
                        bit_count <= bcnt;
                        i2c_state <= START;
                    else
                        int_scl <= '1';
                        int_sda <= '1';
                        i2c_ready <= '1';
                    end if;
                when START => -- sda falls
                    int_sda <= '0';
                    i2c_state <= CLK_P1;
                when CLK_P1 => -- scl falls , detect stop
                    int_scl <= '0';
                    if (bit_count <= 0) then
                        int_sda <= '0';
                        i2c_state <= STOP_P1;
                    else
                        i2c_state <= CLK_P2;
                    end if;
                when CLK_P2 => -- sda <= treg
                    int_sda <= treg(bit_count-1);
                    i2c_state <= CLK_P3;
                when CLK_P3 => -- scl rises
                    int_scl <= '1';
                    i2c_state <= CLK_P4;
                when CLK_P4 => -- rreg <= sda , decrement bit_count
                    if (bit_count > 0) then
                        rreg(bit_count - 1) <= sda;
                        bit_count <= bit_count - 1;
                    end if;
                    i2c_state <= CLK_P1;
                when STOP_P1 => -- pause
                    i2c_state <= STOP_P2;
                when STOP_P2 => -- scl rises
                    int_scl <= '1';
                    i2c_state <= STOP_P3;
                when STOP_P3 => -- sda rises
                    int_sda <= '1';
                    i2c_state <= IDLE;
                when others =>
                    i2c_state <= IDLE;
                    int_scl <= '1';
                    int_sda <= '1';
            end case;
        end if;
    end if;
end process i2c_con;

end rtl;

