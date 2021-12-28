#include "game.h"
#include "stdlib.h"



uint16_t generateRnd(uint16_t maxValue)		//generates random number
{
	return (rand() % (maxValue + 1));
}


void updateSnake (Snake_part snake[],int snake_size,Direction last_dir_command)
{
	for(int i = snake_size - 1; i > -1 ; i--)
	{
		if (i == 0)
		{
		snake[i].next_dir = last_dir_command;		//a kígyó feje az utolsó érintés alapján kap irányt
		}
		else
		{
			snake[i].next_dir = snake[i-1].next_dir;	//a további tagok az elöttük lévõ tag elõzõ irányát kapja meg
		}
		switch (snake[i].next_dir)						//mozgás végrehajtása
		{
		case dirLeft:
			leftTurn(&snake[i].pos);
			break;
		case dirRight:
			rightTurn(&snake[i].pos);
			break;
		case dirStraight:
			straightMov(&snake[i].pos);
			break;
		}
	}
}

void addToSnake(Snake_part * snake, int snake_size, Snake_part new_pos){
	for(int i = snake_size - 1; i > -1; i--)				//hátulról kezdünk másolni
	{
		if (i == 0)
		{
			snake[i].pos.x = new_pos.pos.x;			//az új fej az argumentum szerint
			snake[i].pos.y = new_pos.pos.y;
			snake[i].pos.heading = new_pos.pos.heading;
			snake[i].next_dir = new_pos.next_dir;
		}
		else
		{
			snake[i].pos.x = snake[i-1].pos.x;		//elõzõ tag paramétereit átmásoljuk
			snake[i].pos.y = snake[i-1].pos.y;
			snake[i].pos.heading = snake[i-1].pos.heading;
			snake[i].next_dir = snake[i-1].next_dir;
		}
	}
}

void copySnake (Snake_part* new_snake, const Snake_part* old_snake, int snake_size){
	for (int i = 0; i < snake_size; i++)
	{
		new_snake[i].pos.x = old_snake[i].pos.x;
		new_snake[i].pos.y = old_snake[i].pos.y;
		new_snake[i].pos.heading = old_snake[i].pos.heading;
		new_snake[i].next_dir = old_snake[i].next_dir;
	}
	return;
}

//a mozgás iránya szerint megnézzük, hogy a kígyó rész és a tárgy téglalapja átfedésben van-e
bool checkIfSamePos(const Snake_part snake,const Position object){
	switch(snake.pos.heading)
	{
	case Up:
		if((object.x <= snake.pos.x + FOOD_WIDHT -1 + SNAKE_HEIGHT && object.x >= snake.pos.x - FOOD_WIDHT +1) &&
			(object.y + FOOD_HEIGHT -1 >= snake.pos.y && object.y <= snake.pos.y + SNAKE_WIDHT -1))
				return true;
			else
				return false;
		break;
	case Down:
		if((object.x <= snake.pos.x + FOOD_WIDHT -1 + SNAKE_HEIGHT && object.x >= snake.pos.x - FOOD_WIDHT +1) &&
			(object.y <= snake.pos.y + SNAKE_WIDHT -1 && object.y >= snake.pos.y))
			return true;
		else
			return false;
		break;
	case Left:
		if((object.y >= snake.pos.y - FOOD_HEIGHT + 1 && object.y <= snake.pos.y + SNAKE_HEIGHT + FOOD_HEIGHT -1) &&
			(snake.pos.x <= object.x + FOOD_WIDHT -1 && snake.pos.x + SNAKE_WIDHT - 1 >= object.x))
			return true;
		else
			return false;
		break;
	case Right:
		if((object.y >= snake.pos.y - FOOD_HEIGHT + 1 && object.y <= snake.pos.y + SNAKE_HEIGHT + FOOD_HEIGHT -1) &&
			(object.x - FOOD_WIDHT -1 <= snake.pos.x + SNAKE_WIDHT -1 && object.x >= snake.pos.x))
			return true;
		else
			return false;
		break;
	}
	return false;
}

bool checkIfSnakeLooped (const Snake_part* snake, int snake_size){
	for(int i = 0; i < snake_size - 1; i++)				//minden részre lefut
	{
		for (int k = i + 1; k < snake_size; k++)
		{
			if (checkIfSamePos(snake[i], snake[k].pos))
			{
				return true;
			}
		}
	}
	return false;
}

Position generateFood(Snake_part * snake, int snake_size){
	Position new_food;
	bool food_is_correct = false;
	while(!food_is_correct)
	{
	food_is_correct = true;
	new_food.x = (unsigned int)generateRnd(DISPLAY_WIDTH);	//az étel szélessége/magassága 5 pixel, így annyival kisebb helyre generálunk
	new_food.y = (unsigned int)generateRnd(DISPLAY_HEIGTH);
	new_food.heading = Left;
	for (int i = 0; i < snake_size; i ++)		//ha egy olyan helyre raktuk volna le, ahol már van kígyó akkor újra kell generálni
		if (checkIfSamePos(snake[i], new_food))
		{
			food_is_correct = false;
		}
	}
	return new_food;
}



void displaySnake(Snake_part * snake,int snake_size, unsigned long* buffer, bool delete){		//kígyó kirajzolása, irány szerint
	unsigned long color = 0xff00ff00;
	if (delete)
	{
		color = BACKGROUND;
	}
	for (int i = 0; i<snake_size; i++)
	{
		int index;
		switch(snake[i].pos.heading)
		    {
		      case Up:
		      case Down:
		    	//  BSP_LCD_FillRect(original_snake[i].pos.x, original_snake[i].pos.y, SNAKE_HEIGHT, SNAKE_WIDHT);
		    	  for (int w = 0; w < SNAKE_HEIGHT; ++w)
		    	  {
			    	  for (int h = 0; h < SNAKE_WIDHT; ++h)
			    	  {
				    	  index = snake[i].pos.x + w + (snake[i].pos.y+h) * DISPLAY_WIDTH;
				    	  if (index + BUFFER_OFFSET > 640*480)
				    	  {
				    		  index = index + BUFFER_OFFSET - 640*480;
				    	  }
				    	  else
				    	  {
				    		  index = index + BUFFER_OFFSET;
				    	  }
				    	  buffer[index] = color;
			    	  }
		    	  }
		    	  break;

		      case Left:
		      case Right:
		    	  for (int w = 0; w < SNAKE_WIDHT; ++w)
		    	  {
			    	  for (int h = 0; h < SNAKE_HEIGHT; ++h)
			    	  {
				    	  index = snake[i].pos.x + w + (snake[i].pos.y+h) * DISPLAY_WIDTH;
				    	  if (index + BUFFER_OFFSET > DISPLAY_WIDTH*DISPLAY_HEIGTH)
				    	  {
				    		  index = index + BUFFER_OFFSET - DISPLAY_WIDTH*DISPLAY_HEIGTH;
				    	  }
				    	  else
				    	  {
				    		  index = index + BUFFER_OFFSET;
				    	  }
				    	  buffer[index] = color;
			    	  }
		    	  }
		    	  break;
		    }
	}
}

void displayFood(unsigned long* buffer, Position food)
{
  for (int w = 0; w < FOOD_WIDHT; ++w)
  {
	  for (int h = 0; h < FOOD_HEIGHT; ++h)
	  {
		  int index = food.x + w + (food.y+h) * DISPLAY_WIDTH;
		  if (index + BUFFER_OFFSET > DISPLAY_WIDTH*DISPLAY_HEIGTH)
		  {
			  index = index + BUFFER_OFFSET - DISPLAY_WIDTH*DISPLAY_HEIGTH;
		  }
		  else
		  {
			  index = index + BUFFER_OFFSET;
		  }
		  buffer[index] = 0xffff0000;
	  }
  }
}

void removeFood(unsigned long* buffer, Position food)
{
  for (int w = 0; w < FOOD_WIDHT; ++w)
  {
	  for (int h = 0; h < FOOD_HEIGHT; ++h)
	  {
		  int index = food.x + w + (food.y+h) * 640;
		  if (index + BUFFER_OFFSET > 640*480)
		  {
			  index = index + BUFFER_OFFSET - 640*480;
		  }
		  else
		  {
			  index = index + BUFFER_OFFSET;
		  }
		  buffer[index] = BACKGROUND;
	  }
  }
}

