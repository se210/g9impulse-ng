library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use WORK.view_pckg.ALL;
use WORK.HexDriver_pckg.ALL;

ENTITY viewtest IS 
	PORT
	(
		CLOCK_50 :  IN  STD_LOGIC;
		KEY :  IN  STD_LOGIC_VECTOR(0 TO 0);
		SW :  IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		VGA_CLK :  OUT  STD_LOGIC;
		VGA_SYNC :  OUT  STD_LOGIC;
		VGA_BLANK :  OUT  STD_LOGIC;
		VGA_VS :  OUT  STD_LOGIC;
		VGA_HS :  OUT  STD_LOGIC;
        pixelval : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		LEDR :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);
		VGA_B :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		VGA_G :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		VGA_R :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		SRAM_ADDR : OUT STD_LOGIC_VECTOR(17 downto 0);
		SRAM_DQ : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		SRAM_WE_N : OUT STD_LOGIC;
		SRAM_OE_N : OUT STD_LOGIC;
		SRAM_UB_N : OUT STD_LOGIC;
		SRAM_LB_N : OUT STD_LOGIC;
		SRAM_CE_N : OUT STD_LOGIC
	);
END viewtest;

architecture behavioral of viewtest is

signal wr : std_logic;
signal pixel : std_logic_vector(15 downto 0);
signal count : std_logic_vector(15 downto 0);
signal visible : std_logic;
signal vga_clk_in : std_logic;
signal rst_i : std_logic;
signal eof_i : std_logic;
signal full_i : std_logic;

begin
	u1: view
	PORT MAP(Clk => CLOCK_50,
			 nReset => rst_i,
			 wr => wr,
			 field_color => SW(7 downto 0),
			 pixel_data_in => pixel,
			 eof => eof_i,
			 full => full_i,
			 VGA_clk => vga_clk_in,
			 sync => VGA_SYNC,
			 blank => VGA_BLANK,
			 vs => VGA_VS,
			 hs => VGA_HS,
			 Blue => VGA_B,
			 Green => VGA_G,
			 Red => VGA_R,
			 visible_out => visible,
			 pin_sram_addr => SRAM_ADDR,
			 pin_sram_dq => SRAM_DQ,
			 pin_sram_we_n => SRAM_WE_N,
			 pin_sram_oe_n => SRAM_OE_N,
			 pin_sram_ub_n => SRAM_UB_N,
			 pin_sram_lb_n => SRAM_LB_N,
			 pin_sram_ce_n => SRAM_CE_N);
	
--	u2: HexDriver
--	Port map( In0 => "000" & full_i,
--			  Out0 => HEX0);
			 
VGA_CLK <= vga_clk_in;
rst_i <= KEY(0);
LEDR(0) <= eof_i;
--wr <= not full_i and not visible;
wr <= '0';
			 
count_pixel : process (CLOCK_50, eof_i, full_i, rst_i)
begin
	if(eof_i = '1' or rst_i = '0') then
		count <= x"0000";
	elsif rising_edge(CLOCK_50) and full_i='0' then
		count <= count+1;
	end if;
end process;

    pixel <= x"FFFF" when count = SW else x"0000";
    pixelval <= pixel;
end;
