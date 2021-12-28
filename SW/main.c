#include <xparameters.h>
#include <xgpio_l.h>
#include <xintc_l.h>
#include <xtmrctr_l.h>
#include <mb_interface.h>
#include <xaxidma_hw.h>
#include <stdbool.h>
#include "game.h"

//*****************************************************************************
//* Makrók a memória írásához és olvasásához.                                 *
//*****************************************************************************
#define MEM8(addr)   (*(volatile unsigned char *)(addr))
#define MEM16(addr)  (*(volatile unsigned short *)(addr))
#define MEM32(addr)  (*(volatile unsigned long *)(addr))

//Státusz regiszter: 32 bites, csak olvasható
#define CUSTOM_PER_STATUS_REG				0x00
//Megszakítás engedélyezõ regiszter: 32 bites, írható/olvasható
#define CUSTOM_PER_IE_REG					0x04
//Megszakítás flag regiszter: 32 bites, olvasható  és '1' beírással törölhetõ
#define CUSTOM_PER_IF_REG					0x08

//A folyadékszint jelzõ periféria megszakítás eseményei.
#define LVL_FULL_IRQ				(1 << 0)
#define LVL_EMPTY_IRQ				(1 << 1)
#define LVL_ERROR_IRQ				(1 << 2)

// kep buffer
unsigned long dma_tx_buf[DISPLAY_WIDTH*DISPLAY_HEIGTH] __attribute__((aligned(128), section(".extmem")));

//*****************************************************************************
//* Hétszegmenses dekóder.                                                    *
//*****************************************************************************
unsigned char bin2sevenseg[] = {
	0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x6f, 0x07,
	0x7f, 0x7d, 0x77, 0x7c, 0x39, 0x5e, 0x79, 0x71
};


void dma_mm2s_start(unsigned long baseaddr, void *src, unsigned long length)
{
	//A forráscím beállítása. A felsõ 32 bit mindig 0.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SRCADDR_OFFSET)) = (unsigned long)src;
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SRCADDR_MSB_OFFSET)) = 0;
	//Az adatméret beállítása, ennek hatására indul az MM2S DMA átvitel.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_BUFFLEN_OFFSET)) = length;
}

void dma_mm2s_wait(unsigned long baseaddr)
{
	unsigned long status;

	//Várakozás, amíg az MM2S DMA átvitel be nem fejezõdik.
	for (;;)
	{
		//A státusz regiszter beolvasása.
		status = MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET));
		//Kilépünk a ciklusból, ha az IDLE bit 1.
		if (status & XAXIDMA_IDLE_MASK)
			break;
	}
}

volatile int point_counter = 0;
volatile bool display_digit = false;
void displayPoints(bool display_first_digit)
{
	if(display_first_digit)
	{
		unsigned long data = bin2sevenseg[point_counter/10 & 0x0f];
		data |= (1 << 8);
		XGpio_WriteReg(
			XPAR_AXI_LEDS_BASEADDR,
			XGPIO_DATA2_OFFSET,
			data
		);
	}
	else
	{
		unsigned long data2 = bin2sevenseg[point_counter%10 & 0x0f];
		data2 |= (1 << 9);
		XGpio_WriteReg(
			XPAR_AXI_LEDS_BASEADDR,
			XGPIO_DATA2_OFFSET,
			data2
		);
	}

}

#define ENABLE_MB_DCACHE     1
#define DMA_TRANSFER_SIZE    DISPLAY_WIDTH*DISPLAY_HEIGTH *2

//*****************************************************************************
//* Az idõzítõ megszakításkezelõ rutinja.                                     *
//*****************************************************************************
volatile unsigned char led_value;
volatile unsigned char led_blink;
volatile bool start_transfer;
volatile int interrupt_counter = 0;
volatile bool game_cycle;
volatile int lvl_counter = 1;
volatile bool reset_game = false;

void timer_int_handler(void *instancePtr)
{
	unsigned long csr;

	start_transfer = true;
	interrupt_counter++;
	if(interrupt_counter == 120 / lvl_counter)
	{
		interrupt_counter = 0;
		game_cycle = true;
	}
	display_digit = !display_digit;
	displayPoints(display_digit);

	//A megszakítás jelzés törlése. A jelzés az idõzítõ kontroll/státusz
	//regiszterében 1 beírásával törölhetõ.
	csr = XTmrCtr_GetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0);
	XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0, csr);
}

void button_int_handler(void *instancePtr)
{
	unsigned char ifr;

	//A megszakítás jelzés törlése. A jelzés a periféria megszakítás flag
	//regiszterében 1 beírásával törölhetõ.
	ifr = MEM32(XPAR_CUSTOM_PER_0_BASEADDR + CUSTOM_PER_IF_REG);
	MEM32(XPAR_CUSTOM_PER_0_BASEADDR + CUSTOM_PER_IF_REG) = ifr;

	if (ifr == 2)
	{
		interrupt_counter = 0;
		lvl_counter++;
		XGpio_WriteReg(XPAR_AXI_LEDS_BASEADDR, XGPIO_DATA_OFFSET, 1 << (lvl_counter -1));
	}
	else if(ifr ==1)
	{
		reset_game = true;
	}
}


void dma_init(unsigned long baseaddr)
{
	//Az MM2S csatorna engedélyezése: a vezérlõ reg. RS bitjének 1-be állítása.
	//Megszakításokat nem használunk.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_CR_OFFSET)) = XAXIDMA_CR_RUNSTOP_MASK;
}

Direction getTurnDirection()
{
	unsigned long data = MEM32(XPAR_CUSTOM_PER_0_BASEADDR + CUSTOM_PER_STATUS_REG);
	if(data == 1 )
			return dirLeft;
	else if(data == 2)
			return dirRight;
	return dirStraight;
}

//*****************************************************************************
//* Fõprogram.                                                                *
//*****************************************************************************
int main()
{
	led_value = 0;
	led_blink = 0;
	unsigned int buffer_counter = 0;

	unsigned long i;
	for(i = 0; i < DISPLAY_WIDTH * DISPLAY_HEIGTH; i++)
	{
		dma_tx_buf[i] = (unsigned long)(BACKGROUND);
	}
	dma_init(XPAR_AXIDMA_0_BASEADDR);

	//A megszakításkezelõ rutinok regisztrálása.
	//XIntc_RegisterHandler()
	XIntc_RegisterHandler(
		XPAR_INTC_0_BASEADDR,
		XPAR_MICROBLAZE_0_AXI_INTC_AXI_TIMER_0_INTERRUPT_INTR,
		(XInterruptHandler)timer_int_handler,
		NULL
	);

	XIntc_RegisterHandler(
		XPAR_INTC_0_BASEADDR,
		XPAR_MICROBLAZE_0_AXI_INTC_CUSTOM_PER_0_IRQ_INTR,
		(XInterruptHandler)button_int_handler,
		NULL
	);

	//A használt megszakítások engedélyezése a megszakítás vezérlõben.
	//XIntc_MasterEnable()
	//XIntc_EnableIntr()
	XIntc_MasterEnable(XPAR_INTC_0_BASEADDR);
	XIntc_EnableIntr(
		XPAR_INTC_0_BASEADDR,
		XPAR_AXI_TIMER_0_INTERRUPT_MASK |
		XPAR_CUSTOM_PER_0_IRQ_MASK
		);

	//A hiba megszakítás engedélyezése a folyadékszint kijelzõ perifériában:
	//ERROR flag törlése, ERROR megszakítás engedélyezése.
	MEM32(XPAR_CUSTOM_PER_0_BASEADDR + CUSTOM_PER_IF_REG) = 1<<0 | 1<<1 | LVL_ERROR_IRQ | 1<<3;
	MEM32(XPAR_CUSTOM_PER_0_BASEADDR+ CUSTOM_PER_IE_REG) = 1<<0 | 1<<1 | LVL_ERROR_IRQ | 1<<3;

	//A megszakítások engedélyezése a MicroBlaze processzoron.
	//microblaze_enable_interrupts()
	microblaze_enable_interrupts();

	//A timer LOAD regiszterének beállítása (megszakítás 0,25 másodpercenként).
	//XTmrCtr_SetLoadReg()
	XTmrCtr_SetLoadReg(
		XPAR_AXI_TIMER_0_BASEADDR,
		0,
		XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ / 240 /2
	);

	//A timer alapállapotba állítása:
	//- a timer leállítása
	//- a megszakítás jelzés törlése
	//- a LOAD regiszter betöltése a számlálóba
	//XTmrCtr_SetControlStatusReg()
	XTmrCtr_SetControlStatusReg(
		XPAR_AXI_TIMER_0_BASEADDR,
		0,
		XTC_CSR_INT_OCCURED_MASK | XTC_CSR_LOAD_MASK
	);

	//A timer elindítása:
	//- a timer engedélyezése
	//- a megszakítás engedélyezése
	//- automatikus számláló újratöltés (periodikus) mód
	//- a számláló lefele számlál (0 a végállapot)
	//XTmrCtr_SetControlStatusReg()
	XTmrCtr_SetControlStatusReg(
		XPAR_AXI_TIMER_0_BASEADDR,
		0,
		XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_ENABLE_INT_MASK |
		XTC_CSR_AUTO_RELOAD_MASK | XTC_CSR_DOWN_COUNT_MASK
	);

	static Snake_part original_snake[MAX_SNAKE_SNIZE];
	static int snake_size;
	original_snake[0].pos.x = 0;
	original_snake[0].pos.y = 0;
	original_snake[0].pos.heading = Right;
	snake_size = 1;
	Position food = generateFood(original_snake, snake_size);
	food.x = 300;
	food.y = 0;
	XGpio_WriteReg(XPAR_AXI_LEDS_BASEADDR, XGPIO_DATA_OFFSET, 1);
	for (;;)
	{
		//A DMA adatátvitel elindítása. Ha az adat cache engedélyezve
		//van, akkor azt az MM2S írány indítása elõtt ki kell üríteni.
		if (start_transfer)
		{
			start_transfer = false;
#if (ENABLE_MB_DCACHE != 0)
			microblaze_flush_dcache();
#endif
			dma_mm2s_start(XPAR_AXIDMA_0_BASEADDR, dma_tx_buf + buffer_counter * BUFFER_OFFSET *2, DMA_TRANSFER_SIZE);
			buffer_counter ++;
			if (buffer_counter == 4 /2)
				buffer_counter = 0;

			if (game_cycle)
			{
				if (reset_game)
				{
					reset_game = false;
					displaySnake(original_snake, snake_size, dma_tx_buf, true);
					removeFood(dma_tx_buf, food);
					original_snake[0].pos.x = 0;
					original_snake[0].pos.y = 0;
					original_snake[0].pos.heading = Right;
					snake_size = 1;
					food = generateFood(original_snake, snake_size);
					lvl_counter = 1;
					point_counter = 0;
					XGpio_WriteReg(XPAR_AXI_LEDS_BASEADDR, XGPIO_DATA_OFFSET, 1);
					game_over = false;
				}
				if(snake_size == 10)
				{
					displaySnake(original_snake, snake_size, dma_tx_buf, true);
					snake_size = 1;
					lvl_counter++;
					XGpio_WriteReg(XPAR_AXI_LEDS_BASEADDR, XGPIO_DATA_OFFSET, 1 << (lvl_counter -1));
				}
				if(lvl_counter == 8)
				{
					game_over = true;
				}
				if(!game_over)
				{
					  	  displaySnake(original_snake, snake_size, dma_tx_buf, true);
				  		  Snake_part snake_copy[snake_size];	//egy másolt kígyóval mozgunk
				  		  copySnake(snake_copy,original_snake,snake_size);
				  		  updateSnake(snake_copy, snake_size,getTurnDirection());	//tényleges mozgás érintés alapján
				  		  if(!checkIfSnakeLooped(snake_copy,snake_size))	//Ha nem harapott magába
				  		  {
				  			  if(checkIfSamePos(snake_copy[0],food))	//és felvette az ennivalót
				  			  {
				  				  snake_size++;
				  				  addToSnake(original_snake, snake_size, snake_copy[0]);				//akkor a másolt kígyó fejét hozzáadjuk az eredeti kígyóhoz, a többi rész nem mozdul
				  				  removeFood(dma_tx_buf, food);
				  				  food = generateFood(original_snake, snake_size);					//új étel random generálása
				  				  point_counter++;

				  			  }
				  			  else
				  			  {
				  				  copySnake(original_snake,snake_copy,snake_size);	//Ha nem vettünk fel ételt akkor a tovább mozdított másolt kígyó lesz az eredeti
				  			  }
				  		  }
				  		  else									//game over ha magába harapott
				  		  {
				  			  game_over = true;
				  			  copySnake(original_snake,snake_copy,snake_size);
				  		  }

				}
				if(snake_size == MAX_SNAKE_SNIZE)		//mivel statikus tömb a kígyó, így ha elértük a max-ot akkor leállítjuk a játékot
				{
					game_over = true;
				}
				displayFood(dma_tx_buf, food);		//étel és kígyó kirajzolása
				displaySnake(original_snake, snake_size, dma_tx_buf, false);
				game_cycle = false;
			  	  }
			//Várakozás a DMA átvitel befejezõdésére.
			dma_mm2s_wait(XPAR_AXIDMA_0_BASEADDR);

			//Ha az adat cache engedélyezve van, akkor azt az S2MM irányú
			//átvitel befejezõdése után és az adatbuffer hozzáférés elõtt
			//érvényteleníteni kell.
#if (ENABLE_MB_DCACHE != 0)
			microblaze_invalidate_dcache();
#endif
		}
	}

	return 0;
}
