#include "map_and_movement.h"

#define LEFT_SIDE 0
#define RIGHT_SIDE 640
#define TOP 0
#define BOTTOM 480

/*Mindegyik f�ggv�ny ir�ny szerint d�nti el, hogy merre kell legk�zelebb fordulni.
 * Ha a fordul�st k�vet�en a k�gy� r�sz�t reprezent�l� t�glalap �tny�lna a t�loldalra,
 * akkor automatikusan az eg�sz t�glalapot �thelyezz�k a t�loldalra.
 *
 * A t�glalap orient�ci�ja k�l�nb�zik vertik�lis �s horizont�lis helyzetekben!!*/
void leftTurn(Position* pos){
	if(pos->heading == Right)
	{
		if (pos->y - SNAKE_WIDHT < TOP)
			pos->y = BOTTOM -SNAKE_WIDHT;
		else
			pos->y = pos->y - SNAKE_WIDHT;
		if(pos->x + SNAKE_WIDHT + SNAKE_HEIGHT > RIGHT_SIDE)
			pos->x = LEFT_SIDE;
		else
			pos->x = pos->x + SNAKE_WIDHT;
		pos->heading = Up;
		return;
	}
	if(pos->heading == Left)
	{
		if (pos->y + SNAKE_HEIGHT + SNAKE_WIDHT > BOTTOM)
			pos->y = TOP + SNAKE_HEIGHT + SNAKE_WIDHT;
		else
			pos->y = pos->y + SNAKE_HEIGHT;
		if (pos->x - SNAKE_HEIGHT < LEFT_SIDE)
			pos->x = RIGHT_SIDE - SNAKE_HEIGHT;
		else
			pos->x = pos->x - SNAKE_HEIGHT;
		pos->heading = Down;
		return;
	}
	if(pos->heading == Up)
	{
		if(pos->y - SNAKE_HEIGHT < TOP)
			pos->y = BOTTOM - SNAKE_HEIGHT;
		else
			pos->y = pos->y - SNAKE_HEIGHT;
		if(pos->x - SNAKE_WIDHT < LEFT_SIDE)
			pos->x = RIGHT_SIDE - SNAKE_WIDHT ;
		else
			pos->x = pos->x - SNAKE_WIDHT;
		pos->heading = Left;
		return;
	}
	if(pos->heading == Down)
	{
		if(pos->y + SNAKE_WIDHT + SNAKE_HEIGHT > BOTTOM)
			pos->y = TOP + SNAKE_WIDHT;
		else
			pos->y = pos->y + SNAKE_WIDHT;
		if(pos->x + SNAKE_HEIGHT + SNAKE_WIDHT > RIGHT_SIDE)
			pos->x = LEFT_SIDE;
		else
			pos->x = pos->x + SNAKE_HEIGHT;
		pos->heading = Right;
		return;
	}
}
void rightTurn(Position* pos){
	if(pos->heading == Right)
	{
		if(pos->y + SNAKE_HEIGHT + SNAKE_WIDHT > BOTTOM)
			pos->y = TOP + SNAKE_HEIGHT;
		else
			pos->y = pos->y + SNAKE_HEIGHT;
		if(pos->x + SNAKE_WIDHT + SNAKE_HEIGHT > RIGHT_SIDE)
			pos->x = LEFT_SIDE + SNAKE_WIDHT;
		else
			pos->x = pos->x + SNAKE_WIDHT;
		pos->heading = Down;
		return;
	}
	if(pos->heading == Left)
	{
		if(pos->y - SNAKE_WIDHT < TOP)
			pos->y = BOTTOM - SNAKE_WIDHT;
		else
			pos->y = pos->y - SNAKE_WIDHT;
		if(pos->x - SNAKE_HEIGHT < LEFT_SIDE)
			pos->x = RIGHT_SIDE - SNAKE_HEIGHT;
		else
			pos->x = pos->x - SNAKE_HEIGHT;
		pos->heading = Up;
		return;
	}
	if(pos->heading == Up)
	{
		if(pos->y - SNAKE_HEIGHT < TOP)
			pos->y = BOTTOM - SNAKE_HEIGHT;
		else
			pos->y = pos->y - SNAKE_HEIGHT;
		if(pos->x + SNAKE_HEIGHT + SNAKE_WIDHT > RIGHT_SIDE)
			pos->x = LEFT_SIDE + SNAKE_HEIGHT;
		else
			pos->x = pos->x + SNAKE_HEIGHT;
		pos->heading = Right;
		return;
	}
	if(pos->heading == Down)
	{
		if(pos->y + SNAKE_WIDHT + SNAKE_HEIGHT > BOTTOM)
			pos->y = TOP + SNAKE_WIDHT;
		else
			pos->y = pos->y + SNAKE_WIDHT;
		if(pos->x - SNAKE_WIDHT < LEFT_SIDE)
			pos->x = RIGHT_SIDE - SNAKE_WIDHT;
		else
			pos->x = pos->x - SNAKE_WIDHT;
		pos->heading = Left;
		return;
	}
}

void straightMov(Position* pos){
	if(pos->heading == Right)
	{
		if(pos->x + 2*SNAKE_WIDHT > RIGHT_SIDE)
			pos->x = LEFT_SIDE + SNAKE_WIDHT;
		else
			pos->x = pos->x + SNAKE_WIDHT;
		return;
	}
	if(pos->heading == Left)
	{
		if(pos->x - SNAKE_WIDHT < LEFT_SIDE)
			pos->x = RIGHT_SIDE - SNAKE_WIDHT;
		else
			pos->x = pos->x - SNAKE_WIDHT;
		return;
	}
	if(pos->heading == Up)
	{
		if(pos->y - SNAKE_WIDHT < TOP)
			pos->y = BOTTOM - SNAKE_WIDHT;
		else
			pos->y = pos->y - SNAKE_WIDHT;
		return;
	}
	if(pos->heading == Down)
	{
		if(pos->y + 2*SNAKE_WIDHT > BOTTOM)
			pos->y = TOP + SNAKE_WIDHT;
		else
			pos->y = pos->y + SNAKE_WIDHT;
		return;
	}
}



