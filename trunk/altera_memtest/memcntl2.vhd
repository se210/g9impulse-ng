-- Copyright (C) 1991-2010 Altera Corporation
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, Altera MegaCore Function License 
-- Agreement, or other applicable license agreement, including, 
-- without limitation, that your use is for the sole purpose of 
-- programming logic devices manufactured by Altera and sold by 
-- Altera or its authorized distributors.  Please refer to the 
-- applicable agreement for further details.

-- PROGRAM		"Quartus II"
-- VERSION		"Version 9.1 Build 350 03/24/2010 Service Pack 2 SJ Web Edition"
-- CREATED		"Wed Nov 24 16:19:53 2010"

LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

ENTITY memcntl2 IS 
	PORT
	(
		CLOCK_50 :  IN  STD_LOGIC;
		DRAM_DQ :  INOUT  STD_LOGIC_VECTOR(15 DOWNTO 0);
		KEY :  IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
		DRAM_CAS_N :  OUT  STD_LOGIC;
		DRAM_CKE :  OUT  STD_LOGIC;
		DRAM_CS_N :  OUT  STD_LOGIC;
		DRAM_RAS_N :  OUT  STD_LOGIC;
		DRAM_WE_N :  OUT  STD_LOGIC;
		DRAM_UDQM :  OUT  STD_LOGIC;
		DRAM_LDQM :  OUT  STD_LOGIC;
		DRAM_BA_1 :  OUT  STD_LOGIC;
		DRAM_BA_0 :  OUT  STD_LOGIC;
		DRAM_CLK :  OUT  STD_LOGIC;
		DRAM_ADDR :  OUT  STD_LOGIC_VECTOR(11 DOWNTO 0);
		HEX0 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX1 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX2 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX3 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX4 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX5 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX7 :  OUT  STD_LOGIC_VECTOR(6 DOWNTO 0);
		LEDG :  OUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		LEDR :  OUT  STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END memcntl2;

ARCHITECTURE bdf_type OF memcntl2 IS 

COMPONENT memtest
	PORT(rvalid : IN STD_LOGIC;
		 waitreq : IN STD_LOGIC;
		 reset : IN STD_LOGIC;
		 start : IN STD_LOGIC;
		 clk : IN STD_LOGIC;
		 skip_write : IN STD_LOGIC;
		 data_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 rd : OUT STD_LOGIC;
		 wr : OUT STD_LOGIC;
		 rst : OUT STD_LOGIC;
		 cs : OUT STD_LOGIC;
		 addr : OUT STD_LOGIC_VECTOR(21 DOWNTO 0);
		 be_n : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		 data_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		 errcnt : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
		 state_num : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END COMPONENT;

COMPONENT sdram_0
	PORT(az_cs : IN STD_LOGIC;
		 az_rd_n : IN STD_LOGIC;
		 az_wr_n : IN STD_LOGIC;
		 clk : IN STD_LOGIC;
		 reset_n : IN STD_LOGIC;
		 az_addr : IN STD_LOGIC_VECTOR(21 DOWNTO 0);
		 az_be_n : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		 az_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 zs_dq : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		 za_valid : OUT STD_LOGIC;
		 za_waitrequest : OUT STD_LOGIC;
		 zs_cas_n : OUT STD_LOGIC;
		 zs_cke : OUT STD_LOGIC;
		 zs_cs_n : OUT STD_LOGIC;
		 zs_ras_n : OUT STD_LOGIC;
		 zs_we_n : OUT STD_LOGIC;
		 za_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		 zs_addr : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
		 zs_ba : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		 zs_dqm : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
	);
END COMPONENT;

COMPONENT hexdriver
	PORT(In0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 Out0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END COMPONENT;

COMPONENT sdram_pll
	PORT(inclk0 : IN STD_LOGIC;
		 c0 : OUT STD_LOGIC;
		 c1 : OUT STD_LOGIC
	);
END COMPONENT;

SIGNAL	addr :  STD_LOGIC_VECTOR(21 DOWNTO 0);
SIGNAL	data :  STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL	DRAM_BA :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL	DRAM_DQM :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL	errcnt :  STD_LOGIC_VECTOR(23 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_0 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_1 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_2 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_3 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_17 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_5 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_6 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_7 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_8 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_10 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_11 :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_12 :  STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_13 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_14 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_15 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_16 :  STD_LOGIC_VECTOR(3 DOWNTO 0);


BEGIN 



b2v_inst : memtest
PORT MAP(rvalid => SYNTHESIZED_WIRE_0,
		 waitreq => SYNTHESIZED_WIRE_1,
		 reset => SYNTHESIZED_WIRE_2,
		 start => SYNTHESIZED_WIRE_3,
		 clk => SYNTHESIZED_WIRE_17,
		 skip_write => SYNTHESIZED_WIRE_5,
		 data_in => data,
		 rd => SYNTHESIZED_WIRE_13,
		 wr => SYNTHESIZED_WIRE_14,
		 rst => SYNTHESIZED_WIRE_15,
		 cs => SYNTHESIZED_WIRE_6,
		 addr => addr,
		 be_n => SYNTHESIZED_WIRE_11,
		 data_out => SYNTHESIZED_WIRE_12,
		 errcnt => errcnt,
		 state_num => SYNTHESIZED_WIRE_16);


b2v_inst1 : sdram_0
PORT MAP(az_cs => SYNTHESIZED_WIRE_6,
		 az_rd_n => SYNTHESIZED_WIRE_7,
		 az_wr_n => SYNTHESIZED_WIRE_8,
		 clk => SYNTHESIZED_WIRE_17,
		 reset_n => SYNTHESIZED_WIRE_10,
		 az_addr => addr,
		 az_be_n => SYNTHESIZED_WIRE_11,
		 az_data => SYNTHESIZED_WIRE_12,
		 zs_dq => DRAM_DQ,
		 za_valid => SYNTHESIZED_WIRE_0,
		 za_waitrequest => SYNTHESIZED_WIRE_1,
		 zs_cas_n => DRAM_CAS_N,
		 zs_cke => DRAM_CKE,
		 zs_cs_n => DRAM_CS_N,
		 zs_ras_n => DRAM_RAS_N,
		 zs_we_n => DRAM_WE_N,
		 za_data => data,
		 zs_addr => DRAM_ADDR,
		 zs_ba => DRAM_BA,
		 zs_dqm => DRAM_DQM);


b2v_inst10 : hexdriver
PORT MAP(In0 => errcnt(23 DOWNTO 20),
		 Out0 => HEX5);


SYNTHESIZED_WIRE_7 <= NOT(SYNTHESIZED_WIRE_13);



b2v_inst12 : hexdriver
PORT MAP(In0 => data(3 DOWNTO 0));


b2v_inst13 : hexdriver
PORT MAP(In0 => data(7 DOWNTO 4));


b2v_inst14 : hexdriver
PORT MAP(In0 => data(11 DOWNTO 8));


SYNTHESIZED_WIRE_2 <= NOT(KEY(0));



SYNTHESIZED_WIRE_3 <= NOT(KEY(1));



b2v_inst17 : hexdriver
PORT MAP(In0 => data(15 DOWNTO 12));


SYNTHESIZED_WIRE_8 <= NOT(SYNTHESIZED_WIRE_14);



b2v_inst2 : sdram_pll
PORT MAP(inclk0 => CLOCK_50,
		 c0 => DRAM_CLK,
		 c1 => SYNTHESIZED_WIRE_17);


SYNTHESIZED_WIRE_5 <= NOT(KEY(2));



SYNTHESIZED_WIRE_10 <= NOT(SYNTHESIZED_WIRE_15);



b2v_inst4 : hexdriver
PORT MAP(In0 => SYNTHESIZED_WIRE_16,
		 Out0 => HEX7);


b2v_inst5 : hexdriver
PORT MAP(In0 => errcnt(3 DOWNTO 0),
		 Out0 => HEX0);


b2v_inst6 : hexdriver
PORT MAP(In0 => errcnt(7 DOWNTO 4),
		 Out0 => HEX1);


b2v_inst7 : hexdriver
PORT MAP(In0 => errcnt(11 DOWNTO 8),
		 Out0 => HEX2);


b2v_inst8 : hexdriver
PORT MAP(In0 => errcnt(15 DOWNTO 12),
		 Out0 => HEX3);


b2v_inst9 : hexdriver
PORT MAP(In0 => errcnt(19 DOWNTO 16),
		 Out0 => HEX4);

DRAM_UDQM <= DRAM_DQM(1);
DRAM_LDQM <= DRAM_DQM(0);
DRAM_BA_1 <= DRAM_BA(1);
DRAM_BA_0 <= DRAM_BA(0);
LEDG(7 DOWNTO 0) <= addr(21 DOWNTO 14);
LEDR <= data;

END bdf_type;