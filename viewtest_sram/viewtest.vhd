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
		SW :  IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		VGA_CLK :  OUT  STD_LOGIC;
		VGA_SYNC :  OUT  STD_LOGIC;
		VGA_BLANK :  OUT  STD_LOGIC;
		VGA_VS :  OUT  STD_LOGIC;
		VGA_HS :  OUT  STD_LOGIC;
		LEDR :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);
		VGA_B :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		VGA_G :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		VGA_R :  OUT  STD_LOGIC_VECTOR(9 DOWNTO 8);
		HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		--SRAM Connections
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

signal clk : std_logic;
signal wr : std_logic; --write to SRAM
signal wr_addr : std_logic_vector(17 downto 0);
signal addr_cur : std_logic_vector(17 downto 0);
signal pixel : std_logic_vector(15 downto 0);
signal count : std_logic_vector(15 downto 0);
signal visible : std_logic;
signal vga_clk_in : std_logic;
signal rst_i, nrst_i : std_logic;
signal eof_i : std_logic;
signal wait_request : std_logic;
signal wr_be_n : std_logic_vector(1 downto 0);

begin
	u1: view
	PORT MAP(Clk => clk,
			 nReset => nrst_i,
			 wr => wr,
			 wr_addr => wr_addr,
			 wr_be_n => wr_be_n,
			 wait_request => wait_request,
			 field_color => SW(7 downto 0),
			 pixel_data_in => pixel,
			 sof => open,
			 eof => eof_i,
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
			 
clk <= CLOCK_50;
VGA_CLK <= vga_clk_in;
rst_i <= not KEY(0);
nrst_i <= KEY(0);
LEDR(0) <= eof_i;
wr <= '1';
wr_addr <= addr_cur(17 downto 0);
wr_be_n <= "10" when addr_cur=SW else "00";
pixel <= x"FFFF" when addr_cur=SW else x"0000";

update : process(clk,eof_i, rst_i, wait_request)
begin
	if(eof_i='1' or rst_i='1') then
		addr_cur <= (others=>'0');
	elsif(rising_edge(clk)) then
		if(wait_request='0') then
			addr_cur <= addr_cur+1;
		else
			addr_cur <= addr_cur;
		end if;
	end if;
end process;
end;