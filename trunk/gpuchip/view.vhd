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
           Reset : in std_logic;
           wr : in  std_logic;    -- write-enable for pixel buffer
           pixel_data_in   : in  std_logic_vector(15 downto 0);  -- input databus to pixel buffer

		   eof             : out std_logic;    -- end of vga frame
		   full            : out std_logic;    -- pixel buffer full           
           Red   : out std_logic_vector(1 downto 0);
           Green : out std_logic_vector(1 downto 0);
           Blue  : out std_logic_vector(1 downto 0);
           VGA_clk : out std_logic; 
           sync : out std_logic;
           blank : out std_logic;
           vs : out std_logic;
           hs : out std_logic);
    end component view;
end package view_pckg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity view is
    Port ( Clk : in std_logic;
           Reset : in std_logic;
           wr : in  std_logic;    -- write-enable for pixel buffer
           pixel_data_in   : in  std_logic_vector(15 downto 0);  -- input databus to pixel buffer

		   eof             : out std_logic;    -- end of vga frame
		   full            : out std_logic;    -- pixel buffer full           
           Red   : out std_logic_vector(1 downto 0);
           Green : out std_logic_vector(1 downto 0);
           Blue  : out std_logic_vector(1 downto 0);
           VGA_clk : out std_logic; 
           sync : out std_logic;
           blank : out std_logic;
           vs : out std_logic;
           hs : out std_logic);
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
          Blue  : out std_logic_vector(1 downto 0));
end component;

signal rst, vsSig : std_logic;
signal DrawXSig, DrawYSig : std_logic_vector(9 downto 0);
signal r,g,b : std_logic_vector(1 downto 0);
signal blank_i : std_logic
signal   eof_i        :     std_logic;
signal   fifo_rst, fifo_empty       :     std_logic;
signal   fifo_level                 :     std_logic_vector(7 downto 0);

begin

rst <= not Reset; -- The push buttons are active low

vgaSync_instance : vga_controller
   Port map(clk => clk,
            reset => rst,
            hs => hs,
            vs => vsSig,
            pixel_clk => VGA_clk,
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
            Blue => Blue);
            
fifo : fifo_cc
    port map (
      clk      => clk,
      rd       => cke_rd,
      wr       => wr,
      data_in  => pixel_data_in,
      rst      => fifo_rst,
      data_out => pixel_data_out,
      full     => open,
      empty    => fifo_empty,
      level    => fifo_level
      );
  full   <= YES when fifo_level(7 downto 3) = "11111" else NO;
            
vs <= vsSig;
blank <= blank_i;
r <= "10";
g <= "10";
b <= "10";

  eof      <= eof_i;
  fifo_rst <= eof_i or rst;             -- clear the contents of the pixel buffer at the end of every frame

  visible    <= not blank_i;    -- pixels are visible when blank is inactive 

  -- get the current pixel from the word of pixel data or read more pixel data from the buffer
  get_pixel : process(visible, pixel_data_out, pixel_data_r, rd_r, pixel_cnt, fifo_empty)
  begin
    rd_x <= NO;                         -- by default, don't read next word of pixel data from the buffer

    -- shift pixel data depending on its width so the next pixel is in the LSBs of the pixel data shift register
    case PIXEL_WIDTH is
      when 1      =>                    -- 1-bit pixels, 16 per pixel data word
        if (visible = YES) and (pixel_cnt(3 downto 0) = 0) then
          rd_x       <= YES;            -- read new pixel data from buffer every 16 clocks during visible portion of scan line
        end if;
        pixel_data_x <= "0" & pixel_data_r(15 downto 1);  -- left-shift pixel data to move next pixel to LSB
      when 2      =>                    -- 2-bit pixels, 8 per pixel data word
        if (visible = YES) and (pixel_cnt(2 downto 0) = 0) then
          rd_x       <= YES;            -- read new pixel data from buffer every 8 clocks during visible portion of scan line
        end if;
        pixel_data_x <= "00" & pixel_data_r(15 downto 2);  -- left-shift pixel data to move next pixel to LSB 
      when 4      =>                    -- 4-bit pixels, 4 per pixel data word
        if (visible = YES) and (pixel_cnt(1 downto 0) = 0) then
          rd_x       <= YES;            -- read new pixel data from buffer every 4 clocks during visible portion of scan line
        end if;
        pixel_data_x <= "0000" & pixel_data_r(15 downto 4);  -- left-shift pixel data to move next pixel to LSB 
      when 8      =>                    -- 8-bit pixels, 2 per pixel data word
        if (visible = YES) and (pixel_cnt(0 downto 0) = 0) then
          rd_x       <= YES;            -- read new pixel data from buffer every 2 clocks during visible portion of scan line
        end if;
        pixel_data_x <= "00000000" & pixel_data_r(15 downto 8);  -- left-shift pixel data to move next pixel to LSB 
      when others =>                    -- any other width, then 1 per pixel data word
        if (visible = YES) then
          rd_x       <= YES;            -- read new pixel data from buffer every clock during visible portion of scan line
        end if;
        pixel_data_x <= pixel_data_r;
    end case;

    -- store the pixel data from the buffer instead of shifting the pixel data
    -- if a read operation was initiated in the previous cycle.
    if rd_r = YES then
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
  map_pixel : process(pixel, rgb_r, blank_r)
  begin
    if NUM_RGB_BITS=2 then
    case PIXEL_WIDTH is
      when 1          =>                -- 1-bit pixels map to black or white
			  rgb_x <= (others => pixel(0));
      when 2          =>                -- 2-bit pixels map to black, 2/3 gray, 1/3 gray, and white
			  rgb_x <= pixel(1 downto 0) & pixel(1 downto 0) & pixel(1 downto 0);
      when 4          =>                -- 4-bit pixels map to 8 colors (ignore MSB)
			  rgb_x <= pixel(2) & pixel(2) & pixel(1) & pixel(1) & pixel(0) & pixel(0);
      when 8          =>                -- 8-bit pixels map directly to RGB values
        rgb_x <= pixel(7 downto 6) & pixel(4 downto 1);
      when others     =>                -- 16-bit pixels maps directly to RGB values
        rgb_x <= pixel(8) & pixel(7) & pixel(5) & pixel(4) & pixel(2) & pixel(1);
    end case;
    else -- NUM_RGB_BITS=3
    case PIXEL_WIDTH is
      when 1          =>                -- 1-bit pixels map to black or white
			  rgb_x <= (others => pixel(0));
      when 2          =>                -- 2-bit pixels map to black, 5/7 gray, 3/7 gray, and  1/7 gray
			  rgb_x <= pixel(1 downto 0) & '0' & pixel(1 downto 0) & '0' & pixel(1 downto 0) & '0';
      when 4          =>                -- 4-bit pixels map to 8 colors (ignore MSB)
			  rgb_x <= pixel(2) & pixel(2) & pixel(2) & pixel(1) & pixel(1) & pixel(1) & pixel(0) & pixel(0) & pixel(0);
      when 8          =>                -- 8-bit pixels map to RGB with reduced resolution in green component
        rgb_x <= pixel(7 downto 5) & pixel(4 downto 3) & '0' & pixel(2 downto 0);
      when others     =>                -- 16-bit pixels map directly to RGB values
        rgb_x <= pixel(8 downto 0);
    end case;
    end if;

    -- just blank the pixel if not in the visible region of the screen
    if blank_r(blank_r'high-1) = YES then
      rgb_x <= (others => '0');
    end if;

    -- break the pixel into its red, green and blue components
    --r <= rgb_r(3*NUM_RGB_BITS-1 downto 2*NUM_RGB_BITS);
    r <= "11";
    --g <= rgb_r(2*NUM_RGB_BITS-1 downto NUM_RGB_BITS);
    --b <= rgb_r(NUM_RGB_BITS-1 downto 0);
    g <= "11";
    b <= "11";
  end process map_pixel;

-- update registers
  update : process(rst, clk)
  begin
    if rst = YES then
      eof_r          <= '0';
      rd_r           <= NO;
      hsync_r        <= (others => '1');
      blank_r        <= (others => '0');
      pixel_data_r   <= (others => '0');
      rgb_r          <= (others => '0');
    elsif rising_edge(clk) then
      eof_r          <= eof_x;          -- end-of-frame signal goes at full clock rate to external system
      if cke = YES then
        rd_r         <= rd_x;
        hsync_r      <= hsync_x;
        blank_r      <= blank_x;
        pixel_data_r <= pixel_data_x;
        rgb_r        <= rgb_x;
      end if;
    end if;
  end process update;
  
  eof_proc : process(DrawYSig)
  begin
	if(rising_edge(clk)) then
		if(DrawYSig = 239) then
			eof_i <= '1';
		else
			eof_i <= '0';
		end if;
	end if;
  end process eof_proc;

end Behavioral;      
