/********************************************************************
*  PSC Status Thread
*  J. Mead
*  4-17-24
*
*  This thread is responsible for sending all slow data (10Hz) to the IOC.   It does
*  this over to message ID's (30 = slow status, 31 = 10Hz data)
*
*  It starts a listening server on
*  port 600.  Upon establishing a connection with a client, it begins to send out
*  packets containing all 10Hz updated data.
********************************************************************/

#include <stdio.h>
#include <string.h>
#include <sleep.h>
#include "xiicps.h"


#include "lwip/sockets.h"
#include "netif/xadapter.h"
#include "lwipopts.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "task.h"

/* Hardware support includes */
#include "zubpm_defs.h"
#include "pl_regs.h"
#include "psc_msg.h"


#define PORT  600

extern XIicPs IicPsInstance;

extern u32 UptimeCounter;



float power(float base, int exponent) {
    float result = 1.0;
    int i;

    // Handle negative exponents by inverting the base and using positive exponent
    if (exponent < 0) {
        base = 1.0 / base;
        exponent = -exponent;
    }
    for (i = 0; i < exponent; i++) {
        result *= base;
    }
    return result;
}






void i2c_ltc2977_stats(struct SysHealthMsg *p) {

	const u8 I2C_ADDR = 0x5C;
	const u8 TEMP_REG = 0x8D;
	const s32 TXLEN = 1;
	const s32 RXLEN = 2;

	u8 txBuf[] = {TEMP_REG};
	u8 rxBuf[] = {0,0};
	u32 res;


	i2c_set_port_expander(I2C_PORTEXP0_ADDR,0);
	i2c_set_port_expander(I2C_PORTEXP1_ADDR,8);

    // The LTC2977 requires a repeated start i2c transaction
    while (XIicPs_BusIsBusy(&IicPsInstance)); //Make sure bus is not busy
    XIicPs_SetOptions(&IicPsInstance, XIICPS_REP_START_OPTION);
    //write the command address

    XIicPs_MasterSendPolled(&IicPsInstance, txBuf, TXLEN, I2C_ADDR);
    XIicPs_ClearOptions(&IicPsInstance, XIICPS_REP_START_OPTION);
    //read the register
    XIicPs_MasterRecvPolled(&IicPsInstance, rxBuf, RXLEN, I2C_ADDR);



}




void i2c_sfp_get_stats(struct SysHealthMsg *p, u8 sfp_slot) {

	const float TEMP_SCALE = 256;   //Temp is a 16bit signed 2's comp integer in increments of 1/256 degree C
	const float VCC_SCALE = 10000;  //VCC is a 16bit unsigned int in increments of 100uV
	const float TXBIAS_SCALE = 2000; //TxBias is a 16 bit unsigned integer in increments of 2uA
	const float PWR_SCALE = 10000;  //Tx and Rx Pwr is 16 bit unsigned integer in increments of 0.1uW

	s32 status;
    u8 addr = 0x51;  //SFP A2 address space
    u8 txBuf[3] = {96};
    u8 rxBuf[10] = {0,0,0,0,0,0,0,0,0,0};

	i2c_set_port_expander(I2C_PORTEXP0_ADDR,(1 << sfp_slot));
	i2c_set_port_expander(I2C_PORTEXP1_ADDR,0);
	//read 10 bytes starting at address 96 (see data sheet)
    i2c_write(txBuf,1,addr);
    status = i2c_read(rxBuf,10,addr);
    if (status != XST_SUCCESS) {
    	//No SFP module was found, read error, set all values to zero
    	p->sfp_temp[sfp_slot] = 0;
        p->sfp_vcc[sfp_slot] = 0;
        p->sfp_txbias[sfp_slot] = 0;
        p->sfp_txpwr[sfp_slot] = 0;
        p->sfp_rxpwr[sfp_slot] = 0;
    }
    else {
    	p->sfp_temp[sfp_slot]   = (float) ((rxBuf[0] << 8) | (rxBuf[1])) / TEMP_SCALE;
    	p->sfp_vcc[sfp_slot]    = (float) ((rxBuf[2] << 8) | (rxBuf[3])) / VCC_SCALE;
    	p->sfp_txbias[sfp_slot] = (float) ((rxBuf[4] << 8) | (rxBuf[5])) / TXBIAS_SCALE;
    	p->sfp_txpwr[sfp_slot]  = (float) ((rxBuf[6] << 8) | (rxBuf[7])) / PWR_SCALE;
    	p->sfp_rxpwr[sfp_slot]  = (float) ((rxBuf[8] << 8) | (rxBuf[9])) / PWR_SCALE;
    }
   /*
    xil_printf("SFP Slot : %d\r\n",sfp_slot);
    printf("SFP Temp = %f\r\n", p->sfp_temp[sfp_slot]);
    printf("SFP VCC = %f\r\n", p->sfp_vcc[sfp_slot]);
    printf("SFP txbias = %f\r\n", p->sfp_txbias[sfp_slot]);
    printf("SFP Tx Pwr = %f\r\n", p->sfp_txpwr[sfp_slot]);
    printf("SFP Rx Pwr = %f\r\n", p->sfp_rxpwr[sfp_slot]);
    xil_printf("\r\n");
    */

}





void Host2NetworkConvStatus(char *inbuf, int len) {

    int i;
    u8 temp;
    //Swap bytes to reverse the order within the 4-byte segment
    //Start at byte 8 (skip the PSC Header)
    for (i=8;i<len;i=i+4) {
    	temp = inbuf[i];
    	inbuf[i] = inbuf[i + 3];
    	inbuf[i + 3] = temp;
    	temp = inbuf[i + 1];
    	inbuf[i + 1] = inbuf[i + 2];
    	inbuf[i + 2] = temp;
    }

}





void ReadGenRegs(char *msg) {

    u32 *msg_u32ptr;
    struct StatusMsg status;
    u32 dmastatus;
    //char  *msg_ptr;

    //write the PSC header
    msg_u32ptr = (u32 *)msg;
    msg[0] = 'P';
    msg[1] = 'S';
    msg[2] = 0;
    msg[3] = (short int) MSGID30;
    *++msg_u32ptr = htonl(MSGID30LEN); //body length

    status.cha_gain = Xil_In32(XPAR_M_AXI_BASEADDR + CHA_GAIN_REG);
    status.chb_gain = Xil_In32(XPAR_M_AXI_BASEADDR + CHB_GAIN_REG);
    status.chc_gain = Xil_In32(XPAR_M_AXI_BASEADDR + CHC_GAIN_REG);
    status.chd_gain = Xil_In32(XPAR_M_AXI_BASEADDR + CHD_GAIN_REG);

    status.kx = Xil_In32(XPAR_M_AXI_BASEADDR + KX_REG);
    status.ky = Xil_In32(XPAR_M_AXI_BASEADDR + KY_REG);



    status.trig_eventno = Xil_In32(XPAR_M_AXI_BASEADDR + EVR_TRIGNUM_REG);
    status.evr_ts_s_triglat = Xil_In32(XPAR_M_AXI_BASEADDR + EVR_TS_S_LAT_REG);
    status.evr_ts_ns_triglat = Xil_In32(XPAR_M_AXI_BASEADDR + EVR_TS_NS_LAT_REG);
    //status.trigtobeam_thresh = Xil_In32(XPAR_M_AXI_BASEADDR + TRIGTOBEAM_THRESH_REG);
    //status.trigtobeam_dly = Xil_In32(XPAR_M_AXI_BASEADDR + TRIGTOBEAM_DLY_REG);

    //xil_printf("Trig TS_S: %d\r\n",status.evr_ts_s_triglat);
    //xil_printf("Trig TS_NS: %d\r\n",status.evr_ts_ns_triglat);

    //print DMA status
    //xil_printf("DMA Status : %x\r\n",Xil_In32(XPAR_M_AXI_BASEADDR + DMA_STATUS_REG));

    //copy the structure to the PSC msg buffer
    memcpy(&msg[MSGHDRLEN],&status,sizeof(status));

}




void ReadPosRegs(char *msg) {

    u32 *msg_u32ptr;
    //char  *msg_ptr;
    struct SAdataMsg SAdata;

    //write the PSC header
    msg_u32ptr = (u32 *)msg;
    msg[0] = 'P';
    msg[1] = 'S';
    msg[2] = 0;
    msg[3] = (short int) MSGID31;
    *++msg_u32ptr = htonl(MSGID31LEN); //body length

    //write the PSC message structure
    SAdata.count     = Xil_In32(XPAR_M_AXI_BASEADDR + SA_TRIGNUM_REG);
    SAdata.evr_ts_s  = Xil_In32(XPAR_M_AXI_BASEADDR + EVR_TS_S_REG);
    SAdata.evr_ts_ns = Xil_In32(XPAR_M_AXI_BASEADDR + EVR_TS_NS_REG);
    SAdata.cha_mag   = Xil_In32(XPAR_M_AXI_BASEADDR + SA_CHAMAG_REG);
    SAdata.chb_mag   = Xil_In32(XPAR_M_AXI_BASEADDR + SA_CHBMAG_REG);
    SAdata.chc_mag   = Xil_In32(XPAR_M_AXI_BASEADDR + SA_CHCMAG_REG);
    SAdata.chd_mag   = Xil_In32(XPAR_M_AXI_BASEADDR + SA_CHDMAG_REG);
    SAdata.sum       = Xil_In32(XPAR_M_AXI_BASEADDR + SA_SUM_REG);
    SAdata.xpos_nm   = Xil_In32(XPAR_M_AXI_BASEADDR + SA_XPOS_REG);
    SAdata.ypos_nm   = Xil_In32(XPAR_M_AXI_BASEADDR + SA_YPOS_REG);

    //xil_printf("TS_S: %d\r\n",SAdata.evr_ts_s);
    //xil_printf("TS_NS: %d\r\n",SAdata.evr_ts_ns);
    //copy the structure to the PSC msg buffer
    memcpy(&msg[MSGHDRLEN],&SAdata,sizeof(SAdata));





}


void ReadSysInfo(char *msg) {

    u32 *msg_u32ptr;
    u8 i;
    float temp1, temp2;
    struct SysHealthMsg syshealth;

    //write the PSC header
    msg_u32ptr = (u32 *)msg;
    msg[0] = 'P';
    msg[1] = 'S';
    msg[2] = 0;
    msg[3] = (short int) MSGID32;
    *++msg_u32ptr = htonl(MSGID32LEN); //body length

    //write the PSC message

    //read FPGA version (git checksum) from PL register
    syshealth.git_shasum = Xil_In32(XPAR_M_AXI_BASEADDR + GIT_SHASUM);

    //read DFE temperature from i2c bus
    i2c_set_port_expander(I2C_PORTEXP1_ADDR,1);
    syshealth.dfe_temp[0] = read_i2c_temp(BRDTEMP0_ADDR);
    syshealth.dfe_temp[1] = read_i2c_temp(BRDTEMP1_ADDR);
    syshealth.dfe_temp[2] = read_i2c_temp(BRDTEMP2_ADDR);
    syshealth.dfe_temp[3] = read_i2c_temp(BRDTEMP3_ADDR);

    //read AFE temperature from i2c bus
    i2c_set_port_expander(I2C_PORTEXP1_ADDR,0x40);
    syshealth.afe_temp[0] = read_i2c_temp(BRDTEMP0_ADDR);
    syshealth.afe_temp[1] = read_i2c_temp(BRDTEMP2_ADDR);



    //read voltage & currents from LTC2991 chips
	i2c_set_port_expander(I2C_PORTEXP1_ADDR,4);
	i2c_configure_ltc2991();
    syshealth.vin_v = i2c_ltc2991_vcc_vin();
    syshealth.vin_i = i2c_ltc2991_vcc_vin_current();
    syshealth.v3_3_v = i2c_ltc2991_vcc_3v3();
    syshealth.v3_3_i = i2c_ltc2991_vcc_3v3_current();
    syshealth.v2_5_v = i2c_ltc2991_vcc_2v5();
    syshealth.v2_5_i = i2c_ltc2991_vcc_2v5_current();
    syshealth.v1_8_v = i2c_ltc2991_vcc_1v8();
    syshealth.v1_8_i = i2c_ltc2991_vcc_1v8_current();
    syshealth.v1_2ddr_v = i2c_ltc2991_vcc_1v2_ddr();
    syshealth.v1_2ddr_i = i2c_ltc2991_vcc_1v2_ddr_current();
    syshealth.v0_85_v = i2c_ltc2991_vcc_0v85();
    syshealth.v0_85_i = i2c_ltc2991_vcc_0v85_current();
    syshealth.v2_5mgt_v = i2c_ltc2991_vcc_mgt_2v5();
    syshealth.v2_5mgt_i = i2c_ltc2991_vcc_mgt_2v5_current();
    syshealth.v1_2mgt_v = i2c_ltc2991_vcc_mgt_1v2();
    syshealth.v1_2mgt_i = i2c_ltc2991_vcc_mgt_1v2_current();
    syshealth.v0_9mgt_v = i2c_ltc2991_vcc_mgt_0v9();
    syshealth.v0_9mgt_i =  i2c_ltc2991_vcc_mgt_0v9_current();
    syshealth.reg_temp[0] = i2c_ltc2991_reg1_temp();
    syshealth.reg_temp[1] = i2c_ltc2991_reg2_temp();
    syshealth.reg_temp[2] = i2c_ltc2991_reg3_temp();

    // read SFP status information from i2c bus
    for (i=0;i<=5;i++)
       i2c_sfp_get_stats(&syshealth, i);

    // Read power management info from i2c bus
    i2c_ltc2977_stats(&syshealth);


    // Read the Uptime counter
    syshealth.uptime = UptimeCounter;
    //xil_printf("Uptime: %d\r\n",UptimeCounter);

    //copy the syshealth structure to the PSC msg buffer
    memcpy(&msg[MSGHDRLEN],&syshealth,sizeof(syshealth));

}



void psc_status_thread()
{

	int sockfd, newsockfd;
	int clilen;
	struct sockaddr_in serv_addr, cli_addr;
    int n,loop=0;
    int sa_trigwait, sa_cnt=0, sa_cnt_prev=0;



    xil_printf("Starting PSC Status Server...\r\n");

	// Initialize socket structure
	memset(&serv_addr, 0, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(PORT);
	serv_addr.sin_addr.s_addr = INADDR_ANY;

    // First call to socket() function
	if ((sockfd = lwip_socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		xil_printf("Error: PSC Status : Creating Socket");
	}


    // Bind to the host address using bind()
	if (lwip_bind(sockfd, (struct sockaddr *)&serv_addr, sizeof (serv_addr)) < 0) {
		xil_printf("Error: PSC Status : Creating Socket");
		//vTaskDelete(NULL);
	}


    // Now start listening for the clients
	lwip_listen(sockfd, 0);


    xil_printf("PSC Status Server listening on port %d...\r\n",PORT);


reconnect:

	clilen = sizeof(cli_addr);

	newsockfd = lwip_accept(sockfd, (struct sockaddr *)&cli_addr, (socklen_t *)&clilen);
	if (newsockfd < 0) {
	    xil_printf("PSC Status: ERROR on accept\r\n");
	}
	/* If connection is established then start communicating */
	xil_printf("PSC Status: Connected Accepted...\r\n");




	while (1) {

		//xil_printf("In Status main loop...\r\n");

		//loop here until next 10Hz event
		do {
		   sa_trigwait++;
		   sa_cnt = Xil_In32(XPAR_M_AXI_BASEADDR + SA_TRIGNUM_REG);
		   //xil_printf("SA CNT: %d    %d\r\n",sa_cnt, sa_cnt_prev);
		   vTaskDelay(pdMS_TO_TICKS(10));
		}
	    while (sa_cnt_prev == sa_cnt);
		sa_cnt_prev = sa_cnt;


        ReadGenRegs(msgid30_buf);
        //write 10Hz msg30 packet
	    Host2NetworkConvStatus(msgid30_buf,sizeof(msgid30_buf)+MSGHDRLEN);
	    n = write(newsockfd,msgid30_buf,MSGID30LEN+MSGHDRLEN);
        if (n < 0) {
           printf("Status socket: ERROR writing MSG 30 - 10Hz Info\n");
           close(newsockfd);
           goto reconnect;
        }



        ReadPosRegs(msgid31_buf);
        //write 10Hz msg31 packet
        Host2NetworkConvStatus(msgid31_buf,sizeof(msgid31_buf)+MSGHDRLEN);
	    n = write(newsockfd,msgid31_buf,MSGID31LEN+MSGHDRLEN);
        if (n < 0) {
          printf("Status socket: ERROR writing MSG 31 - Pos Info\n");
          close(newsockfd);
          goto reconnect;
        }


        // Update Slow status information at 1Hz
    	if ((loop % 10) == 0) {
           //printf("Reading Sys Info\n");
           ReadSysInfo(msgid32_buf);
    	   Host2NetworkConvStatus(msgid32_buf,sizeof(msgid32_buf)+MSGHDRLEN);
    	    //for(i=0;i<160;i=i+4)
              //    printf("%d: %d  %d  %d  %d\n",i-8,msgid32_buf[i], msgid32_buf[i+1],
              //		                msgid32_buf[i+2], msgid32_buf[i+3]);
           n = write(newsockfd,msgid32_buf,MSGID32LEN+MSGHDRLEN);
           if (n < 0) {
              printf("Status socket: ERROR writing MSG 32 - System Info\n");
              close(newsockfd);
              goto reconnect;
            }
    	}

		loop++;



	}

	/* close connection */
	close(newsockfd);
	vTaskDelete(NULL);
}


