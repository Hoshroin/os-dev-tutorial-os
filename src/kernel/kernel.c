char* text_pos_to_vram (int col, int row) {
	char* sum = (char*) 0xB8000 + 2 * (row * 80 + col);
}

void main () {
	// pointer to the first text cell in VRAM
	char* video_memory = text_pos_to_vram(3, 0);
	// deref, store data in the address
	*video_memory = 'X';
}
