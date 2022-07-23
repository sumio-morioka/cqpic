// PROGROM.v (ALTERA LPM version)
// Program ROM of CQPIC (PIC16F84)
// (1) Version 1.00a		Nov 1 1999
//
// Copyright(c)1999-2002 Sumio Morioka
// e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka/cqpic.htm

module progrom(romaddr, clk, romout);
	input	[12:0]	romaddr;
	input			clk;
	output	[13:0]	romout;

	lpm_rom u (
		.address(romaddr),
		//	.inclock(clk),
		.outclock(clk),
		.q(romout)
	);

	defparam	u.LPM_WIDTH		= 14;
	defparam	u.LPM_WIDTHAD	= 13;		// decrease bus size if total memory amount is smaller
	defparam	u.LPM_FILE		= "progrom.mif";
	defparam	u.LPM_ADDRESS_CONTROL	= "UNREGISTERED";
	defparam	u.LPM_OUTDATA	= "REGISTERED";

endmodule
