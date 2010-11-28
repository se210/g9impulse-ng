library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use work.sdram.all;

entity test_sdramcntl is
end test_sdramcntl;

architecture behavior of test_sdramcntl is
    -- constants from sdramcntl, be sure to update these accordingly

    constant FREQ                   : natural := 50_000;  -- operating frequency in KHz
    constant IN_PHASE               : boolean := true;  -- SDRAM and controller work on same or opposite clock edge
    constant PIPE_EN                : boolean := false;  -- if true, enable pipelined read operations
    constant MAX_NOP                : natural := 10000;  -- number of NOPs before entering self-refresh
    constant MULTIPLE_ACTIVE_ROWS   : boolean := false;  -- if true, allow an active row in each bank
    constant DATA_WIDTH             : natural := 16;  -- host & SDRAM data width
    constant NROWS                  : natural := 4096;  -- number of rows in SDRAM array
    constant NCOLS                  : natural := 512;  -- number of columns in SDRAM array
    constant HADDR_WIDTH            : natural := 23;  -- host-side address width
    constant SADDR_WIDTH            : natural := 12;  -- SDRAM-side address width

    -- declare inputs and outputs and initialize them
    -- host side
    signal clk          : std_logic := '0';
    signal lock         : std_logic := '1';
    signal rst          : std_logic := '1';
    signal rd           : std_logic := '0';
    signal wr           : std_logic := '0';
    signal earlyOpBegun : std_logic;
    signal opBegun      : std_logic;
    signal rdPending    : std_logic;
    signal done         : std_logic;
    signal rdDone       : std_logic;
    signal hAddr        : std_logic_vector(HADDR_WIDTH-1 downto 0) := conv_std_logic_vector(0, HADDR_WIDTH);
    signal hDIn         : std_logic_vector(DATA_WIDTH-1 downto 0)  := conv_std_logic_vector(0, DATA_WIDTH);
    signal hDOut        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal status       : std_logic_vector(3 downto 0);

    -- SDRAM side
    signal cke      : std_logic;
    signal ce_n     : std_logic;
    signal ras_n    : std_logic;
    signal cas_n    : std_logic;
    signal we_n     : std_logic;
    signal ba       : std_logic_vector(1 downto 0);
    signal sAddr    : std_logic_vector(SADDR_WIDTH-1 downto 0);
    signal sData    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal dqmh     : std_logic;
    signal dqml     : std_logic;

    -- Clock period definitions
    constant clk_period : time := 20 ns;
    
begin
    uut : sdramCntl port map (
            -- host side
            clk => clk,     -- master clock
            lock => lock,   -- true if clock is stable
            rst => rst,     -- reset
            rd => rd,       -- initiate read operation
            wr => wr,       -- initiate write operation
            earlyOpBegun => earlyOpBegun, -- read/write/self-refresh op has begun (async)
            opBegun => opBegun, -- read/write/self-refresh op has begun (clocked)
            rdPending => rdPending, -- true if read operation(s) are still in the pipeline
            done => done,   -- read or write operation is done
            rdDone => rdDone, -- read operation is done and data is available
            hAddr => hAddr, -- address from host to SDRAM
            hDIn => hDIn,   -- data from host       to SDRAM
            hDOut => hDOut, -- data from SDRAM to host
            status => status, -- diagnostic status of the FSM         

            -- SDRAM side
            cke => cke,     -- clock-enable to SDRAM
            ce_n => ce_n,   -- chip-select to SDRAM
            ras_n => ras_n, -- SDRAM row address strobe
            cas_n => cas_n, -- SDRAM column address strobe
            we_n => we_n,   -- SDRAM write enable
            ba => ba,       -- SDRAM bank address
            sAddr => sAddr, -- SDRAM row/column address
            -- sDIn => sDIn, -- data from SDRAM
            -- sDOut => sDOut, -- data to SDRAM
            -- sDOutEn => sDOutEn, -- true if data is output to SDRAM on sDOut
            sData => sData, -- SDRAM in/out databus
            dqmh => dqmh,   -- enable upper-byte of SDRAM databus if true
            dqml => dqml    -- enable lower-byte of SDRAM databus if true
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
