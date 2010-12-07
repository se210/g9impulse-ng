---------------------------------------------------------------------------
--    Color_Mapper.vhd                                                   --
--    Stephen Kempf                                                      --
--    3-1-06                                                             --
--									 --
--    Modified by David Kesler - 7-16-08				 --
--                                                                       --
--    Fall 2007 Distribution                                             --
--                                                                       --
--    For use with ECE 385 Lab 9                                         --
--    UIUC ECE Department                                                --
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity Color_Mapper is
   Port ( DrawX : in std_logic_vector(9 downto 0);
          DrawY : in std_logic_vector(9 downto 0);
          R_in : in std_logic_vector(1 downto 0);
          G_in : in std_logic_vector(1 downto 0);
          B_in : in std_logic_vector(1 downto 0);
          
          Red   : out std_logic_vector(1 downto 0);
          Green : out std_logic_vector(1 downto 0);
          Blue  : out std_logic_vector(1 downto 0);
          visible: out std_logic);
end Color_Mapper;

architecture Behavioral of Color_Mapper is

signal game_on : std_logic; --signal that determines if the game screen is to be displayed
constant game_x_max : std_logic_vector(9 downto 0) := CONV_STD_LOGIC_VECTOR(319, 10);  --maximum pixel coordinate of X axis
constant game_y_max : std_logic_vector(9 downto 0) := CONV_STD_LOGIC_VECTOR(239, 10);  --maximum line number of Y axis

begin

visible <= game_on;

game_on_proc : process (DrawX, DrawY)
begin
	if((DrawX >= 0) and (DrawX < 320) and (DrawY >= 0) and (DrawY < 240)) then
		game_on <= '1';
	else
		game_on <= '0';
	end if;
end process;

  RGB_Display : process (DrawX, DrawY)
  begin
    if (game_on = '1') then
      Red <= R_in;
      Green <= G_in;
      Blue <= B_in;
    else          -- gradient background
--      Red   <= "0" & DrawX(4 downto 0) & "0000";
--      Green <= "0" & DrawY(5 downto 0) & "000";
--      Blue  <= '0' & DrawX(9 downto 1);
--		Red <= DrawX(1 downto 0);
--		Green <= DrawY(7 downto 6);
--		Blue <= DrawX(4 downto 3);
        Red <= "00";
        Green <= "00";
        Blue <= "11";
    end if;
  end process RGB_Display;

end Behavioral;
