#pragma once
#ifndef SRC_GAME_H_
#define SRC_GAME_H_


#include <stdbool.h>
#include "map_and_movement.h"


#define MAX_SNAKE_SNIZE 100
#define BUFFER_OFFSET 76800
#define BACKGROUND 0xff555555
#define DISPLAY_WIDTH 640
#define DISPLAY_HEIGTH 480

typedef enum {
	dirStraight,
	dirLeft,
	dirRight
} Direction;

typedef struct {
	Position pos;
	Direction next_dir;
}Snake_part;


static bool game_over;

void startGame();

void updateSnake (Snake_part snake[],int snake_size,Direction last_dir_command);
void addToSnake (Snake_part * snake, int snake_size, Snake_part new_pos);
void copySnake (Snake_part* new_snake, const Snake_part* old_snake, int snake_size);
bool checkIfSamePos(const Snake_part snake,const Position object);
bool checkIfSnakeLooped (const Snake_part* snake, int snake_size);
Position generateFood (Snake_part * snake, int snake_size);
void displaySnake(Snake_part * snake,int snake_size, unsigned long* buffer, bool delete);
void removeFood(unsigned long* buffer, Position food);
void displayFood(unsigned long* buffer, Position food);

#endif /* SRC_GAME_H_ */
