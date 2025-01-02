
--//////////////////////////////////////////////////////////////////////////////////
--// Company: 
--// Engineer: 
--// 
--// Create Date: 05/14/2015 02:56:06 PM
--// Design Name: 
--// Module Name: evr_top
--// Project Name: 
--// Target Devices: 
--// Tool Versions: 
--// Description: 
--// 
--// Dependencies: 
--// 
--// Revision:
--// Revision 0.01 - File Created
--// Additional Comments:
--//
--//
--//	SFP 5    - X0Y1
--//	SFP 6    - X0Y2   --- EVR Port
--//
--// 
--//////////////////////////////////////////////////////////////////////////////////

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library work;
use work.xbpm_package.ALL;


entity fofb_top is
   port(
    sys_clk        : in std_logic;
    sys_rst        : in std_logic;
    gtx_reset      : in std_logic_vector(7 downto 0);
    gtx_refclk     : in std_logic;
    fa_data        : in data_type;  
    tx_p           : out std_logic;
    tx_n           : out std_logic;
    rx_p           : in std_logic;
    rx_n           : in std_logic;
    fofb_rcvd_clk  : out std_logic;
    fofb_rcvd_data : out std_logic_vector(31 downto 0);
    fofb_rcvd_val  : out std_logic;
    fofb_txactive  : out std_logic;
    fofb_txusr_clk : out std_logic

);
end fofb_top;
 
 
architecture behv of fofb_top is


component LocalDataCRC is
  port(
	clk            : in std_logic;
	rst            : in std_logic;		
	data_in        : in std_logic_vector(31 downto 0);
	crc_en         : in std_logic;
    CRCout         : out std_logic_vector(31 downto 0)
	);
end component;
	

    type state_type is (IDLE, WR_HEADER, WR_W0, WR_W1, WR_W2, WR_W3, WR_W4, WR_W5, WR_W6, WR_W7, WR_W8, WR_W9);                    
    signal   state   : state_type;


   signal rxout_clk         : std_logic;
   signal rxusr_clk         : std_logic;
   signal rxdata            : std_logic_vector(31 downto 0);  
   signal rxcharisk         : std_logic_vector(3 downto 0);   
   signal rxresetdone       : std_logic;  
   
   signal rxdisperr         : std_logic_vector(3 downto 0);
   signal rxnotintable      : std_logic_vector(3 downto 0);

   
   signal txdata            : std_logic_vector(31 downto 0);
   signal txout_clk         : std_logic;
   signal txusr_clk         : std_logic; 
   signal txcharisk         : std_logic_vector(3 downto 0);
   signal txresetdone       : std_logic;
   
   signal count             : std_logic_vector(31 downto 0) := 32d"0"; 
   
   signal tx_fsm_reset_done : std_logic;
   signal rx_fsm_reset_done : std_logic;
   
   signal cpllfbclklost     : std_logic;
   signal cplllock          : std_logic;
   
   signal data_rdy_s        : std_logic_vector(2 downto 0);
   
   signal crcdata           : std_logic_vector(31 downto 0);
   signal crc_en            : std_logic := '0';
   signal crc               : std_logic_vector(31 downto 0);
   signal crc_rst           : std_logic;
   
   attribute ASYNC_REG : string;
   attribute ASYNC_REG of data_rdy_s : signal is "true";

   
--   --debug signals (connect to ila)
   attribute mark_debug     : string;
  
   attribute mark_debug of rxdata: signal is "true";
   attribute mark_debug of rxcharisk: signal is "true";
   attribute mark_debug of rxresetdone: signal is "true";
   attribute mark_debug of txdata: signal is "true";
   attribute mark_debug of txcharisk: signal is "true";
   attribute mark_debug of txresetdone: signal is "true";
   attribute mark_debug of gtx_reset: signal is "true";
   
   attribute mark_debug of count: signal is "true";



begin


fofb_txusr_clk <= txusr_clk;
fofb_txactive <= txcharisk(0);

-- received FOFB data (for remote mode)
fofb_rcvd_clk <= rxusr_clk;
fofb_rcvd_data <= rxdata;
fofb_rcvd_val <= NOT rxcharisk(0);



--sync the data_rdy signal to the txusr_clk domain
process (txusr_clk)
begin
  if (rising_edge(txusr_clk)) then
    data_rdy_s(2) <= fa_data.data_rdy;
    data_rdy_s(1) <= data_rdy_s(2);
    data_rdy_s(0) <= data_rdy_s(1);
  end if;
end process;




txoutclk_bufg0_i : BUFG
    port map ( I => txout_clk, O => txusr_clk);
  
    
rxoutclk_bufg0_i : BUFG
        port map ( I => rxout_clk, O => rxusr_clk);   



--write samples to transceiver
process(sys_rst, txusr_clk)
  begin
    if (rising_edge(txusr_clk)) then
      if (sys_rst = '1') then
        state <= idle;
        crcdata <= 32d"0";
        txdata <= x"5051523C";
        crc_en <= '0';
        crc_rst <= '1';
        txcharisk <= x"1";              
      else
        case state is
          when IDLE => 
            txdata <= x"5051523C";
            txcharisk <= x"1";  
            crcdata <= 32d"0";
            crc_rst <= '1';    
            if (data_rdy_s(0) = '1') then
              crc_rst <= '0';
              state <= wr_header;
            end if;
             
          when WR_HEADER =>
            crc_en <= '1';
            crcdata <= x"00A0005C";
            state <= wr_w0;   
             
          when WR_W0 =>
            crcdata <= fa_data.cha_mag;
            txdata  <= x"00A0005C";
            txcharisk <= x"0";
            state <= wr_w1;

          when WR_W1 =>
            crcdata <= fa_data.chb_mag;         
            txdata  <= fa_data.cha_mag;
            state <= wr_w2;
              
         when WR_W2 =>
            crcdata <= fa_data.chc_mag;
            txdata  <= fa_data.chb_mag;
            state <= wr_w3;

          when WR_W3 =>
            crcdata <= fa_data.chd_mag;
            txdata  <= fa_data.chc_mag;
            state <= wr_w4;
 
          when WR_W4 =>
            crcdata <= fa_data.xpos;
            txdata <= fa_data.chd_mag;
            state <= wr_w5;                                      
 
         when WR_W5 =>
            crcdata <= fa_data.ypos;
            txdata <= fa_data.xpos;
            state <= wr_w6;

          when WR_W6 =>
            crcdata <= fa_data.sum;
            txdata <= fa_data.ypos;
            state <= wr_w7;
 
          when WR_W7 =>
            crcdata <= 32d"0";
            txdata <= fa_data.sum;         
            state <= wr_w8;  
            
         when WR_W8 =>
            crc_en <= '0';
            txdata <= 32d"0"; --status;
            state <= wr_w9;             
            
          when WR_W9 =>
            txdata <= crc;
            state <= idle;   

          when OTHERS => 
              state <= idle;    
              
         end case;
       end if;
     end if;
end process; 


fofb: LocalDataCRC 
  port map(
	clk => txusr_clk,
	rst => crc_rst, 		
	data_in => crcdata,
	crc_en => crc_en, 
    CRCout => crc
	);


--process
--begin
--   txout_clk <= '0';
--   wait for 4 ns;
--   txout_clk <= '1';
--   wait for 4 ns;
--end process;


--process (rxusr_clk)
--begin
--  if (rising_edge(rxusr_clk)) then
--    if (sys_rst = '1') then
--      count <= 32d"0";
--      xdata <= x"505152BC";
--      txcharisk <= x"1";
--    else
--      if (count = 32d"100") then
--        txdata <= x"505152BC";
--        txcharisk <= x"1";
--        count <= 32d"0";
--      else
--        txdata <= count;
--        txcharisk <= x"0"; 
--        count <= count + 1;
--      end if;
--    end if;
--  end if;
--end process;
    


fofb_gtx_init_i : entity work.fofb_gtx
    port map
    (
        sysclk_in                       =>      sys_clk,
        soft_reset_tx_in                =>      gtx_reset(1),
        soft_reset_rx_in                =>      gtx_reset(2), 
        dont_reset_on_data_error_in     =>      '0',
        gt0_tx_fsm_reset_done_out       =>      tx_fsm_reset_done,
        gt0_rx_fsm_reset_done_out       =>      rx_fsm_reset_done,
        gt0_data_valid_in               =>      '1', 

        --_____________________________________________________________________
        --_____________________________________________________________________
        --GT0  (X0Y3)

        --------------------------------- CPLL Ports -------------------------------
        gt0_cpllfbclklost_out           =>      cpllfbclklost,
        gt0_cplllock_out                =>      cplllock,
        gt0_cplllockdetclk_in           =>      sys_clk,
        gt0_cpllreset_in                =>      gtx_reset(0), 
        -------------------------- Channel - Clocking Ports ------------------------
        gt0_gtrefclk0_in                =>      gtx_refclk,
        gt0_gtrefclk1_in                =>      '0',
        ---------------------------- Channel - DRP Ports  --------------------------
        gt0_drpaddr_in                  =>      (others => '0'),
        gt0_drpclk_in                   =>      sys_clk,
        gt0_drpdi_in                    =>      (others => '0'), 
        gt0_drpdo_out                   =>      open,
        gt0_drpen_in                    =>      '0',
        gt0_drprdy_out                  =>      open,
        gt0_drpwe_in                    =>      '0',
        --------------------------- Digital Monitor Ports --------------------------
        gt0_dmonitorout_out             =>      open, 
        --------------------- RX Initialization and Reset Ports --------------------
        gt0_eyescanreset_in             =>      '0',
        gt0_rxuserrdy_in                =>      '1',
        -------------------------- RX Margin Analysis Ports ------------------------
        gt0_eyescandataerror_out        =>      open,
        gt0_eyescantrigger_in           =>      '0',
        ------------------ Receive Ports - FPGA RX Interface Ports -----------------
        gt0_rxusrclk_in                 =>      rxusr_clk,
        gt0_rxusrclk2_in                =>      rxusr_clk,
        ------------------ Receive Ports - FPGA RX interface Ports -----------------
        gt0_rxdata_out                  =>      rxdata,
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        gt0_rxdisperr_out               =>      rxdisperr,
        gt0_rxnotintable_out            =>      rxnotintable,
        --------------------------- Receive Ports - RX AFE -------------------------
        gt0_gtxrxp_in                   =>      rx_p,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        gt0_gtxrxn_in                   =>      rx_n,
        -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
        gt0_rxcommadet_out              =>      open, 
        gt0_rxmcommaalignen_in          =>      '1', 
        gt0_rxpcommaalignen_in          =>      '1', 
        --------------------- Receive Ports - RX Equalizer Ports -------------------
        gt0_rxdfelpmreset_in            =>      '0', 
        gt0_rxmonitorout_out            =>      open, 
        gt0_rxmonitorsel_in             =>      "00", 
        --------------- Receive Ports - RX Fabric Output Control Ports -------------
        gt0_rxoutclk_out                =>      rxout_clk,
        gt0_rxoutclkfabric_out          =>      open,
        ------------- Receive Ports - RX Initialization and Reset Ports ------------
        gt0_gtrxreset_in                =>      gtx_reset(3),
        gt0_rxpmareset_in               =>      gtx_reset(4),
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        gt0_rxchariscomma_out           =>      open, 
        gt0_rxcharisk_out               =>      rxcharisk,
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        gt0_rxresetdone_out             =>      rxresetdone,
        --------------------- TX Initialization and Reset Ports --------------------
        gt0_gttxreset_in                =>      gtx_reset(5),
        gt0_txuserrdy_in                =>      '1',
        ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
        gt0_txusrclk_in                 =>      txusr_clk,
        gt0_txusrclk2_in                =>      txusr_clk,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        gt0_txdata_in                   =>      txdata,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        gt0_gtxtxn_out                  =>      tx_n,
        gt0_gtxtxp_out                  =>      tx_p,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        gt0_txoutclk_out                =>      txout_clk,
        gt0_txoutclkfabric_out          =>      open, 
        gt0_txoutclkpcs_out             =>      open, 
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        gt0_txcharisk_in                =>      txcharisk,
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
        gt0_txresetdone_out             =>      txresetdone,

        gt0_qplloutclk_in               =>      '0', 
        gt0_qplloutrefclk_in            =>      '0' 
    );





		

			 
end behv;
