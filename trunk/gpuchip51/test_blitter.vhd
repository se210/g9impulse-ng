library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use work.Blitter_pckg.all;

entity test_blitter is
end test_blitter;

architecture behavior of test_blitter is
    -- declare inputs and outputs and initialize them

    -- Clock period definitions
    constant clk_period : time := 20 ns;
    
begin
    uut : blitter port map (
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
        rst <= '0';
        wait;

    end process;

end behavior;

