-- Inputs: SW7?0 are parallel port inputs to the Nios II system.
-- CLOCK_50 is the system clock.
-- KEY0 is the active-low system reset.
-- Outputs: LEDG7?0 are parallel port outputs from the Nios II system.
-- SDRAM ports correspond to the signals in Figure 2; their names are those
-- used in the DE2 User Manual.
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
ENTITY g9_gpu IS
PORT ( SW : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
KEY : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
CLOCK_50 : IN STD_LOGIC;
LEDG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
DRAM_CLK, DRAM_CKE : OUT STD_LOGIC;
DRAM_ADDR : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
DRAM_BA_1, DRAM_BA_0 : BUFFER STD_LOGIC;
DRAM_CS_N, DRAM_CAS_N, DRAM_RAS_N, DRAM_WE_N : OUT STD_LOGIC;
DRAM_DQ : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
DRAM_UDQM, DRAM_LDQM : BUFFER STD_LOGIC );
END g9_gpu;
ARCHITECTURE Structure OF g9_gpu IS
COMPONENT gpu
PORT ( clk_0 : IN STD_LOGIC;
reset_n : IN STD_LOGIC;
out_port_from_the_LEDs : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
in_port_to_the_Switches : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
zs_addr_from_the_sdram_0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
zs_ba_from_the_sdram_0 : BUFFER STD_LOGIC_VECTOR(1 DOWNTO 0);
zs_cas_n_from_the_sdram_0 : OUT STD_LOGIC;
zs_cke_from_the_sdram_0 : OUT STD_LOGIC;
zs_cs_n_from_the_sdram_0 : OUT STD_LOGIC;
zs_dq_to_and_from_the_sdram_0 : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
zs_dqm_from_the_sdram_0 : BUFFER STD_LOGIC_VECTOR(1 DOWNTO 0);
zs_ras_n_from_the_sdram_0 : OUT STD_LOGIC;
zs_we_n_from_the_sdram_0 : OUT STD_LOGIC );
END COMPONENT;
SIGNAL BA : STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL DQM : STD_LOGIC_VECTOR(1 DOWNTO 0);
BEGIN
DRAM_BA_1 <= BA(1); DRAM_BA_0 <= BA(0);
DRAM_UDQM <= DQM(1); DRAM_LDQM <= DQM(0);
-- Instantiate the Nios II system entity generated by the SOPC Builder.
NiosII: gpu PORT MAP (CLOCK_50, KEY(0), LEDG, SW,
DRAM_ADDR, BA, DRAM_CAS_N, DRAM_CKE, DRAM_CS_N,
DRAM_DQ, DQM, DRAM_RAS_N, DRAM_WE_N );
DRAM_CLK <= CLOCK_50;
END Structure;