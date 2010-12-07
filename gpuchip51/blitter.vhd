library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package blitter_pckg is
    component blitter is
        port (
                clk     : in std_logic;
                reset   : in std_logic;
                -- signals to SDRAM
                sdram_addr      : out std_logic_vector (21 downto 0);
                sdram_be_n      : out std_logic_vector (1 downto 0);
                sdram_cs        : out std_logic;
                sdram_wr_data   : out std_logic_vector (15 downto 0);
                sdram_rd_n      : out std_logic;
                sdram_wr_n      : out std_logic;
                -- signals from SDRAM
                sdram_rd_data       : in std_logic_vector (15 downto 0);
                sdram_valid         : in std_logic;
                sdram_waitrequest   : in std_logic;
                -- signals to SRAM
                sram_addr   : out std_logic_vector(17 downto 0);
                sram_dq     : inout std_logic_vector(15 downto 0);
                sram_we_n   : out std_logic;
                sram_oe_n   : out std_logic;
                sram_ub_n   : out std_logic;
                sram_lb_n   : out std_logic;
                sram_ce_n   : out std_logic;
                sram_be_n   : out std_logic_vector(1 downto 0);
                -- signals from SRAM
                sram_waitrequest    : in std_logic;
                -- signals from gpuchip
                blit_begin      : in std_logic;
                source_address  : in std_logic_vector(21 downto 0); -- SDRAM
                target_address  : in std_logic_vector(21 downto 0); -- SRAM
                source_lines    : in std_logic_vector(7 downto 0);
                line_size       : in std_logic_vector(7 downto 0);
                alpha_op        : in std_logic;
                front_buffer    : in std_logic;
                -- signals to gpuchip
                blit_done   : out std_logic
            );
    end component blitter;
end blitter_pckg;

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.common.all;
use work.blitter_fifo_pckg.all;

entity blitter is
    port (
            clk     : in std_logic;
            reset   : in std_logic;
            -- signals to SDRAM
            sdram_addr      : out std_logic_vector (21 downto 0);
            sdram_be_n      : out std_logic_vector (1 downto 0);
            sdram_cs        : out std_logic;
            sdram_wr_data   : out std_logic_vector (15 downto 0);
            sdram_rd_n      : out std_logic;
            sdram_wr_n      : out std_logic;
            -- signals from SDRAM
            sdram_rd_data       : in std_logic_vector (15 downto 0);
            sdram_valid         : in std_logic;
            sdram_waitrequest   : in std_logic;
            -- signals to SRAM
            sram_addr   : out std_logic_vector(17 downto 0);
            sram_dq     : inout std_logic_vector(15 downto 0);
            sram_we_n   : out std_logic;
            sram_oe_n   : out std_logic;
            sram_ub_n   : out std_logic;
            sram_lb_n   : out std_logic;
            sram_ce_n   : out std_logic;
            sram_be_n   : out std_logic_vector(1 downto 0);
            -- signals from SRAM
            sram_waitrequest    : in std_logic;
            -- signals from gpuchip
            blit_begin      : in std_logic;
            source_address  : in std_logic_vector(21 downto 0); -- SDRAM
            target_address  : in std_logic_vector(21 downto 0); -- SRAM
            source_lines    : in std_logic_vector(7 downto 0);
            line_size       : in std_logic_vector(7 downto 0);
            alpha_op        : in std_logic;
            front_buffer    : in std_logic;
            -- signals to gpuchip
            blit_done   : out std_logic

        );
end blitter;

architecture behavior of blitter is
    type readState is (
        STANDBY,
        INIT,
        INIT_LINE,
        READ,
        CONTINUE
    );
    signal read_state_r, read_state_x   : readState;

    type writeState is (
        STANDBY,
        INIT,
        WRITE,
        CONTINUE
    );
    signal write_state_r, write_state_x : writeState;

    -- registers
    -- FIXME
    signal read_line_r, read_line_x : std_logic_vector(7 downto 0);
    signal read_count_r, read_count_x : std_logic_vector(7 downto 0);
    signal read_addr_r, read_addr_x : std_logic_vector(21 downto 0);

    signal s_addr_r, s_addr_x   : std_logic_vector(21 downto 0);
    signal t_addr_r, t_addr_x   : std_logic_vector(21 downto 0);

    signal write_line_r, write_line_x   : std_logic_vector(7 downto 0);
    signal write_count_r, write_count_x : std_logic_vector(7 downto 0);
    signal write_addr_r, write_addr_x   : std_logic_vector(21 downto 0);
    
    signal write_addr_buf  : std_logic_vector(21 downto 0);

    -- fifo signals
    signal rd_q     : std_logic;
    signal wr_q     : std_logic;
    signal full_q   : std_logic;
    signal empty_q  : std_logic;
    signal wr_q_en  : std_logic;
    signal out_q    : std_logic_vector(15 downto 0);

    signal sdram_rd : std_logic;
    signal sram_we  : std_logic;
    signal sram_be  : std_logic_vector(1 downto 0);

    function blend(data : std_logic_vector(15 downto 0); alpha_op : std_logic) return std_logic_vector is
        variable byte_enable : std_logic_vector(1 downto 0) := "11";
    begin
        if (alpha_op = '1') then
            if (data(15 downto 8) = x"E7") then
                byte_enable(1) := NO;
            end if;

            if (data(7 downto 0) = x"E7") then
                byte_enable(0) := NO;
            end if;
        end if;
        return byte_enable;
    end function blend;
    
begin
    fifo_inst : blitter_fifo
    port map (  clock => clk,
                data => sdram_rd_data,
                rdreq => rd_q,
                wrreq => wr_q,
                almost_full => full_q,
                empty => empty_q,
                full => open,
                q => out_q,
                usedw => open
             );

    -- SDRAM outputs
    sdram_addr  <= read_addr_r(21)&read_addr_r(19 downto 8)&read_addr_r(20)&read_addr_r(7 downto 0);
    sdram_wr_n  <= '1';     -- disable writes
    sdram_be_n  <= "00";    -- enable both bytes
    sdram_cs    <= '1';     -- chip select??
    sdram_wr_data <= (others => 'Z');
    sdram_rd_n  <= not sdram_rd;

    -- SRAM outputs
    --sram_addr <= write_addr_r(17 downto 0);
    sram_addr <= write_addr_buf(17 downto 0);
    sram_oe_n <= '1';   -- no reading by blitter
    sram_ce_n <= '0';   -- chip enable??
    sram_we_n <= not sram_we;
    sram_be <= blend(out_q, alpha_op);
    sram_ub_n <= not sram_be(1);
    sram_lb_n <= not sram_be(0);
    sram_dq <= out_q;
    sram_be_n <= not sram_be;

    -- GPU outputs
    blit_done <= YES when read_state_r = CONTINUE and
                         write_state_r = CONTINUE else NO;

    -- fifo write?
    wr_q <= wr_q_en and sdram_valid;

    read_comb : process (read_state_r, s_addr_r, read_line_r, read_addr_r,
                         read_count_r, sdram_waitrequest, sdram_valid,
                         source_address, full_q, source_lines,
                         line_size, blit_begin)
    begin
        sdram_rd    <= NO;
        wr_q_en     <= NO;

        s_addr_x    <= s_addr_r;

        read_line_x     <= read_line_r;
        read_count_x    <= read_count_r;
        read_addr_x     <= read_addr_r;
        read_state_x    <= read_state_r;

        case read_state_r is
            when STANDBY =>
                if (blit_begin = YES) then
                    read_state_x <= INIT;
                end if;

            when INIT =>
                s_addr_x <= source_address;
                read_addr_x <= source_address;
                read_line_x <= x"00";
                read_count_x <= x"00";
                read_state_x <= READ;

            when READ =>
                wr_q_en <= YES;
                if (sdram_waitrequest = NO and full_q = NO) then
                    sdram_rd <= YES;

                    --read_addr_x <= read_addr_r + '1';
                    if (read_count_r = line_size - '1') then
                        read_count_x    <= x"00";
                        read_line_x     <= read_line_r + '1';
                        read_addr_x     <= s_addr_r + x"000A0";
                        s_addr_x        <= s_addr_r + x"000A0";
                    else
                        read_addr_x <= read_addr_r + '1';
                        read_count_x <= read_count_r + '1';
                    end if;
                end if;

                if (read_line_r = source_lines) then
                    sdram_rd <= NO;
                    read_state_x <= CONTINUE;
                end if;

            when others =>
                NULL;
        end case;
    end process read_comb;

    write_comb : process (write_state_r, t_addr_r, write_line_r, write_addr_r,
                          write_count_r, target_address, empty_q,
                          source_lines, line_size, blit_begin,
                          front_buffer, sram_waitrequest)
    begin
        --sram_we <= NO;
        rd_q <= NO;

        t_addr_x <= t_addr_r;

        write_line_x    <= write_line_r;
        write_count_x   <= write_count_r;
        write_addr_x    <= write_addr_r;
        write_state_x   <= write_state_r;

        case write_state_r is
            when STANDBY =>
                if (blit_begin = YES) then
                    write_state_x <= INIT;
                end if;

            when INIT =>
                t_addr_x <= target_address;
                write_addr_x <= target_address;
                write_line_x <= x"00";
                write_count_x <= x"00";
                write_state_x <= WRITE;

            when WRITE =>
                if (empty_q = NO and sram_waitrequest = NO) then
                    --sram_we <= YES;
                    rd_q <= YES;

                    --write_addr_x <= write_addr_r + '1';
                    if (write_count_r = line_size - '1') then
                        write_count_x   <= x"00";
                        write_line_x    <= write_line_r + '1';
                        write_addr_x    <= t_addr_r + x"000A0";
                        t_addr_x        <= t_addr_r + x"000A0";
                    else
                        write_addr_x    <= write_addr_r + '1';
                        write_count_x   <= write_count_r + '1';
                    end if;
                end if;

                if (write_line_r = source_lines) then
                    --sram_we <= NO;
                    write_state_x <= CONTINUE;
                end if;

            when others =>
                NULL;
        end case;
    end process write_comb;

    update : process (clk, reset, sram_waitrequest)
    begin
        if (reset = '1') then
			read_state_r <= STANDBY;
			write_state_r <= STANDBY;
		elsif (rising_edge(clk)) then
			s_addr_r <= s_addr_x;
			t_addr_r <= t_addr_x;

			read_line_r <= read_line_x;
			read_count_r <= read_count_x;
			read_addr_r <= read_addr_x;

			read_state_r <= read_state_x;
			write_state_r <= write_state_x;

			write_line_r <= write_line_x;
			write_count_r <= write_count_x;
			write_addr_r <= write_addr_x;
			write_addr_buf <= write_addr_r;
			if (sram_waitrequest = NO) then
				sram_we <= rd_q;
			end if;
        end if;
    end process update;

end behavior;
