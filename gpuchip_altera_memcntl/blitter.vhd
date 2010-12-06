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
                addr    : out std_logic_vector(21 downto 0);
                be_n    : out std_logic_vector(1 downto 0);
                sdram_in: out std_logic_vector(15 downto 0);
                rd      : out std_logic;
                wr      : out std_logic;
                -- signals from SDRAM
                sdram_out   : in std_logic_vector(15 downto 0);
                valid       : in std_logic;
                waitrequest : in std_logic;
                rd_pending  : in std_logic;
                -- signals from gpuchip
                blit_begin      : in std_logic;
                source_address  : in std_logic_vector(21 downto 0);
                target_address  : in std_logic_vector(21 downto 0);
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.common.all;
use work.fifo_cc_pckg.all;

entity blitter is
    port (
            clk     : in std_logic;
            reset   : in std_logic;
            -- signals to SDRAM
            addr    : out std_logic_vector(21 downto 0);
            be_n    : out std_logic_vector(1 downto 0);
            sdram_in: out std_logic_vector(15 downto 0);
            rd      : out std_logic;
            wr      : out std_logic;
            -- signals from SDRAM
            sdram_out   : in std_logic_vector(15 downto 0);
            valid       : in std_logic;
            waitrequest : in std_logic;
            rd_pending  : in std_logic;
            -- signals from gpuchip
            blit_begin      : in std_logic;
            source_address  : in std_logic_vector(21 downto 0);
            target_address  : in std_logic_vector(21 downto 0);
            source_lines    : in std_logic_vector(7 downto 0);
            line_size       : in std_logic_vector(7 downto 0);
            alpha_op        : in std_logic;
            front_buffer    : in std_logic;
            -- signals to gpuchip
            blit_done   : out std_logic
        );
end blitter;

architecture behavior of blitter is
    type blitState is (
        STANDBY,
        INIT,
        INIT_LINE,
        READ1,
        EMPTY_PIPE,
        WRITE1,
        WRITE2,
        STOP
    );
    signal state_r, state_x : blitState;

    -- registers
    signal addr_r, addr_x : unsigned(addr'range);
    signal s_addr_r, s_addr_x : std_logic_vector(21 downto 0);
    signal t_addr_r, t_addr_x : std_logic_vector(21 downto 0);

    signal current_line_r, current_line_x   : std_logic_vector(7 downto 0);
    signal current_count_r, current_count_x : std_logic_vector(7 downto 0);
    signal line_size_r, line_size_x         : std_logic_vector(7 downto 0);
    signal data_r, data_x   : std_logic_vector(15 downto 0);
    signal be_r, be_x       : std_logic_vector(1 downto 0);

    -- internal signals
    signal rd_q     : std_logic;
    signal wr_q     : std_logic;
    signal wr_q_en  : std_logic;
    signal empty_q  : std_logic;
    signal level_q  : std_logic_vector(7 downto 0);
    signal reset_q  : std_logic;
    signal out_q    : std_logic_vector(15 downto 0);

    function blend(data : std_logic_vector(15 downto 0); alpha_op : std_logic) return std_logic_vector is
        variable byte_enable : std_logic_vector(1 downto 0) := "11";
    begin
        if (alpha_op = '1') then
            if (data(15 downto 0) = x"E7") then
                byte_enable(1) := NO;
            end if;

            if (data(7 downto 0) = x"E7") then
                byte_enable(0) := NO;
            end if;
        end if;
        return not byte_enable;
    end function blend;
    
begin
    pixel_queue : fifo_cc
    port map (
                clk => clk,
                rst => reset_q,
                rd => rd_q,
                wr => wr_q,
                data_in => sdram_out,
                data_out => out_q,
                full => open,
                empty => empty_q,
                level => level_q
            );

    -- connect internal registers to external busses
    addr <= conv_std_logic_vector(addr_r, 22);
    be_n <= not be_r;
    sdram_in <= out_q;

    -- write to queue when read done
    wr_q <= valid and wr_q_en;

    combinatorial : process(state_r, addr_r, current_line_r,
                            current_count_r, s_addr_r, t_addr_r,
                            waitrequest, valid, source_address,
                            target_address, empty_q, source_lines,
                            line_size, line_size_r,
                            alpha_op, level_q, blit_begin, front_buffer)
    begin
        -- default operations and register maintenance
        rd          <= NO;
        wr          <= NO;
        rd_q        <= NO;
        wr_q_en     <= NO;
        reset_q     <= NO;
        blit_done   <= NO;

        addr_x      <= addr_r;
        s_addr_x    <= s_addr_r;
        t_addr_x    <= t_addr_r;

        current_line_x  <= current_line_r;
        current_count_x <= current_count_r;
        line_size_x     <= line_size_r;
        data_x          <= data_r;
        be_x            <= be_r;
        state_x			<= state_r;
        

        case state_r is
            when STANDBY =>
                if (blit_begin = YES) then
                    state_x <= INIT;
                end if;

            when INIT =>
                if (front_buffer = YES) then
                    t_addr_x <= target_address;
                else
                    t_addr_x <= target_address + x"0E000";
                end if;

                s_addr_x        <= source_address;
                line_size_x     <= line_size;
                current_line_x  <= x"00";
                current_count_x <= x"00";
                reset_q <= YES;
                state_x <= INIT_LINE;

            when INIT_LINE =>
                addr_x          <= unsigned(s_addr_r);
                current_count_x <= x"00";
                state_x         <= READ1;

            when READ1 =>
                rd <= YES;
                wr_q_en <= YES;

                if (waitrequest = NO) then
                    addr_x <= addr_r + 1;
                    current_count_x <= current_count_r + 1;
                end if;

                if (current_count_r = line_size_r) then
                    state_x <= EMPTY_PIPE;
                end if;

            when EMPTY_PIPE =>
                wr_q_en <= YES;
                if (rd_pending = NO) then
                    current_count_x <= x"00";
                    addr_x <= unsigned(t_addr_r);
                    state_x <= WRITE1;
                end if;

            when WRITE1 =>
                current_count_x <= x"00";
                rd_q <= YES;

                be_x <= blend(out_q, alpha_op);

                state_x <= WRITE2;

            when WRITE2 =>
                wr <= YES;

                if (waitrequest = NO) then
                    rd_q <= YES;

                    be_x <= blend(out_q, alpha_op);

                    if (empty_q = NO) then
                        addr_x <= addr_r + 1;
                        current_count_x <= current_count_r + 1;
                    else
                        current_line_x <= current_line_r + 1;
                        state_x <= STOP;
                    end if;
                end if;

            when others =>
                if (current_line_r = source_lines) then
                    blit_done <= YES;
                else
                    current_count_x <= x"00";
                    s_addr_x <= s_addr_r + x"000A0";
                    t_addr_x <= t_addr_r + x"000A0";                            
                    reset_q <= YES;
                    state_x <= INIT_LINE;
                end if;
        end case;

    end process combinatorial;

    update : process (clk, reset)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
				state_r <= STANDBY;
			else
				addr_r <= addr_x;
				s_addr_r <= s_addr_x;
				t_addr_r <= t_addr_x;

				current_line_r <= current_line_x;
				current_count_r <= current_count_x;
				line_size_r <= line_size_x;
				data_r <= data_x;
				be_r <= be_x;
				state_r <= state_x;
			end if;
        end if;
    end process update;

end behavior;
