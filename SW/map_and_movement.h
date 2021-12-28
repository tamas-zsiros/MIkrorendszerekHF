#ifndef SRC_MAP_AND_MOVEMENT_H_
#define SRC_MAP_AND_MOVEMENT_H_

#include <stdint.h>

#define SNAKE_WIDHT 4
#define SNAKE_HEIGHT 2
#define FOOD_WIDHT 2
#define FOOD_HEIGHT 2

typedef enum {
	Up,
	Left,
	Down,
	Right
}Heading;

typedef struct {
	 int x;
	 int y;
	Heading heading;
} Position;


void leftTurn(Position* pos);
void rightTurn(Position* pos);
void straightMov(Position* pos);

#endif /* SRC_MAP_AND_MOVEMENT_H_ */
