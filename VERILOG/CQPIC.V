// CQPIC.v
// CQPIC top (PIC16F8 with CPU-core, program ROM and data RAM)
// (1) Version 1.00a		Nov 1 1999
//
// Copyright(c)1999-2002 Sumio Morioka
// e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka

module cqpic(ra4_in, ra3_in, ra2_in, ra1_in, ra0_in,
			rb7_in, rb6_in, rb5_in, rb4_in, rb3_in, rb2_in, rb1_in, rb0_in, 
			ponrst_n, mclr_n, clkin, 
			wdtena, wdtclk, 
			ra4_out, ra3_out, ra2_out, ra1_out, ra0_out, 
			rb7_out, rb6_out, rb5_out, rb4_out, rb3_out, rb2_out, rb1_out, rb0_out, 
			ra4_dir, ra3_dir, ra2_dir, ra1_dir, ra0_dir, 
			rb7_dir, rb6_dir, rb5_dir, rb4_dir, rb3_dir, rb2_dir, rb1_dir, rb0_dir, 
			clkout, wdtfull, 
			powerdown, startclkin);

	input			ra4_in;
	input			ra3_in;
	input			ra2_in;
	input			ra1_in;
	input			ra0_in;
	input			rb7_in;
	input			rb6_in;
	input			rb5_in;
	input			rb4_in;
	input			rb3_in;
	input			rb2_in;
	input			rb1_in;
	input			rb0_in;

	input			ponrst_n;
	input			mclr_n;
	input			clkin;
	input			wdtena;
	input			wdtclk;

	output			ra4_out;
	output			ra3_out;
	output			ra2_out;
	output			ra1_out;
	output			ra0_out;
	output			rb7_out;
	output			rb6_out;
	output			rb5_out;
	output			rb4_out;
	output			rb3_out;
	output			rb2_out;
	output			rb1_out;
	output			rb0_out;

	output			ra4_dir;
	output			ra3_dir;
	output			ra2_dir;
	output			ra1_dir;
	output			ra0_dir;
	output			rb7_dir;
	output			rb6_dir;
	output			rb5_dir;
	output			rb4_dir;
	output			rb3_dir;
	output			rb2_dir;
	output			rb1_dir;
	output			rb0_dir;

	output			clkout;
	output			wdtfull;
	output			powerdown;
	output			startclkin;


	wire	[12:0]	romaddr;
	wire	[13:0]	romdata;

	wire	[8:0]	ramaddr;
	wire	[7:0]	ramindata;
	wire	[7:0]	ramoutdata;
	wire			readram;
	wire			writeram;

	wire	[4:0]	rain_node;
	wire	[4:0]	raout_node;
	wire	[4:0]	radir_node;

	wire	[7:0]	rbin_node;
	wire	[7:0]	rbout_node;
	wire	[7:0]	rbdir_node;

	wire			VCC_node;
	wire			GND_node;
	wire	[7:0]	GND_vec_node;


	assign	VCC_node		= 1'b1;
	assign	GND_node		= 1'b0;
	assign	GND_vec_node	= 8'b00000000;

	piccore U1 (
		.progdata(romdata),		//  in
		.progadr(romaddr),		//  out
		.ramdtin(ramoutdata),	//  in
		.ramdtout(ramindata),	//  out
		.ramadr(ramaddr),		//  out
		.readram(readram),		//  out
		.writeram(writeram),	//  out
		.existeeprom(GND_node),	//  in
		.eepdtin(GND_vec_node),	//  in
		//	NC		.eepdtout(),	//  out
		//	NC		.eepadr(),		//  out
		//	NC		.readeepreq(),	//  out
		.readeepack(VCC_node),	//  in
		//	NC		.writeeepreq(),	//  out
		.writeeepack(VCC_node),	//  in
		.porta_in(rain_node),	//  in
		.porta_out(raout_node),	//  out
		.porta_dir(radir_node),	//  out
		.portb_in(rbin_node),	//  in
		.portb_out(rbout_node),	//  out
		.portb_dir(rbdir_node),	//  out
		// NC		.rbpu(),		//  out
		.int0(rbin_node[0]),	//  in
		.int4(rbin_node[4]),	//  in
		.int5(rbin_node[5]),	//  in
		.int6(rbin_node[6]),	//  in
		.int7(rbin_node[7]),	//  in
		.t0cki(rain_node[4]),	//  in
		.wdtena(wdtena),		//  in
		.wdtclk(wdtclk),		//  in
		.wdtfull(wdtfull),		//  out
		.powerdown(powerdown),	//  out
		.startclkin(startclkin),//  out
		.ponrst_n(ponrst_n),	//  in
		.mclr_n(mclr_n),		//  in
		.clkin(clkin),			//  in
		.clkout(clkout)			//  out
	);

	progrom	U2 (
		.romaddr(romaddr),
		.clk(clkin),
		.romout(romdata)
	);

	dataram	U3 (
		.addr(ramaddr),
		.read(readram),
		.write(writeram),
		.clk(clkin),
		.datain(ramindata),
		.dataout(ramoutdata)
	);

	assign	rain_node[4]	= ra4_in;
	assign	rain_node[3]	= ra3_in;
	assign	rain_node[2]	= ra2_in;
	assign	rain_node[1]	= ra1_in;
	assign	rain_node[0]	= ra0_in;

	assign	ra4_out	= raout_node[4];
	assign	ra3_out	= raout_node[3];
	assign	ra2_out	= raout_node[2];
	assign	ra1_out	= raout_node[1];
	assign	ra0_out	= raout_node[0];

	assign	ra4_dir	= radir_node[4];
	assign	ra3_dir	= radir_node[3];
	assign	ra2_dir	= radir_node[2];
	assign	ra1_dir	= radir_node[1];
	assign	ra0_dir	= radir_node[0];

	assign	rbin_node[7]	= rb7_in;
	assign	rbin_node[6]	= rb6_in;
	assign	rbin_node[5]	= rb5_in;
	assign	rbin_node[4]	= rb4_in;
	assign	rbin_node[3]	= rb3_in;
	assign	rbin_node[2]	= rb2_in;
	assign	rbin_node[1]	= rb1_in;
	assign	rbin_node[0]	= rb0_in;

	assign	rb7_out	= rbout_node[7];
	assign	rb6_out	= rbout_node[6];
	assign	rb5_out	= rbout_node[5];
	assign	rb4_out	= rbout_node[4];
	assign	rb3_out	= rbout_node[3];
	assign	rb2_out	= rbout_node[2];
	assign	rb1_out	= rbout_node[1];
	assign	rb0_out	= rbout_node[0];

	assign	rb7_dir	= rbdir_node[7];
	assign	rb6_dir	= rbdir_node[6];
	assign	rb5_dir	= rbdir_node[5];
	assign	rb4_dir	= rbdir_node[4];
	assign	rb3_dir	= rbdir_node[3];
	assign	rb2_dir	= rbdir_node[2];
	assign	rb1_dir	= rbdir_node[1];
	assign	rb0_dir	= rbdir_node[0];

endmodule
