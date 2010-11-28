--ECE395 GPU:
--Top Level HDL
--=====================================================
--Designed by:
--Zuofu Cheng
--James Cavanaugh
--Eric Sands
--
--of the University of Illinois at Urbana Champaign
--under the direction of Dr. Lippold Haken
--====================================================
--
--Heavily based off of HDL examples provided by XESS Corporation
--www.xess.com
--
--Based in part on Doug Hodson's work which in turn
--was based off of the XSOC from Gray Research LLC.
--										
--
--release under the GNU General Public License
--and kindly hosted by www.opencores.org


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use WORK.common.all;
use WORK.sdram.all;
use WORK.blitter_pckg.all;
use WORK.sdram_pll_pckg.all;
use WORK.view_pckg.all;
use WORK.HexDriver_pckg.all;

entity gpuChip is
	
	generic(
		FREQ            :       natural                       := 50_000;  -- frequency of operation in KHz
		PIPE_EN         :       boolean                       := true;  -- enable fast, pipelined SDRAM operation
		MULTIPLE_ACTIVE_ROWS:   boolean 					  := false;  -- if true, allow an active row in each bank
		CLK_DIV         :       real						  := 1.0;  -- SDRAM Clock div
		NROWS           :       natural                       := 4096;  -- number of rows in the SDRAM
		NCOLS           :       natural                       := 512;  -- number of columns in each SDRAM row
		SADDR_WIDTH 	:  		natural						  := 12;
	  	DATA_WIDTH      :       natural 					  := 16;  -- SDRAM databus width
		ADDR_WIDTH      :       natural 					  := 24;  -- host-side address width
	 	VGA_CLK_DIV     :       natural 					  := 4;  -- pixel clock = FREQ / CLK_DIV
		PIXEL_WIDTH     :       natural 					  := 8;  -- width of a pixel in memory
    	NUM_RGB_BITS    :       natural 					  := 2;  -- #bits in each R,G,B component of a pixel
    	PIXELS_PER_LINE :       natural 					  := 320; -- width of image in pixels
    	LINES_PER_FRAME :       natural 					  := 240;  -- height of image in scanlines
    	FIT_TO_SCREEN   :       boolean 					  := true;  -- adapt video timing to fit image width x 		 
	    PORT_TIME_SLOTS :       std_logic_vector(15 downto 0) := "0000001111111111"
   );
	
	port(
		pin_clkin   : in std_logic;       -- main clock input from external clock source
		pin_clkout  : out std_logic;		 -- clock output to PIC
		pin_ce_n    : out std_logic;      -- Flash RAM chip-enable
		pin_pushbtn : in std_logic; -- push button reset
	

		-- blitter port connections
		pin_port_in	  : in std_logic_vector (7 downto 0);
		pin_port_addr : in std_logic_vector	(3 downto 0);
		pin_load		  : in std_logic;
		pin_start	  : in std_logic;
		pin_done		  : out std_logic;

		-- vga port connections
		pin_red     : out std_logic_vector(9 downto 0);
		pin_green   : out std_logic_vector(9 downto 0);
		pin_blue    : out std_logic_vector(9 downto 0);
		pin_hsync_n : out std_logic;
		pin_vsync_n : out std_logic;
		pin_vga_clk : out std_logic;
		pin_vga_blank : out std_logic;
		pin_vga_sync : out std_logic;

		-- SDRAM pin connections
		pin_sclkfb : in std_logic;                   -- feedback SDRAM clock with PCB delays
		pin_sclk   : out std_logic;                  -- clock to SDRAM
		pin_cke    : out std_logic;                  -- SDRAM clock-enable
		pin_cs_n   : out std_logic;                  -- SDRAM chip-select
		pin_ras_n  : out std_logic;                  -- SDRAM RAS
		pin_cas_n  : out std_logic;                  -- SDRAM CAS
		pin_we_n   : out std_logic;                  -- SDRAM write-enable
		pin_ba     : out std_logic_vector( 1 downto 0);      -- SDRAM bank-address
		pin_sAddr  : out std_logic_vector(11 downto 0);      -- SDRAM address bus
		pin_sData  : inout std_logic_vector (16-1 downto 0);  -- data bus to SDRAM
		pin_dqmh   : out std_logic;                  -- SDRAM DQMH
		pin_dqml   : out std_logic;                   -- SDRAM DQML	
		
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0);
		hex4 : out std_logic_vector(6 downto 0);
		hex5 : out std_logic_vector(6 downto 0);
		hex6 : out std_logic_vector(6 downto 0);
		hex7 : out std_logic_vector(6 downto 0)		
	);
end gpuChip;

architecture arch of gpuChip is

	constant YES:	std_logic := '1';
	constant NO:	std_logic := '0';
	constant HI:	std_logic := '1';
	constant LO:	std_logic := '0';

	type gpuState is (
	 INIT,                           -- init
	 LOAD,
	 DRAW,
	 REST                           
    );
	
	signal state_r, state_x : gpuState;  -- state register and next state

	--registers
	signal source_address_x, source_address_r	: std_logic_vector (ADDR_WIDTH - 1 downto 0);  -- sprite dest register
	signal target_address_x, target_address_r : std_logic_vector (ADDR_WIDTH -1 downto 0);	  -- sprite source register
	signal source_lines_x, source_lines_r 		: std_logic_vector (7 downto 0);					  -- number of lines to blit
	signal line_size_x, line_size_r 				: std_logic_vector (7 downto 0);	              -- num# of pixels in each line /2
	signal alphaOp_x, alphaOp_r 					: std_logic;
	signal front_buffer_x, front_buffer_r		: std_logic;
	signal idle_x, idle_r							: std_logic;
	signal db_enable_x, db_enable_r				: std_logic;
	signal not_fb										: std_logic;
	signal field_color_x, field_color_r			: std_logic_vector (7 downto 0);				  -- software controllable interlace field color
	signal drawpending_x, drawpending_r			: std_logic;

	--internal signals
    signal sysReset 										: std_logic;  -- system reset
	signal blit_reset										: std_logic;
	signal reset_blitter									: std_logic;

	-- Blitter signals
  	signal blit_begin										: std_logic;
  	signal source_address				            : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal source_lines									: std_logic_vector (7 downto 0);
	signal line_size										: std_logic_vector (7 downto 0);
	signal target_address								: std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal blit_done									 	: std_logic;	
	signal alphaOp											: std_logic;
	signal front_buffer									: std_logic;

	signal port_in											: std_logic_vector (7 downto 0);
	signal port_addr										: std_logic_vector (3 downto 0);

	 --Application Side Signals for the DualPort Controller
  	signal rst_i											: std_logic; 	--tied reset signal
   signal opBegun0, opBegun1                	   : std_logic;  -- read/write operation started indicator
   signal earlyOpBegun0, earlyOpBegun1          : std_logic;  -- read/write operation started indicator
   signal rdPending0, rdPending1					   : std_logic;  -- read operation pending in SDRAM pipeline indicator
   signal done0, done1		                     : std_logic;  -- read/write operation complete indicator
   signal rdDone0, rdDone1			               : std_logic;  -- read operation complete indicator
   signal hAddr0, hAddr1		       	         : std_logic_vector(ADDR_WIDTH-1 downto 0);  -- host-side address bus
   signal hDIn0, hDIn1			                  : std_logic_vector(DATA_WIDTH-1 downto 0);  -- host-side data to SDRAM
   signal hDOut0, hDOut1						      : std_logic_vector(DATA_WIDTH-1 downto 0);  -- host-side data from SDRAM
   signal rd0, rd1		                        : std_logic;  -- host-side read control signal
   signal wr0, wr1                              : std_logic;  -- host-side write control signal

  	-- SDRAM host side signals
	signal sdram_bufclk 									: std_logic;    -- buffered input (non-DLL) clock
	signal sdram_clk1x  									: std_logic;    -- internal master clock signal
	signal sdram_clk2x  									: std_logic;		-- doubled clock
	signal sdram_lock  									: std_logic;    -- SDRAM clock DLL lock indicator
	signal sdram_rst    									: std_logic;    -- internal reset signal
	signal sdram_rd     									: std_logic;    -- host-side read control signal
	signal sdram_wr     									: std_logic;    -- host-side write control signal
	signal sdram_earlyOpBegun							: std_logic;
	signal sdram_OpBegun									: std_logic;
	signal sdram_rdPending								: std_logic;
	signal sdram_done   									: std_logic;    -- SDRAM operation complete indicator
	signal sdram_rdDone 									: std_logic;		-- host-side read completed signal
	signal sdram_hAddr  									: std_logic_vector(ADDR_WIDTH -1 downto 0);  -- host address bus
	signal sdram_hDIn   									: std_logic_vector(DATA_WIDTH -1 downto 0);	-- host-side data to SDRAM
	signal sdram_hDOut  									: std_logic_vector(DATA_WIDTH -1 downto 0);	-- host-side data from SDRAM
	signal sdram_status 									: std_logic_vector(3 downto 0);  -- SDRAM controller status

    -- fifo signals
    signal fifo_wr  : std_logic;

    type fifo_wren_state is (REST, READY, DECREMENT, ZERO);
    signal fifo_wren_r, fifo_wren_x : fifo_wren_state;

	-- VGA related signals
	signal eof         									: std_logic;      -- end-of-frame signal from VGA controller
   signal full												: std_logic;      -- indicates when the VGA pixel buffer is full
   signal vga_address      							: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- SDRAM address counter
	signal pixels											: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal rst_n											: std_logic;		--VGA reset (active low)
	signal drawframe										: std_logic;  -- flag to indicate whether we are drawing current frame	
	signal pin_red_in										: std_logic_vector(1 downto 0);
	signal pin_green_in									: std_logic_vector(1 downto 0);
	signal pin_blue_in									: std_logic_vector(1 downto 0);
	signal visible : std_logic;
	
--------------------------------------------------------------------------------------------------------------
-- Beginning of Submodules
-- All instances of submodules and signals associated with them
-- are declared within. Signals not directly associated with
-- submodules are declared elsewhere.
--  
--------------------------------------------------------------------------------------------------------------

begin
 ------------------------------------------------------------------------
 -- Instantiate the dualport module
 ------------------------------------------------------------------------
--  u1 : dualport
--    generic map(
--      PIPE_EN         => PIPE_EN,
--      PORT_TIME_SLOTS => PORT_TIME_SLOTS,
--      DATA_WIDTH      => DATA_WIDTH,
--      HADDR_WIDTH     => ADDR_WIDTH
--      )
--    port map(
--      clk             => sdram_clk1x,
--
--		-- Memory Port 0 connections
--		rst0            => rst_i,
--      rd0             => rd0,
--      wr0             => wr0,
--      rdPending0      => rdPending0,
--      opBegun0        => opBegun0,
--      earlyOpBegun0   => earlyOpBegun0,
--      rdDone0         => rdDone0,
--      done0           => done0,
--      hAddr0          => hAddr0,
--      hDIn0           => hDIn0,
--      hDOut0          => hDOut0,
--      status0         => open,
--		
--		-- Memory Port 1 connections
--      rst1            => rst_i,
--      rd1             => rd1,
--      wr1             => wr1,
--      rdPending1      => rdPending1,
--      opBegun1        => opBegun1,
--      earlyOpBegun1   => earlyOpBegun1,
--      rdDone1         => rdDone1,
--      done1           => done1,
--      hAddr1          => hAddr1,
--      hDIn1           => hDIn1,
--      hDOut1          => hDOut1,
--      status1         => open,
--      
--		-- connections to the SDRAM controller
--      rst             => sdram_rst,
--      rd              => sdram_rd,
--      wr              => sdram_wr,
--      rdPending       => sdram_rdPending,
--      opBegun         => sdram_opBegun,
--      earlyOpBegun    => sdram_earlyOpBegun,
--      rdDone          => sdram_rdDone,
--      done            => sdram_done,
--      hAddr           => sdram_hAddr,
--      hDIn            => sdram_hDIn,
--      hDOut           => sdram_hDOut,
--      status          => sdram_status
--      );

 
  ------------------------------------------------------------------------
  -- Instantiate the SDRAM controller that connects to the dualport
  -- module and interfaces to the external SDRAM chip.
  ------------------------------------------------------------------------
  u2 : sdramCntl
    generic map(
      FREQ       				  => FREQ,
--      CLK_DIV    				  => CLK_DIV,
      PIPE_EN     		     => PIPE_EN,
      MULTIPLE_ACTIVE_ROWS   => MULTIPLE_ACTIVE_ROWS,
		DATA_WIDTH  			  => DATA_WIDTH,
      NROWS        			  => NROWS,
      NCOLS        			  => NCOLS,
      HADDR_WIDTH  			  => ADDR_WIDTH,
      SADDR_WIDTH  			  => SADDR_WIDTH
      )
    port map(
	 	--Dual Port Controller (Host) Side
      clk          => sdram_clk1x,             -- master clock from external clock source (unbuffered)
      lock         => sdram_lock,       		-- DLL lock indicator
      rst          => rst_i,        		-- reset
      rd           => sdram_rd,         		-- host-side SDRAM read control from dualport
      wr           => sdram_wr,         		-- host-side SDRAM write control from dualport
      earlyOpBegun => sdram_earlyOpBegun,		-- early indicator that memory operation has begun 
		opBegun      => sdram_opBegun,       	-- indicates memory read/write has begun
		rdPending    => sdram_rdPending,   		-- read operation to SDRAM is in progress
      done         => sdram_done,        		-- indicates SDRAM memory read or write operation is done
      rdDone       => sdram_rdDone,      		-- indicates SDRAM memory read operation is done
      hAddr        => sdram_hAddr,           -- host-side address from dualport to SDRAM
      hDIn         => sdram_hDIn,            -- test data pattern from dualport to SDRAM
      hDOut        => sdram_hDOut,           -- SDRAM data output to dualport
      status       => sdram_status,          -- SDRAM controller state (for diagnostics)
     
	   --SDRAM (External) Side
      cke          => pin_cke,              -- SDRAM clock enable
      ce_n         => pin_cs_n,             -- SDRAM chip-select
      ras_n        => pin_ras_n,            -- SDRAM RAS
      cas_n        => pin_cas_n,            -- SDRAM CAS
      we_n         => pin_we_n,             -- SDRAM write-enable
      ba           => pin_ba,               -- SDRAM bank address
      sAddr        => pin_sAddr,            -- SDRAM address
      sData        => pin_sData,            -- SDRAM databus
      dqmh         => pin_dqmh,             -- SDRAM DQMH
      dqml         => pin_dqml              -- SDRAM DQML
      );

------------------------------------------------------------------------------------------------------------
-- Instance of VGA driver, this unit generates the video signals from VRAM
------------------------------------------------------------------------------------------------------------
 

-- 	u3 : vga
--    generic map (
--      FREQ            => FREQ,
--      CLK_DIV         => VGA_CLK_DIV,
--      PIXEL_WIDTH     => PIXEL_WIDTH,
--      PIXELS_PER_LINE => PIXELS_PER_LINE,
--      LINES_PER_FRAME => LINES_PER_FRAME,
--      NUM_RGB_BITS    => NUM_RGB_BITS,
--      FIT_TO_SCREEN   => FIT_TO_SCREEN
--      )
--    port map (
--      rst             => rst_i,
--      clk             => sdram_clk1x,   -- use the resync'ed master clock so VGA generator is in sync with SDRAM
--      wr              => rdDone0,       -- write to pixel buffer when the data read from SDRAM is available
--      pixel_data_in   => pixels, 		 -- pixel data from SDRAM
--		field_color		 => field_color_r, -- interlace field color  
--		full            => full,          -- indicates when the pixel buffer is full
--      eof             => eof,           -- indicates when the VGA generator has finished a video frame
--      r               => pin_red_in,       -- RGB components (output)
--      g               => pin_green_in,
--      b               => pin_blue_in,
--      hsync_n         => pin_hsync_n,   -- horizontal sync
--      vsync_n         => pin_vsync_n,   -- vertical sync
--      blank           => pin_vga_blank
--      );

------------------------------------------------------------------------------------------------------------
-- instance of main blitter
------------------------------------------------------------------------------------------------------------
 
	u4: Blitter
	generic map(
                   FREQ              => FREQ, 
                   PIPE_EN           => PIPE_EN,
                   DATA_WIDTH        => DATA_WIDTH,
                   ADDR_WIDTH        => ADDR_WIDTH
               )
    port map (	
                 clk					 => sdram_clk1x,             
                 rst					 => blit_reset,		 
                 -- 	 rd           	 	 => rd1,      
                 --    wr                => wr1,
                 rd => open,
                 wr => open,
                 opBegun        	 => opBegun1,       
                 earlyopBegun   	 => earlyOpBegun1,       
                 done           	 => done1,
                 rddone		 	    => rddone1,      
                 rdPending		    => rdPending1,
                 Addr              => hAddr1,    
                 DIn               => hDIn1,     
                 DOut              => hDOut1,     
                 blit_begin		    => blit_begin,
                 source_address    => source_address, 
                 source_lines	    => source_lines,
                 target_address    => target_address,
                 line_size		    => line_size,
                 alphaOp			    => alphaOp,
                 blit_done		    => blit_done,
                 front_buffer	    => not_fb
             );
	 
	 u5: sdram_pll
	port map (
		inclk0		=> pin_clkin,
		c0			=> pin_sclk,
		c1			=> sdram_clk1x,
		c2 => open
	);
	
	u6: view
	port map ( 
           Clk => sdram_clk1x,
           nReset => not rst_i,
           wr => fifo_wr,
           pixel_data_in => pixels,
           field_color => field_color_r,
           
           eof => eof,
           full => full,
           Red => pin_red_in,
           Green => pin_green_in,
           Blue  => pin_blue_in,
           VGA_clk => pin_vga_clk, 
           sync => pin_vga_sync,
           blank => pin_vga_blank,
           vs => pin_vsync_n,
           hs => pin_hsync_n,
           visible_out => visible);
        
--------------------------------------------------------------------------------------------------------------
--Debugging Modules
--------------------------------------------------------------------------------------------------------------
	u7: HexDriver
	port map ( In0 => "000" & sdram_rd,
		   Out0 => hex0);
		   
	u8: HexDriver
	port map ( In0 => port_in(7 downto 4),
				Out0 => hex1);
				
	u9: HexDriver
	port map ( In0 => std_logic_vector(vga_address(3 downto 0)),
			Out0 => hex2);
			
	u10: HexDriver
	port map ( In0 => std_logic_vector(vga_address(7 downto 4)),
			Out0 => hex3);
			
	u11: HexDriver
	port map ( In0 => std_logic_vector(vga_address(11 downto 8)),
			Out0 => hex4);
			
	u12: HexDriver
	port map ( In0 => std_logic_vector(vga_address(15 downto 12)),
			Out0 => hex5);
	
	u13: HexDriver
	port map ( In0 => std_logic_vector(vga_address(19 downto 16)),
			Out0 => hex6);
			
	u14: HexDriver
	port map ( In0 => std_logic_vector(vga_address(23 downto 20)),
			Out0 => hex7);
--------------------------------------------------------------------------------------------------------------
-- End of Submodules
--------------------------------------------------------------------------------------------------------------
-- Begin Top Level Module
	rst_i <= not pin_pushbtn;
	sdram_rd <= not full;
	sdram_wr <= '0';
	sdram_lock <= '1';
	sdram_hAddr <= vga_address;
	sdram_hDIn <= x"0000";
	pixels <= sdram_hDOut;
	
	rd1 <= '0';
	wr1 <= '0';
	pin_clkout <= sdram_clk1x;
	pin_ce_n <= '1';						  -- disable Flash RAM
	
	
	pin_red <= pin_red_in & x"00";
	pin_green <= pin_green_in & x"00";
	pin_blue <= pin_blue_in & x"00";
	
	field_color_r <= x"06";
	
    calc_fifo_rw : process (fifo_wren_r, sdram_opBegun, sdram_rdPending)
    begin
        fifo_wren_x <= fifo_wren_r;

        case fifo_wren_r is
            when REST =>
                if (sdram_opBegun = '0' and sdram_rdPending = '1') then
                    fifo_wren_x <= READY;
                end if;
            when READY =>
                fifo_wren_x <= DECREMENT;
            when DECREMENT =>
                fifo_wren_x <= ZERO;
            when ZERO =>
                if (sdram_opBegun = '1') then
                    fifo_wren_x <= REST;
                end if;
            when others =>
                NULL;
        end case;
    end process calc_fifo_rw;

    update : process (sdram_clk1x, rst_i)
    begin
        if (rst_i = '1') then
            fifo_wren_r <= REST;
        elsif (rising_edge(sdram_clk1x)) then
            fifo_wren_r <= fifo_wren_x;
        end if;
    end process update;

    fifo_wr <= '1' when sdram_rdDone = '1' and fifo_wren_r /= ZERO else '0';

    increment_addr : process (sdram_clk1x, rst_i, sdram_earlyOpBegun, sdram_opBegun, sdram_rdPending)
    begin
        if (rst_i = '1' or eof = '1') then
            vga_address <= (others => '0');
        elsif (rising_edge(sdram_clk1x)) then
            if (sdram_earlyOpBegun = '1') then
                if (sdram_opBegun = '1' and sdram_rdPending = '0') then
                    vga_address <= vga_address;
                else
                    vga_address <= vga_address + 1;
                end if;
            else
                vga_address <= vga_address;
            end if;
        else
            vga_address <= vga_address;
        end if;
    end process increment_addr;
end arch;
