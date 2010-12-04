---------------------------------------------------------------------------
--      BouncingBall.vhd                                                 --
--      Viral Mehta                                                      --
--      Spring 2005                                                      --
--                                                                       --
--      Modified by Stephen Kempf 03-01-2006                             --
--                                03-12-2007                             --
--      Fall 2008 Distribution                                         --
--                                                                       --
--      For use with ECE 385 Lab 9                                       --
--      UIUC ECE Department                                              --
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package view_pckg is
	component view is
    Port ( Clk : in std_logic;
           nReset : in std_logic;
           field_color 	  : in std_logic_vector(7 downto 0);

		   eof             : out std_logic;    -- end of vga frame
		   full            : out std_logic;    -- pixel buffer full           
           Red   : out std_logic_vector(1 downto 0);
           Green : out std_logic_vector(1 downto 0);
           Blue  : out std_logic_vector(1 downto 0);
           VGA_clk : out std_logic; 
           sync : out std_logic;
           blank : out std_logic;
           vs : out std_logic;
           hs : out std_logic;
           visible_out : out std_logic;
           
           --SRAM interface
           wr : in  std_logic;    -- write-enable for pixel buffer
           pixel_data_in   : in  std_logic_vector(15 downto 0);  -- input databus to pixel buffer
           pin_sram_addr : out std_logic_vector(17 downto 0);
           pin_sram_dq : inout std_logic_vector(15 downto 0);
           pin_sram_we_n : out std_logic;
           pin_sram_oe_n : out std_logic;
           pin_sram_ub_n : out std_logic;
           pin_sram_lb_n : out std_logic;
           pin_sram_ce_n : out std_logic
           );
    end component view;
end package view_pckg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity view is
    Port ( Clk : in std_logic;
           nReset : in std_logic;
           field_color 	  : in std_logic_vector(7 downto 0);

		   eof             : out std_logic;    -- end of vga frame
		   full            : out std_logic;    -- pixel buffer full           
           Red   : out std_logic_vector(1 downto 0);
           Green : out std_logic_vector(1 downto 0);
           Blue  : out std_logic_vector(1 downto 0);
           VGA_clk : out std_logic; 
           sync : out std_logic;
           blank : out std_logic;
           vs : out std_logic;
           hs : out std_logic;
           visible_out : out std_logic;
           
           --SRAM interface
           wr : in  std_logic;    -- write-enable for pixel buffer
           pixel_data_in   : in  std_logic_vector(15 downto 0);  -- input databus to pixel buffer
           pin_sram_addr : out std_logic_vector(17 downto 0);
           pin_sram_dq : inout std_logic_vector(15 downto 0);
           pin_sram_we_n : out std_logic;
           pin_sram_oe_n : out std_logic;
           pin_sram_ub_n : out std_logic;
           pin_sram_lb_n : out std_logic;
           pin_sram_ce_n : out std_logic
           );
end view;

architecture Behavioral of view is

component vga_controller is
    Port ( clk : in std_logic;
           reset : in std_logic;
           hs : out std_logic;
           vs : out std_logic;
           pixel_clk : out std_logic;
           blank : out std_logic;
           sync : out std_logic;
           DrawX : out std_logic_vector(9 downto 0);
           DrawY : out std_logic_vector(9 downto 0));
end component;

component Color_Mapper is
   Port ( DrawX : in std_logic_vector(9 downto 0);
          DrawY : in std_logic_vector(9 downto 0);
          R_in : in std_logic_vector(1 downto 0);
          G_in : in std_logic_vector(1 downto 0);
          B_in : in std_logic_vector(1 downto 0);
          
          Red   : out std_logic_vector(1 downto 0);
          Green : out std_logic_vector(1 downto 0);
          Blue  : out std_logic_vector(1 downto 0);
          visible: out std_logic);
end component;

signal rst, vsSig : std_logic;
signal DrawXSig, DrawYSig : std_logic_vector(9 downto 0);
signal r,g,b : std_logic_vector(1 downto 0);
signal blank_i : std_logic;
signal sof_i: std_logic;
signal eof_i : std_logic;
signal pixel_clk : std_logic;
signal pixel_data_out             :     std_logic_vector(15 downto 0);
signal visible : std_logic;
signal duo_pixel_r : std_logic_vector(15 downto 0);
signal current_pixel : std_logic_vector(7 downto 0);

--SRAM related signals
signal rd : std_logic;
signal full_i : std_logic;
signal rd_addr  : std_logic_vector(17 downto 0) := (others=>'0');
signal wr_addr  : std_logic_vector(17 downto 0) := (others=>'0');
signal level_i  : std_logic_vector(17 downto 0) := (others=>'0');
signal rd_allow : std_logic;
signal wr_allow : std_logic;
signal fifo_rst : std_logic;

begin

visible_out <= visible;
rst <= not nReset; -- The push buttons are active low

vgaSync_instance : vga_controller
   Port map(clk => clk,
            reset => rst,
            hs => hs,
            vs => vsSig,
            pixel_clk => pixel_clk,
            blank => blank_i,
            sync => sync,
            DrawX => DrawXSig,
            DrawY => DrawYSig);

Color_instance : Color_Mapper
   Port Map(DrawX => DrawXSig,
            DrawY => DrawYSig,
            R_in => r,
            G_in => g,
            B_in => b,
            Red => Red,
            Green => Green,
            Blue => Blue,
            visible => visible);
  
  
  --FIFO buffer implemented by SRAM
  rd_allow <= rd;
  wr_allow <= wr and not full_i;

  process (clk, rst)
  begin
    if fifo_rst = '1' then
      rd_addr   <= (others => '0');
      wr_addr   <= (others => '0');
      level_i   <= (others => '0');
    elsif rising_edge(clk) then
      if rd_allow = '1' then
        rd_addr <= rd_addr + '1';
      elsif wr_allow = '1' then
        wr_addr <= wr_addr + '1';
      end if;
      if (wr_allow and not rd_allow and not full_i) = '1' then
        level_i <= level_i + '1';
      elsif (rd_allow and not wr_allow) = '1' then
        --level_i <= level_i - '1';
      end if;
    end if;
  end process;

  full_i  <= '1' when level_i = "111111111111111111" else '0';
  full    <= full_i;
  
  
	-- memory read/write processes
	-- reading from memory has priority over writing to memory
	
	pixel_data_out <= pin_sram_dq;
	
	Mem_Write : process (wr, pixel_data_in) is
	begin
	   pin_sram_dq <= "ZZZZZZZZZZZZZZZZ";
	   if (rd = '0' and wr = '1') then
		  pin_sram_dq <= pixel_data_in;
	   else
		  null;
	   end if;
	end process;
	
  --connections to SRAM
   pin_sram_addr <= rd_addr when rd='1' else wr_addr;
   pin_sram_we_n <= not wr;
   pin_sram_oe_n <= not rd;
   pin_sram_ub_n <= '0';
   pin_sram_lb_n <= '0';
   pin_sram_ce_n <= '0';  
            
            
  --other VGA stuff
  vs <= vsSig;
  blank <= blank_i;
  VGA_clk <= pixel_clk;

  eof      <= eof_i;
  fifo_rst <= eof_i or rst;             -- clear the contents of the pixel buffer at the end of every frame

  --Wenxun wrote this, blame him
  grab_pixel : process(clk, pixel_clk, DrawXSig, rst, eof_i)
  begin
      if(rst='1' or eof_i='1') then
          duo_pixel_r<=x"0000";
      elsif falling_edge(clk) and pixel_clk='0' and DrawXSig(0)='0' then
      -- Together with the set_read process a word is read right before it's needed for the even pixel
      -- I used falling edge because that's when the other two signals are stable
		  duo_pixel_r <= pixel_data_out;
      end if;
  end process;

  set_read : process(clk, pixel_clk, DrawXSig, rst, eof_i)
  begin
      if(rst='1' or eof_i='1') then
          rd <= '0';
      elsif falling_edge(clk)  then
          if pixel_clk='0' and ((DrawXSig(0)='1' and visible='1') or sof_i='1')  then
              rd<='1';
          else 
              rd<='0';
          end if;
      end if;
  end process;

  --Not sure about Endian, probably need to be fixed later. (Now higher byte to the left of lower byte on screen)
  current_pixel<= duo_pixel_r(15 downto 8) when DrawXSig(0)='0' else duo_pixel_r(7 downto 0);
  r <= current_pixel(7 downto 6);
  g <= current_pixel(4 downto 3);
  b <= current_pixel(2 downto 1);

  -- (524, 799) is the last coordinate output from the vgasync component, which indicates the advent of the first pixel
  -- on the screen.
  sof_i <= '1' when DrawXSig = conv_std_logic_vector(799, 10) and DrawYSig = conv_std_logic_vector(524, 10) else'0';

  -- (319, 239) is the last coordinate in the frame we actually draw, so eof goes high one pixel after that
  eof_i <= '1' when DrawXSig = conv_std_logic_vector(320,10) and DrawYSig = conv_std_logic_vector(239,10) else '0';

end Behavioral;      
