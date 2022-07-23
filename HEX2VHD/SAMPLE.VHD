library ieee;
use ieee.std_logic_1164.all;

entity sample is
	port (
		romaddr	: in  std_logic_vector(12 downto 0);
		romout	: out std_logic_vector(13 downto 0)
	);
end sample;

architecture RTL of sample is
begin
	process (romaddr)
	begin
		case romaddr is
		when "0000000000000" => romout <= "10100000000101";	-- addr 0000: data 2805
		when "0000000000100" => romout <= "10100000010011";	-- addr 0004: data 2813
		when "0000000000101" => romout <= "01011010000011";	-- addr 0005: data 1683
		when "0000000000110" => romout <= "11000011010111";	-- addr 0006: data 30D7
		when "0000000000111" => romout <= "00000010000001";	-- addr 0007: data 0081
		when "0000000001000" => romout <= "11000010111000";	-- addr 0008: data 30B8
		when "0000000001001" => romout <= "00000010001011";	-- addr 0009: data 008B
		when "0000000001010" => romout <= "01001010000011";	-- addr 000A: data 1283
		when "0000000001011" => romout <= "00000100000011";	-- addr 000B: data 0103
		when "0000000001100" => romout <= "00000010010001";	-- addr 000C: data 0091
		when "0000000001101" => romout <= "00000010010010";	-- addr 000D: data 0092
		when "0000000001110" => romout <= "11000000000000";	-- addr 000E: data 3000
		when "0000000001111" => romout <= "00000010010011";	-- addr 000F: data 0093
		when "0000000010000" => romout <= "00100000010001";	-- addr 0010: data 0811
		when "0000000010001" => romout <= "00000010000110";	-- addr 0011: data 0086
		when "0000000010010" => romout <= "10100000010000";	-- addr 0012: data 2810
		when "0000000010011" => romout <= "00000010010000";	-- addr 0013: data 0090
		when "0000000010100" => romout <= "01110100001011";	-- addr 0014: data 1D0B
		when "0000000010101" => romout <= "10100000110101";	-- addr 0015: data 2835
		when "0000000010110" => romout <= "01110000010010";	-- addr 0016: data 1C12
		when "0000000010111" => romout <= "10100000110101";	-- addr 0017: data 2835
		when "0000000011000" => romout <= "00100000010001";	-- addr 0018: data 0811
		when "0000000011001" => romout <= "11111000000001";	-- addr 0019: data 3E01
		when "0000000011010" => romout <= "00000010010001";	-- addr 001A: data 0091
		when "0000000011011" => romout <= "01110010010010";	-- addr 001B: data 1C92
		when "0000000011100" => romout <= "10100000110101";	-- addr 001C: data 2835
		when "0000000011101" => romout <= "00100000010011";	-- addr 001D: data 0813
		when "0000000011110" => romout <= "11110000000111";	-- addr 001E: data 3C07
		when "0000000011111" => romout <= "01110100000011";	-- addr 001F: data 1D03
		when "0000000100000" => romout <= "10100000100011";	-- addr 0020: data 2823
		when "0000000100001" => romout <= "01000000010010";	-- addr 0021: data 1012
		when "0000000100010" => romout <= "10100000110101";	-- addr 0022: data 2835
		when "0000000100011" => romout <= "00100000010100";	-- addr 0023: data 0814
		when "0000000100100" => romout <= "11110001000000";	-- addr 0024: data 3C40
		when "0000000100101" => romout <= "01100100000011";	-- addr 0025: data 1903
		when "0000000100110" => romout <= "10100000101011";	-- addr 0026: data 282B
		when "0000000100111" => romout <= "00100000010100";	-- addr 0027: data 0814
		when "0000000101000" => romout <= "11111000000001";	-- addr 0028: data 3E01
		when "0000000101001" => romout <= "00000010010100";	-- addr 0029: data 0094
		when "0000000101010" => romout <= "10100000110101";	-- addr 002A: data 2835
		when "0000000101011" => romout <= "00100000010011";	-- addr 002B: data 0813
		when "0000000101100" => romout <= "11111000000001";	-- addr 002C: data 3E01
		when "0000000101101" => romout <= "00000010010011";	-- addr 002D: data 0093
		when "0000000101110" => romout <= "11100100000111";	-- addr 002E: data 3907
		when "0000000101111" => romout <= "11100011010000";	-- addr 002F: data 38D0
		when "0000000110000" => romout <= "01011010000011";	-- addr 0030: data 1683
		when "0000000110001" => romout <= "00000010000001";	-- addr 0031: data 0081
		when "0000000110010" => romout <= "01001010000011";	-- addr 0032: data 1283
		when "0000000110011" => romout <= "00000110010100";	-- addr 0033: data 0194
		when "0000000110100" => romout <= "00000110000001";	-- addr 0034: data 0181
		when "0000000110101" => romout <= "01110010001011";	-- addr 0035: data 1C8B
		when "0000000110110" => romout <= "10100001000010";	-- addr 0036: data 2842
		when "0000000110111" => romout <= "01010000010010";	-- addr 0037: data 1412
		when "0000000111000" => romout <= "01000010010010";	-- addr 0038: data 1092
		when "0000000111001" => romout <= "11000000000000";	-- addr 0039: data 3000
		when "0000000111010" => romout <= "00000010010011";	-- addr 003A: data 0093
		when "0000000111011" => romout <= "11100100000111";	-- addr 003B: data 3907
		when "0000000111100" => romout <= "11100011010000";	-- addr 003C: data 38D0
		when "0000000111101" => romout <= "01011010000011";	-- addr 003D: data 1683
		when "0000000111110" => romout <= "00000010000001";	-- addr 003E: data 0081
		when "0000000111111" => romout <= "01001010000011";	-- addr 003F: data 1283
		when "0000001000000" => romout <= "00000110000001";	-- addr 0040: data 0181
		when "0000001000001" => romout <= "10100001000111";	-- addr 0041: data 2847
		when "0000001000010" => romout <= "01110000001011";	-- addr 0042: data 1C0B
		when "0000001000011" => romout <= "10100001000111";	-- addr 0043: data 2847
		when "0000001000100" => romout <= "01010010010010";	-- addr 0044: data 1492
		when "0000001000101" => romout <= "00000110010100";	-- addr 0045: data 0194
		when "0000001000110" => romout <= "00000110000001";	-- addr 0046: data 0181
		when "0000001000111" => romout <= "01000100001011";	-- addr 0047: data 110B
		when "0000001001000" => romout <= "01000010001011";	-- addr 0048: data 108B
		when "0000001001001" => romout <= "01000000001011";	-- addr 0049: data 100B
		when "0000001001010" => romout <= "00100000010000";	-- addr 004A: data 0810
		when "0000001001011" => romout <= "00000000001001";	-- addr 004B: data 0009
		when others => romout <= "00000000000000";
		end case;
	end process;

end RTL;
