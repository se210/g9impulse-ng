library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity memtest is
    port(rvalid: in std_logic;
	     waitreq : in std_logic;
	     reset: in std_logic;
         start: in std_logic;
         clk : in std_logic;
         data_in : in std_logic_vector(15 downto 0);
		 skip_write : in std_logic;
			
         rd : out std_logic;
         wr : out std_logic;
         rst : out std_logic;
         addr : out std_logic_vector(21 downto 0);
         be_n : out std_logic_vector(1 downto 0);
         cs : out std_logic;
         data_out: out std_logic_vector(15 downto 0);
         errcnt: out std_logic_vector(23 downto 0);
		 state_num: out std_logic_vector(3 downto 0));
end entity memtest;

architecture behavior of memtest is
    type testState is
        (INIT_W, WRITE_S, WRITE_INC, WRITE_CHK, INIT_R, READ_S, READ_INC, REST);
    signal state_cur, state_nxt: testState;

    signal cnt :std_logic_vector(23 downto 0);
    signal addr_cnt: std_logic_vector(21 downto 0);
    signal en_cnt:std_logic;
	signal skip_wrt : std_logic;
	signal state_num_internal : std_logic_vector(3 downto 0);
	signal to_data_out : std_logic_vector(15 downto 0);

begin
    --Wires connection

	skip_wrt <= skip_write;
    rst <= reset;
    errcnt <= cnt;
    addr <= addr_cnt;
    data_out <= addr_cnt(15 downto 0);
    be_n <= "00";
    cs <= '1';
	state_num <= state_num_internal;

    control_reg: process (reset, clk, skip_wrt)
    begin
        if(reset ='1') then
            state_cur<=INIT_W;
		  elsif (skip_wrt = '1') then
				state_cur<=INIT_R;
        elsif (rising_edge(clk)) then
            state_cur<=state_nxt;
        end if;
    end process;

    address_cnt:process (state_cur, clk)
    begin
        if(state_cur=INIT_W or state_cur=INIT_R) then
            addr_cnt<= conv_std_logic_vector(0,22);
        elsif (rising_edge(clk)) then
            if(state_cur=WRITE_INC or state_cur=READ_INC) then
                addr_cnt<=addr_cnt+1;
            else
                addr_cnt<=addr_cnt;
            end if;
        end if;
    end process;

    error_cnt: process(state_cur, clk, addr_cnt, data_in)
    begin
        if(state_cur=INIT_W) then
            cnt<= conv_std_logic_vector(0,24);
        elsif (rising_edge(clk)) then
            if (state_cur= READ_INC) then
            --currently valid data is at the previous address in SDRAM
				if(rvalid='1') then
					if ((addr_cnt(7 downto 0)-1) /= data_in(7 downto 0)) then
						cnt<=cnt+1;
					end if;
            end if;
        end if;
    end process;
	 
    next_state: process (state_cur, start, waitreq, rvalid, addr_cnt)
    begin
        case state_cur is
            when INIT_W => 
                rd <= '0';
                wr <= '0';
                if (start ='1') then 
                    state_nxt<= WRITE_S;
                else 
                    state_nxt<= INIT_W;
                end if;
					 state_num_internal <= x"0";
            when WRITE_S =>
                rd <= '0';
                wr <= '1';
				--data_out <= x"ABCD";
					 --we need to keep outputting current address if waitreq is high
                if (waitreq = '1') then
                    state_nxt<= WRITE_S;
                else
                    state_nxt<= WRITE_INC;
                end if;
					 state_num_internal <= x"1";
            when WRITE_INC=>
                rd <= '0';
                wr <= '1';
					 state_nxt<=WRITE_CHK;
					 state_num_internal <= x"2";
			   when WRITE_CHK=>
				 rd <= '0';
				 wr <= '1';
				 if (addr_cnt = x"3FFFFF") then
					state_nxt<=INIT_R;
				 else
					state_nxt<=WRITE_S;
				 end if;
				 state_num_internal <= x"3";
            when INIT_R =>
                rd <= '0';
                wr <= '0';
					 if (start ='1') then 
                    state_nxt<= READ_S;
                else 
                    state_nxt<= INIT_R;
                end if;
					 state_num_internal <= x"4";
            when READ_S =>
                rd <= '1';
                wr <= '0';
                --if (rvalid='1' and waitreq='0') then
					 --we need to keep outputting current address if waitreq is high
				if (waitreq='1') then
                    state_nxt<= READ_S;
                else
                    state_nxt<= READ_INC;
                end if;
					 state_num_internal <= x"5";
            when READ_INC=>
                rd <= '1';
                wr <= '0';
                if (addr_cnt = x"3FFFFF") then
                    state_nxt<= REST;
	                else
                    state_nxt<=READ_S;
                end if;
					 state_num_internal <= x"6";
            when REST=>
                rd <= '1';
                wr <= '0';
                state_nxt<= REST;
				state_num_internal <= x"7";
        end case;
    end process;
end architecture behavior;
