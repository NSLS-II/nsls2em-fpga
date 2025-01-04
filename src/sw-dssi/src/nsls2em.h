#ifndef NSLS2EM_H_
#define NSLS2EM_H_

#include "xbasic_types.h"

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
#define QUAD_PSC_SEL 200
#define I_V_SEL 210

#define REG_DAC_OP_MODE 74
#define REG_DAC_DATA 72
#define REG_DAC_LOAD  73  //not used

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
