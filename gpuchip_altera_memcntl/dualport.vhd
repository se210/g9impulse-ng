library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
package dualport_pckg is
    component dualport
        generic(
        DATA_WIDTH      :    natural                       := 16;  -- host & SDRAM data width
        HADDR_WIDTH     :    natural                       := 22  -- host-side address width
        );
        port(
        clk           : in std_logic;
        portselect    : in std_logic;
        reset         : in std_logic;
        active_port  : out std_logic;

        -- host-side port 0
        rd0           : in std_logic;
        wr0           : in std_logic;
        be0_n           : in std_logic_vector(1 downto 0);
        waitrequest0  : out std_logic;
        rdPending0    : out std_logic;
        rdvalid0       : out std_logic;
        hAddr0        : in  std_logic_vector(HADDR_WIDTH-1 downto 0);
        hDIn0         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        hDOut0        : out std_logic_vector(DATA_WIDTH-1 downto 0);
 
        -- host-side port 1
        rd1           : in  std_logic;
        wr1           : in  std_logic;
        be1_n           : in std_logic_vector(1 downto 0);
        waitrequest1  : out std_logic;
        rdPending1    : out std_logic;
        rdvalid1       : out std_logic;
        hAddr1        : in  std_logic_vector(HADDR_WIDTH-1 downto 0);
        hDIn1         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        hDOut1        : out std_logic_vector(DATA_WIDTH-1 downto 0);

        -- SDRAM controller port
        rd           : out std_logic;
        wr           : out std_logic;
        be_n           : out std_logic_vector(1 downto 0);
        waitrequest  : in  std_logic;
        rdvalid      : in  std_logic;
        hAddr        : out std_logic_vector(HADDR_WIDTH-1 downto 0);
        hDIn         : out std_logic_vector(DATA_WIDTH-1 downto 0);
        hDOut        : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
    end component dualport;
end package dualport_pckg;


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity dualport is
    generic(
      DATA_WIDTH      :    natural                       := 16;  -- host & SDRAM data width
      HADDR_WIDTH     :    natural                       := 22  -- host-side address width
      );

    port(
        clk           : in std_logic;
        portselect    : in std_logic;
        reset         : in std_logic;
        active_port  : out std_logic;      -- Output information about active port.
        -- host-side port 0
        rd0           : in std_logic;      -- initiate read operation
        wr0           : in std_logic;      -- initiate write operation
        be0_n           : in std_logic_vector(1 downto 0);  -- Byte enable(active low)
        waitrequest0  : out std_logic;      -- Host should wait if this signal is high
        rdPending0    : out std_logic;      -- true if read operation(s) are still in the pipeline
        rdvalid0       : out std_logic;     -- read operation is done and data is available
        hAddr0        : in  std_logic_vector(HADDR_WIDTH-1 downto 0);  -- address from host to SDRAM
        hDIn0         : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from host to SDRAM
        hDOut0        : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from SDRAM to host
 
        -- host-side port 1
        rd1           : in  std_logic;      -- initiate read operation
        wr1           : in  std_logic;      -- initiate write operation
        be1_n           : in std_logic_vector(1 downto 0);  -- Byte enable
        waitrequest1  : out std_logic;      -- Host should wait if this signal is high
        rdPending1    : out std_logic;      -- true if read operation(s) are still in the pipeline
        rdvalid1       : out std_logic;     -- read operation is done and data is available
        hAddr1        : in  std_logic_vector(HADDR_WIDTH-1 downto 0);  -- address from host to SDRAM
        hDIn1         : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from host to SDRAM
        hDOut1        : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from SDRAM to host

        -- SDRAM controller port
        rd           : out std_logic;
        wr           : out std_logic;
        be_n           : out std_logic_vector(1 downto 0);
        waitrequest  : in  std_logic;
        rdvalid      : in  std_logic;
        hAddr        : out std_logic_vector(HADDR_WIDTH-1 downto 0);
        hDIn         : out std_logic_vector(DATA_WIDTH-1 downto 0);
        hDOut        : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end dualport;

architecture arch of dualport is
    type portstate is (port0, port1);
    signal port_r, port_x : portstate;

    signal rdpending    : std_logic;      --Indicates if there's unfinished operation
    signal rops         : std_logic_vector(1 downto 0);--Records the number of pipelined read commands.
    signal rd_i         : std_logic;        --Internal read signal
    signal can_switch   : std_logic;        --Indicate if it's safe to switch port
    signal addr_i       : std_logic_vector(HADDR_WIDTH-1 downto 0); 
begin

    active_port <= '0' when port_r=port0 else '1';
    rdpending <= '0' when (rops="00") else '1';         --read pending when number of commands not 0
    ----------------------------------------------------------------------------
    -- multiplex the SDRAM controller port signals to/from the dual host-side ports  
    ----------------------------------------------------------------------------
    -- send the SDRAM controller the address and data from the currently active port
    addr_i <= hAddr0 when port_r = port0 else hAddr1;
    hAddr <= addr_i(21)&addr_i(19 downto 8)&addr_i(20)&addr_i(7 downto 0);  --Change to sdram_o convention
    hDIn  <= hDIn0  when port_r = port0 else hDIn1;
  
    -- both ports get the data from the SDRAM but only the active port will use it
    hDOut0 <= hDOut;
    hDOut1 <= hDOut;
    
    -- byte enable is always connected to active port
    be_n <= be0_n when (port_r = port0) else be1_n;

    -- active port controls read when a switch is not requested
    -- when a switch is happening. there should not be command issued any more.
    rd_i <= rd0 when (port_r = port0 and port_x = port0) else
          rd1 when (port_r = port1 and port_x = port1) else
          '0';
    rd <= rd_i;

    -- active port controls write when a switch is not requested
    wr <= wr0 when (port_r = port0 and port_x = port0) else
          wr1 when (port_r = port1 and port_x = port1) else
          '0';

    -- send the status signals back to the hosts

    -- if there's no port switching waitrequest is connected to active port
    -- when there's port switching waitrequest will be high and remains high for inactive port
    -- therefore waitrequest is only connected when the active port is also the chosen port
    waitrequest0 <= waitrequest when (port_r = port0 and portselect='0') else '1';
    waitrequest1 <= waitrequest when (port_r = port1 and portselect='1') else '1';

    -- rdpending connected to active port, inactive port always has rdpending='0'
    rdPending0 <= rdPending when (port_r = port0) else '0';
    rdPending1 <= rdPending when (port_r = port1) else '0';

    -- rdvalid connected to active port, inactive port always has rdvalid='0'
    rdvalid0 <= rdvalid when (port_r = port0) else '0';
    rdvalid1 <= rdvalid when (port_r = port1) else '0';

    count_ops : process(clk, reset, waitrequest, rd_i, rdvalid)
    begin
        if(reset='1') then 
            rops <= "00";
        elsif(rising_edge(clk)) then    --rd='1' waitrequest='0' means there will be a read command issued
--          rops <= rops + (rd_i and waitrequest='0') - rdvalid;
            if(rd_i='1' and waitrequest='0') then --rdvalid indicates a read command is finished
                if(rdvalid='0') then
                    rops <= rops + 1;
                else
                    rops <= rops;
                end if;
            else
                if(rdvalid='0') then
                    rops <= rops;
                else
                    rops <= rops - 1;
                end if;
            end if;
        end if;
    end process;

    -- next port signal
    -- can switch when no read operation pending and no read being issued now
    can_switch <= '1' when (rdpending='0' and rd_i='0') else '0';
    port_x <= port0 when (can_switch='1' and portselect='0') else
              port1 when (can_switch='1' and portselect='1') else
              port_r;

    -- update port at rising edge
    set_port : process(clk, reset)
    begin
        if(reset = '1') then
            port_r <= port0;
        elsif(rising_edge(clk)) then
            port_r <= port_x;
        end if;
    end process;
end architecture;
