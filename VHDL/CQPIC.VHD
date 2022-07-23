-- CQPIC.vhd
-- CQPIC top (PIC16F8 with CPU-core, program ROM and data RAM)
-- (1) Version 1.00a		Nov 1 1999
--
-- Copyright(c)1999-2002 Sumio Morioka
-- e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity cqpic is
	port (
		ra4_in		: in  std_logic;
		ra3_in		: in  std_logic;
		ra2_in		: in  std_logic;
		ra1_in		: in  std_logic;
		ra0_in		: in  std_logic;
		rb7_in		: in  std_logic;
		rb6_in		: in  std_logic;
		rb5_in		: in  std_logic;
		rb4_in		: in  std_logic;
		rb3_in		: in  std_logic;
		rb2_in		: in  std_logic;
		rb1_in		: in  std_logic;
		rb0_in		: in  std_logic;

		ponrst_n	: in  std_logic;
		mclr_n		: in  std_logic;
		clkin		: in  std_logic;
		wdtena		: in  std_logic;
		wdtclk		: in  std_logic;

		ra4_out		: out std_logic;
		ra3_out		: out std_logic;
		ra2_out		: out std_logic;
		ra1_out		: out std_logic;
		ra0_out		: out std_logic;
		rb7_out		: out std_logic;
		rb6_out		: out std_logic;
		rb5_out		: out std_logic;
		rb4_out		: out std_logic;
		rb3_out		: out std_logic;
		rb2_out		: out std_logic;
		rb1_out		: out std_logic;
		rb0_out		: out std_logic;

		ra4_dir		: out std_logic;
		ra3_dir		: out std_logic;
		ra2_dir		: out std_logic;
		ra1_dir		: out std_logic;
		ra0_dir		: out std_logic;
		rb7_dir		: out std_logic;
		rb6_dir		: out std_logic;
		rb5_dir		: out std_logic;
		rb4_dir		: out std_logic;
		rb3_dir		: out std_logic;
		rb2_dir		: out std_logic;
		rb1_dir		: out std_logic;
		rb0_dir		: out std_logic;

		clkout		: out std_logic;
		wdtfull		: out std_logic;
		powerdown	: out std_logic;
		startclkin	: out std_logic
	);
end cqpic;

architecture RTL of cqpic is
	-- CPU core
	component piccore
		generic (
			STACK_SIZE	: integer;
			WDT_SIZE	: integer
		);
		port (
			progdata	: in  std_logic_vector(13 downto 0);
			progadr		: out std_logic_vector(12 downto 0);
			ramdtin		: in  std_logic_vector(7 downto 0);
			ramdtout	: out std_logic_vector(7 downto 0);
			ramadr		: out std_logic_vector(8 downto 0);
			readram		: out std_logic;
			writeram	: out std_logic;
			existeeprom	: in  std_logic;
			eepdtin		: in  std_logic_vector(7 downto 0);
			eepdtout	: out std_logic_vector(7 downto 0);
			eepadr		: out std_logic_vector(7 downto 0);
			readeepreq	: out std_logic;
			readeepack	: in  std_logic;
			writeeepreq	: out std_logic;
			writeeepack	: in  std_logic;
			porta_in	: in  std_logic_vector(4 downto 0);
			porta_out	: out std_logic_vector(4 downto 0);
			porta_dir	: out std_logic_vector(4 downto 0);
			portb_in	: in  std_logic_vector(7 downto 0);
			portb_out	: out std_logic_vector(7 downto 0);
			portb_dir	: out std_logic_vector(7 downto 0);
			rbpu		: out std_logic;
			int0		: in  std_logic;
			int4		: in  std_logic;
			int5		: in  std_logic;
			int6		: in  std_logic;
			int7		: in  std_logic;
			t0cki		: in  std_logic;
			wdtena		: in  std_logic;
			wdtclk		: in  std_logic;
			wdtfull		: out std_logic;
			powerdown	: out std_logic;
			startclkin	: out std_logic;
			ponrst_n	: in  std_logic;
			mclr_n		: in  std_logic;
			clkin		: in  std_logic;
			clkout		: out std_logic
		);
	end component;

	-- program ROM
	component progrom
		port (
			romaddr		: in  std_logic_vector(12 downto 0);
			clk			: in  std_logic;
			romout		: out std_logic_vector(13 downto 0)
		);
	end component;

	-- data RAM (SRAM)
	component dataram
		port (
			addr	: in  std_logic_vector(8 downto 0);
			read	: in  std_logic;
			write	: in  std_logic;
			clk		: in  std_logic;
			datain	: in  std_logic_vector(7 downto 0);
			dataout	: out std_logic_vector(7 downto 0)
		);
	end component;

	signal romaddr		: std_logic_vector(12 downto 0);
	signal romdata		: std_logic_vector(13 downto 0);

	signal ramaddr		: std_logic_vector(8 downto 0);
	signal ramindata	: std_logic_vector(7 downto 0);
	signal ramoutdata	: std_logic_vector(7 downto 0);
	signal readram		: std_logic;
	signal writeram		: std_logic;

	signal rain_node	: std_logic_vector(4 downto 0);
	signal raout_node	: std_logic_vector(4 downto 0);
	signal radir_node	: std_logic_vector(4 downto 0);

	signal rbin_node	: std_logic_vector(7 downto 0);
	signal rbout_node	: std_logic_vector(7 downto 0);
	signal rbdir_node	: std_logic_vector(7 downto 0);

	signal VCC_node		: std_logic;
	signal GND_node		: std_logic;
	signal GND_vec_node	: std_logic_vector(7 downto 0);

begin
	VCC_node		<= '1';
	GND_node		<= '0';
	GND_vec_node	<= "00000000";

	U1: piccore
		generic map (
			STACK_SIZE	=> 8,
			WDT_SIZE	=> 255
		)
		port map (
			progdata	=>	romdata,		--  in
			progadr		=>	romaddr,		--  out
			ramdtin		=>	ramoutdata,		--  in
			ramdtout	=>	ramindata,		--  out
			ramadr		=>	ramaddr,		--  out
			readram		=>	readram,		--  out
			writeram	=>	writeram,		--  out
			existeeprom	=>	GND_node,		--  in
			eepdtin		=>	GND_vec_node,	--  in
--	NC		eepdtout	=>	,				--  out
--	NC		eepadr		=>	,				--  out
--	NC		readeepreq	=>	,				--  out
			readeepack	=>	VCC_node,		--  in
--	NC		writeeepreq	=>	,				--  out
			writeeepack	=>	VCC_node,		--  in
			porta_in	=>	rain_node,		--  in
			porta_out	=>	raout_node,		--  out
			porta_dir	=>	radir_node,		--  out
			portb_in	=>	rbin_node,		--  in
			portb_out	=>	rbout_node,		--  out
			portb_dir	=>	rbdir_node,		--  out
-- NC		rbpu		=>					--  out
			int0		=>	rbin_node(0),	--  in
			int4		=>	rbin_node(4),	--  in
			int5		=>	rbin_node(5),	--  in
			int6		=>	rbin_node(6),	--  in
			int7		=>	rbin_node(7),	--  in
			t0cki		=>	rain_node(4),	--  in
			wdtena		=>	wdtena,			--  in
			wdtclk		=>	wdtclk,			--  in
			wdtfull		=>	wdtfull,		--  out
			powerdown	=>	powerdown,		--  out
			startclkin	=>	startclkin,		--  out
			ponrst_n	=>	ponrst_n,		--  in
			mclr_n		=>	mclr_n,			--  in
			clkin		=>	clkin,			--  in
			clkout		=>	clkout			--  out
		);

	U2: progrom
		port map (
			romaddr		=> romaddr,
			clk			=> clkin,
			romout		=> romdata
		);

	U3: dataram
		port map (
			addr		=> ramaddr,
			read		=> readram,
			write		=> writeram,
			clk			=> clkin,
			datain		=> ramindata,
			dataout		=> ramoutdata
		);

	rain_node(4) <= ra4_in;
	rain_node(3) <= ra3_in;
	rain_node(2) <= ra2_in;
	rain_node(1) <= ra1_in;
	rain_node(0) <= ra0_in;

	ra4_out	<= raout_node(4);
	ra3_out	<= raout_node(3);
	ra2_out	<= raout_node(2);
	ra1_out	<= raout_node(1);
	ra0_out	<= raout_node(0);

	ra4_dir	<= radir_node(4);
	ra3_dir	<= radir_node(3);
	ra2_dir	<= radir_node(2);
	ra1_dir	<= radir_node(1);
	ra0_dir	<= radir_node(0);


	rbin_node(7) <= rb7_in;
	rbin_node(6) <= rb6_in;
	rbin_node(5) <= rb5_in;
	rbin_node(4) <= rb4_in;
	rbin_node(3) <= rb3_in;
	rbin_node(2) <= rb2_in;
	rbin_node(1) <= rb1_in;
	rbin_node(0) <= rb0_in;

	rb7_out	<= rbout_node(7);
	rb6_out	<= rbout_node(6);
	rb5_out	<= rbout_node(5);
	rb4_out	<= rbout_node(4);
	rb3_out	<= rbout_node(3);
	rb2_out	<= rbout_node(2);
	rb1_out	<= rbout_node(1);
	rb0_out	<= rbout_node(0);

	rb7_dir	<= rbdir_node(7);
	rb6_dir	<= rbdir_node(6);
	rb5_dir	<= rbdir_node(5);
	rb4_dir	<= rbdir_node(4);
	rb3_dir	<= rbdir_node(3);
	rb2_dir	<= rbdir_node(2);
	rb1_dir	<= rbdir_node(1);
	rb0_dir	<= rbdir_node(0);

end RTL;
