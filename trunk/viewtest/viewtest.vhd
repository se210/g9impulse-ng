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
		LEDR :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);
		VGA_B :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		VGA_G :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		VGA_R :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END viewtest;

architecture behavioral of viewtest is

signal wr : std_logic;
signal pixel : std_logic_vector(15 downto 0);
signal visible : std_logic;
signal vga_clk_in : std_logic;
signal rst_i : std_logic;
signal eof_i : std_logic;
signal full_i : std_logic;

begin
	u1: view
	PORT MAP(Clk => CLOCK_50,
			 Reset => rst_i,
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
			 visible_out => visible);
	
	u2: HexDriver
	Port map( In0 => "000" & full_i,
			  Out0 => HEX0);
			 
VGA_CLK <= vga_clk_in;
rst_i <= KEY(0);
LEDR(0) <= eof_i;
wr <= not full_i;
			 
generate_pixel : process (vga_clk_in,eof_i)
begin
	if(eof_i = '1') then
		pixel <= (others=>'0');
	elsif rising_edge(vga_clk_in) and visible='1' then
		pixel <= pixel+1;
	end if;
end process;

end;