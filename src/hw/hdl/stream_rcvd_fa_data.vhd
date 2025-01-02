-- Stream10kdata.vhd
--
--  This module will buffer the 10 KHz data in a fifo to be readout by the iobus
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


entity stream_rcvd_fa_data is
  port(
     sys_clk            : in std_logic;
     fa_rcvd_clk        : in std_logic;
     reset              : in std_logic;
     fa_data            : in std_logic_vector(31 downto 0);
     fa_data_val        : in std_logic;
     fa_data_enb        : in std_logic;
     fa_data_fiforst    : in std_logic;
	 fifo_rdstr         : in  std_logic;
	 fifo_dout          : out std_logic_vector(31 downto 0);
	 fifo_rdcnt         : out std_logic_vector(31 downto 0)	    
    );

end stream_rcvd_fa_data;
  

architecture behv of stream_rcvd_fa_data is

component fa_rcvd_fifo IS
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    rd_data_count : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
end component;


    signal fifo_din         : std_logic_vector(127 downto 0);  
    
    signal fifo_full        : std_logic;
    signal fifo_empty       : std_logic;
    signal fifo_rd_data_cnt : std_logic_vector(15 downto 0);

    signal fifo_rdstr_prev  : std_logic;
    signal fifo_rdstr_fe    : std_logic;
    signal fa_data_enb_s    : std_logic_vector(1 downto 0);
    signal fa_data_enb_sync : std_logic;
    signal fa_data_val_prev : std_logic;



     

   attribute mark_debug     : string;
   attribute mark_debug of fa_data: signal is "true";
   attribute mark_debug of fa_data_val: signal is "true";
   attribute mark_debug of fa_data_enb: signal is "true";  
   attribute mark_debug of fa_data_enb_sync: signal is "true";    
   attribute mark_debug of fa_data_fiforst: signal is "true";
   attribute mark_debug of fifo_rd_data_cnt: signal is "true";
   attribute mark_debug of fifo_din: signal is "true";



begin
  
 
 
  

fifo_rdcnt  <= x"0000" & fifo_rd_data_cnt;

process (fa_rcvd_clk)
  begin
    if (rising_edge(fa_rcvd_clk)) then
      if (reset = '1') then
        fa_data_enb_s <= "00";
        fa_data_val_prev <= '0';
        fa_data_enb_sync <= '0';
      else
        fa_data_enb_s(0) <= fa_data_enb;
        fa_data_enb_s(1) <= fa_data_enb_s(0);
        fa_data_val_prev <= fa_data_val;
        if (fa_data_enb_s(1) = '1' and fa_data_val = '0' and fa_data_val_prev = '1') then
           fa_data_enb_sync <= '1';
        end if;
        if (fa_data_enb_s(1) = '0' and fa_data_val = '0' and fa_data_val_prev = '1') then
           fa_data_enb_sync <= '0';
        end if;        
      end if;
    end if;
end process;


--since fifo is fall-through mode, want the rdstr
--to happen after the current word is read.
process (reset,sys_clk)
   begin
       if (reset = '1') then
          fifo_rdstr_prev <= '0';
          fifo_rdstr_fe <= '0';
       elsif (sys_clk'event and sys_clk = '1') then
          fifo_rdstr_prev <= fifo_rdstr;
          if (fifo_rdstr = '0' and fifo_rdstr_prev = '1') then
              fifo_rdstr_fe <= '1'; --falling edge
          else
              fifo_rdstr_fe <= '0';
          end if;
       end if;
end process;
        



fafifo : fa_rcvd_fifo
  PORT MAP (
    rst             => fa_data_fiforst,
    wr_clk          => fa_rcvd_clk,
    wr_en           => fa_data_val and fa_data_enb_sync,  
    din             => fa_data,    
    rd_clk          => sys_clk,
    rd_en           => fifo_rdstr_fe,
    dout            => fifo_dout,
    full            => fifo_full,
    empty           => fifo_empty,
    rd_data_count   => fifo_rd_data_cnt
  );





              







end behv;


