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
use WORK.fifo_cc_pckg.ALL;

package view_pckg is
	component view is
    Port ( Clk : in std_logic;
           Reset : in std_logic;
           wr : in  std_logic;    -- write-enable for pixel buffer
           pixel_data_in   : in  std_logic_vector(15 downto 0);  -- input databus to pixel buffer
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
           visible_out : out std_logic);
    end component view;
end package view_pckg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use WORK.fifo_cc_pckg.ALL;

entity view is
    Port ( Clk : in std_logic;
           Reset : in std_logic;
           wr : in  std_logic;    -- write-enable for pixel buffer
           pixel_data_in   : in  std_logic_vector(15 downto 0);  -- input databus to pixel buffer
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
           visible_out : out std_logic);
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
signal eof_i : std_logic;
signal fifo_rst, fifo_empty : std_logic;
signal fifo_level : std_logic_vector(7 downto 0);
signal   cke                        :     std_logic;
signal cke_rd, rd_x, rd_r : std_logic;
signal pixel_clk : std_logic;
signal   pixel                      :     std_logic_vector(7 downto 0);
signal   pixel_data_x, pixel_data_r :     std_logic_vector(15 downto 0);
signal   pixel_data_out             :     std_logic_vector(15 downto 0);
signal   rgb_x, rgb_r               :     std_logic_vector(5 downto 0);
signal visible : std_logic;
signal   clk_div_cnt                :     unsigned(7 downto 0);

begin

visible_out <= visible;
rst <= not Reset; -- The push buttons are active low
--cke<='1';
--process(clk, rst)
--  begin
--    if rst = '1' then
--      clk_div_cnt   <= (others => '0');
--      cke           <= '1';
--    elsif rising_edge(clk) then
--      if clk_div_cnt = 1 then
--        clk_div_cnt <= (others => '0');
--        cke         <= '1';
--      else
--        clk_div_cnt <= clk_div_cnt + 1;
--        cke         <= '0';
--      end if;
--    end if;
--end process;

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

  -- pixel data buffer
   cke_rd <= rd_x and cke;
          
fifo : fifo_cc
    port map (
      clk      => clk,
      rd       => cke_rd,
      wr       => wr,
      data_in  => pixel_data_in,
      rst      => fifo_rst,
      data_out => pixel_data_out,
      full     => full,
      empty    => fifo_empty,
      level    => fifo_level
      );
  --full   <= '1' when fifo_level(7 downto 3) = "11111" else '0';
            
vs <= vsSig;
blank <= blank_i;
VGA_clk <= pixel_clk;
cke <= pixel_clk;

  eof      <= eof_i;
  fifo_rst <= eof_i or rst;             -- clear the contents of the pixel buffer at the end of every frame

  -- get the current pixel from the word of pixel data or read more pixel data from the buffer
  get_pixel : process(visible, pixel_data_out, pixel_data_r, rd_r, DrawXSig, fifo_empty)
  begin
    rd_x <= '0';                         -- by default, don't read next word of pixel data from the buffer

    -- shift pixel data depending on its width so the next pixel is in the LSBs of the pixel data shift register
    -- 8-bit pixels, 2 per pixel data word
    if (visible = '1') and (DrawXSig(0) = '0') then
      rd_x       <= '1';            -- read new pixel data from buffer every 2 clocks during visible portion of scan line
    end if;
    pixel_data_x <= "00000000" & pixel_data_r(15 downto 8);  -- left-shift pixel data to move next pixel to LSB 

    -- store the pixel data from the buffer instead of shifting the pixel data
    -- if a read operation was initiated in the previous cycle.
    if rd_r = '1' then
	 	if fifo_empty = '1' then							--ERIC
			pixel_data_x <= field_color & field_color;--ERIC
		else														--ERIC
     		pixel_data_x <= pixel_data_out;
	   end if;													--ERIC
    end if;

    -- the current pixel is in the lower bits of the pixel data shift register
    	pixel <= pixel_data_r(pixel'range);
  end process get_pixel;

  -- map the current pixel to RGB values
  map_pixel : process(pixel, rgb_r, visible)
  begin
    -- 8-bit pixels map directly to RGB values
    rgb_x <= pixel(7 downto 6) & pixel(4 downto 1);

    -- just blank the pixel if not in the visible region of the screen
    if visible = '0' then
      rgb_x <= (others => '0');
    end if;

    -- break the pixel into its red, green and blue components
    r <= rgb_r(5 downto 4);
    g <= rgb_r(3 downto 2);
    b <= rgb_r(1 downto 0);
  end process map_pixel;

-- update registers
  update : process(rst, clk)
  begin
    if rst = '1' then
      --eof_r          <= '0';
      rd_r           <= '0';
      --hsync_r        <= (others => '1');
      --blank_r        <= (others => '0');
      pixel_data_r   <= (others => '0');
      rgb_r          <= (others => '0');
    elsif falling_edge(clk) then
      --eof_r          <= eof_x;          -- end-of-frame signal goes at full clock rate to external system
      if cke = '1' then
        rd_r         <= rd_x;
        --hsync_r      <= hsync_x;
        --blank_r      <= blank_x;
        pixel_data_r <= pixel_data_x;
        rgb_r        <= rgb_x;
      end if;
    end if;
  end process update;
  
  eof_proc : process(DrawXSig,DrawYSig)
  begin
	if(rising_edge(clk)) then
		if(DrawYSig = conv_std_logic_vector(240,10) and DrawXSig = conv_std_logic_vector(320,10)) then
			eof_i <= '1';
		else
			eof_i <= '0';
		end if;
	end if;
  end process eof_proc;

end Behavioral;      
