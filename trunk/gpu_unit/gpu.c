#define Switches (volatile char *) 0x1003000
#define LEDs (char *) 0x1003010
#define sdram (char *) 0x800000
void wait();

void main()
{ while (1){
	int i;
	for(i=0; i<0xFF; i++){
		*sdram = (char)i;
		wait();
		*LEDs = *sdram;
	};
	   }
}

void wait(){
	int i;
	for(i=0; i<0xFFFFF; i++){}
}

