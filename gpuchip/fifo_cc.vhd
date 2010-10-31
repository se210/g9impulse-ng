library ieee, unisim;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.ram2port_pckg.all;

package fifo_cc_pckg is
  component fifo_cc
    port (
      clk                             : in  std_logic;
      rst                             : in  std_logic;
      rd                              : in  std_logic;
      wr                              : in  std_logic;
      data_in                         : in  std_logic_vector(15 downto 0);
      data_out                        : out std_logic_vector(15 downto 0);
      full                            : out std_logic;
      empty                           : out std_logic;
      level                           : out std_logic_vector(7 downto 0)
      );
  end component fifo_cc;
end package fifo_cc_pckg;


library ieee, unisim;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.ram2port_pckg.all;
--use unisim.vcomponents.all;
--------------------------------
entity fifo_cc is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    rd       : in  std_logic;
    wr       : in  std_logic;
    data_in  : in  std_logic_vector(15 downto 0);
    data_out : out std_logic_vector(15 downto 0);
    full     : out std_logic;
    empty    : out std_logic;
    level    : out std_logic_vector(7 downto 0)
    );
end entity fifo_cc;

architecture arch of fifo_cc is

  signal full_i   : std_logic;
  signal empty_i  : std_logic;
  signal rd_addr  : std_logic_vector(7 downto 0) := "00000000";
  signal wr_addr  : std_logic_vector(7 downto 0) := "00000000";
  signal level_i  : std_logic_vector(7 downto 0) := "00000000";
  signal rd_allow : std_logic;
  signal wr_allow : std_logic;
begin
  --bram1 : RAMB4_S16_S16 port map (addra => rd_addr, addrb => wr_addr,
  --                               dia    => (others => '0'), dib => data_in, wea => '0', web => '1',
  --                               clka   => clk, clkb => clk, rsta => '0', rstb => '0',
  --                               ena    => rd_allow, enb => wr_allow, doa => data_out );
  bram1 : ram2port port map ( clock => clk,
							  data => data_in,
							  rdaddress => rd_addr,
						  	  rden => rd_allow,
                              wren => wr_allow,
							  wraddress => wr_addr,
							  q => data_out);

  rd_allow <= rd and not empty_i;
  wr_allow <= wr and not full_i;

  process (clk, rst)
  begin
    if rst = '1' then
      rd_addr   <= (others => '0');
      wr_addr   <= (others => '0');
      level_i   <= (others => '0');
    elsif rising_edge(clk) then
      if rd_allow = '1' then
        rd_addr <= rd_addr + '1';
      end if;
      if wr_allow = '1' then
        wr_addr <= wr_addr + '1';
      end if;
      if (wr_allow and not rd_allow and not full_i) = '1' then
        level_i <= level_i + '1';
      elsif (rd_allow and not wr_allow and not empty_i) = '1' then
        level_i <= level_i - '1';
      end if;
    end if;
  end process;

  full_i  <= '1' when level_i = "11111111" else '0';
  full    <= full_i;
  empty_i <= '1' when level_i = "00000000" else '0';
  empty   <= empty_i;
  level   <= level_i;

end architecture arch;
