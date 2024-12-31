
#include <stdio.h>
#include <string.h>
#include <sleep.h>
#include "xil_cache.h"

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





#define PORT  7



void set_fpleds(u32 msgVal)  {
	Xil_Out32(XPAR_M_AXI_BASEADDR + FP_LEDS_REG, msgVal);
}


void soft_trig(u32 msgVal) {
	Xil_Out32(XPAR_M_AXI_BASEADDR + DMA_SOFTTRIG_REG, msgVal);
}

void set_atten(u32 msgVal) {
    xil_printf("Setting RF attenuator to %d dB\r\n",msgVal);
    Xil_Out32(XPAR_M_AXI_BASEADDR + RF_DSA_REG, msgVal*4);
}

void set_geo_dly(u32 msgVal) {
    // the Geo delay is the same as tbt_gate delay, set them both for now
	Xil_Out32(XPAR_M_AXI_BASEADDR + FINE_TRIG_DLY_REG, msgVal);
	Xil_Out32(XPAR_M_AXI_BASEADDR + TBT_GATEDLY_REG, msgVal);
}


void set_coarse_dly(u32 msgVal) {
	Xil_Out32(XPAR_M_AXI_BASEADDR + COARSE_TRIG_DLY_REG, msgVal);
}



void set_trigtobeam_thresh(int msgVal) {
	Xil_Out32(XPAR_M_AXI_BASEADDR + TRIGTOBEAM_THRESH_REG, msgVal);
}


void set_eventno(u32 msgVal) {
	Xil_Out32(XPAR_M_AXI_BASEADDR + EVR_DMA_TRIGNUM_REG, msgVal);
}

void set_trigsrc(u32 msgVal) {
    if (msgVal == 0) {
        xil_printf("Setting Trigger Source to EVR\r\n");
        Xil_Out32(XPAR_M_AXI_BASEADDR + DMA_TRIGSRC_REG, msgVal);
    }
    else if (msgVal == 1) {
	    xil_printf("Setting Trigger Source to INT (soft)\r\n");
        Xil_Out32(XPAR_M_AXI_BASEADDR + DMA_TRIGSRC_REG, msgVal);
    }
    else
        xil_printf("Invalid Trigger Source\r\n");

}



void set_kxky(u32 axis, u32 msgVal) {

    if (axis == HOR)	{
       xil_printf("Setting Kx to %d nm\r\n",msgVal);
       Xil_Out32(XPAR_M_AXI_BASEADDR + KX_REG, msgVal);
    }
    else {
       xil_printf("Setting Ky to %d nm\r\n",msgVal);
       Xil_Out32(XPAR_M_AXI_BASEADDR + KY_REG, msgVal);

    }
}


void set_bbaoffset(u32 axis, u32 msgVal) {

    if (axis == HOR)	{
       xil_printf("Setting BBA X to %d nm\r\n",msgVal);
       Xil_Out32(XPAR_M_AXI_BASEADDR + BBA_XOFF_REG, msgVal);

    }
    else {
       xil_printf("Setting BBA Y to %d nm\r\n",msgVal);
       Xil_Out32(XPAR_M_AXI_BASEADDR + BBA_YOFF_REG, msgVal);
    }
}

void set_dmalen(u32 channel, u32 msgVal) {

  switch(channel) {
    case ADC:
       Xil_Out32(XPAR_M_AXI_BASEADDR + DMA_ADCBURSTLEN_REG, msgVal);
       xil_printf("Setting ADC DMA length to %d\r\n",msgVal);
	   break;
	case TBT:
	   Xil_Out32(XPAR_M_AXI_BASEADDR + DMA_TBTBURSTLEN_REG, msgVal);
       xil_printf("Setting TBT DMA length to %d\r\n",msgVal);
	   break;
    case FA:
       Xil_Out32(XPAR_M_AXI_BASEADDR + DMA_FABURSTLEN_REG, msgVal);
       xil_printf("Setting FA DMA length to %d\r\n",msgVal);
	   break;
    default:
       xil_printf("Invalid channel number\r\n");
	   break;
    }


}





void set_gain(u32 channel, u32 msgVal) {

switch(channel) {
    case CHA:
       Xil_Out32(XPAR_M_AXI_BASEADDR + CHA_GAIN_REG, msgVal);
       xil_printf("Setting ChA gain to %d \r\n",msgVal);
	   break;
	case CHB:
	   Xil_Out32(XPAR_M_AXI_BASEADDR + CHB_GAIN_REG, msgVal);
       xil_printf("Setting ChB gain to %d\r\n",msgVal);
	   break;
    case CHC:
       Xil_Out32(XPAR_M_AXI_BASEADDR + CHC_GAIN_REG, msgVal);
       xil_printf("Setting ChC gain to %d\r\n",msgVal);
	   break;
	case CHD:
	   Xil_Out32(XPAR_M_AXI_BASEADDR + CHD_GAIN_REG, msgVal);
       xil_printf("Setting ChD gain to %d\r\n",msgVal);
	   break;
    default:
       xil_printf("Invalid gain channel number\r\n");
	   break;
    }
}





void psc_control_thread()
{
	int sockfd, newsockfd;
	int clilen;
	struct sockaddr_in serv_addr, cli_addr;
	int RECV_BUF_SIZE = 1024;
	char buffer[RECV_BUF_SIZE];
	int n, *bufptr, numpackets=0;
    u32 MsgAddr, MsgData, rdval;
    u32 rdbk, regAddr, regVal;



    xil_printf("Starting PSC Control Server...\r\n");

	// Initialize socket structure
	memset(&serv_addr, 0, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(PORT);
	serv_addr.sin_addr.s_addr = INADDR_ANY;

    // First call to socket() function
	if ((sockfd = lwip_socket(AF_INET, SOCK_STREAM, 0)) < 0)
		xil_printf("PSC Control : Error Creating Socket\r\n");

    // Bind to the host address using bind()
	if (lwip_bind(sockfd, (struct sockaddr *)&serv_addr, sizeof (serv_addr)) < 0)
		xil_printf("PSC Control : Error Creating Socket\r\n");

    // Now start listening for the clients
	lwip_listen(sockfd, 0);


    xil_printf("PSC Control: Server listening on port %d...\r\n",PORT);


reconnect:

	clilen = sizeof(cli_addr);

	newsockfd = lwip_accept(sockfd, (struct sockaddr *)&cli_addr, (socklen_t *)&clilen);
	if (newsockfd < 0) {
	    xil_printf("PSC Control: ERROR on accept\r\n");

	}
	/* If connection is established then start communicating */
	xil_printf("PSC Control: Connected Accepted...\r\n");

	while (1) {
		/* read a max of RECV_BUF_SIZE bytes from socket */
		n = read(newsockfd, buffer, RECV_BUF_SIZE);
        if (n <= 0) {
            xil_printf("PSC Control: ERROR reading from socket..  Reconnecting...\r\n");
            close(newsockfd);
	        goto reconnect;
        }

        bufptr = (int *) buffer;
        xil_printf("\nPacket %d Received : NumBytes = %d\r\n",++numpackets,n);
        xil_printf("Header: %c%c \t",buffer[0],buffer[1]);
        xil_printf("Message ID : %d\t",(ntohl(*bufptr++)&0xFFFF));
        xil_printf("Body Length : %d\t",ntohl(*bufptr++));
        MsgAddr = ntohl(*bufptr++);
        xil_printf("Msg Addr : %d\t",MsgAddr);
	    MsgData = ntohl(*bufptr);
        xil_printf("Data : %d\r\n",MsgData);
        //blink fp_led on message received
        set_fpleds(1);
        set_fpleds(0);


        switch(MsgAddr) {
			case SOFT_TRIG_MSG1:
				xil_printf("Soft Trigger Message:   Value=%d\r\n",MsgData);
                soft_trig(MsgData);
                break;

			case DMA_TRIG_SRC_MSG1:
				xil_printf("Set Trigger Source Message:   Value=%d\r\n",MsgData);
                set_trigsrc(MsgData);
                break;

			case RF_ATTEN_MSG1:
				xil_printf("RF Attenuator Message:   Value=%d\r\n",MsgData);
                set_atten(MsgData);
                break;

			case KX_MSG1:
				xil_printf("Kx Message:   Value=%d\r\n",MsgData);
                set_kxky(HOR,MsgData);
                break;

			case KY_MSG1:
				xil_printf("Ky Message:   Value=%d\r\n",MsgData);
                set_kxky(VERT,MsgData);
                break;

            case BBA_XOFF_MSG1:
            	xil_printf("BBA X Offset:   Value=%d\r\n",MsgData);
            	set_bbaoffset(HOR,MsgData);
                break;

            case BBA_YOFF_MSG1:
            	xil_printf("BBA Y Offset:   Value=%d\r\n",MsgData);
            	set_bbaoffset(VERT,MsgData);
                break;

            case CHA_GAIN_MSG1:
            	xil_printf("ChA Gain Message:   Value=%d\r\n",MsgData);
                set_gain(CHA,MsgData);
                break;

            case CHB_GAIN_MSG1:
            	xil_printf("ChB Gain Message:   Value=%d\r\n",MsgData);
                set_gain(CHB,MsgData);
                break;

            case CHC_GAIN_MSG1:
            	xil_printf("ChC Gain Message:   Value=%d\r\n",MsgData);
                set_gain(CHC,MsgData);
                break;

            case CHD_GAIN_MSG1:
            	xil_printf("ChD Gain Message:   Value=%d\r\n",MsgData);
                set_gain(CHD,MsgData);
                break;

            case FINE_TRIG_DLY_MSG1:
            	xil_printf("Fine Trig Delay Message:   Value=%d\r\n",MsgData);
                //set_geo_dly(MsgData);
                break;

            case COARSE_TRIG_DLY_MSG1:
            	xil_printf("Coarse Trig Delay Message:   Value=%d\r\n",MsgData);
            	//set_coarse_dly(MsgData);
            	break;

            case TRIGTOBEAM_THRESH_MSG1:
            	xil_printf("Trigger to Beam Threshold Message:   Value=%d\r\n",MsgData);
            	//set_trigtobeam_thresh(MsgData);
            	break;


            case EVENT_NO_MSG1:
            	xil_printf("DMA Event Number Message:   Value=%d\r\n",MsgData);
                set_eventno(MsgData);
                break;


            case FP_LED_MSG1:
            	xil_printf("Setting FP LED:   Value=%d\r\n",MsgData);
            	//set_fpleds(MsgData);
            	break;

            case DMA_ADCLEN_MSG1:
            	xil_printf("Setting DMA ADC Length:   Value=%d\r\n",MsgData);
            	set_dmalen(ADC,MsgData);
            	break;

            case DMA_TBTLEN_MSG1:
             	xil_printf("Setting DMA TBT Length:   Value=%d\r\n",MsgData);
             	set_dmalen(TBT,MsgData);
             	break;

            case DMA_FALEN_MSG1:
             	xil_printf("Setting DMA FA Length:   Value=%d\r\n",MsgData);
             	set_dmalen(FA,MsgData);
             	break;

            case EVENT_SRC_SEL_MSG1:
              	xil_printf("Setting Event Source:   Value=%d\r\n",MsgData);
              	Xil_Out32(XPAR_M_AXI_BASEADDR + EVENT_SRC_SEL_REG, MsgData);
              	break;

            case ADC_IDLY_MSG1:
            	xil_printf("Setting ADC IDLY:  Value=%d\r\n",MsgData);
            	Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_IDLYWVAL_REG, MsgData);
            	//strobe the idly value into all 16 idly registers
            	Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_IDLYSTR_REG, 0xFFFF);
            	Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_IDLYSTR_REG, 0);
            	usleep(10);
            	rdval = Xil_In32(XPAR_M_AXI_BASEADDR + ADC_IDLYCHARVAL_REG);
            	xil_printf("ChA IDLY rval=%d\r\n",rdval);
            	rdval = Xil_In32(XPAR_M_AXI_BASEADDR + ADC_IDLYCHBRVAL_REG);
            	xil_printf("ChB IDLY rval=%d\r\n",rdval);
            	rdval = Xil_In32(XPAR_M_AXI_BASEADDR + ADC_IDLYCHCRVAL_REG);
            	xil_printf("ChC IDLY rval=%d\r\n",rdval);
            	rdval = Xil_In32(XPAR_M_AXI_BASEADDR + ADC_IDLYCHDRVAL_REG);
            	xil_printf("ChD IDLY rval=%d\r\n",rdval);
           	    break;


            case ADC_MMCM0_MSG1:
            	if (MsgData == 1) {
            		xil_printf("Setting ADC0 MMCM FCO Delay\r\n");
            	    Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_FCOMMCM_REG, 1);
            	    Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_FCOMMCM_REG, 0);
            	}
                break;

            case ADC_MMCM1_MSG1:
            	if (MsgData == 1) {
            		xil_printf("Setting ADC1 MMCM FCO Delay\r\n");
            	    Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_FCOMMCM_REG, 2);
            	    Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_FCOMMCM_REG, 0);
            	}
                break;

            case ADC_SPI_MSG1:
            	regAddr = (MsgData & 0xFF00) >> 8;
            	regVal = (MsgData & 0xFF);
            	xil_printf("Programming ADC SPI Register  Addr: %x   Data: %x \r\n", regAddr, regVal);
            	Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_SPI_REG, regAddr<<8 | regVal);
            	usleep(1000);
            	//read back
            	Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_SPI_REG, 0x8000 | regAddr<<8 | regVal);
            	usleep(1000);
            	rdbk = Xil_In32(XPAR_M_AXI_BASEADDR + ADC_SPI_REG);
            	xil_printf("SPI Read Back ADC0 Reg: %d = %x\r\n",regAddr,rdbk);
            	usleep(1000);
            	Xil_Out32(XPAR_M_AXI_BASEADDR + ADC_SPI_REG, 0x10000 | 0x8000 | regAddr<<8 | regVal);
            	usleep(1000);
            	rdbk = Xil_In32(XPAR_M_AXI_BASEADDR + ADC_SPI_REG);
            	xil_printf("SPI Read Back ADC1 Reg: %d = %x\r\n",regAddr,rdbk);
                break;

            default:
            	xil_printf("Msg not supported yet...\r\n");
            	break;
        }

	}

	/* close connection */
	close(newsockfd);
	vTaskDelete(NULL);
}


