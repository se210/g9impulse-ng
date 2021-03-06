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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use WORK.common.all;
use WORK.sdram.all;
use WORK.Blitter_pckg.all;
use WORK.sdram_pll_pckg.all;
use WORK.view_pckg.all;
use WORK.HexDriver_pckg.all;
use WORK.dualport_pckg.all;

entity gpuChip is
	
	generic(
		FREQ            :       natural                       := 50_000;  -- frequency of operation in KHz
		PIPE_EN         :       boolean                       := true;  -- enable fast, pipelined SDRAM operation
		MULTIPLE_ACTIVE_ROWS:   boolean 					  := false;  -- if true, allow an active row in each bank
		CLK_DIV         :       real						  := 1.0;  -- SDRAM Clock div
		NROWS           :       natural                       := 4096;  -- number of rows in the SDRAM
		NCOLS           :       natural                       := 512;  -- number of columns in each SDRAM row
		SADDR_WIDTH 	 : 		natural						  := 12;
	  	DATA_WIDTH      :       natural 					  := 16;  -- SDRAM databus width
		ADDR_WIDTH      :       natural 					  := 22;  -- host-side address width
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
		pin_pushbtn_out : out std_logic; -- push button reset output to PIC
	

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

        SW         : in std_logic_vector(17 downto 0);  --Controls the location of the start of screen
		
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
	constant FRONT_BUFFER_ADDR : std_logic_vector(23 downto 0) := x"009600";

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
  	signal be0_n, be1_n										: std_logic_vector(1 downto 0); -- byte enable mask
  	signal valid0, valid1									: std_logic; -- data valid signal from SDRAM
  	signal waitrequest0, waitrequest1						: std_logic; -- wait request signal from SDRAM
    signal hAddr0, hAddr1		       	         			: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- host-side address bus
    signal hDIn0, hDIn1			                 			: std_logic_vector(DATA_WIDTH-1 downto 0);  -- host-side data to SDRAM
    signal hDOut0, hDOut1						     		: std_logic_vector(DATA_WIDTH-1 downto 0);  -- host-side data from SDRAM
    signal rd0, rd1		                        			: std_logic;  -- host-side read control signal
    signal wr0, wr1                              			: std_logic;  -- host-side write control signal
    signal rdPending0, rdPending1							: std_logic; -- host-side read pending signal
    signal portselect										: std_logic;

  	-- SDRAM host side signals
    signal sdram_clk1x   									: std_logic;    -- normal clock signal
    signal sdram_lock										: std_logic;	-- locked output from the PLL
	signal sdram_rd     									: std_logic;    -- host-side read control signal
	signal sdram_wr     									: std_logic;    -- host-side write control signal
	signal sdram_rd_n   									: std_logic;    -- host-side read control signal inverted
	signal sdram_wr_n   									: std_logic;    -- host-side write control signal inverted
	signal sdram_be_n										: std_logic_vector(1 downto 0); -- host-side byte enable mask
	signal sdram_hAddr  									: std_logic_vector(ADDR_WIDTH -1 downto 0);  -- host address bus
	signal sdram_hDIn   									: std_logic_vector(DATA_WIDTH -1 downto 0);	-- host-side data to SDRAM
	signal sdram_hDOut  									: std_logic_vector(DATA_WIDTH -1 downto 0);	-- host-side data from SDRAM

    signal sdram_valid                                      : std_logic;
    signal sdram_waitrequest                                : std_logic;
    signal sdram_dqm_i                                      : std_logic_vector(1 downto 0);
    signal sdram_addr_fixed                                 : std_logic_vector(ADDR_WIDTH -1 downto 0); --fixed address for sdram_0
    
    signal hex_rd : std_logic_vector(3 downto 0);


	-- VGA related signals
	signal eof         										: std_logic;      -- end-of-frame signal from VGA controller
    signal full												: std_logic;      -- indicates when the VGA pixel buffer is full
    signal vga_address      								: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- SDRAM address counter
	signal pixels											: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal rst_n											: std_logic;		--VGA reset (active low)
	signal drawframe										: std_logic;  -- flag to indicate whether we are drawing current frame	
	signal pin_red_in										: std_logic_vector(1 downto 0);
	signal pin_green_in										: std_logic_vector(1 downto 0);
	signal pin_blue_in										: std_logic_vector(1 downto 0);
	signal visible : std_logic;
	signal DrawX											: std_logic_vector(9 downto 0);
	signal DrawY											: std_logic_vector(9 downto 0);
	
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
  u1 : dualport
    generic map(
      DATA_WIDTH      => DATA_WIDTH,
      HADDR_WIDTH     => ADDR_WIDTH
      )
     port map(
        clk 			=> sdram_clk1x,
        portselect    	=> portselect,
        reset			=> rst_i,
        active_port  	=> open,  -- Output information about active port.
        -- host-side port 0
        rd0				=> rd0, -- initiate read operation
        wr0				=> wr0, -- initiate write operation
        be0_n 			=> be0_n, -- Byte enable(active low)
        waitrequest0  	=> waitrequest0, -- Host should wait if this signal is high
        rdPending0    	=> rdPending0, -- true if read operation(s) are still in the pipeline
        rdvalid0       	=> valid0,    -- read operation is done and data is available
        hAddr0        	=> hAddr0, -- address from host to SDRAM
        hDIn0         	=> hDIn0,  -- data from host to SDRAM
        hDOut0        	=> hDOut0, -- data from SDRAM to host
 
        -- host-side port 1
        rd1           	=> rd1, -- initiate read operation
        wr1           	=> wr1, -- initiate write operation
        be1_n           => be1_n, -- Byte enable
        waitrequest1  	=> waitrequest1, -- Host should wait if this signal is high
        rdPending1    	=> rdPending1, -- true if read operation(s) are still in the pipeline
        rdvalid1       	=> valid1, -- read operation is done and data is available
        hAddr1        	=> hAddr1,  -- address from host to SDRAM
        hDIn1         	=> hDIn1,  -- data from host to SDRAM
        hDOut1        	=> hDOut1,  -- data from SDRAM to host


        -- SDRAM controller port
        rd           	=> sdram_rd,
        wr           	=> sdram_wr,
        be_n           	=> sdram_be_n,
        waitrequest  	=> sdram_waitrequest,
        rdvalid      	=> sdram_valid,
        hAddr        	=> sdram_hAddr,
        hDIn         	=> sdram_hDIn,
        hDOut        	=> sdram_hDOut
    );
 
  ------------------------------------------------------------------------
  -- Instantiate the SDRAM controller that connects to the dualport
  -- module and interfaces to the external SDRAM chip.
  ------------------------------------------------------------------------

    u2 : sdram_0
    port map (
                clk => sdram_clk1x,
                reset_n => rst_n,
                az_addr => sdram_hAddr,
                az_be_n => sdram_be_n,
                az_cs => '1',
                az_data => sdram_hDIn,              --Input port on the memory controller
                az_rd_n => sdram_rd_n,
                az_wr_n => sdram_wr_n,

                za_data => sdram_hDOut,               --Output port on the memory controller
                za_valid => sdram_valid,
                za_waitrequest => sdram_waitrequest,
                zs_addr => pin_sAddr,
                zs_ba => pin_ba,
                zs_cas_n => pin_cas_n,
                zs_cke => pin_cke,
                zs_cs_n => pin_cs_n,
                zs_dq => pin_sData,
                zs_dqm => sdram_dqm_i,
                zs_ras_n => pin_ras_n,
                zs_we_n => pin_we_n
             );
    sdram_rd_n <= not sdram_rd;
    sdram_wr_n <= not sdram_wr;
    pin_dqmh <= sdram_dqm_i(1);
    pin_dqml <= sdram_dqm_i(0);

------------------------------------------------------------------------------------------------------------
-- Instance of VGA driver, this unit generates the video signals from VRAM
------------------------------------------------------------------------------------------------------------
	
	u3: view
	port map ( 
	   Clk 				=> sdram_clk1x,
	   nReset			=> rst_n,
	   wr 				=> valid0,
	   pixel_data_in 	=> pixels,
	   field_color 		=> field_color_r,
	   
	   eof 				=> eof,
	   full 			=> full,
	   Red 				=> pin_red_in,
	   Green 			=> pin_green_in,
	   Blue  			=> pin_blue_in,
	   VGA_clk 			=> pin_vga_clk, 
	   sync 			=> pin_vga_sync,
	   blank 			=> pin_vga_blank,
	   vs 				=> pin_vsync_n,
	   hs 				=> pin_hsync_n,
	   visible_out	 	=> visible,
	   DrawXOut			=> DrawX,
	   DrawYOut			=>DrawY);
	   
------------------------------------------------------------------------------------------------------------
-- instance of main blitter
------------------------------------------------------------------------------------------------------------
 
	-- the new blitter entity connection
	u4: Blitter
	port map (
	clk 				=> sdram_clk1x,
	reset 				=> blit_reset,
	-- signals to SDRAM
	addr 				=> hAddr1,
	be_n 				=> be1_n,
	sdram_in			=> hDIn1,
	rd 					=> rd1,
	wr 					=> wr1,
	-- signals from SDRAM
	sdram_out 			=> hDOut1,
	valid 				=> valid1,
	waitrequest 		=> waitrequest1,
    rd_pending  		=> rdPending1,
	-- signals from gpuchip
	blit_begin 			=> blit_begin,
	source_address 		=> source_address,
	target_address 		=> target_address,
	source_lines 		=> source_lines,
	line_size 			=> line_size,
	alpha_op 			=> alphaOp,
	front_buffer 		=> not_fb,
	-- signals to gpuchip
	blit_done 			=> blit_done);
	 
	u5: sdram_pll
	port map (
		inclk0		=> pin_clkin,
		c0			=> pin_sclk,
		c1			=> sdram_clk1x,
		locked		=> sdram_lock
	);
        
--------------------------------------------------------------------------------------------------------------
--Debugging Modules
--------------------------------------------------------------------------------------------------------------
	u7: HexDriver
	port map ( In0 => hex_rd,
		   Out0 => hex0);
		   
	u8: HexDriver
	port map ( In0 => port_in(3 downto 0),
				Out0 => hex1);
				
	u9: HexDriver
	port map ( In0 => port_in(7 downto 4),
			Out0 => hex2);
			
	u10: HexDriver
	port map ( In0 => port_addr,
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
	port map ( In0 => "00"&vga_address(21 downto 20),
			Out0 => hex7);
--------------------------------------------------------------------------------------------------------------
-- End of Submodules
--------------------------------------------------------------------------------------------------------------
-- Begin Top Level Module
    -- Corrected format for the SDRAM address to match the way that DE2 Control Panel writes to the SDRAM
	
	hex_rd <= "000"& pin_load;
	
	
	pin_red <= pin_red_in & x"00";
	pin_green <= pin_green_in & x"00";
	pin_blue <= pin_blue_in & x"00";
	
	field_color_r <= x"02";
------------------------------------------------------------------------------------------------------------------	
	-- connect internal signals	
	rst_i <= sysReset;
	rst_n <= not sysReset; -- active-low reset signal
	pin_ce_n <= '1';						  -- disable Flash RAM
	pin_clkout <= sdram_clk1x; -- clock to the PIC
	pin_pushbtn_out <= pin_pushbtn;
	
	portselect <= '1' when (visible='0' and full='1' and rdPending0='0' and DrawY > conv_std_logic_vector(240,10) and DrawY < conv_std_logic_vector(524,10)) else '0';
  	
	--rd0 <= ((not full) and drawframe); -- negate the full signal for use in controlling the SDRAM read operation
	rd0 <= not full;
	hDIn0 <= "0000000000000000"; 		  -- don't need to write to port 0 (VGA Port)
	wr0 <= '0';
	hAddr0 <= std_logic_vector(vga_address);
	be0_n <= "00";
	
	blit_reset <= rst_i or reset_blitter;

	-- Port0 is reserved for VGA
	--pixels <= hDOut0 when drawframe = '1' else "0000000000000000";
	pixels <= hDOut0;

	port_in   		<= pin_port_in;
	port_addr 		<= pin_port_addr;
	pin_done		<= idle_r;

	source_address	<= source_address_r;
	line_size		<= line_size_r;
	target_address	<= target_address_r;
	source_lines	<= source_lines_r;
	alphaOp			<= alphaOp_r;
	
	front_buffer	<= front_buffer_r when db_enable_r = '1' else YES;	
	not_fb			<= (not front_buffer_r) when db_enable_r = '1' else YES;

	comb:process(state_r, port_in, pin_load, port_addr, pin_start, blit_done)
	begin
	  	blit_begin 			<= NO;						--default operations		
		reset_blitter 		<= NO;
		
		state_x 			<= state_r;			 		--default register values
	    source_address_x	<= source_address_r;
		target_address_x 	<= target_address_r;
		source_lines_x		<= source_lines_r;
		line_size_x 		<= line_size_r;
		alphaOp_x			<= alphaOp_r;
		db_enable_x			<= db_enable_r;
		front_buffer_x 		<= front_buffer_r;
		idle_x			 	<= idle_r;
			
		case state_r is
			when INIT =>
				idle_x <= YES;
				reset_blitter <= YES;
				state_x <= LOAD;
			
			when LOAD =>
				if (pin_load = YES) then
					case port_addr is 
						when "0000" => source_address_x(21 downto 16) <= port_in(5 downto 0);			
						when "0001" => source_address_x(15 downto 8)  <= port_in; 
						when "0010" => source_address_x(7 downto  0)  <= port_in;			
						when "0011" => target_address_x(21 downto 16) <= port_in(5 downto 0);				
						when "0100" => target_address_x(15 downto 8)  <= port_in;			
						when "0101" => target_address_x(7 downto  0)  <= port_in;				
						when "0110" => source_lines_x				  <= port_in;  			
						when "0111" => line_size_x					  <= port_in;    			
						when "1000" => alphaOp_x					  <= port_in(0);
						when "1001" => db_enable_x 					  <= port_in(0);
						when "1010" => front_buffer_x				  <= port_in(0);
						when others => NULL;
					end case;				
				end if;
		
				if (pin_start = YES) then
					idle_x <= NO;
					state_x <= DRAW;
				end if;

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
	end process;

   -- update the SDRAM address counter
   process(sdram_clk1x)
   begin
     if rising_edge(sdram_clk1x) then
		
		 --VGA Related Stuff
		 if eof = YES then
			drawframe <= not drawframe; 					 -- draw every other scan frame

		 -- reset the address at the end of a video frame depending on which buffer is the front
		 if (front_buffer = YES) then
		 	vga_address <= (others=>'0');
		 else
			vga_address <= FRONT_BUFFER_ADDR(21 downto 0); 
		 end if;
			
		 elsif (waitrequest0 = '0' and full = '0') then
		  	vga_address <= vga_address + 1;           -- go to the next address once the read of the current address has begun
		 end if;
   	
		--reset stuff
		if (sysReset = YES) then
		   state_r <= INIT;
		end if;

 		state_r 			<= state_x;
		source_address_r	<= source_address_x;
		target_address_r 	<= target_address_x;
		source_lines_r		<= source_lines_x;
		line_size_r 		<= line_size_x;
     	alphaOp_r			<= alphaOp_x;
	    front_buffer_r		<= front_buffer_x;
		db_enable_r			<= db_enable_x;
		idle_r		 		<= idle_x;
	
	  end if;
   end process;

	--process reset circuitry
	process(pin_clkin)
	begin
		if (rising_edge(pin_clkin)) then
			if sdram_lock='0' then
				sysReset <= '1';     -- keep in reset until DLLs start up
			else
				sysReset <= not pin_pushbtn;  -- push button will reset
			end if;
		end if;
	end process;
end arch;
