-- Implements a simple Nios II system for the DE2 board.
-- Inputs: SW7?0 are parallel port inputs to the Nios II system
-- CLOCK_50 is the system clock
-- KEY0 is the active-low system reset
-- Outputs: LEDG7?0 are parallel port outputs from the Nios II system
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
ENTITY g9_gpu IS
PORT (
SW : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
KEY : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
CLOCK_50 : IN STD_LOGIC;
LEDG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
);
END g9_gpu;
ARCHITECTURE Structure OF g9_gpu IS
COMPONENT gpu
PORT (
clk_0 : IN STD_LOGIC;
reset_n : IN STD_LOGIC;
out_port_from_the_LEDs : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
in_port_to_the_Switches : IN STD_LOGIC_VECTOR (7 DOWNTO 0)
);
END COMPONENT;
BEGIN
-- Instantiate the Nios II system entity generated by the SOPC Builder
NiosII: gpu PORT MAP (CLOCK_50, KEY(0), LEDG, SW);
END Structure;