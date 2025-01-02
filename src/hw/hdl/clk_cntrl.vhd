library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

 

entity clk_cntrl is
  
  port (
    clk                 : in std_logic;
    reset               : in std_logic;
       
    mach_clk_sel        : in std_logic_vector(1 downto 0);
    machclk_divide      : in std_logic_vector(7 downto 0);
    fa_divide           : in std_logic_vector(31 downto 0);
    sa_divide           : in std_logic_vector(31 downto 0);
      
    --ext_tbtclk          : in std_logic;
    evr_tbtclk          : in std_logic;
    evr_fatrig          : in std_logic;
    evr_satrig          : in std_logic;
    
    mach_clk            : out std_logic;
    fa_trig             : out std_logic;
    sa_trig             : out std_logic
    
  );

end clk_cntrl;




architecture rtl of clk_cntrl is

   signal mach_clk_int   : std_logic;
   signal mach_clk_src   : std_logic;
   signal clk_cnt        : std_logic_vector(8 downto 0);
   
   signal fa_cnt_i       : std_logic_vector(31 downto 0);
   signal sa_cnt_i       : std_logic_vector(31 downto 0);
   
   signal sa_trig_i      : std_logic;
   signal fa_trig_i      : std_logic;
   
   

begin  


--mach_clk_sel  0=ext, 1=int, 2=evr (for ext and int, generate tenhz and tenkhz trig internally,
--for evr, sa and fa triggiers come from event link)  
sa_trig  <= evr_satrig  when (mach_clk_sel = "01") else sa_trig_i;  
fa_trig  <= evr_fatrig  when (mach_clk_sel = "01") else fa_trig_i;  
--sa_trig  <= sa_trig_i;  
--fa_trig  <= fa_trig_i;  




--generate internal machine clk from sys_clk
process(clk,reset)
  begin
     if (reset = '1') then
        mach_clk_int <= '0';
        clk_cnt <= (others => '0');
     elsif (clk'event and clk = '1') then
        if (clk_cnt = 9d"132") then    --100MHz / 132*2 = 378.5KHz
           mach_clk_int <= not mach_clk_int; 
           clk_cnt <= (others => '0');
        else
           clk_cnt <= clk_cnt + 1;
        end if;
     end if;
end process;


--evr_tbtclk doesn't stay high on evr in ring, but works in lab.
--for now, just use tbtclk from back panel.
mach_clk_src  <= evr_tbtclk  when (mach_clk_sel = "01") else 
                 mach_clk_int;

-- keep it internal only for now.
--mach_clk_src <= mach_clk_int;                

                
                

mach_clk_bufg_inst : BUFG  port map (O => mach_clk, I => mach_clk_src);




-- generate SA trig internally
process(reset,mach_clk)
  begin
     if (reset = '1') then
        sa_trig_i <= '0';
        sa_cnt_i <= (others => '0');    
     elsif (mach_clk'event and mach_clk = '1') then
        if (sa_cnt_i >= (sa_divide-1)) then
           sa_trig_i <= '1';
           sa_cnt_i <= x"00000000";
        else
           sa_trig_i <= '0';
           sa_cnt_i <= sa_cnt_i + 1;
        end if;
     end if;
end process;



-- generate FA trig internally
process(reset,mach_clk)
  begin
     if (reset = '1') then
        fa_trig_i <= '0';
        fa_cnt_i <= (others => '0');
        
     elsif (mach_clk'event and mach_clk = '1') then
        if (fa_cnt_i >= (fa_divide-1)) then
           fa_trig_i <= '1';
           fa_cnt_i <= x"00000000"; 
        else
           fa_trig_i <= '0';
           fa_cnt_i <= fa_cnt_i + 1;
        end if;
     end if;
end process;









  
end rtl;
