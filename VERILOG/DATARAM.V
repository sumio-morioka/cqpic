// DATARAM.v (ALTERA LPM version)
// Data RAM of CQPIC (PIC16F84)
// (1) Version 1.00a		Nov 1 1999
//
// Copyright(c)1999-2002 Sumio Morioka
// e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka/cqpic.htm

module dataram(addr, read, write, clk, datain, dataout);
	input	[8:0]	addr;
	input			read;
	input			write;
	input			clk;
	input	[7:0]	datain;
	output	[7:0]	dataout;

	lpm_ram_dq u (
		.data(datain),
		//	.address(addr),		// Full implementation of BANK3-0
		.address(addr[6:0]),	// BANK0 only
		//	.inclock(clk),
		.outclock(clk),
		.we(write),
		.q(dataout)
	);

//	defparam	u.LPM_WIDTHAD	= 9;	// LPM_WIDTHAD (Full implementation of BANK3-0)
	defparam	u.LPM_WIDTHAD	= 7;	// LPM_WIDTHAD (BANK0 only)
	defparam	u.LPM_WIDTH		= 8;
	defparam	u.LPM_INDATA	= "UNREGISTERED";
	defparam	u.LPM_ADDRESS_CONTROL	= "UNREGISTERED";
	defparam	u.LPM_OUTDATA	= "REGISTERED";

endmodule
