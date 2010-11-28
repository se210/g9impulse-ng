library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use WORK.common.all;
use WORK.sdram.all;
--use WORK.Blitter_pckg.all;
use WORK.sdram_pll_pckg.all;
use WORK.view_pckg.all;
use WORK.HexDriver_pckg.all;

entity gpuchip_sim is
	port(
		pin_clkin   : in std_logic;       -- main clock input from external clock source
		pin_clkout  : out std_logic;		 -- clock output to PIC
		pin_ce_n    : out std_logic;      -- Flash RAM chip-enable
		pin_pushbtn : in std_logic; -- push button reset
	
		-- vga port connections
		pin_red      : out std_logic_vector(9 downto 0);
		pin_green    : out std_logic_vector(9 downto 0);
		pin_blue     : out std_logic_vector(9 downto 0);
		pin_hsync_n  : out std_logic;
		pin_vsync_n  : out std_logic;
		pin_vga_clk  : out std_logic;
		pin_vga_blank : out std_logic;
		pin_vga_sync : out std_logic
	);
end gpuchip_sim;


architecture arch of gpuchip_sim is

component gpuChip is
	port(
		pin_clkin   : in std_logic;       -- main clock input from external clock source
		pin_clkout  : out std_logic;		 -- clock output to PIC
		pin_ce_n    : out std_logic;      -- Flash RAM chip-enable
		pin_pushbtn : in std_logic; -- push button reset
	

		-- blitter port connections
		pin_port_in	  : in std_logic_vector (7 downto 0);
		pin_port_addr : in std_logic_vector	(3 downto 0);
		pin_load		  : in std_logic;
		pin_start	  : in std_logic;
		pin_done		  : out std_logic;

		-- vga port connections
		pin_red     : out std_logic_vector(9 downto 0);
		pin_green   : out std_logic_vector(9 downto 0);
		pin_blue    : out std_logic_vector(9 downto 0);
		pin_hsync_n : out std_logic;
		pin_vsync_n : out std_logic;
		pin_vga_clk : out std_logic;
		pin_vga_blank : out std_logic;
		pin_vga_sync : out std_logic;

		-- SDRAM pin connections
		pin_sclkfb : in std_logic;                   -- feedback SDRAM clock with PCB delays
		pin_sclk   : out std_logic;                  -- clock to SDRAM
		pin_cke    : out std_logic;                  -- SDRAM clock-enable
		pin_cs_n   : out std_logic;                  -- SDRAM chip-select
		pin_ras_n  : out std_logic;                  -- SDRAM RAS
		pin_cas_n  : out std_logic;                  -- SDRAM CAS
		pin_we_n   : out std_logic;                  -- SDRAM write-enable
		pin_ba     : out std_logic_vector( 1 downto 0);      -- SDRAM bank-address
		pin_sAddr  : out std_logic_vector(11 downto 0);      -- SDRAM address bus
		pin_sData  : inout std_logic_vector (16-1 downto 0);  -- data bus to SDRAM
		pin_dqmh   : out std_logic;                  -- SDRAM DQMH
		pin_dqml   : out std_logic;                   -- SDRAM DQML	
		
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0);
		hex4 : out std_logic_vector(6 downto 0);
		hex5 : out std_logic_vector(6 downto 0);
		hex6 : out std_logic_vector(6 downto 0);
		hex7 : out std_logic_vector(6 downto 0)		
	);
end component;

component sdram_0_test_component is 
        port (
              -- inputs:
                 signal clk : IN STD_LOGIC;
                 signal zs_addr : IN STD_LOGIC_VECTOR (11 DOWNTO 0);
                 signal zs_ba : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
                 signal zs_cas_n : IN STD_LOGIC;
                 signal zs_cke : IN STD_LOGIC;
                 signal zs_cs_n : IN STD_LOGIC;
                 signal zs_dqm : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
                 signal zs_ras_n : IN STD_LOGIC;
                 signal zs_we_n : IN STD_LOGIC;

              -- outputs:
                 signal zs_dq : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0)
              );

end component;

    signal pin_sclk_i , pin_cas_n_i, pin_cke_i, pin_cs_n_i, pin_ras_n_i, pin_we_n_i: std_logic;
    signal pin_dqm_i, pin_ba_i : std_logic_vector(1 downto 0);
    signal pin_sAddr_i : std_logic_vector(11 downto 0);
    signal pin_sData_i : std_logic_vector(15 downto 0);


begin
    gpu : gpuChip
    port map(
      pin_clkin => pin_clkin,
      pin_clkout => pin_clkout,
      pin_ce_n => pin_ce_n,
      pin_pushbtn => pin_pushbtn,

      pin_port_in => (others => '0'),
      pin_port_addr => (others => '0'),
      pin_load	  => '0',
      pin_start	  => '0',
      pin_done	  => open,

      -- vga port connections
      pin_red => pin_red,
      pin_green => pin_green,
      pin_blue => pin_blue,
      pin_hsync_n => pin_hsync_n,
      pin_vsync_n => pin_vsync_n,
      pin_vga_clk => pin_vga_clk,
      pin_vga_blank => pin_vga_blank,
      pin_vga_sync => pin_vga_sync,

      pin_sclkfb => '0',
      pin_sclk => pin_sclk_i,
      pin_cke => pin_cke_i,
      pin_cs_n => pin_cs_n_i,
      pin_ras_n => pin_ras_n_i,
      pin_cas_n => pin_cas_n_i,
      pin_we_n => pin_we_n_i,
      pin_ba => pin_ba_i,
      pin_sAddr => pin_sAddr_i,
      pin_sData => pin_sData_i,
      pin_dqmh => pin_dqm_i(1),
      pin_dqml => pin_dqm_i(0),

      hex0 => open,
      hex1 => open,
      hex2 => open,
      hex3 => open,
      hex4 => open,
      hex5 => open,
      hex6 => open,
      hex7 => open);

    sdram_component : sdram_0_test_component
    port map(
      clk => pin_sclk_i,
      zs_addr => pin_sAddr_i,
      zs_ba => pin_ba_i,
      zs_cas_n => pin_cas_n_i,
      zs_cke => pin_cke_i,
      zs_cs_n => pin_cs_n_i,
      zs_dqm => pin_dqm_i,
      zs_ras_n => pin_ras_n_i,
      zs_we_n => pin_we_n_i,

      zs_dq => pin_sData_i);
end architecture;
