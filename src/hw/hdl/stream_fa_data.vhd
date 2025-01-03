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


entity stream_fa_data is
  port(
     mach_clk           : in std_logic;
     sys_clk            : in std_logic;
     reset              : in std_logic;

     fa_data            : in data_type;
     
     fa_data_enb        : in std_logic;
     fa_data_fiforst    : in std_logic;
     
     adc_raw            : in adc_raw_type;
	 
	 evr_timestamp      : in std_logic_vector(63 downto 0); 	 
	 
	 fifo_rdstr         : in  std_logic;
	 fifo_dout          : out std_logic_vector(31 downto 0);
	 fifo_rdcnt         : out std_logic_vector(31 downto 0)
	 	    
    );

end stream_fa_data;
  

architecture behv of stream_fa_data is


component fa_fifo
  PORT (
    wr_rst                  : IN STD_LOGIC;
    wr_clk                  : IN STD_LOGIC;
    rd_rst                  : IN STD_LOGIC;
    rd_clk                  : IN STD_LOGIC;
    din                     : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    wr_en                   : IN STD_LOGIC;
    rd_en                   : IN STD_LOGIC;
    dout                    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full                    : OUT STD_LOGIC;
    empty                   : OUT STD_LOGIC;
    rd_data_count           : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
end component;


    type state_type is (IDLE, FIFO_WRITE_W0, FIFO_WRITE_W1, FIFO_WRITE_W2, FIFO_WRITE_W3);                    
    signal   state   : state_type;

    type ADC_SUM_TYPE is array(0 to NUM_ADCS-1) of signed(31 downto 0);
    
    signal tenkhz_cnt       : unsigned(31 downto 0);
    

    signal adc_raw_se       : adc_ave_type;
    signal adc_sum          : adc_sum_type;
    signal adc_lat          : adc_ave_type;
 
    
    signal fifo_din         : std_logic_vector(127 downto 0);  
    
    signal fifo_full        : std_logic;
    signal fifo_empty       : std_logic;
    signal fifo_rd_data_cnt : std_logic_vector(15 downto 0);
    
    signal tst_data         : unsigned(31 downto 0);
    signal tst_cnt          : std_logic_vector(31 downto 0);
       
    signal fifo_rdstr_prev  : std_logic;
    signal fifo_rdstr_fe    : std_logic;
    signal fifo_wrstr       : std_logic;
    signal fifo_wren        : std_logic;
    
    signal sample_num       : std_logic_vector(31 downto 0);
     

   attribute mark_debug     : string;
   attribute mark_debug of fa_data: signal is "true";
   attribute mark_debug of fa_data_enb: signal is "true";  
   attribute mark_debug of fa_data_fiforst: signal is "true";
   attribute mark_debug of fifo_wren: signal is "true";
   attribute mark_debug of fifo_rd_data_cnt: signal is "true";
   attribute mark_debug of sample_num: signal is "true";
   attribute mark_debug of fifo_din: signal is "true";



begin
  
 
 
  

fifo_rdcnt  <= x"0000" & fifo_rd_data_cnt;




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
        



--write samples to fifo
process(reset, sys_clk)
  begin
     if (rising_edge(sys_clk)) then
       if (reset = '1') then
          fifo_wren <= '0';
          sample_num <= x"00000000";
          state <= idle;
       else
         case state is
           when IDLE =>  
             fifo_wren <= '0';     
             if (fa_data_enb = '0') then
               sample_num <= (others => '0');
             end if;      
             if (fa_data_enb = '1') and (fa_data.data_rdy = '1') then
                sample_num <= sample_num + 1;
                state <= fifo_write_w0;
             end if;
             
           when FIFO_WRITE_W0 =>
              fifo_wren <= '1';
              fifo_din <= x"80000000" & sample_num & evr_timestamp;  
              state <= fifo_write_w1;
              
          when FIFO_WRITE_W1 =>
              fifo_din <= fa_data.cha_mag & fa_data.chb_mag & fa_data.chc_mag & fa_data.chd_mag;
              state <= fifo_write_w2;
               
          when FIFO_WRITE_W2 =>
              fifo_din <= fa_data.sum & fa_data.xpos & fa_data.ypos & x"00000000";
              state <= fifo_write_w3;               
               
          when FIFO_WRITE_W3 =>
              fifo_din <= fa_data.che_mag & fa_data.chf_mag & fa_data.chg_mag & fa_data.chf_mag;
              state <= idle;
          
          when OTHERS => 
              state <= idle;    
              
         end case;
       end if;
     end if;
end process; 
              
              
              




fafifo : fa_fifo
  PORT MAP (
    wr_clk          => sys_clk,
    wr_rst          => fa_data_fiforst,
    wr_en           => fifo_wren,  
    din             => fifo_din,    
    rd_clk          => sys_clk,
    rd_rst          => fa_data_fiforst,
    rd_en           => fifo_rdstr_fe,
    dout            => fifo_dout,
    full            => fifo_full,
    empty           => fifo_empty,
    rd_data_count   => fifo_rd_data_cnt
  );



end behv;


