library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.vga_controller_pckg.all;

entity test_VGA_controller is
end test_VGA_controller;

architecture behavior of test_VGA_controller is
    -- declare inputs and initialize them
    signal clk       : std_logic := '0';  -- 50 MHz clock
    signal reset     : std_logic := '1';  -- reset signal

    -- declare outputs
    signal hs        : std_logic;  -- Horizontal sync pulse.  Active low
    signal vs        : std_logic;  -- Vertical sync pulse.  Active low
    signal pixel_clk : std_logic;  -- 25 MHz pixel clock
    signal blank     : std_logic;  -- Blanking interval indicator.  Active low.
    signal sync      : std_logic;  -- Composite Sync signal.  Active low.  We don't use it in this lab,
                                   --   but the video DAC on the DE2 board requires an input for it.
    signal DrawX     : std_logic_vector(9 downto 0);   -- horizontal coordinate
    signal DrawY     : std_logic_vector(9 downto 0); -- vertical coordinate

    -- Clock period definitions
    constant clk_period : time := 20 ns;
    
begin
    uut : vga_controller port map (
            clk => clk,
            reset => reset,
            hs => hs,
            vs => vs,
            pixel_clk => pixel_clk,
            blank => blank,
            sync => sync,
            DrawX => DrawX,
            DrawY => DrawY
    );

    -- Clock process definitions( clock with 50% duty cycle is generated here.
    clk_proc : process
    begin
        clk <= '0';
        wait for clk_period/2;  --for 0.5 ns signal is '0'.
        clk <= '1';
        wait for clk_period/2;  --for next 0.5 ns signal is '1'.
    end process;

    -- Stimulus process
    Stimulus_proc : process
    begin
        wait for 10 ns;
        reset <= '0';
        wait;

    end process;

end behavior;

