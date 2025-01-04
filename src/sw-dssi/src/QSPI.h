void BulkErase(XQspiPs * , u8 * );
void DieErase(XQspiPs * , u8 * );
void FlashErase(XQspiPs * , u32, u32, u8 * );
void FlashRead(XQspiPs * , u32, u32, u8, u8 * , u8 * );
int FlashReadID(XQspiPs * , u8 * , u8 * );
void FlashReadPV(XQspiPs * , u16, u8 * , int);
void FlashWrite(XQspiPs * , u32, u32, u8, u8 * );
void FlashWritePV(XQspiPs * , u16, u8 * , int);
u32 GetRealAddr(XQspiPs * , u32);
int QspiG128FlashExample(XQspiPs * , u16);
int macIPCOntrol(XQspiPs * , u16);
int QspiG128FlashInit(XQspiPs * , u16);
int SendBankSelect(XQspiPs * , u8 * , u32);
void UpdateFlash(XQspiPs * , u16);
int WriteConfigToQSPI();
void testFlashWriteRead();

/* QSPI */
#define QSPI_DEVICE_ID XPAR_XQSPIPS_0_DEVICE_ID
XQspiPs QspiInstance;
XQspiPs * QspiInstancePtr;
#define PAGE_COUNT 4
#define MAX_PAGE_SIZE 256
#define DATA_OFFSET 4 /* Start of Data for Read/Write */
#define DUMMY_OFFSET 4 /* Dummy byte offset for fast, dual and quad */
#define DUMMY_SIZE 1 /* Number of dummy bytes for fast, dual and quad reads */
//u8 ReadBuffer[(PAGE_COUNT * MAX_PAGE_SIZE) + (DATA_OFFSET + DUMMY_SIZE)*8];
//u8 WriteBuffer[(PAGE_COUNT * MAX_PAGE_SIZE) + DATA_OFFSET];

u8 RdBuffer[(PAGE_COUNT * MAX_PAGE_SIZE) + (DATA_OFFSET + DUMMY_SIZE) * 8];
u8 WrBuffer[(PAGE_COUNT * MAX_PAGE_SIZE) + DATA_OFFSET];

u8 TimeReadBuffer[(PAGE_COUNT * MAX_PAGE_SIZE) + (DATA_OFFSET + DUMMY_SIZE) * 8];
u8 TimeWriteBuffer[(PAGE_COUNT * MAX_PAGE_SIZE) + DATA_OFFSET];
#define LASER_PARAMETER_ADDRESS 0xFF0000
#define QUAD_READ_CMD 0x6B
#define TIME_1min 200 //SSTT 2000
#define TIME_BLINK 10

#define CONFIG_SIZE 5000192 //0c4c4c00
u8 DataConfig[CONFIG_SIZE];
int DataIndex = 0;
int totalRxByte = 0;
