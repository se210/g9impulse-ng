.include "nios_macros.s"
.equ Switches, 0x01003000
.equ LEDs, 0x01003010
.global _start
_start:
movia r2, Switches
movia r3, LEDs
loop: ldbio r4, 0(r2)
stbio r4, 0(r3)
br loop

