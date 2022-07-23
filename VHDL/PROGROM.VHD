-- PROGROM.vhd (LPM version)
-- Program ROM of CQPIC (PIC16F84)
-- (1) Version 1.00a		Nov 1 1999
--
-- Copyright(c)1999-2002 Sumio Morioka
-- e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka/cqpic.htm

-- 注意：このファイルはALTERA用です．Xilinxの場合はCoreGeneratorでメモリを生成して使ってください．
-- そのとき，レジスタは付けても付けなくても大丈夫です（レイテンシが３以下ならなんでもよい）．

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use		lpm.lpm_components.all;

entity progrom is
	port (
		romaddr		: in  std_logic_vector(12 downto 0);
		clk			: in  std_logic;
		romout		: out std_logic_vector(13 downto 0)
	);
end progrom;

architecture RTL of progrom is
begin
	u1: lpm_rom
		generic map (
			LPM_WIDTH			=> 14,
			LPM_WIDTHAD			=> 13,				-- decrease bus size if total memory amount is smaller
			LPM_FILE			=> "progrom.mif",
			LPM_ADDRESS_CONTROL	=> "UNREGISTERED",
			LPM_OUTDATA			=> "REGISTERED"
		)
		port map (
			address		=> romaddr,
--			inclock		=> clk,
			outclock	=> clk,
			q			=> romout
		);
end RTL;
