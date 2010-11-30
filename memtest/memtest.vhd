library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use WORK.sdram.ALL;
use WORK.HexDriver_pckg.ALL;
use WORK.sdram_pll_pckg.ALL;

entity memtest is
    port(KEY : in std_logic_vector(3 downto 0); --reset & start
		 CLOCK_50 : in std_logic; --50MHz clk
		 SW : in std_logic_vector(17 downto 0); -- data_in
		
		--output to SDRAM
		DRAM_CLK : out std_logic;
		DRAM_CKE : out std_logic;
		DRAM_CS_N : out std_logic;
		DRAM_RAS_N : out std_logic;
		DRAM_CAS_N : out std_logic;
		DRAM_WE_N : out std_logic;
		DRAM_BA_1 : out std_logic;
		DRAM_BA_0 : out std_logic;
		DRAM_ADDR : out std_logic_vector(11 downto 0);
		DRAM_DQ : inout std_logic_vector(15 downto 0);
		DRAM_UDQM : out std_logic;
		DRAM_LDQM : out std_logic;
		
		--debug outputs
		HEX0 : out std_logic_vector(6 downto 0);
		HEX1 : out std_logic_vector(6 downto 0);
		HEX2 : out std_logic_vector(6 downto 0);
		HEX3 : out std_logic_vector(6 downto 0);
		HEX4 : out std_logic_vector(6 downto 0);
		HEX5 : out std_logic_vector(6 downto 0);
		HEX6 : out std_logic_vector(6 downto 0);
		HEX7 : out std_logic_vector(6 downto 0));
end entity memtest;

architecture behavior of memtest is
    type testState is
        (INIT_W, WRITE_S, WRITE_INC, WRITE_CHK, INIT_R, READ_S, READ_INC, READ_CHK, REST);
    signal state_cur, state_nxt: testState;
    
    signal clk : std_logic;
    signal reset : std_logic;
    signal start : std_logic;
    signal cnt :std_logic_vector(23 downto 0);
    signal addr_cnt: std_logic_vector(22 downto 0);
    signal en_cnt:std_logic;
	signal skip_wrt : std_logic;
	signal state_num : std_logic_vector(3 downto 0);
	signal data_cnt : std_logic_vector(15 downto 0);
	
	signal rd_i : std_logic;
	signal wr_i : std_logic;
	signal addr : std_logic_vector(21 downto 0);
	signal data_in : std_logic_vector(15 downto 0);
	signal data_out : std_logic_vector(15 downto 0);
	signal earlyOpBegun_i : std_logic;
	signal opBegun_i : std_logic;
	signal rdPending_i : std_logic;
	signal done_i : std_logic;
	signal rdDone_i : std_logic;

begin
    --Wires connection
    reset <= not KEY(0);
    start <= not KEY(1);
    skip_wrt <= not KEY(2);
    addr <= addr_cnt(21 downto 0);

	--Components declaration
	u1 : sdramCntl
	port map(
		-- host side input
		clk =>		clk,
		lock =>		'1',
		rst =>		reset,
		rd =>		rd_i,
		wr =>		wr_i,
		hAddr =>	addr,
		hDIn => 	data_in,
		-- host side output
		hDOut =>		data_out,
		earlyOpBegun => earlyOpBegun_i,
		opBegun => 		opBegun_i,
		rdPending =>	rdPending_i,
		done=>			done_i,
		rdDone=>		rdDone_i,
		status =>		open,
		
		-- SDRAM side
		cke =>		DRAM_CKE,
		ce_n => 	DRAM_CS_N,
		ras_n =>	DRAM_RAS_N,
		cas_n =>	DRAM_CAS_N,
		we_n =>		DRAM_WE_N,
		ba(1) =>	DRAM_BA_1,
		ba(0) =>	DRAM_BA_0,
		sAddr =>	DRAM_ADDR,
		sData =>	DRAM_DQ,
		dqmh =>		DRAM_UDQM,
		dqml =>		DRAM_LDQM);
		
	u2: HexDriver
	port map ( In0 => cnt(3 downto 0),
		   Out0 => HEX0);
	u3: HexDriver
	port map ( In0 => cnt(7 downto 4),
		   Out0 => HEX1);
	u4: HexDriver
	port map ( In0 => cnt(11 downto 8),
		   Out0 => HEX2);
	u5: HexDriver
	port map ( In0 => cnt(15 downto 12),
		   Out0 => HEX3);
	u6: HexDriver
	port map ( In0 => cnt(19 downto 16),
		   Out0 => HEX4);
	u7: HexDriver
	port map ( In0 => cnt(23 downto 20),
		   Out0 => HEX5);
	u8: HexDriver
	port map ( In0 => "0000",
		   Out0 => HEX6);
	u9: HexDriver
	port map ( In0 => state_num,
		   Out0 => HEX7);
		   
	u10: sdram_pll
	port map(
			inclk0	=> CLOCK_50,
			c0		=> DRAM_CLK,
			c1		=> clk,
			c2		=> open 
		);

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
            addr_cnt<= conv_std_logic_vector(0,23);
            data_cnt<= conv_std_logic_vector(0,16);
        elsif (rising_edge(clk)) then
            if(state_cur=WRITE_INC or state_cur=READ_INC) then
                addr_cnt<=addr_cnt+1;
            elsif(state_cur=WRITE_CHK or state_cur=READ_CHK) then
                data_cnt<=data_cnt+1;
            else
                addr_cnt<=addr_cnt;
                data_cnt<=data_cnt;
            end if;
        end if;
    end process;

    error_cnt: process(state_cur, clk, addr_cnt, data_in)
    begin
        if(state_cur=INIT_R) then
            cnt<= conv_std_logic_vector(0,24);
        elsif (rising_edge(clk)) then
            if (state_cur= READ_INC) then
				if (data_out /= data_cnt-1) then
					cnt<=cnt+1;
				end if;
            end if;
        end if;
    end process;
	 
    next_state: process (state_cur, start, done_i, rdDone_i, addr_cnt)
    begin
        case state_cur is
            when INIT_W => 
                rd_i <= '0';
                wr_i <= '0';
                if (start ='1') then 
                    state_nxt<= WRITE_S;
                else 
                    state_nxt<= INIT_W;
                end if;
				state_num <= x"0";
            when WRITE_S =>
                rd_i <= '0';
                wr_i <= '1';
                if(addr_cnt < x"000A0") then
					data_in <= x"C0C0"; -- red
				elsif(addr_cnt < x"00140") then
					data_in <= x"1818"; -- green
				elsif(addr_cnt < x"00280") then
					data_in <= x"0606"; -- blue
					
				elsif(addr_cnt < x"00320") then
					data_in <= x"1818"; -- green
				elsif(addr_cnt < x"003C0") then
					data_in <= x"0606"; -- blue
				elsif(addr_cnt < x"00460") then
					data_in <= x"FFFF"; -- white
					
				elsif((addr_cnt>= x"009560") and (addr_cnt < x"009600")) then
					data_in <= x"FFFF";
				else
					data_in <= x"1818"; -- green
				end if;
--				data_in <= addr_cnt(15 downto 0);
				--we need to keep outputting current address if done is low
                if (done_i = '0') then
                    state_nxt<= WRITE_S;
                else
                    state_nxt<= WRITE_INC;
                end if;
				state_num <= x"1";
            when WRITE_INC=>
                rd_i <= '0';
                wr_i <= '0';
				state_nxt<=WRITE_CHK;
				state_num <= x"2";
			when WRITE_CHK=>
				 rd_i <= '0';
				 wr_i <= '0';
				 if (addr_cnt < x"400000") then
					state_nxt<=WRITE_S;
				 else
					state_nxt<=INIT_R;
				 end if;
				 state_num <= x"3";
            when INIT_R =>
                rd_i <= '0';
                wr_i <= '0';
				if (start ='1') then 
                    state_nxt<= READ_S;
                else 
                    state_nxt<= INIT_R;
                end if;
				state_num <= x"4";
            when READ_S =>
                rd_i <= '1';
                wr_i <= '0';
				--we need to keep outputting current address if rdDone is low
				if (earlyOpBegun_i = '0') then
                    state_nxt<= READ_S;
                else
                    state_nxt<= READ_INC;
                end if;
				state_num <= x"5";
            when READ_INC=>
                rd_i <= '0';
                wr_i <= '0';
                state_nxt <= READ_CHK;
                state_num <= x"6";
                
            when READ_CHK=>
				rd_i <= '0';
				wr_i <= '0';
                if (addr_cnt < x"400000") then
                    state_nxt<= READ_S;
	            else
                    state_nxt<=REST;
                end if;
				state_num <= x"7";
            when REST=>
                rd_i <= '0';
                wr_i <= '0';
                state_nxt<= REST;
				state_num <= x"8";
        end case;
    end process;
end architecture behavior;
