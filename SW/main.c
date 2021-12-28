#include <xparameters.h>
#include <xgpio_l.h>
#include <xintc_l.h>
#include <xtmrctr_l.h>
#include <mb_interface.h>
#include <xaxidma_hw.h>
#include <stdbool.h>
#include "game.h"

//*****************************************************************************
//* Makr�k a mem�ria �r�s�hoz �s olvas�s�hoz.                                 *
//*****************************************************************************
#define MEM8(addr)   (*(volatile unsigned char *)(addr))
#define MEM16(addr)  (*(volatile unsigned short *)(addr))
#define MEM32(addr)  (*(volatile unsigned long *)(addr))

//St�tusz regiszter: 32 bites, csak olvashat�
#define CUSTOM_PER_STATUS_REG				0x00
//Megszak�t�s enged�lyez� regiszter: 32 bites, �rhat�/olvashat�
#define CUSTOM_PER_IE_REG					0x04
//Megszak�t�s flag regiszter: 32 bites, olvashat�  �s '1' be�r�ssal t�r�lhet�
#define CUSTOM_PER_IF_REG					0x08

//A folyad�kszint jelz� perif�ria megszak�t�s esem�nyei.
#define LVL_FULL_IRQ				(1 << 0)
#define LVL_EMPTY_IRQ				(1 << 1)
#define LVL_ERROR_IRQ				(1 << 2)

// kep buffer
unsigned long dma_tx_buf[DISPLAY_WIDTH*DISPLAY_HEIGTH] __attribute__((aligned(128), section(".extmem")));

//*****************************************************************************
//* H�tszegmenses dek�der.                                                    *
//*****************************************************************************
unsigned char bin2sevenseg[] = {
	0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x6f, 0x07,
	0x7f, 0x7d, 0x77, 0x7c, 0x39, 0x5e, 0x79, 0x71
};


void dma_mm2s_start(unsigned long baseaddr, void *src, unsigned long length)
{
	//A forr�sc�m be�ll�t�sa. A fels� 32 bit mindig 0.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SRCADDR_OFFSET)) = (unsigned long)src;
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SRCADDR_MSB_OFFSET)) = 0;
	//Az adatm�ret be�ll�t�sa, ennek hat�s�ra indul az MM2S DMA �tvitel.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_BUFFLEN_OFFSET)) = length;
}

void dma_mm2s_wait(unsigned long baseaddr)
{
	unsigned long status;

	//V�rakoz�s, am�g az MM2S DMA �tvitel be nem fejez�dik.
	for (;;)
	{
		//A st�tusz regiszter beolvas�sa.
		status = MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET));
		//Kil�p�nk a ciklusb�l, ha az IDLE bit 1.
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
//* Az id�z�t� megszak�t�skezel� rutinja.                                     *
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

	//A megszak�t�s jelz�s t�rl�se. A jelz�s az id�z�t� kontroll/st�tusz
	//regiszter�ben 1 be�r�s�val t�r�lhet�.
	csr = XTmrCtr_GetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0);
	XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0, csr);
}

void button_int_handler(void *instancePtr)
{
	unsigned char ifr;

	//A megszak�t�s jelz�s t�rl�se. A jelz�s a perif�ria megszak�t�s flag
	//regiszter�ben 1 be�r�s�val t�r�lhet�.
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
	//Az MM2S csatorna enged�lyez�se: a vez�rl� reg. RS bitj�nek 1-be �ll�t�sa.
	//Megszak�t�sokat nem haszn�lunk.
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
//* F�program.                                                                *
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

	//A megszak�t�skezel� rutinok regisztr�l�sa.
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

	//A haszn�lt megszak�t�sok enged�lyez�se a megszak�t�s vez�rl�ben.
	//XIntc_MasterEnable()
	//XIntc_EnableIntr()
	XIntc_MasterEnable(XPAR_INTC_0_BASEADDR);
	XIntc_EnableIntr(
		XPAR_INTC_0_BASEADDR,
		XPAR_AXI_TIMER_0_INTERRUPT_MASK |
		XPAR_CUSTOM_PER_0_IRQ_MASK
		);

	//A hiba megszak�t�s enged�lyez�se a folyad�kszint kijelz� perif�ri�ban:
	//ERROR flag t�rl�se, ERROR megszak�t�s enged�lyez�se.
	MEM32(XPAR_CUSTOM_PER_0_BASEADDR + CUSTOM_PER_IF_REG) = 1<<0 | 1<<1 | LVL_ERROR_IRQ | 1<<3;
	MEM32(XPAR_CUSTOM_PER_0_BASEADDR+ CUSTOM_PER_IE_REG) = 1<<0 | 1<<1 | LVL_ERROR_IRQ | 1<<3;

	//A megszak�t�sok enged�lyez�se a MicroBlaze processzoron.
	//microblaze_enable_interrupts()
	microblaze_enable_interrupts();

	//A timer LOAD regiszter�nek be�ll�t�sa (megszak�t�s 0,25 m�sodpercenk�nt).
	//XTmrCtr_SetLoadReg()
	XTmrCtr_SetLoadReg(
		XPAR_AXI_TIMER_0_BASEADDR,
		0,
		XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ / 240 /2
	);

	//A timer alap�llapotba �ll�t�sa:
	//- a timer le�ll�t�sa
	//- a megszak�t�s jelz�s t�rl�se
	//- a LOAD regiszter bet�lt�se a sz�ml�l�ba
	//XTmrCtr_SetControlStatusReg()
	XTmrCtr_SetControlStatusReg(
		XPAR_AXI_TIMER_0_BASEADDR,
		0,
		XTC_CSR_INT_OCCURED_MASK | XTC_CSR_LOAD_MASK
	);

	//A timer elind�t�sa:
	//- a timer enged�lyez�se
	//- a megszak�t�s enged�lyez�se
	//- automatikus sz�ml�l� �jrat�lt�s (periodikus) m�d
	//- a sz�ml�l� lefele sz�ml�l (0 a v�g�llapot)
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
		//A DMA adat�tvitel elind�t�sa. Ha az adat cache enged�lyezve
		//van, akkor azt az MM2S �r�ny ind�t�sa el�tt ki kell �r�teni.
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
				  		  Snake_part snake_copy[snake_size];	//egy m�solt k�gy�val mozgunk
				  		  copySnake(snake_copy,original_snake,snake_size);
				  		  updateSnake(snake_copy, snake_size,getTurnDirection());	//t�nyleges mozg�s �rint�s alapj�n
				  		  if(!checkIfSnakeLooped(snake_copy,snake_size))	//Ha nem harapott mag�ba
				  		  {
				  			  if(checkIfSamePos(snake_copy[0],food))	//�s felvette az ennival�t
				  			  {
				  				  snake_size++;
				  				  addToSnake(original_snake, snake_size, snake_copy[0]);				//akkor a m�solt k�gy� fej�t hozz�adjuk az eredeti k�gy�hoz, a t�bbi r�sz nem mozdul
				  				  removeFood(dma_tx_buf, food);
				  				  food = generateFood(original_snake, snake_size);					//�j �tel random gener�l�sa
				  				  point_counter++;

				  			  }
				  			  else
				  			  {
				  				  copySnake(original_snake,snake_copy,snake_size);	//Ha nem vett�nk fel �telt akkor a tov�bb mozd�tott m�solt k�gy� lesz az eredeti
				  			  }
				  		  }
				  		  else									//game over ha mag�ba harapott
				  		  {
				  			  game_over = true;
				  			  copySnake(original_snake,snake_copy,snake_size);
				  		  }

				}
				if(snake_size == MAX_SNAKE_SNIZE)		//mivel statikus t�mb a k�gy�, �gy ha el�rt�k a max-ot akkor le�ll�tjuk a j�t�kot
				{
					game_over = true;
				}
				displayFood(dma_tx_buf, food);		//�tel �s k�gy� kirajzol�sa
				displaySnake(original_snake, snake_size, dma_tx_buf, false);
				game_cycle = false;
			  	  }
			//V�rakoz�s a DMA �tvitel befejez�d�s�re.
			dma_mm2s_wait(XPAR_AXIDMA_0_BASEADDR);

			//Ha az adat cache enged�lyezve van, akkor azt az S2MM ir�ny�
			//�tvitel befejez�d�se ut�n �s az adatbuffer hozz�f�r�s el�tt
			//�rv�nytelen�teni kell.
#if (ENABLE_MB_DCACHE != 0)
			microblaze_invalidate_dcache();
#endif
		}
	}

	return 0;
}
