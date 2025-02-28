#ifndef NSLS2EM_H_
#define NSLS2EM_H_

#include "xbasic_types.h"


//PL AXI4 Bus Registers

#define GPIO_IN_REG 0x0
#define GPIO_OUT_REG 0x4
#define ADC_TESTMODE_REG 0x8
#define FP_LEDS_REG 0x14
#define FPGA_VER_REG 0x1C
#define SA_DIVIDE_REG 0x20
#define SA_IRQENB_REG 0x24
#define FA_DIVIDE_REG 0x28
#define MACHCLK_SEL_REG 0x2C  //0=int, 1=evr
#define FAN_SETSPEED_REG 0x30
#define FAN_TACHCNT_REG 0x34
#define FAN_STATUS_REG 0x38
#define SA_TRIGNUM_REG 0x40
#define KX_REG 0x44
#define KY_REG 0x48
#define MACHCLK_DIVIDE_REG 0x4C
#define CHA_OFFSET_REG 0x50
#define CHB_OFFSET_REG 0x54
#define CHC_OFFSET_REG 0x58
#define CHD_OFFSET_REG 0x5C
#define CHA_GAIN_REG 0x60
#define CHB_GAIN_REG 0x64
#define CHC_GAIN_REG 0x68
#define CHD_GAIN_REG 0x6C
#define AFE_CNTRL_REG 0x70
#define AFE_DB_GAIN_REG 0x74
#define GTX_RESET_REG 0x7C
#define BIAS_DAC_REG 0x80
#define XPOS_OFFSET_REG 0x88
#define YPOS_OFFSET_REG 0x8C
#define ADCRAW_CHA_REG 0x90
#define ADCRAW_CHB_REG 0x94
#define ADCRAW_CHC_REG 0x98
#define ADCRAW_CHD_REG 0x9C
#define ADCRAW_CHE_REG 0xA0
#define ADCRAW_CHF_REG 0xA4
#define ADCRAW_CHG_REG 0xA8
#define ADCRAW_CHH_REG 0xAC
#define SA_CHAMAG_REG 0xB0
#define SA_CHBMAG_REG 0xB4
#define SA_CHCMAG_REG 0xB8
#define SA_CHDMAG_REG 0xBC
#define SA_SUM_REG 0xC0
#define SA_XPOS_REG 0xC4
#define SA_YPOS_REG 0xC8
#define EVR_TS_S_REG 0xD0
#define EVR_TS_NS_REG 0xD4
#define EVR_TS_S_LAT_REG 0xD8
#define EVR_TS_NS_LAT_REG 0xDC
#define EVR_TRIGDLY_REG 0xE0
#define EVR_TRIGNUM_REG 0xE4
#define SIM_DDS_FREQ_REG 0xF0
#define SIM_POS_SEL_REG 0xF4  //0=sim use DDS, 1=real
#define FDBK_DAC_DATA_REG 0x120
#define FDBK_DAC_LDAC_REG 0x124
#define FDBK_DAC_OPMODE_REG 0x128
#define HEAT_DAC_DATA_REG 0x130
#define HEAT_DAC_LDAC_REG 0x134
#define THERMISTOR_REG 0x140
#define TEMP_SENSE0_REG 0x150
#define TEMP_SENSE1_REG 0x154
#define PWR_VIN_REG 0x158
#define PWR_IIN_REG 0x15C
#define FA_SOFT_TRIG_REG 0x200
#define FA_TRIG_STAT_REG 0x204
#define FA_TRIG_CLEAR_REG 0x208
#define FA_FIFO_STREAMENB_REG 0x210
#define FA_FIFO_RST_REG 0x214
#define FA_FIFO_DATA_REG 0x218
#define FA_FIFO_CNT_REG 0x21C
#define FA_RCVD_FIFO_STREAMENB_REG 0x220
#define FA_RCVD_FIFO_RST_REG 0x224
#define FA_RCVD_FIFO_DATA_REG 0x228
#define FA_RCVD_FIFO_CNT_REG 0x22C
#define MOD_ID_NUM 0x400
#define MOD_ID_VER 0x404
#define PROJ_ID_NUM 0x408
#define PROJ_ID_VER 0x40C
#define GIT_SHASUM 0x410
#define COMPILE_TIMESTAMP 0x414



/*
#define FIFODATAREG  128
#define FIFOWDCNTREG 129
#define SOFTTRIGREG 130
#define FADIVREG 133
#define FIFOCNTRLREG 134
#define TRIGCLR 135

#define FA_RATE_SEL 10
#define I_GAIN_SEL 28
#define CURRENT_REG 36
#define VOLTATE_REG 40
#define FIFO_REG_START 128
#define QUAD_SYN 100

#define I_V_SEL 210

#define REG_DAC_OP_MODE 74
#define REG_DAC_DATA 72
#define REG_DAC_LOAD  73  //not used

*/

#define QUAD_SYN 100
#define QUAD_PSC_SEL 200
#define CURRENT_FLOAT_TX_REG 201
#define VOLTAGE_FLOAT_TX_REG 205
#define DAC_DATA_REG_OFFSET 210



//assume voltage ADC is 16-bit: range 64K, middle 32K
#define VOLTAGE_FILL_RANGE 65535.0
#define VOLTAGE_MIDDLE 32767.0
#define VOLTAGE_VOLTAGE_RANGE 10.0

#define TIMER_ID	1
#define THREAD_STACKSIZE 1024
#define cmdStsPort 7
#define adcPort 17
#define cmdStsBuf_SIZE 1408

#define DATA_10KHZ_SIZE_BYTE 40 //32 ADC * 10KHz * 1 second *4bytes = 1310720 byte
#define QUADEM_SIZE_BYTE 40
#define THREAD_STACKSIZE 1024
#define DATA_10HZ_SIZE 512
#define DATA_10HZ_SIZE_CMD 1400


//Network variables:
extern char MAC[6],IP[4],MSK[4],GW[4];
extern char mac1,mac2,mac3,mac4,mac5,mac6,ip1,ip2,ip3,ip4,msk1,msk2,msk3,msk4,gw1,gw2,gw3,gw4;
extern volatile char * IPReadabck;
extern volatile Xuint32 ConnectionClose;
extern volatile Xuint32 netConfig;
extern volatile char * mac_addr;

//FIFO variables:
extern volatile char fifoRun,fifoRunReg,fifoRunRegReg;
extern volatile Xuint32 adcFifo[4];
extern int fifoIndex, fifoLength;
extern volatile char quadSyncFifoTrig, quadSyncFifoTrigReg, fifoInit;

//pscDrv variables:
extern char txBuf[cmdStsBuf_SIZE];
extern char rxBuf[cmdStsBuf_SIZE];
extern char adcTxBuf[DATA_10KHZ_SIZE_BYTE + 8];
extern volatile int writeFlag;
extern volatile Xuint32 I_GAIN_Reg28;

//EM variables:
extern float I_SA[4];
extern float current[4];
extern double current_double[4];

extern int main_thread();
extern int netConfigProcess();
extern void applicationThread(int);
extern void cmdProcess(void *);
extern void statusProcess(void *);
extern void adcProcess(void *);
extern void lwip_init();
extern void verifyMAC();
extern void verifyIP(int,char []);
extern void DAC_Init();
extern void currentCalc(int);

#endif
