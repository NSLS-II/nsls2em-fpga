#include <stdio.h>
#include <string.h>
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
#include "xil_cache.h"
#include "nsls2em.h"
//#include "iobus.h"

static int
lwip_writeall(int s,
  const void * data, int size) {
  int sent = 0;
  int ret;
  do {
    ret = lwip_write(s, data + sent, size - sent);
    if (ret < 1) return ret;
    sent += ret;
  } while (sent < size);
  return size;
}

//OPT: cmdProcess: rxBuf --> registers
static int processCmdData(char frameID, unsigned int grepBytes) {
  int cmdRegMax = 38;
  int cmdRegIndex[38] = {1,2,8,9,10,11,12,17,18,19,20,21,22,23,24,25,26,27,28,29,
		                 31,32,34,35,56,57,72,73,74,76,80,84,85,86,87,130,133,134,135};
  int index, byteIndex, regIndex;
  volatile Xuint32 regData;

  for (index = 0; index <= cmdRegMax; index++) {
    regIndex = cmdRegIndex[index];
    byteIndex = 4 * regIndex;
    regData = ((Xuint32) rxBuf[byteIndex] << 24) + ((Xuint32) rxBuf[byteIndex + 1] << 16) +
      ((Xuint32) rxBuf[byteIndex + 2] << 8) + ((Xuint32) rxBuf[byteIndex + 3]);

    //don't write to fifo-related control registers. They are controlled by fifo operation in a group
    //if((regIndex < FIFO_REG_START)&&(regIndex!=FA_RATE_SEL)&&(regIndex!=REG_DAC_DATA)
    //		&&(regIndex!=REG_DAC_OP_MODE)&&(regIndex!=REG_DAC_LOAD)&&(regIndex!=I_GAIN_SEL))
    	//Xil_Out32(XPAR_M_AXI_BASEADDR + regIndex, regData);
    if(regIndex==AFE_CNTRL_REG) {
    	//R28 changed
    	if(regData != I_GAIN_Reg28)  Xil_Out32(XPAR_M_AXI_BASEADDR + AFE_CNTRL_REG, regData);
    	I_GAIN_Reg28 = regData;
    }
  }
  //update DAC register for the four channels. Reg 210, 211, 212,213
  /*
  for (index = 0; index < 4; index++) {
	  regIndex = DAC_DATA_REG_OFFSET + index;
	  byteIndex = 4 * regIndex;
	  regData = ((Xuint32) rxBuf[byteIndex] << 24) + ((Xuint32) rxBuf[byteIndex + 1] << 16) +
	        ((Xuint32) rxBuf[byteIndex + 2] << 8) + ((Xuint32) rxBuf[byteIndex + 3]);
	  //IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, REG_DAC_DATA * 4, regData);
	  Xil_Out32(XPAR_M_AXI_BASEADDR + FDBK_DAC_DATA_REG, regData);
	  usleep(5);
  }
  */
  writeFlag = 1;
}

/*OPT: receive command and send status back */
void cmdProcess(void * p) {
  int sd = (int) p;
  int n;
  unsigned int bufpos = 0;
  unsigned int grepBytes = 8;
  char frameID = 0;
  char frameHeader = 1;
  int cycle = 0;
  int i = 0;
  unsigned int word;

  quadSyncFifoTrigReg = 0;
  quadSyncFifoTrigReg = 0;
  fifoRun = 0;
  xil_printf("\n\r cmdProcess(1) \n\r");
  xil_printf("verion=\n\r %d\n\r", Xil_In32(XPAR_M_AXI_BASEADDR + FPGA_VER_REG));
  word = Xil_In32(XPAR_M_AXI_BASEADDR + FPGA_VER_REG);

  //Init. DAC
  DAC_Init();
  while (1) {
    if (ConnectionClose == 1) break;
    if ((n = read(sd, rxBuf + bufpos, grepBytes - bufpos)) < 0) {
      xil_printf("%s: error reading from socket %d, closing socket\r\n", __FUNCTION__, sd);
      break;
    }
    if (n <= 0) break;
    bufpos += n;
    if (bufpos < grepBytes) continue;
    //Check header
    if (bufpos != grepBytes) {
      xil_printf("Read wrong header bytes. Should never be here! %u %d\n\r", bufpos, grepBytes);
      close(sd);
      return;
    } else {
      //Check if this is frame header
      if (frameHeader == 1) {
        if ((rxBuf[0] != 0x50) || (rxBuf[1] != 0x53) || (rxBuf[2] != 0x0) || (rxBuf[3] > 0x52) || (rxBuf[3] < 0x50)) {
          xil_printf("Wrong header\n\r");
          close(sd);
          return;
        } else {
          //Calculate body length
          frameID = rxBuf[3];
          grepBytes = (Xuint8) rxBuf[4] * 256 * 256 * 256 + (Xuint8) rxBuf[5] * 256 * 256 + (Xuint8) rxBuf[6] * 256 + (Xuint8) rxBuf[7] * 1;
          if (grepBytes == 0) { //this is 0 byte frame -- so, don't expect any body. wait for new header
            grepBytes = 8;
            bufpos = 0;
            frameHeader = 1;
          } else {
            bufpos = 0;
            frameHeader = 0;
          }
        }
      } else {
        processCmdData(frameID, grepBytes);
        quadSyncFifoTrigReg = quadSyncFifoTrig;
        quadSyncFifoTrig = rxBuf[QUAD_SYN*4+3];
        if ((quadSyncFifoTrigReg == 0) && (quadSyncFifoTrig == 1)) fifoRun = 1;
        if (quadSyncFifoTrig == 0) { fifoRun = 0; fifoInit = 0;}
        if (ConnectionClose != 1) {
          txBuf[0] = 'P';
          txBuf[1] = 'S';
          txBuf[2] = 0x0;
          //msgID=80
          txBuf[3] = 0x50;
          txBuf[4] = 0x0;
          txBuf[5] = 0x0;
          txBuf[6] = 0x05;
          txBuf[7] = 0x78;
          for (i = 0; i < 88; i++) {
            //word = IOBUS_mReadReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, i * 4);
            word = Xil_In32(XPAR_M_AXI_BASEADDR + i*4);
            txBuf[8 + 4 * i] = (char)(word >> 24); txBuf[9 + 4 * i] = (char)(word >> 16);
            txBuf[10 + 4 * i] = (char)(word >> 8); txBuf[11 + 4 * i] = (char)(word);
            //usleep(1);
          }
          //all fifo register, except fifidata
          for (i = 129; i < 136; i++) {
            //word = IOBUS_mReadReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, i * 4);
        	word = Xil_In32(XPAR_M_AXI_BASEADDR + i*4);
            txBuf[8 + 4 * i] = (char)(word >> 24); txBuf[9 + 4 * i] = (char)(word >> 16);
            txBuf[10 + 4 * i] = (char)(word >> 8); txBuf[11 + 4 * i] = (char)(word);
            //usleep(1);
          }
          for (i = 140; i < 200; i++) {
            txBuf[8 + 4 * i] = (char) rxBuf[4 * i];   txBuf[9 + 4 * i] = (char) rxBuf[4 * i + 1];
            txBuf[10 + 4 * i] = (char) rxBuf[4 * i + 2]; txBuf[11 + 4 * i] = (char) rxBuf[4 * i + 3];
            //usleep(1);
          }

          //xil_printf("\n\rSending...\n\r");
          if (lwip_writeall(sd, txBuf, cmdStsBuf_SIZE) != cmdStsBuf_SIZE) {
            xil_printf("\n\rClosing TX socket place 4 %d\n\r", sd);
            ConnectionClose = 1;
            close(sd);
            return;
          }
        }
        grepBytes = 8;
        bufpos = 0;
        frameHeader = 1;
      }
    }
  }
  close(sd);
  ConnectionClose = 1;
  xil_printf("\n\r Closing CommandStatus process (1). \n\r");
  vTaskDelete(NULL);
}

/* adc: for nsls2-em, 48 bytes */
void adcSnapShowProcess(void * p) {
  int sd = (int) p;
  int n;
  volatile Xuint32 fifoData;
  volatile Xuint32 * fifoAddP;
  int ADCTimer = 0;
  int ADCPeriod = 4;
  int adcTxBufIndex = 0;
  int adcTxBufWordIndex = 0;
  int i, j;
  int pscSel;
  union {
    double d;
    char bytes[sizeof(double)];
  }
  u;

  fifoIndex = 0;
  fifoLength = 0;
  fifoInit = 0;
  //Init the R28
  //IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, I_GAIN_SEL * 4, 0);
  Xil_Out32(XPAR_M_AXI_BASEADDR + AFE_CNTRL_REG, 0);
  usleep(100000);
  //IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, I_GAIN_SEL * 4, 0x01010101);
  Xil_Out32(XPAR_M_AXI_BASEADDR + AFE_CNTRL_REG, 0x01010101);
  usleep(100000);
  //IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, I_GAIN_SEL * 4, 0);
  Xil_Out32(XPAR_M_AXI_BASEADDR + AFE_CNTRL_REG, 0x01010101);
  usleep(100000);
  xil_printf("\n\r adcSnapShowProcess (2).\n\r");
  while (1) {
    usleep(5); //10kHz
    if (ConnectionClose == 1) break;

    if (fifoRun == 0) {
      usleep(5);
      currentCalc(0); //if fifo not running, read from raw reg and send current to pscDrv
      if (ConnectionClose == 1) break;
    } else {
      //Init FIFO
      if (fifoInit == 0) {
        //stop trigger
        //IOBUS_mWriteReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, SOFTTRIGREG * 4, 0);
    	Xil_Out32(XPAR_M_AXI_BASEADDR + FA_SOFT_TRIG_REG, 0);
        //reset FIFO
        //IOBUS_mWriteReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, FIFOCNTRLREG * 4, 0x1);
    	Xil_Out32(XPAR_M_AXI_BASEADDR + FA_FIFO_RST_REG, 1);
        usleep(100);
        //IOBUS_mWriteReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, FIFOCNTRLREG * 4, 0);
    	Xil_Out32(XPAR_M_AXI_BASEADDR + FA_FIFO_RST_REG, 0);
        //softTrigger
        //IOBUS_mWriteReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, SOFTTRIGREG * 4, 0x1);
    	Xil_Out32(XPAR_M_AXI_BASEADDR + FA_SOFT_TRIG_REG, 1);
        usleep(1);
        //IOBUS_mWriteReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, SOFTTRIGREG * 4, 0);
    	Xil_Out32(XPAR_M_AXI_BASEADDR + FA_SOFT_TRIG_REG, 0);
        //wait for FIFO to run
        while ((Xil_In32(XPAR_M_AXI_BASEADDR + FA_SOFT_TRIG_REG) & 0x1) == 0) usleep(10);
        xil_printf("FIFO Running...\n\r");
        fifoLength = 0;
        //while (fifoLength < 100) fifoLength = IOBUS_mReadReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, FIFOWDCNTREG * 4);
        fifoInit = 1;
        fifoIndex = 0;
      }
      //read one block (16 words)
      for (j = 0; j < 16; j++) {
        fifoData = 0; //IOBUS_mReadReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, FIFODATAREG * 4);
        if ((j > 3) && (j < 8)) adcFifo[j - 4] = fifoData;
        fifoIndex++;
      }
      currentCalc(1);
      if (fifoIndex > (fifoLength - 20)) {
        fifoLength = 0;
        while ((fifoLength < 100) && (fifoRun == 1)) fifoLength = 0; //IOBUS_mReadReg(XPAR_IOBUS_1_S00_AXI_BASEADDR, FIFOWDCNTREG * 4);
        fifoIndex = 0;
      }
    }

    if (rxBuf[QUAD_PSC_SEL * 4 + 3] == 1) {
      adcTxBuf[0] = 'P';
      adcTxBuf[1] = 'S';
      //msgID=16
      adcTxBuf[2] = 0x0;
      adcTxBuf[3] = 0x10;
      adcTxBuf[4] = 0x0;
      adcTxBuf[5] = 0x00;
      adcTxBuf[6] = 0x00;
      adcTxBuf[7] = 0x28;
      pscSel = 8;
    } else {
      pscSel = 0;
      usleep(1);
    }
    //assembly the TX data
    for (i = 0; i < 4; i++) {
      current_double[i] = (double) current[i];
      u.d = current_double[i];
      adcTxBuf[pscSel + i * 8] = u.bytes[7];
      adcTxBuf[pscSel + 1 + i * 8] = u.bytes[6];
      adcTxBuf[pscSel + 2 + i * 8] = u.bytes[5];
      adcTxBuf[pscSel + 3 + i * 8] = u.bytes[4];
      adcTxBuf[pscSel + 4 + i * 8] = u.bytes[3];
      adcTxBuf[pscSel + 5 + i * 8] = u.bytes[2];
      adcTxBuf[pscSel + 6 + i * 8] = u.bytes[1];
      adcTxBuf[pscSel + 7 + i * 8] = u.bytes[0];
    }
    /*last word is NAN: FFF4 0002 FFFF FFFF for QuadEM */
    adcTxBuf[32 + pscSel] = 0xFF;
    adcTxBuf[33 + pscSel] = 0xF4;
    adcTxBuf[34 + pscSel] = 0x00;
    adcTxBuf[35 + pscSel] = 0x02;
    adcTxBuf[36 + pscSel] = 0xFF;
    adcTxBuf[37 + pscSel] = 0xFF;
    adcTxBuf[38 + pscSel] = 0xFF;
    adcTxBuf[39 + pscSel] = 0xFF;

    if (ConnectionClose != 1) {
      if ((rxBuf[QUAD_SYN * 4 + 3] == 0) && (pscSel == 0)) sleep(0.5);
      else {
        if (lwip_writeall(sd, adcTxBuf, (DATA_10KHZ_SIZE_BYTE + pscSel)) != (DATA_10KHZ_SIZE_BYTE + pscSel)) {
          xil_printf("\n\rClosing adcTX socket (2). %d\n\r", sd);
          ConnectionClose = 1;
          close(sd);
          vTaskDelete(NULL);
          return;
        }
      }
    } else {
      ConnectionClose = 1;
      close(sd);
      vTaskDelete(NULL);
      return;
    }
  }
  /* close connection */
  ConnectionClose = 1;
  close(sd);
  xil_printf("\n\rClosing adc process (2). \n\r");
  vTaskDelete(NULL);
}

//OPT
void applicationThread(int mode) {
  int sock, new_sd;
  int size;
  struct sockaddr_in address, remote;
  memset( & address, 0, sizeof(address));
  if ((sock = lwip_socket(AF_INET, SOCK_STREAM, 0)) < 0) return;
  address.sin_family = AF_INET;
  if (mode == 1) address.sin_port = htons(cmdStsPort);
  else if (mode == 2) address.sin_port = htons(adcPort);
  else { xil_printf("\nError Mode=%d\n", mode); return; }
  address.sin_addr.s_addr = INADDR_ANY;
  if (lwip_bind(sock, (struct sockaddr * ) & address, sizeof(address)) < 0) return;
  lwip_listen(sock, 0);
  size = sizeof(remote);
  while (1) {
    if (mode == 1) {
      if ((new_sd = lwip_accept(sock, (struct sockaddr * ) & remote, (socklen_t * ) & size)) > 0) {
        ConnectionClose = 0;
        //clost config thread
        netConfig = 1;
        sys_thread_new("cmdStatssProcess", cmdProcess, (void * ) new_sd, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
      }
    } else if (mode == 2) {
      if ((new_sd = lwip_accept(sock, (struct sockaddr * ) & remote, (socklen_t * ) & size)) > 0) {
        ConnectionClose = 0;
        //clost config thread
        netConfig = 1;
        sys_thread_new("adcWaveformProcess", adcSnapShowProcess, (void * ) new_sd, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
      }
    } else {
      xil_printf("Wrong Mode=%d\n", mode);
      return;
    }
  }
}

//calculat current: mode=0 to use raw data; mode=1 to use FA data
void currentCalc(int mode) {
	  int i;
	  int chanOffset, offsetWordLocation, gainWordLocation;
	  char gainSel;
	  float rangeF;
	  unsigned int offsetReg, gainReg, currentADCReg, word;
	  float offset, gain, currentADC;
	  union Int_Byte {int d; char bytes[sizeof(float)];} u1;
	  union F_Byte {float d; char bytes[sizeof(float)];} u;
	  for (i = 0; i < 4; i++) { //chan A, B, C, D
	    chanOffset = 48 * i;
	    gainSel = rxBuf[115 - i]; //MSB is low byte
	    if (gainSel == 0) rangeF = 10.0E+3; //10mA
	    else if (gainSel == 1) rangeF = 1.0E+3; //1mA
	    else if (gainSel == 2) rangeF = 100.0; //100uA
	    else if (gainSel == 3) rangeF = 10.0; //10uA
	    else if (gainSel == 4) rangeF = 1.0; //1uA
	    else if (gainSel == 5) rangeF = 0.1; //100nA
	    else rangeF = 10.0E-3;

	    offsetWordLocation = 140 + 12 * i + gainSel;
	    gainWordLocation = 146 + 12 * i + gainSel;
	    offsetReg = (rxBuf[offsetWordLocation * 4] << 24) + (rxBuf[offsetWordLocation * 4 + 1] << 16) +
	      (rxBuf[offsetWordLocation * 4 + 2] << 8) + rxBuf[offsetWordLocation * 4 + 3];
	    gainReg = (rxBuf[gainWordLocation * 4] << 24) + (rxBuf[gainWordLocation * 4 + 1] << 16) +
	      (rxBuf[gainWordLocation * 4 + 2] << 8) + rxBuf[gainWordLocation * 4 + 3];
	    currentADCReg = Xil_In32(XPAR_M_AXI_BASEADDR + ADCRAW_CHA_REG + i);

	    word = offsetReg;
	    u1.bytes[3] = (word & 0xFF000000) >> 24;  u1.bytes[2] = (word & 0x00FF0000) >> 16;
	    u1.bytes[1] = (word & 0x0000FF00) >> 8;   u1.bytes[0] = (word & 0x000000FF);
	    offset = u1.d;

	    word = gainReg;
	    u1.bytes[3] = (word & 0xFF000000) >> 24;  u1.bytes[2] = (word & 0x00FF0000) >> 16;
	    u1.bytes[1] = (word & 0x0000FF00) >> 8;   u1.bytes[0] = (word & 0x000000FF);
	    gain = u1.d;

	    if(mode==0) word = currentADCReg; else word = adcFifo[i];
	    u1.bytes[3] = (word & 0xFF000000) >> 24;  u1.bytes[2] = (word & 0x00FF0000) >> 16;
	    u1.bytes[1] = (word & 0x0000FF00) >> 8;   u1.bytes[0] = (word & 0x000000FF);
	    currentADC = u1.d;

	    current[i] = currentADC * 1.0;
	    current[i] = (((float) currentADC - (float) offset) / (float) gain) * rangeF;
	    u.d = current[i];
	    txBuf[8 + CURRENT_FLOAT_TX_REG*4 + i * 4] = u.bytes[3];   txBuf[9 + CURRENT_FLOAT_TX_REG*4 + i * 4] = u.bytes[2];
	    txBuf[10 + CURRENT_FLOAT_TX_REG*4 + i * 4] = u.bytes[1];  txBuf[11 + CURRENT_FLOAT_TX_REG*4 + i * 4] = u.bytes[0];
	  }
	  return;
}

void verifyMAC() {
	int verify=0;
	int validInput=0;
    while (verify == 0) {
      if (netConfig == 1) break;
      xil_printf("\n\rPlease input the MAC address in HEX format...\r\n");
      setvbuf(stdin, NULL, _IONBF, 0);
      if ((scanf("%x %x %x %x %x %x", & MAC[0],& MAC[1],& MAC[2],& MAC[3],& MAC[4],& MAC[5]) != 6)) {
        xil_printf("!!!!!! Wrong input. Please try again. \n\r");
        validInput=0;
        verify=0;
      }
      else validInput=1;
      if(validInput==1) {
      xil_printf("------ Set MAC to: 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x\n\r", MAC[0],MAC[1],MAC[2],MAC[3],MAC[4],MAC[5]);
      xil_printf("Please verify MAC setting is correct: 1=Yes 0=No and retry.\r\n");
      setvbuf(stdin, NULL, _IONBF, 0);
      scanf("%d", & verify);
      if((verify!=0)&&(verify!=1)) verify=0;
      }
    }
    return;
}

void verifyIP(int type,char IPType[]){
	int verify=0;
	int inputValid=0;
	char ip4[4];
	if(type==1) memcpy(ip4, IP, 4*sizeof(char));
	else if(type==2) memcpy(ip4, MSK, 4*sizeof(char));
	else if(type==3) memcpy(ip4, GW, 4*sizeof(char));
	else {xil_printf("!!!!wrong type\n\r"); return;}


    while (verify == 0) {
      if (netConfig == 1) break;
      xil_printf("\n\rPlease input the %s in decimal format...\r\n",IPType);
      setvbuf(stdin, NULL, _IONBF, 0);
      if (scanf("%d %d %d %d", & ip4[0],& ip4[1],& ip4[2],& ip4[3])!= 4) {
        xil_printf("!!!!!! Wrong input. Please try again. \n\r");
        inputValid=0;
        verify=0;
      }
      else inputValid=1;
      if(inputValid==1) {
    	  xil_printf("------ Set %s to: %d.%d.%d.%d\n\r",IPType, ip4[0],ip4[1],ip4[2],ip4[3]);
      xil_printf("Please verify the %s setting is correct: 1=Yes 0=No and retry.\r\n",IPType);
      setvbuf(stdin, NULL, _IONBF, 0);
      scanf("%d", & verify);
      if((verify!=0)&&(verify!=1)) verify=0;
      }
    }
	//input confirmed
	if(type==1) memcpy(IP,ip4, 4*sizeof(char));
	else if(type==2) memcpy(MSK,ip4, 4*sizeof(char));
	else if(type==3) memcpy(GW,ip4, 4*sizeof(char));
	else {xil_printf("!!!!wrong type\n\r"); return;}
    return;
}

int netConfigProcess() {
  static int n = 0;
  unsigned int word;
  //xil_printf("\n\r netConfigProcess(3) \n\r");
  netConfig = 0;
  int confirm = 0;
  int confirmAll = 0;
  int Count;
  int validInput=0;

  while (1) {
    vTaskDelay(500 / portTICK_RATE_MS);
    usleep(8000000);
    if (netConfig == 1) break;
    else {
      while (confirmAll == 0) {
        if (netConfig == 1) break;
        verifyMAC();
        confirm = 0;
        verifyIP(1,"IP");
        confirm = 0;
        verifyIP(2,"Netmask");
        confirm = 0;
        verifyIP(3,"Gateway");
        confirm = 0;
        while (confirmAll == 0) {
          if (netConfig == 1) break;
          xil_printf("MAC: %x %x %x %x %x %x\n\r", MAC[0],MAC[1],MAC[2],MAC[3],MAC[4],MAC[5]);
          xil_printf("IP: %d.%d.%d.%d\n\r", IP[0],IP[1],IP[2],IP[3]);
          xil_printf("Netmask: %d.%d.%d.%d\n\r", MSK[0],MSK[1],MSK[2],MSK[3]);
          xil_printf("Gateway: %d.%d.%d.%d\n\r", GW[0],GW[1],GW[2],GW[3]);
          xil_printf("Please confirm the above network settings are correct: 1=Yes 0=No and retry.\n\r");
          setvbuf(stdin, NULL, _IONBF, 0);
          scanf("%d", & confirmAll);
          if((confirmAll!=0)&&(confirmAll!=1)) confirmAll=0;
        }
      }
      MacIPSetup(1);
      MacIPSetup(0);
      xil_printf("\n\rNetwork settings have changed. Please reboot to take effect.\n\r");
      vTaskDelete(NULL);
      break;
    }
  }
  xil_printf("\n\r Closing netConfigProcess (3). \n\r");
  vTaskDelete(NULL);
}

//set DAC's range
void DAC_Init()
{
	//Turn on DAC output
	//IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, REG_DAC_DATA * 4, 0x10001F);
	Xil_Out32(XPAR_M_AXI_BASEADDR + FDBK_DAC_DATA_REG, 0x10001F);
	usleep(1000);
	//Range: -10V to 10V
	//IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, REG_DAC_DATA * 4, 0x0C0004);
	Xil_Out32(XPAR_M_AXI_BASEADDR + FDBK_DAC_DATA_REG, 0x10001F);
	usleep(1000);
	//Input from ARM
	//IOBUS_mWriteReg(XPAR_IOBUS_0_S00_AXI_BASEADDR, REG_DAC_OP_MODE * 4, 0);
	Xil_Out32(XPAR_M_AXI_BASEADDR + FDBK_DAC_OPMODE_REG, 0);
}
