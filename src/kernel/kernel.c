#include <stddef.h>
#include <stdint.h>

/* Hardware text mode color constants */
enum vga_color {
	VGA_COLOR_BLACK = 0,
	VGA_COLOR_BLUE = 1,
	VGA_COLOR_GREEN = 2,
	VGA_COLOR_CYAN = 3,
	VGA_COLOR_RED = 4,
	VGA_COLOR_MAGENTA = 5,
	VGA_COLOR_BROWN = 6,
	VGA_COLOR_LIGHT_GREY = 7,
	VGA_COLOR_DARK_GREY = 8,
	VGA_COLOR_LIGHT_BLUE = 9,
	VGA_COLOR_LIGHT_GREEN = 10,
	VGA_COLOR_LIGHT_CYAN = 11,
	VGA_COLOR_LIGHT_RED = 12,
	VGA_COLOR_LIGHT_MAGENTA = 13,
	VGA_COLOR_LIGHT_BROWN = 14,
	VGA_COLOR_WHITE = 15
};

// one entry is 16-bit big
volatile uint16_t* vga_buffer = (uint16_t*)0xB8000;
// by default, VGA textmode buffer has a size of 80*25 chars
const int VGA_COLS = 80;
const int VGA_ROWS = 25;

int curs_col = 0;
int curs_row = 0;
uint8_t term_color = 0x0F;  //white on black

// Returns entry's color setting (8-bit)
uint8_t vga_entry_color(uint8_t fg, uint8_t bg) {
	// BBBBFFFF
	uint8_t sum = bg << 4 | fg;
	return sum;
}

// Clears the terminal
void term_init() {
	for (int col = 0; col < VGA_COLS; col++) {
		for (int row = 0; row < VGA_ROWS; row++) {
			const size_t index = (VGA_COLS * row) + col;
			// VGA buffer entry BBBBFFFFCCCCCCCC
			// - B: background color
			// - F: foreground color
			// - C: ASCII character
			vga_buffer[index] = ((uint16_t)term_color << 8) | ' ';  // space is good enough to blank
		}
	}
}

// Scroll up the screen by lines
// Params:
//   - sl: scroll up how many lines
void term_scroll(int sl) {
	// Copy data from lower row to higher row
	for (int col = 0; col < VGA_COLS; col++) {
		for (int row = sl; row < VGA_ROWS; row++) {
			const size_t index_src = (VGA_COLS * row) + col;  // lower row
			const size_t index_dst = (VGA_COLS * (row - sl)) + col;  // higher row

			uint16_t entry_src = vga_buffer[index_src];
			vga_buffer[index_dst] = entry_src;
		}
	}

	// Clear the bottom area
	for (int col = 0; col < VGA_COLS; col++) {
		for (int row = (VGA_ROWS - sl); row < VGA_ROWS; row++) {
			const size_t index = (VGA_COLS * row) + col;
			vga_buffer[index] = ((uint16_t)term_color << 8) | ' ';  // space is good enough to blank
		}
	}
}

// Puts a char onto the screen
void term_putc(char c) {
	switch (c) {
	case '\n':  // implements newline by moving cursor
		{
			curs_col = 0;
			curs_row++;
			break;
		}
	
	default:  // otherwise, display char and increment the column
		{
			const size_t index = (VGA_COLS * curs_row) + curs_col;
			vga_buffer[index] = ((uint16_t)term_color << 8) | c;
			curs_col++;
			break;
		}
	}

	// if get past the last column, implements a newline
	if (curs_col >= VGA_COLS) {
		curs_col = 0;
		curs_row++;
	}

	// if get past the last row, scroll the screen and get a new line
	if (curs_row >= VGA_ROWS) {
		term_scroll(1);
		curs_col = 0;
		curs_row = VGA_ROWS;
	}
}

// Prints an entire string onto the screen
void term_print(const char* str) {
	for (size_t i = 0; str[i] != '\0'; i++) {  // stops when get a \0
		term_putc(str[i]);
	}
}

// Prints an entire string onto the screen but rainbowly
void term_rainbow_print(const char* str) {
	uint8_t temp_term_color = term_color;  // to save the original color setting
	
	for (size_t i = 0; str[i] != '\0'; i++) {  // stops when get a \0
		term_color = vga_entry_color((uint8_t)(i % 16), (uint8_t)(i % 16));  // loop through avaliable colors
		term_putc(str[i]);
	}

	term_color = temp_term_color;  // to restore the original color setting
}

// Kernel's main entry
void main () {
	term_init();

	term_print("Ah, welcome to the cozy kernel. :3\n");
	term_rainbow_print("No more swearing, no more size limiting. :3\n");
}
