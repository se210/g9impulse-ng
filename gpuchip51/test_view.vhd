library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use work.view_pckg.all;

entity test_view is
end test_view;

architecture behavior of test_view is
    -- declare inputs and initialize them
    signal Clk              : std_logic := '0';
    signal Reset            : std_logic := '0';
    signal wr               : std_logic := '0';    -- write-enable for pixel buffer
    signal pixel_data_in    : std_logic_vector(15 downto 0) := x"0000"; -- input databus to pixel buffer
    signal field_color 	    : std_logic_vector(7 downto 0)  := x"00";

    -- declare outputs
    signal eof              : std_logic;    -- end of vga frame
    signal full             : std_logic;    -- pixel buffer full           
    signal Red              : std_logic_vector(1 downto 0);
    signal Green            : std_logic_vector(1 downto 0);
    signal Blue             : std_logic_vector(1 downto 0);
    signal VGA_clk          : std_logic; 
    signal sync             : std_logic;
    signal blank            : std_logic;
    signal vs               : std_logic;
    signal hs               : std_logic;

    -- Clock period definitions
    constant clk_period : time := 20 ns;
    
begin
    uut : view port map (
            Clk => Clk,
            Reset => Reset,
            wr => wr,
            pixel_data_in => pixel_data_in,
            field_color => field_color,
		    eof => eof,
		    full => full,
            Red => Red,
            Green => Green,
            Blue => Blue ,
            VGA_clk => VGA_clk,
            sync => sync,
            blank => blank,
            vs => vs,
            hs => hs
    );

    -- Clock process definitions( clock with 50% duty cycle is generated here.
    clk_proc : process
    begin
        Clk <= '0';
        wait for clk_period/2;  --for 0.5 ns signal is '0'.
        Clk <= '1';
        wait for clk_period/2;  --for next 0.5 ns signal is '1'.
    end process;

    -- Stimulus process
    Stimulus_proc : process
    begin
        wait for 10 ns;
        Reset <= '1';
        wait for 20 ns;
        pixel_data_in <= x"0123";
        wr <= '1';
        wait for 160 ns;
        wait for 20 ns;
        wr <= '0';
        wait for 20 ns;
        pixel_data_in <= x"3210";
        wr <= '1';
        wait for 20 ns;
        wr <= '0';
        wait;

    end process;

end behavior;
