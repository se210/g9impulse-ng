library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.common.all;
use work.sdram.all;
use work.blitter_pckg.all;
use work.sdram_pll_pckg.all;
use work.view_pckg.all;
use work.hexdriver_pckg.all;

entity new_gpuchip is
    generic (
                ADDR_WIDTH  : natural   := 22;
                SADDR_WIDTH : natural   := 12;
                DATA_WIDTH  : natural   := 16
            );
    port (
            pin_clkin   : in std_logic;
            pin_clkout  : out std_logic;
            pin_pushbtn : in std_logic;

            -- blitter port connections
            pin_port_in     : in std_logic_vector(7 downto 0);
            pin_port_addr   : in std_logic_vector(3 downto 0);
            pin_load        : in std_logic;
            pin_start       : in std_logic;
            pin_done        : out std_logic;

            -- vga port connections
            pin_red         : out std_logic_vector(9 downto 0);
            pin_green       : out std_logic_vector(9 downto 0);
            pin_blue        : out std_logic_vector(9 downto 0);
            pin_hsync       : out std_logic;
            pin_vsync       : out std_logic;
            pin_vga_clk     : out std_logic;
            pin_vga_blank   : out std_logic;
            pin_vga_sync    : out std_logic;

            -- SDRAM pin connections
            pin_sdram_clk   : out std_logic;
            pin_sdram_addr  : out std_logic_vector(SADDR_WIDTH-1 downto 0);
            pin_sdram_ba    : out std_logic_vector(1 downto 0);
            pin_sdram_cas_n : out std_logic;
            pin_sdram_cke   : out std_logic;
            pin_sdram_cs_n  : out std_logic;
            pin_sdram_dqm   : out std_logic_vector(1 downto 0);
            pin_sdram_ras_n : out std_logic;
            pin_sdram_we_n  : out std_logic;
            pin_sdram_dq    : inout std_logic_vector(DATA_WIDTH-1 downto 0);

            -- SRAM pin connections
            pin_sram_addr   : out std_logic_vector(17 downto 0);
            pin_sram_dq     : inout std_logic_vector(DATA_WIDTH-1 downto 0);
            pin_sram_we_n   : out std_logic;
            pin_sram_oe_n   : out std_logic;
            pin_sram_ub_n   : out std_logic;
            pin_sram_lb_n   : out std_logic;
            pin_sram_ce_n   : out std_logic;

            -- switches
            SW  : in std_logic_vector(17 downto 0);

            -- 7 segment display pin connections
            hex0 : out std_logic_vector(6 downto 0);
            hex1 : out std_logic_vector(6 downto 0);
            hex2 : out std_logic_vector(6 downto 0);
            hex3 : out std_logic_vector(6 downto 0);
            hex4 : out std_logic_vector(6 downto 0);
            hex5 : out std_logic_vector(6 downto 0);
            hex6 : out std_logic_vector(6 downto 0);
            hex7 : out std_logic_vector(6 downto 0)
        );
end new_gpuchip;

architecture behavior of new_gpuchip is
    constant YES    : std_logic := '1';
    constant NO     : std_logic := '0';
    constant HI     : std_logic := '1';
    constant LO     : std_logic := '0';

    type gpuState is (
        INIT,
        LOAD,
        DRAW,
        REST
    );
    signal state_r, state_x : gpuState;

    -- registers
    signal source_address_r, source_address_x
        : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal target_address_r, target_address_x
        : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal source_lines_r, source_lines_x       : std_logic_vector(7 downto 0);
    signal line_size_r, line_size_x             : std_logic_vector(7 downto 0);
    signal alpha_op_r, alpha_op_x               : std_logic;
    signal front_buffer_r, front_buffer_x       : std_logic;
    signal idle_r, idle_x                       : std_logic;
    signal db_enable_r, db_enable_x             : std_logic;
    signal field_color_r, field_color_x         : std_logic_vector(7 downto 0);
    
    -- internal signals
    signal sys_reset        : std_logic;
    signal blit_reset       : std_logic;
    signal reset_blitter    : std_logic;
    signal reset            : std_logic;
    signal reset_n          : std_logic;
    signal not_fb           : std_logic;

    -- blitter signals
    signal blit_begin           : std_logic;
    signal source_address       : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal source_lines         : std_logic_vector (7 downto 0);
    signal line_size            : std_logic_vector (7 downto 0);
    signal target_address       : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal blit_done            : std_logic;    
    signal alpha_op             : std_logic;
    signal front_buffer         : std_logic;

    -- blitter SDRAM signals
    signal sdram_addr       : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal sdram_be_n       : std_logic_vector(1 downto 0);
    signal sdram_cs         : std_logic;
    signal sdram_wr_data    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sdram_rd_n       : std_logic;
    signal sdram_wr_n       : std_logic;
    signal sdram_rd_data    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sdram_valid      : std_logic;
    signal sdram_waitrequest: std_logic;

    -- SRAM signals between blitter and view
    signal sram_wr          : std_logic;
    signal sram_wr_n        : std_logic;
    signal sram_wr_addr     : std_logic_vector(17 downto 0);
    signal sram_wr_be_n     : std_logic_vector(1 downto 0);

    -- view signals
    signal view_sof         : std_logic;
    signal view_eof         : std_logic;
    signal view_field_color : std_logic_vector(7 downto 0);
    signal view_red         : std_logic_vector(1 downto 0);
    signal view_green       : std_logic_vector(1 downto 0);
    signal view_blue        : std_logic_vector(1 downto 0);
    signal view_visible_out : std_logic;
    signal view_wait_request: std_logic;
    signal pixel_data_in    : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal port_in          : std_logic_vector (7 downto 0);
    signal port_addr        : std_logic_vector (3 downto 0);

    -- clock signals
    signal clk0 : std_logic;    -- phase shifted clock from PLL
    signal clk1 : std_logic;    -- normal clock from PLL
begin
    -------------------------------------------------------------------
    -- PLL
    -------------------------------------------------------------------
    pll_inst : sdram_pll
    port map (
                inclk0  => pin_clkin,
                c0      => clk0,
                c1      => clk1,
                c2      => open
            );
    pin_clkout <= clk1;

    -------------------------------------------------------------------
    -- view
    -------------------------------------------------------------------
    view_inst : view
    port map (
                Clk             => clk1,
                nReset          => reset_n,
                field_color     => view_field_color,
                sof             => view_sof,
                eof             => view_eof,
                Red             => view_red,
                Green           => view_green,
                Blue            => view_blue,
                VGA_clk         => pin_vga_clk,
                sync            => pin_vga_sync,
                blank           => pin_vga_blank,
                vs              => pin_vsync,
                hs              => pin_hsync,
                visible_out     => view_visible_out,
                --SRAM interace
                wr              => sram_wr,
                wr_addr         => sram_wr_addr,
                wr_be_n         => sram_wr_be_n,
                wait_request    => view_wait_request,
                pixel_data_in   => pixel_data_in,
                pin_sram_addr   => pin_sram_addr,
                pin_sram_dq     => pin_sram_dq,
                pin_sram_we_n   => pin_sram_we_n,
                pin_sram_oe_n   => pin_sram_oe_n,
                pin_sram_ub_n   => pin_sram_ub_n,
                pin_sram_lb_n   => pin_sram_lb_n,
                pin_sram_ce_n   => pin_sram_ce_n
             );
    pin_red         <= view_red     & x"00";
    pin_green       <= view_green   & x"00";
    pin_blue        <= view_blue    & x"00";

    -------------------------------------------------------------------
    -- blitter
    -------------------------------------------------------------------
    blitter_inst : blitter
    port map (
                 clk                => clk1,
                 reset              => blit_reset,
                 -- signals to SDRAM
                 sdram_addr         => sdram_addr,
                 sdram_be_n         => sdram_be_n,
                 sdram_cs           => sdram_cs,
                 sdram_wr_data      => sdram_wr_data,
                 sdram_rd_n         => sdram_rd_n,
                 sdram_wr_n         => sdram_wr_n,
                 -- signals from SDRAM
                 sdram_rd_data      => sdram_rd_data,
                 sdram_valid        => sdram_valid,
                 sdram_waitrequest  => sdram_waitrequest,
                 -- signals to SRAM
                 sram_addr          => sram_wr_addr,
                 sram_dq            => pixel_data_in,
                 sram_we_n          => sram_wr_n,
                 sram_oe_n          => open,
                 sram_ub_n          => open,
                 sram_lb_n          => open,
                 sram_ce_n          => open,
                 sram_be_n          => sram_wr_be_n,
                 -- signals from SRAM
                 sram_waitrequest   => view_wait_request,
                 -- signals from gpuchip
                 blit_begin         => blit_begin,
                 source_address     => source_address,
                 target_address     => target_address,
                 source_lines       => source_lines,
                 line_size          => line_size,
                 alpha_op           => alpha_op,
                 front_buffer       => not_fb,
                 -- signals to gpuchip
                 blit_done          => blit_done
             );
    sram_wr         <= not sram_wr_n;

    -------------------------------------------------------------------
    -- SDRAM controller
    -------------------------------------------------------------------
    sdramcntl_inst : sdram_0
    port map (
                -- inputs
                az_addr     => sdram_addr,
                az_be_n     => sdram_be_n,
                az_cs       => sdram_cs,
                az_data     => sdram_wr_data,
                az_rd_n     => sdram_rd_n,
                az_wr_n     => sdram_wr_n,
                clk         => clk1,
                reset_n     => reset_n,
                -- outputs
                za_data     => sdram_rd_data,
                za_valid    => sdram_valid,
                za_waitrequest => sdram_waitrequest,
                zs_addr     => pin_sdram_addr,
                zs_ba       => pin_sdram_ba,
                zs_cas_n    => pin_sdram_cas_n,
                zs_cke      => pin_sdram_cke,
                zs_cs_n     => pin_sdram_cs_n,
                zs_dq       => pin_sdram_dq,
                zs_dqm      => pin_sdram_dqm,
                zs_ras_n    => pin_sdram_ras_n,
                zs_we_n     => pin_sdram_we_n
            );
    pin_sdram_clk <= clk0;

    -------------------------------------------------------------------
    -- End of Sub Modules
    -------------------------------------------------------------------

    reset       <= not pin_pushbtn;
    reset_n     <= pin_pushbtn;
    blit_reset  <= reset or reset_blitter;

    port_in     <= pin_port_in;
    port_addr   <= pin_port_addr;
    pin_done    <= idle_r;

    source_address  <= source_address_r;
    line_size       <= line_size_r;
    target_address  <= target_address_r;
    source_lines    <= source_lines_r;
    alpha_op        <= alpha_op_r;
    front_buffer    <= front_buffer_r when db_enable_r = YES else YES;
    not_fb          <= (not front_buffer_r) when db_enable_r = YES else YES;

    combinatorial : process (state_r, port_in, port_addr, pin_start)
    begin
        -- default operations
        blit_begin      <= NO;
        reset_blitter   <= NO;

        -- default register values
        state_x             <= state_r;
        source_address_x    <= source_address_r;
        target_address_x    <= target_address_r;
        source_lines_x      <= source_lines_r;
        line_size_x         <= line_size_r;
        alpha_op_x          <= alpha_op_r;
        db_enable_x         <= db_enable_r;
        front_buffer_x      <= front_buffer_r;
        idle_x              <= idle_r;

        case state_r is
            when INIT =>
                idle_x <= YES;
                reset_blitter <= YES;
                state_x <= LOAD;

            when LOAD =>
--                if (pin_load = YES) then
--                    case port_addr is 
--                        when "0000" =>
--                            source_address_x(21 downto 16)  <= port_in(5 downto 0);
--                        when "0001" =>
--                            source_address_x(15 downto 8)   <= port_in; 
--                        when "0010" =>
--                            source_address_x(7 downto  0)   <= port_in;
--                        when "0011" =>
--                            target_address_x(21 downto 16)  <= port_in(5 downto 0);
--                        when "0100" =>
--                            target_address_x(15 downto 8)   <= port_in;
--                        when "0101" =>
--                            target_address_x(7 downto  0)   <= port_in;
--                        when "0110" =>
--                            source_lines_x                  <= port_in;
--                        when "0111" => 
--                            line_size_x                     <= port_in;
--                        when "1000" =>
--                            alpha_op_x                      <= port_in(0);
--                        when "1001" =>
--                            db_enable_x                     <= port_in(0);
--                        when "1010" =>
--                            front_buffer_x                  <= port_in(0);
--                        when others =>
--                            NULL;
--                    end case;                
--                end if;
				--source_address_x <= "11"&x"6CFE0";
				--source_address_x <= "10"&x"22E00";
				--source_address_x <= "00"&x"CC740";
				source_address_x <= "00"&x"D14E4";
				target_address_x <= "00"&x"04030";
				--target_address_x <= (others => '0');
				source_lines_x <= conv_std_logic_vector(10,8);
				line_size_x <= conv_std_logic_vector(5,8);
				alpha_op_x <= '0';

--                if (pin_start = YES) then
--                    idle_x  <= NO;
--                    state_x <= DRAW;
--                end if;
				idle_x <= NO;
				state_x <= DRAW;

            when DRAW =>
                blit_begin <= YES;
                if (blit_done = YES) then
                    reset_blitter <= YES;
                    idle_x <= YES;
                    state_x <= REST;
                end if;

            when REST =>
                reset_blitter <= YES;
                state_x <= LOAD;

        end case;
    end process combinatorial;

    update : process (clk1)
    begin
        if rising_edge(clk1) then
            if (reset = YES) then
                state_r <= INIT;
            end if;

            state_r             <= state_x;
            source_address_r    <= source_address_x;
            target_address_r    <= target_address_x;
            source_lines_r      <= source_lines_x;
            line_size_r         <= line_size_x;
            alpha_op_r          <= alpha_op_x;
            front_buffer_r      <= front_buffer_x;
            db_enable_r         <= db_enable_x;
            idle_r              <= idle_x;
        end if;
            
    end process update;
    
end behavior;
