#include <stdio.h>
#include "platform_config.h"
#include "lwip/sockets.h"
#include "netif/xadapter.h"
#include "lwipopts.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "task.h"
#include "xparameters.h"
#include "xbasic_types.h"
#include "time.h"
#include "xil_io.h"
#include "nsls2em.h"
//#include "iobus.h"
#include "xqspips.h"
#include "QSPI.h"

//Network variables:
char MAC[6],IP[4],MSK[4],GW[4];
char mac1,mac2,mac3,mac4,mac5,mac6,ip1,ip2,ip3,ip4,msk1,msk2,msk3,msk4,gw1,gw2,gw3,gw4;
volatile char * IPReadabck;
volatile Xuint32 ConnectionClose;
volatile Xuint32 netConfig;
volatile char * mac_addr;
static struct netif server_netif;

//FIFO variables:
volatile char fifoRun,fifoRunReg,fifoRunRegReg;
volatile Xuint32 adcFifo[4];
int fifoIndex, fifoLength;
volatile char quadSyncFifoTrig, quadSyncFifoTrigReg, fifoInit;

//pscDrv variables:
char txBuf[cmdStsBuf_SIZE];
char rxBuf[cmdStsBuf_SIZE];
char adcTxBuf[DATA_10KHZ_SIZE_BYTE + 8];
volatile int writeFlag = 0;
//Found R28 read and write are different.  Write to R28 will have impact on R37 reading.
//So, only wirte to R28 when value changed.
volatile Xuint32 I_GAIN_Reg28;

//EM variables:
float I_SA[4];
float current[4];
double current_double[4];

void print_ip(char * msg, ip_addr_t * ip) {
  xil_printf(msg);
  xil_printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

void print_ip_settings(ip_addr_t * ip, ip_addr_t * mask, ip_addr_t * gw) {

  xil_printf("\n\rMAC: %x %x %x %x %x %x\n\r", MAC[0],MAC[1],MAC[2],MAC[3],MAC[4],MAC[5]);
  print_ip("Board IP: ", ip);
  print_ip("Netmask : ", mask);
  print_ip("Gateway : ", gw);
  xil_printf("\n\r");
}

int main() {
  int i;
  Xil_L1DCacheEnable();
  Xil_L2CacheEnable();

  //Init parameters
  xil_printf("\n\rNSLS2_EM\n\r");
  xil_printf("FPGA Version: %d\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + FPGA_VER_REG));
  //FA rate: 10kHz
  //IOBUS_mWriteReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, 0x214, 38);
  Xil_Out32(XPAR_M_AXI_BASEADDR + FA_DIVIDE_REG, 38);
  xil_printf("FA_DIVIDE: %d\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + FA_DIVIDE_REG));
  //Internal clock by default
  //IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, 0x2C, 0);
  Xil_Out32(XPAR_M_AXI_BASEADDR + MACHCLK_SEL_REG, 0);

  //Read mac, IP, netmask and gateway
  MacIPSetup(0);
  sys_thread_new("main_thrd", (void( * )(void * )) main_thread, 0, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
  sys_thread_new("netConfigProcess", (void( * )(void * )) netConfigProcess, 1, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
  vTaskStartScheduler();
  return 0;
}

void network_thread(void * p) {
  int index;
  struct netif * netif;
  ip_addr_t ipaddr, netmask, gw;
  netif = & server_netif;
  for(index=0;index<6;index++) mac_addr[index] = MAC[index];
  IP4_ADDR( & ipaddr, IP[0], IP[1], IP[2],IP[3]);
  IP4_ADDR( & netmask, MSK[0],MSK[1],MSK[2],MSK[3]);
  IP4_ADDR( & gw, GW[0],GW[1],GW[2],GW[3]);
  print_ip_settings( & ipaddr, & netmask, & gw);
  if (!xemac_add(netif, & ipaddr, & netmask, & gw, mac_addr, PLATFORM_EMAC_BASEADDR)) { xil_printf("Error adding N/W interface\r\n"); return;}
  netif_set_default(netif);
  netif_set_up(netif);
  usleep(1000000);
  sys_thread_new("xemacif_input_thread", (void( * )(void * )) xemacif_input_thread, netif, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
  return;
}

int main_thread() {
  int mscnt = 0;
  ConnectionClose = 0;
  lwip_init();
  sys_thread_new("NetworkThread", network_thread, NULL, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
  while (1) {
    vTaskDelay(500 / portTICK_RATE_MS);
    if (server_netif.ip_addr.addr) {
      ConnectionClose = 0;
      sys_thread_new("cmdThread", applicationThread, 1, THREAD_STACKSIZE*20, (DEFAULT_THREAD_PRIO+1));
      //sys_thread_new("cmdThread", applicationThread, 1, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
      sys_thread_new("adcThread", applicationThread, 2, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
      break;
    }
    mscnt += 500;
    if (mscnt >= 5000) {
      xil_printf("ERROR: timed out\r\n");
      ConnectionClose = 0;
      break;
    }
  }
  vTaskDelete(NULL);
  return 0;
}
