library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use WORK.view_pckg.ALL;
use WORK.HexDriver_pckg.ALL;
use WORK.sdram.ALL;
use WORK.sdram_pll_pckg.ALL;

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
		--SRAM Connections
		SRAM_ADDR : OUT STD_LOGIC_VECTOR(17 downto 0);
		SRAM_DQ : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		SRAM_WE_N : OUT STD_LOGIC;
		SRAM_OE_N : OUT STD_LOGIC;
		SRAM_UB_N : OUT STD_LOGIC;
		SRAM_LB_N : OUT STD_LOGIC;
		SRAM_CE_N : OUT STD_LOGIC;
		--SDRAM Connections
		DRAM_CLK : out std_logic;
		DRAM_CKE : out std_logic;
		DRAM_CS_N : out std_logic;
		DRAM_RAS_N : out std_logic;
		DRAM_CAS_N : out std_logic;
		DRAM_WE_N : out std_logic;
		DRAM_BA_1 : out std_logic;
		DRAM_BA_0 : out std_logic;
		DRAM_ADDR : out std_logic_vector(11 downto 0);
		DRAM_DQ : inout std_logic_vector(15 downto 0);
		DRAM_UDQM : out std_logic;
		DRAM_LDQM : out std_logic
	);
END viewtest;

architecture behavioral of viewtest is

signal clk : std_logic;
signal rd : std_logic; --read from SDRAM
signal wr : std_logic; --write to SRAM
signal pixel : std_logic_vector(15 downto 0);
signal count : std_logic_vector(15 downto 0);
signal visible : std_logic;
signal vga_clk_in : std_logic;
signal rst_i, nrst_i : std_logic;
signal eof_i : std_logic;
signal full_i : std_logic;

--SDRAM related signals
type sdramState is (HOLD, READ_S);
signal state_cur, state_next : sdramState;
signal addr_cur, addr_next : std_logic_vector(21 downto 0);
signal earlyOpBegun_i : std_logic;
signal opBegun_i : std_logic;
signal rdPending_i : std_logic;
signal done_i : std_logic;
signal rdDone_i : std_logic;
signal locked : std_logic;

begin
	u1: view
	PORT MAP(Clk => clk,
			 nReset => nrst_i,
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
			 
	u2 : sdramCntl
	port map(
		-- host side input
		clk =>		clk,
		lock =>		locked,
		rst =>		rst_i,
		rd =>		rd,
		wr =>		'0',
		hAddr =>	addr_cur,
		hDIn => 	x"0000",
		-- host side output
		hDOut =>		pixel,
		earlyOpBegun => earlyOpBegun_i,
		opBegun => 		opBegun_i,
		rdPending =>	rdPending_i,
		done=>			done_i,
		rdDone=>		rdDone_i,
		status =>		open,
		
		-- SDRAM side
		cke =>		DRAM_CKE,
		ce_n => 	DRAM_CS_N,
		ras_n =>	DRAM_RAS_N,
		cas_n =>	DRAM_CAS_N,
		we_n =>		DRAM_WE_N,
		ba(1) =>	DRAM_BA_1,
		ba(0) =>	DRAM_BA_0,
		sAddr =>	DRAM_ADDR,
		sData =>	DRAM_DQ,
		dqmh =>		DRAM_UDQM,
		dqml =>		DRAM_LDQM);
		
	u3: sdram_pll
	port map(
			inclk0	=> CLOCK_50,
			c0		=> DRAM_CLK,
			c1		=> clk,
			locked	=> locked 
		);
	
--	u4: HexDriver
--	Port map( In0 => "000" & full_i,
--			  Out0 => HEX0);
			 
VGA_CLK <= vga_clk_in;
rst_i <= not KEY(0);
nrst_i <= KEY(0);
LEDR(0) <= eof_i;
wr <= not full_i and rdDone_i;

update : process (clk,rst_i)
begin
	if(rst_i ='1' or visible ='1') then
		state_cur <= HOLD;
		addr_cur <= (others=>'0');
	elsif (rising_edge(clk)) then
		state_cur <= state_next;
		addr_cur <= addr_next;
	end if;
end process;

next_state: process (eof_i,state_cur, done_i, rdDone_i, addr_next)
begin
	case state_cur is
		when HOLD => 
			rd <= '0';
			addr_next <= (others=>'0');
			if (eof_i ='1') then 
				state_next<= READ_S;
			else 
				state_next<= HOLD;
			end if;
		when READ_S =>
			rd <= '1';
			if (rdDone_i = '1') then
				addr_next <= addr_next+1;
				if (addr_next = "1001011000000000") then -- if address is equal to x"9600"
					state_next <= HOLD;
				else
					state_next <= READ_S;
				end if;
			else
				addr_next <= addr_next;
				state_next <= READ_S;
			end if;
	end case;
end process;
end;