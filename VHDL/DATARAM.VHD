-- DATARAM.vhd (LPM version)
-- Data RAM of CQPIC (PIC16F84)
-- (1) Version 1.00a		Nov 1 1999
--
-- Copyright(c)1999-2002 Sumio Morioka
-- e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka/cqpic.htm

-- 注意：このファイルはALTERA用です．Xilinxの場合はCoreGeneratorでメモリを生成して使ってください．
-- そのとき，出力側はレジスタ付きで入力側はレジスタなし（つまりレイテンシ１クロック）としてください．

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use lpm.lpm_components.all;

entity dataram is
	port (
		addr	: in  std_logic_vector(8 downto 0);
		read	: in  std_logic;
		write	: in  std_logic;
		clk		: in  std_logic;
		datain	: in  std_logic_vector(7 downto 0);
		dataout	: out std_logic_vector(7 downto 0)
	);
end dataram;

architecture RTL of dataram is
begin
	RAM: lpm_ram_dq
		generic map (
--			LPM_WIDTHAD  => 9,			-- Full implementation of BANK3-0
			LPM_WIDTHAD  => 7,			-- BANK0 only
			LPM_WIDTH 	 => 8,
			LPM_INDATA 	 => "UNREGISTERED",
			LPM_ADDRESS_CONTROL => "UNREGISTERED",
			LPM_OUTDATA  => "REGISTERED"
		)
		port map (
			data    => datain,
--			address => addr,				-- Full implementation of BANK3-0
			address => addr(6 downto 0),	-- BANK0 only
--			inclock	=> clk,
			outclock=> clk,
			we      => write,
			q		=> dataout
		);
end RTL;
