// PICCORE.vhd
// CPU core of CQPIC (PIC16F84/16F84A)
// (1) Version 1.00a		Nov 1  1999
// (2) Version 1.00b		Dec 10 2000		made a patch for BUG in MAX+plus2 VHDL compiler
// (3) Version 1.00c		Aug 07 2002		made a patch for carry flag operations at substraction operations
// (4) Version 1.00d		Aug 26 2004		debugged Z flag behavior (in case such that distinations are same as them)
//
// Copyright(c)1999-2004 Sumio Morioka
// e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka/cqpic.htm

module piccore(progdata, progadr, 
				ramdtin, ramdtout, ramadr, readram, writeram, 
				existeeprom, eepdtin, eepdtout, eepadr, readeepreq, readeepack, writeeepreq, writeeepack, 
				porta_in, porta_out, porta_dir, 
				portb_in, portb_out, portb_dir, 
				rbpu, 
				int0, int4, int5, int6, int7, 
				t0cki, 
				wdtena, wdtclk, wdtfull, 
				powerdown, startclkin, 
				ponrst_n, mclr_n, 
				clkin, clkout);

	// program ROM data bus/address bus
	input	[13:0]	progdata;	// ROM read data
	output	[12:0]	progadr;	// ROM address

	// data RAM data bus/address bus/control signals
	input	[7:0]	ramdtin;	// RAM read data
	output	[7:0]	ramdtout;	// RAM write data
	output	[8:0]	ramadr;		// RAM address; ramadr(8..7) indicates RAM-BANK
	output			readram;	// RAM read strobe (H active)
	output			writeram;	// RAM write strobe (H active)

	// EEPROM data bus/address bus
	input			existeeprom;// Set to '1' if EEPROM is implemented.
	input	[7:0]	eepdtin;	// EEPROM read data
	output	[7:0]	eepdtout;	// EEPROM write data
	output	[7:0]	eepadr;		// EEPROM address
	output			readeepreq;	// EEPROM read request (H active)
	input			readeepack;	// EEPROM read acknowledge (H active)
	output			writeeepreq;// EEPROM write request (H active)
	input			writeeepack;// EEPROM write acknowledge (H active)

	// I/O ports
	input	[4:0]	porta_in;	// PORT-A input data
	output	[4:0]	porta_out;	// PORT-A output data
	output	[4:0]	porta_dir;	// TRISA: PORT-A signal direction (H:input, L:output)

	input	[7:0]	portb_in;	// PORT-B input data
	output	[7:0]	portb_out;	// PORT-B output data
	output	[7:0]	portb_dir;	// TRISB: PORT-B signal direction (H:input, L:output)

	output			rbpu;		// PORT_B pull-up enable (usually not used)

	// PORT-B interrupt input
	input			int0;		// PORT-B(0) INT
	input			int4;		// PORT-B(4) INT
	input			int5;		// PORT-B(5) INT
	input			int6;		// PORT-B(6) INT
	input			int7;		// PORT-B(7) INT

	// TMR0 Control
	input			t0cki;		// T0CKI (PORT-A(4))

	// Watch Dog Timer Control
	input			wdtena;		// WDT enable (H active)
	input			wdtclk;		// WDT clock
	output			wdtfull;	// WDT-full indicator (H active)

	// CPU clock stop/start indicators
	output			powerdown;	// SLEEP-mode; if H, you can stop system clock clkin
	output			startclkin;	// WAKEUP; if H, you should turn on clock for waking up from sleep-mode

	// CPU reset
	input			ponrst_n;	// Power-on reset (L active)
	input			mclr_n;		// Normal reset (L active)

	// CPU clock
	input			clkin;		// Clock input
	output			clkout;		// Clock output (clkin/4)


	// User registers
	reg 	[7:0]	w_reg;		// W

	reg 	[7:0]	tmr0_reg;	// TMR0
	reg 	[12:0]	pc_reg;		// PCH/PCL
	reg 	[7:0]	status_reg;	// STATUS
	reg 	[7:0]	fsr_reg;	// FSR
	reg 	[4:0]	portain_sync_reg;	// PORTA IN (synchronizer)
	reg 	[4:0]	portaout_reg;		// PORTA OUT
	reg 	[7:0]	portbin_sync_reg;	// PORTB IN (synchronizer)
	reg 	[7:0]	portbout_reg;		// PORTB OUT
	reg 	[7:0]	eedata_reg;	// EEDATA
	reg 	[7:0]	eeadr_reg;	// EEADR
	reg 	[4:0]	pclath_reg;	// PCLATH
	reg 	[7:0]	intcon_reg;	// INTCON
	reg 	[7:0]	option_reg;	// OPTION
	reg 	[4:0]	trisa_reg;	// TRISA
	reg 	[7:0]	trisb_reg;	// TRISB
	reg 	[4:0]	eecon1_reg;	// EECON1

	// Internal registers for controlling instruction execution
	reg 	[13:0]	inst_reg;		// Hold fetched op-code/operand
	reg 	[7:0]	aluinp1_reg;	// data source (1 of 2)
//> changed ver1.00c, 2002/08/07
	//	reg [7:0]	aluinp2_reg		// data source (2 of 2)
	reg 	[8:0]	aluinp2_reg;	// data source (2 of 2)
//<
	reg 	[7:0]	aluout_reg;		// result of calculation
	reg 			exec_op_reg;	// if L (i.e. GOTO instruction etc), stall exec of instruction
	reg 			intstart_reg;	// if H (i.e. interrupt), stall exec of instruction
	reg 			sleepflag_reg;	// if H, sleeping

	// Stack
	reg 	[12:0]	stack_reg	[8 - 1:0];	// stack body (array of data-registers)
	reg 	[2:0]	stack_pnt_reg;			// stack pointer (binary encoded)
	wire	[8 - 1:0]	stack_pos_node;		// same with stack pointer, but one-hot encoded
	reg 	[12:0]	stacktop_node;			// data value of stack-top

	// WDT register and its control
	reg 	[7:0]	wdt_reg;				// WDT counter
	reg 			wdt_full_reg;			// WDT->CPU; hold WDT-full signal until CPU is reset
	reg 	[2:0]	wdt_full_sync_reg;		// CPU; synchronizer for wdt_full_reg

	reg 			wdt_clr_reg;			// CPU->WDT; request to zero-clear wdt_reg
	reg 			wdt_clr_reqhold_reg;	// CPU; hold a clear-request if previous request is still processing
	reg 	[1:0]	wdtclr_req_reg;			// WDT; synchronizer for wdt_clr_reg
	wire			wdtclr_ack;				// WDT->CPU; ack to wdt_clr_reg (same with wdtclr_req_reg(1))
	reg 			wdtclr_ack_sync_reg;	// CPU; synchronizer for wdtclr_ack

	reg 			wdtfull_clr_reg;		// CPU->WDT; requst to clear wdt_full_reg
	reg 	[1:0]	wdtfullclr_req_reg;		// WDT; synchronizer for wdtfull_clr_reg

	// TMR0 prescaler
	wire			psck;			// clock for prescaler
	reg 	[7:0]	pscale_reg;		// prescaler
	reg 			ps_full_reg;	// clock for TMR0, from prescaler
	wire			inctmrck;		// clock for TMR0
	reg 			inctmrhold_reg;	// hold TMR0 increment request

	// Interrupt registers/nodes
	reg 	[4:0]	intrise_reg;	// detect positive edge of PORT-B inputs
	reg 	[4:0]	intdown_reg;	// detect negative edge of PORT-B inputs
	wire			rb0_int, rb4_int, rb5_int, rb6_int, rb7_int;	// interrupt trigger
	wire			rbint;			// RB4-7 interrupt trigger
	wire			inte;			// RB0   interrupt trigger
	reg 	[4:0]	intclr_reg;		// CPU; clear intrise_reg and intdown_reg

	// State register
	parameter	STATEBIT_SIZE	= 3;
	reg 	[STATEBIT_SIZE - 1:0]	state_reg;
	parameter	Qreset	= 3'b100;	// reset state
	parameter	Q1	= 3'b000;		// state Q1
	parameter	Q2	= 3'b001;		// state Q2
	parameter	Q3	= 3'b011;		// state Q3
	parameter	Q4	= 3'b010;		// state Q4

	// Result of decoding instruction
	wire			INST_ADDLW, INST_ADDWF, INST_ANDLW, INST_ANDWF, INST_BCF, INST_BSF, INST_BTFSC, INST_BTFSS;
	wire			INST_CALL, INST_CLRF, INST_CLRW, INST_CLRWDT, INST_COMF, INST_DECF, INST_DECFSZ;
	wire			INST_GOTO, INST_INCF, INST_INCFSZ, INST_IORLW, INST_IORWF, INST_MOVLW, INST_MOVF, INST_MOVWF;
	wire			INST_RETFIE, INST_RETLW, INST_RET, INST_RLF, INST_RRF;
	wire			INST_SLEEP, INST_SUBLW, INST_SUBWF, INST_SWAPF, INST_XORLW, INST_XORWF;

	// Result of calculating RAM access address
	wire	[8:0]	ramadr_node;	// RAM access address

	wire			ADDR_TMR0, ADDR_PCL, ADDR_STAT, ADDR_FSR, ADDR_PORTA, ADDR_PORTB;
	wire			ADDR_EEDATA, ADDR_EEADR, ADDR_PCLATH, ADDR_INTCON, ADDR_OPTION, ADDR_TRISA, ADDR_TRISB;
	//	wire ADDR_EECON1, ADDR_EECON2, ADDR_SRAM															: std_logic;
	wire			ADDR_EECON1, ADDR_SRAM;

	// Other output registers (for removing hazards)
	reg 			writeram_reg;	// data-sram write strobe
//> deleted ver1.00c, 2002/08/07
	//	reg	[8:0]	ramadr_reg		// data-sram address
//<
	reg 			clkout_reg;		// clkout output

	// Synchronizers
	reg 			inte_sync_reg;
	reg 			rbint_sync_reg;
	reg 	[1:0]	inctmr_sync_reg;
	reg 			rdeep_sync_reg;
	reg 			wreep_sync_reg;
	reg 			mclr_sync_reg;
	reg 			poweron_sync_reg;


// CPU synchronizers
	always @(posedge clkin) begin
		inte_sync_reg		<= inte;
		rbint_sync_reg		<= rbint;
		wdtclr_ack_sync_reg	<= wdtclr_ack;
		mclr_sync_reg		<= mclr_n;
		poweron_sync_reg	<= ponrst_n;
		rdeep_sync_reg		<= readeepack;
		wreep_sync_reg		<= writeeepack;
		inctmr_sync_reg[0]	<= inctmrck;
		inctmr_sync_reg[1]	<= inctmr_sync_reg[0];
		if (poweron_sync_reg == 1'b0 || mclr_sync_reg == 1'b0) begin
			wdt_full_sync_reg	<= 3'b000;
		end else begin
			wdt_full_sync_reg[0]	<= wdt_full_reg;
			wdt_full_sync_reg[1]	<= wdt_full_sync_reg[0];	// (remove meta-stable)
			wdt_full_sync_reg[2]	<= wdt_full_sync_reg[1];	// (detect positive edge)
		end
	end


// Decode OPcode	(see pp.54 of PIC16F84 data sheet)
	// only 1 signal of the following signals will be '1'
	assign	INST_CALL	= (inst_reg[13:11] == 3'b100)   ? 1'b1 : 1'b0;
	assign	INST_GOTO	= (inst_reg[13:11] == 3'b101)   ? 1'b1 : 1'b0;
	assign	INST_BCF	= (inst_reg[13:10] == 4'b0100)  ? 1'b1 : 1'b0;
	assign	INST_BSF	= (inst_reg[13:10] == 4'b0101)  ? 1'b1 : 1'b0;
	assign	INST_BTFSC	= (inst_reg[13:10] == 4'b0110)  ? 1'b1 : 1'b0;
	assign	INST_BTFSS	= (inst_reg[13:10] == 4'b0111)  ? 1'b1 : 1'b0;
	assign	INST_MOVLW	= (inst_reg[13:10] == 4'b1100)  ? 1'b1 : 1'b0;
	assign	INST_RETLW	= (inst_reg[13:10] == 4'b1101)  ? 1'b1 : 1'b0;
	assign	INST_SUBLW	= (inst_reg[13:9] == 5'b11110)  ? 1'b1 : 1'b0;
	assign	INST_ADDLW	= (inst_reg[13:9] == 5'b11111)  ? 1'b1 : 1'b0;
	assign	INST_IORLW	= (inst_reg[13:8] == 6'b111000) ? 1'b1 : 1'b0;
	assign	INST_ANDLW	= (inst_reg[13:8] == 6'b111001) ? 1'b1 : 1'b0;
	assign	INST_XORLW	= (inst_reg[13:8] == 6'b111010) ? 1'b1 : 1'b0;
	assign	INST_SUBWF	= (inst_reg[13:8] == 6'b000010) ? 1'b1 : 1'b0;
	assign	INST_DECF	= (inst_reg[13:8] == 6'b000011) ? 1'b1 : 1'b0;
	assign	INST_IORWF	= (inst_reg[13:8] == 6'b000100) ? 1'b1 : 1'b0;
	assign	INST_ANDWF	= (inst_reg[13:8] == 6'b000101) ? 1'b1 : 1'b0;
	assign	INST_XORWF	= (inst_reg[13:8] == 6'b000110) ? 1'b1 : 1'b0;
	assign	INST_ADDWF	= (inst_reg[13:8] == 6'b000111) ? 1'b1 : 1'b0;
	assign	INST_MOVF	= (inst_reg[13:8] == 6'b001000) ? 1'b1 : 1'b0;
	assign	INST_COMF	= (inst_reg[13:8] == 6'b001001) ? 1'b1 : 1'b0;
	assign	INST_INCF	= (inst_reg[13:8] == 6'b001010) ? 1'b1 : 1'b0;
	assign	INST_DECFSZ	= (inst_reg[13:8] == 6'b001011) ? 1'b1 : 1'b0;
	assign	INST_RRF	= (inst_reg[13:8] == 6'b001100) ? 1'b1 : 1'b0;
	assign	INST_RLF	= (inst_reg[13:8] == 6'b001101) ? 1'b1 : 1'b0;
	assign	INST_SWAPF	= (inst_reg[13:8] == 6'b001110) ? 1'b1 : 1'b0;
	assign	INST_INCFSZ	= (inst_reg[13:8] == 6'b001111) ? 1'b1 : 1'b0;
	assign	INST_MOVWF	= (inst_reg[13:7] == 7'b0000001) ? 1'b1 : 1'b0;
	assign	INST_CLRW	= (inst_reg[13:7] == 7'b0000010) ? 1'b1 : 1'b0;
	assign	INST_CLRF	= (inst_reg[13:7] == 7'b0000011) ? 1'b1 : 1'b0;
	assign	INST_RET	= (inst_reg[13:0] == 14'b00000000001000) ? 1'b1 : 1'b0;
	assign	INST_RETFIE	= (inst_reg[13:0] == 14'b00000000001001) ? 1'b1 : 1'b0;
	assign	INST_SLEEP	= (inst_reg[13:0] == 14'b00000001100011) ? 1'b1 : 1'b0;
	assign	INST_CLRWDT	= (inst_reg[13:0] == 14'b00000001100100) ? 1'b1 : 1'b0;


// Calculate RAM access address	(see pp.19 of PIC16F84 data sheet)

	// if "d"=0, indirect addressing is used, so RAM address is BANK+FSR
	// otherwise, RAM address is BANK+"d"
	// (see pp.19 of PIC16F84 data sheet)
	assign	ramadr_node	= (inst_reg[6:0] == 7'b0000000) 
				? {status_reg[7], fsr_reg[7:0]} : {status_reg[6:5], inst_reg[6:0]};

	// check if this is an access to external RAM or not
	assign	ADDR_SRAM	= (ramadr_node[6:0] > 7'b0001011) ? 1'b1	// 0CH-7FH, 8CH-FFH
						: 1'b0;

	// check if this is an access to special register or not
	// only 1 signal of the following signals will be '1'
	assign	ADDR_TMR0	= (ramadr_node[7:0] == 8'b00000001) ? 1'b1	// 01H
				: 1'b0;
	assign	ADDR_PCL	= (ramadr_node[6:0] == 7'b0000010) ? 1'b1		// 02H, 82H
				: 1'b0;
	assign	ADDR_STAT	= (ramadr_node[6:0] == 7'b0000011) ? 1'b1		// 03H, 83H
				: 1'b0;
	assign	ADDR_FSR	= (ramadr_node[6:0] == 7'b0000100) ? 1'b1		// 04H, 84H
				: 1'b0;
	assign	ADDR_PORTA	= (ramadr_node[7:0] == 8'b00000101) ? 1'b1	// 05H
				: 1'b0;
	assign	ADDR_PORTB	= (ramadr_node[7:0] == 8'b00000110) ? 1'b1	// 06H
				: 1'b0;
	assign	ADDR_EEDATA	= (ramadr_node[7:0] == 8'b00001000) ? 1'b1	// 08H
				: 1'b0;
	assign	ADDR_EEADR	= (ramadr_node[7:0] == 8'b00001001) ? 1'b1	// 09H
				: 1'b0;
	assign	ADDR_PCLATH	= (ramadr_node[6:0] == 7'b0001010) ? 1'b1		// 0AH, 8AH
				: 1'b0;
	assign	ADDR_INTCON	= (ramadr_node[6:0] == 7'b0001011) ? 1'b1		// 0BH, 8BH
				: 1'b0;
	assign	ADDR_OPTION	= (ramadr_node[7:0] == 8'b10000001) ? 1'b1	// 81H
				: 1'b0;
	assign	ADDR_TRISA	= (ramadr_node[7:0] == 8'b10000101) ? 1'b1	// 85H
				: 1'b0;
	assign	ADDR_TRISB	= (ramadr_node[7:0] == 8'b10000110) ? 1'b1	// 86H
				: 1'b0;
	assign	ADDR_EECON1	= (ramadr_node[7:0] == 8'b10001000) ? 1'b1	// 88H
				: 1'b0;
	//	assign ADDR_EECON2	= (ramadr_node[7:0] == 8'b10001001 ? 1'b1 : 1'b0;	// 89H


// Read value of PC-STACK top
	// convert binary value of stack pointer into onehot value (for reducing circuit)
	assign	stack_pos_node[0]	= (stack_pnt_reg == 0) ? 1'b1 : 1'b0;
	assign	stack_pos_node[1]	= (stack_pnt_reg == 1) ? 1'b1 : 1'b0;
	assign	stack_pos_node[2]	= (stack_pnt_reg == 2) ? 1'b1 : 1'b0;
	assign	stack_pos_node[3]	= (stack_pnt_reg == 3) ? 1'b1 : 1'b0;
	assign	stack_pos_node[4]	= (stack_pnt_reg == 4) ? 1'b1 : 1'b0;
	assign	stack_pos_node[5]	= (stack_pnt_reg == 5) ? 1'b1 : 1'b0;
	assign	stack_pos_node[6]	= (stack_pnt_reg == 6) ? 1'b1 : 1'b0;
	assign	stack_pos_node[7]	= (stack_pnt_reg == 7) ? 1'b1 : 1'b0;

	// pick up value of stack-top from stack cells
	reg 	[12:0]	stack_cell;	// value of each stack cell
	reg 	[12:0]	top;		// value of stack top
	wire	[12:0]	stack0_node;
	wire	[12:0]	stack1_node;
	wire	[12:0]	stack2_node;
	wire	[12:0]	stack3_node;
	wire	[12:0]	stack4_node;
	wire	[12:0]	stack5_node;
	wire	[12:0]	stack6_node;
	wire	[12:0]	stack7_node;

	assign	stack0_node	= stack_reg[0];
	assign	stack1_node	= stack_reg[1];
	assign	stack2_node	= stack_reg[2];
	assign	stack3_node	= stack_reg[3];
	assign	stack4_node	= stack_reg[4];
	assign	stack5_node	= stack_reg[5];
	assign	stack6_node	= stack_reg[6];
	assign	stack7_node	= stack_reg[7];

	always @(stack0_node or stack1_node or stack2_node or stack3_node
				or stack4_node or stack5_node or stack6_node or stack7_node
				or stack_pos_node) begin

		if (stack_pos_node[0] == 1'b1) begin	// (if the position is stack top)
			stack_cell[0]	= stack0_node;
		end else begin
			stack_cell[0]	= 13'b0000000000000;
		end

		if (stack_pos_node[1] == 1'b1) begin
			stack_cell[1]	= stack1_node;
		end else begin
			stack_cell[1]	= 13'b0000000000000;
		end

		if (stack_pos_node[2] == 1'b1) begin
			stack_cell[2]	= stack2_node;
		end else begin
			stack_cell[2]	= 13'b0000000000000;
		end

		if (stack_pos_node[3] == 1'b1) begin
			stack_cell[3]	= stack3_node;
		end else begin
			stack_cell[3]	= 13'b0000000000000;
		end

		if (stack_pos_node[4] == 1'b1) begin
			stack_cell[4]	= stack4_node;
		end else begin
			stack_cell[4]	= 13'b0000000000000;
		end

		if (stack_pos_node[5] == 1'b1) begin
			stack_cell[5]	= stack5_node;
		end else begin
			stack_cell[5]	= 13'b0000000000000;
		end

		if (stack_pos_node[6] == 1'b1) begin
			stack_cell[6]	= stack6_node;
		end else begin
			stack_cell[6]	= 13'b0000000000000;
		end

		if (stack_pos_node[7] == 1'b1) begin
			stack_cell[7]	= stack7_node;
		end else begin
			stack_cell[7]	= 13'b0000000000000;
		end

		top	= stack_cell[0];
		top	= top | stack_cell[1];
		top	= top | stack_cell[2];
		top	= top | stack_cell[3];
		top	= top | stack_cell[4];
		top	= top | stack_cell[5];
		top	= top | stack_cell[6];
		top	= top | stack_cell[7];

		stacktop_node	<= top;
	end


// MAIN EFSM: description of register value changes in each clock cycle
	// Intermidiate nodes used for resource sharing
	reg 	[7:0]	ramin_node;			// result of reading RAM/Special registers
	reg 	[12:0]	incpc_node;			// value of PC + 1
	reg 	[7:0]	mask_node;			// bit mask for logical operations
	reg 	[8:0]	add_node;			// result of 8bit addition (std_logic_vector)
	reg 	[4:0]	addLow_node;		// reulst of low-4bit addition (std_logic_vector)
	reg 			aluout_zero_node;	// H if ALUOUT = 0
	reg 			writew_node;		// H if destination is W register
	reg 			writeram_node;		// H if destination is RAM/Special registers
	reg 			int_node;			// H if interrupt request comes
	reg 			wdtreset_node;		// H if WDT-reset request comes
	reg 			reset_cond;			// H if any reset request comes (jump to Qreset state)
// >> added on Dec 10,2000
	reg 	[2:0]	stack_full_node;
// << added on Dec 10,2000
//> added ver1.00c, 2002/08/07
	reg 			extbit_node;
//<

	always @(posedge clkin) begin
		// 1. Intermidiate nodes for resource sharing

		// 1-1. Result of reading RAM; one of data sources	(see pp.13 of PIC16F84 data sheet)
		if (ADDR_SRAM == 1'b1) begin
			ramin_node	= ramdtin;		// data bus output of external SRAM
		end else if (ADDR_EEDATA == 1'b1) begin
			ramin_node	= eedata_reg;	// data bus output of external EEPROM
		end else if (ADDR_TMR0 == 1'b1) begin
			ramin_node	= tmr0_reg;		// TMR0
		end else if (ADDR_PCL == 1'b1) begin
			ramin_node	= pc_reg[7:0];	// PCL
		end else if (ADDR_STAT == 1'b1) begin
			ramin_node	= status_reg;	// STATUS
		end else if (ADDR_FSR == 1'b1) begin
			ramin_node	= fsr_reg;		// FSR
		end else if (ADDR_PORTA == 1'b1) begin
			if (trisa_reg[0] == 1'b1) begin
				ramin_node[0]	= portain_sync_reg[0];	// PORT B (when input mode)
			end else begin
				ramin_node[0]	= portaout_reg[0];		// PORT B (when output mode)
			end

			if (trisa_reg[1] == 1'b1) begin
				ramin_node[1]	= portain_sync_reg[1];
			end else begin
				ramin_node[1]	= portaout_reg[1];
			end

			if (trisa_reg[2] == 1'b1) begin
				ramin_node[2]	= portain_sync_reg[2];
			end else begin
				ramin_node[2]	= portaout_reg[2];
			end

			if (trisa_reg[3] == 1'b1) begin
				ramin_node[3]	= portain_sync_reg[3];
			end else begin
				ramin_node[3]	= portaout_reg[3];
			end

			if (trisa_reg[4] == 1'b1) begin
				ramin_node[4]	= portain_sync_reg[4];
			end else begin
				ramin_node[4]	= portaout_reg[4];
			end

			ramin_node[7:5]	= 3'b000;

		end else if (ADDR_PORTB == 1'b1) begin
			if (trisb_reg[0] == 1'b1) begin
				ramin_node[0]	= portbin_sync_reg[0];	// PORT B (when input mode)
			end else begin
				ramin_node[0]	= portbout_reg[0];		// PORT B (when output mode)
			end

			if (trisb_reg[1] == 1'b1) begin
				ramin_node[1]	= portbin_sync_reg[1];
			end else begin
				ramin_node[1]	= portbout_reg[1];
			end

			if (trisb_reg[2] == 1'b1) begin
				ramin_node[2]	= portbin_sync_reg[2];
			end else begin
				ramin_node[2]	= portbout_reg[2];
			end

			if (trisb_reg[3] == 1'b1) begin
				ramin_node[3]	= portbin_sync_reg[3];
			end else begin
				ramin_node[3]	= portbout_reg[3];
			end

			if (trisb_reg[4] == 1'b1) begin
				ramin_node[4]	= portbin_sync_reg[4];
			end else begin
				ramin_node[4]	= portbout_reg[4];
			end

			if (trisb_reg[5] == 1'b1) begin
				ramin_node[5]	= portbin_sync_reg[5];
			end else begin
				ramin_node[5]	= portbout_reg[5];
			end

			if (trisb_reg[6] == 1'b1) begin
				ramin_node[6]	= portbin_sync_reg[6];
			end else begin
				ramin_node[6]	= portbout_reg[6];
			end

			if (trisb_reg[7] == 1'b1) begin
				ramin_node[7]	= portbin_sync_reg[7];
			end else begin
				ramin_node[7]	= portbout_reg[7];
			end

		end else if (ADDR_EEADR == 1'b1) begin
			ramin_node	= eeadr_reg;			// EEADR
		end else if (ADDR_PCLATH == 1'b1) begin
			ramin_node	= {3'b000, pclath_reg};	// PCLATH (5bit)
		end else if (ADDR_INTCON == 1'b1) begin
			ramin_node	= intcon_reg;			// INTCON
		end else if (ADDR_OPTION == 1'b1) begin
			ramin_node	= option_reg;			// OPTION
		end else if (ADDR_TRISA == 1'b1) begin
			ramin_node	= {3'b000, trisa_reg};	// TRISA
		end else if (ADDR_TRISB == 1'b1) begin
			ramin_node	= trisb_reg;			// TRISB
		end else if (ADDR_EECON1 == 1'b1) begin
			ramin_node	= {3'b000, eecon1_reg};	// EECON1 (5bit)
		end else begin
			ramin_node	= {8{1'b0}};
		end

		// 1-2. PC + 1
		incpc_node	= pc_reg + 13'b0000000000001;

		// 1-3. Adder (ALU)
//> changed ver1.00c, 2002/08/07
		// full 8bit-addtion
		//			add_node		= {1'b0,aluinp1_reg} + {1'b0,aluinp2_reg};
		add_node	= ({1'b0, aluinp1_reg}) + aluinp2_reg;
		// lower 4bit-addtion
		if (INST_SUBLW == 1'b1 || INST_SUBWF == 1'b1) begin
			extbit_node	= aluinp2_reg[4];
		end else begin
			extbit_node	= 1'b0;
		end
		//			addLow_node		= {1'b0,aluinp1_reg[3:0]} + {1'b0,aluinp2_reg[3:0]};
		addLow_node	= ({1'b0, aluinp1_reg[3:0]}) + ({extbit_node, aluinp2_reg[3:0]});
//<

		// 1-4. Test if aluout = 0
		if (aluout_reg == 8'b00000000) begin
			aluout_zero_node	= 1'b1;
		end else begin
			aluout_zero_node	= 1'b0;
		end

		// 1-5. Determine destination
		if (intstart_reg == 1'b1) begin
			writew_node		= 1'b0;
			writeram_node	= 1'b0;
		end else if (INST_MOVWF == 1'b1 || INST_BCF == 1'b1 || INST_BSF == 1'b1 || INST_CLRF == 1'b1) begin
			writew_node		= 1'b0;
			writeram_node	= 1'b1;
		end else if (INST_MOVLW == 1'b1 || INST_ADDLW == 1'b1 || INST_SUBLW == 1'b1 || INST_ANDLW == 1'b1 || INST_IORLW == 1'b1 || INST_XORLW == 1'b1 || INST_RETLW == 1'b1 || INST_CLRW == 1'b1) begin
			writew_node		= 1'b1;
			writeram_node	= 1'b0;
		end else if (INST_MOVF == 1'b1 || INST_SWAPF == 1'b1 || INST_ADDWF == 1'b1 || INST_SUBWF == 1'b1 || INST_ANDWF == 1'b1 || INST_IORWF == 1'b1 || INST_XORWF == 1'b1 || INST_DECF == 1'b1 || INST_INCF == 1'b1 || INST_RLF == 1'b1 || INST_RRF == 1'b1 || INST_DECFSZ == 1'b1 || INST_INCFSZ == 1'b1 || INST_COMF == 1'b1) begin
			writew_node		=  ~inst_reg[7];	// ("d" field of fetched instruction)
			writeram_node	= inst_reg[7];		// ("d" field of fetched instruction)
		end else begin
			writew_node		= 1'b0;
			writeram_node	= 1'b0;
		end

		// 1-6. Interrupt request	(see pp.17 of PIC16F84 data sheet)
		int_node	= intcon_reg[7] 							// GIE
						& ((intcon_reg[3] & intcon_reg[0]) 		// RBIE and RBIF
							| (intcon_reg[4] & intcon_reg[1]) 	// INTE and INTF
							| (intcon_reg[5] & intcon_reg[2]) 	// T0IE and T0IF
							| (intcon_reg[6] & eecon1_reg[4]));	// EEIE and EEIF(EECON1)

		// 1-7. Reset conditions
		wdtreset_node	= wdt_full_sync_reg[1] & ( ~wdt_full_sync_reg[2]);	// WDT

		if (poweron_sync_reg == 1'b0 || mclr_sync_reg == 1'b0 || wdtreset_node == 1'b1) begin	// (all of reset triggers)
			reset_cond	= 1'b1;
		end else begin
			reset_cond	= 1'b0;
		end


		// 2. EFSM body
		case (state_reg)

		// 2-1. Reset state (see pp.14 and pp.42 of PIC16F84 data sheet)
		Qreset: begin
			pc_reg			<= {13{1'b0}};	// 0
			status_reg[7:5]	<= 3'b000;
			pclath_reg		<= {5{1'b0}};	// 0
			intcon_reg[7:1]	<= 7'b0000000;
			option_reg		<= {8{1'b1}};
			trisa_reg		<= {5{1'b1}};
			trisb_reg		<= {8{1'b1}};
			tmr0_reg		<= {8{1'b0}};	// (specification: don't care)
			exec_op_reg		<= 1'b0;
			intclr_reg		<= {5{1'b1}};	// clear int
			intstart_reg	<= 1'b0;
			writeram_reg	<= 1'b0;
			sleepflag_reg	<= 1'b0;

			// (set /T0 and /PD properly; see pp.42 and pp.46 of data sheet)
			if (poweron_sync_reg == 1'b0) begin			// Power-on Reset
				status_reg[4]	<= 1'b1;					// /T0 = 1
				status_reg[3]	<= 1'b1;					// /PD = 1
			end else if (mclr_sync_reg == 1'b0) begin	// MCLR reset/MCLR wake up from sleep
				status_reg[4]	<= 1'b1;					// /T0 = 1
				status_reg[3]	<=  ~sleepflag_reg;			// /PD = 1 if normal reset, /PD = 0 if wake up
			end else if (wdtreset_node == 1'b1) begin	// WDT reset/WDT wake up from sleep
				status_reg[4]	<= 1'b0;					// /T0 = 0
				status_reg[3]	<=  ~sleepflag_reg;			// /PD = 1 if normal reset, /PD = 0 if wake up
			end

			eecon1_reg[4]	<= 1'b0;
			// (set WRERR bit in EECON1 properly; see pp.33 and pp.34 of data sheet)
			if (poweron_sync_reg == 1'b0) begin
				eecon1_reg[3]	<= 1'b0;			// clear WRERR
			end else begin
				eecon1_reg[3]	<= eecon1_reg[1];	// substitute WR into WRERR
			end
			eecon1_reg[2:0]	<= 3'b000;

			if (poweron_sync_reg == 1'b0) begin
				// NOTICE: do NOT clear stack pointer for MCLR reset or WDT reset (the value must be hold)
				stack_pnt_reg	<= 0;
			end

			if (reset_cond == 1'b0) begin	// go to Q1 if reset signal is disasserted.
				state_reg	<= Q1;
			end
		end

		// 2-2. Q1 cycle
		Q1: begin
			// 2-2-1. Clear external interrupt registers if GIE=0
			if (intcon_reg[7] == 1'b1) begin
				intclr_reg	<= {5{1'b0}};
			end else begin	// GIE = 0
				intclr_reg	<= {5{1'b1}};	// clear interrupt
			end

			// 2-2-2. Read I/O port
			portain_sync_reg	<= porta_in;
			portbin_sync_reg	<= portb_in;

			// 2-2-3. Read/Write EEPROM, if necessary
			if (intstart_reg == 1'b0) begin
				if (eecon1_reg[0] == 1'b1 && rdeep_sync_reg == 1'b1) begin	// reading EEPROM complete
					eedata_reg		<= eepdtin;
					eecon1_reg[0]	<= 1'b0;		// clear EECON1_RD
				end
				if (eecon1_reg[1] == 1'b1 && wreep_sync_reg == 1'b1) begin	// writing EEPROM complete
					if (intcon_reg[7] == 1'b1 && intcon_reg[6] == 1'b1) begin
						eecon1_reg[4]	<= 1'b1;	// INT (EE write complete)
					end
					eecon1_reg[1]	<= 1'b0;		// clear EECON1_WR
				end

//> deleted ver1.00c, 2002/08/07
//				if (exec_op_reg == 1'b1) begin
//					ramadr_reg		<= ramadr_node;	// RAM read address
//				end
//<
			end

			// 2-2-4. Check increment-TMR0 request
			if (inctmr_sync_reg == 2'b01) begin
				inctmrhold_reg	<= 1'b1;
			end

			// 2-2-5. Goto next cycle
			if (reset_cond == 1'b1) begin
				state_reg	<= Qreset;
			end else begin
				// if in the sleep mode, wait until wake-up triggers comes
				if (sleepflag_reg == 1'b1 && intstart_reg == 1'b0) begin
					if (inte_sync_reg == 1'b1 || rbint_sync_reg == 1'b1) begin	// if PORT-B interrupts come, then resume execution
						// otherwise, if WDT reset/MCLR reset come, then goto Qreset
						sleepflag_reg	<= 1'b0;
						state_reg		<= Q2;
					end
				end else begin
					state_reg	<= Q2;
				end
			end
		end


		// 2-3. Q2 cycle
		Q2: begin
			// 2-3-1. Read data-RAM and substitute source values to alu-input registers
			if (exec_op_reg == 1'b1 && intstart_reg == 1'b0) begin	// if NOT STALLED

				// 2-3-1-1. Set aluinp1 register (source #1)
				if (INST_MOVF == 1'b1 || INST_SWAPF == 1'b1 || INST_ADDWF == 1'b1 || INST_SUBWF == 1'b1 
						|| INST_ANDWF == 1'b1 || INST_IORWF == 1'b1 || INST_XORWF == 1'b1 || INST_DECF == 1'b1 
						|| INST_INCF == 1'b1 || INST_RLF == 1'b1 || INST_RRF == 1'b1 || INST_BCF == 1'b1 
						|| INST_BSF == 1'b1 || INST_BTFSC == 1'b1 || INST_BTFSS == 1'b1 || INST_DECFSZ == 1'b1 
						|| INST_INCFSZ == 1'b1 || INST_COMF == 1'b1) begin
					aluinp1_reg	<= ramin_node;		// RAM/Special registers
				end else if (INST_MOVLW == 1'b1 || INST_ADDLW == 1'b1 || INST_SUBLW == 1'b1 
						|| INST_ANDLW == 1'b1 || INST_IORLW == 1'b1 || INST_XORLW == 1'b1 
						|| INST_RETLW == 1'b1) begin
					aluinp1_reg	<= inst_reg[7:0];	// Immidiate value ("k")
				end else if (INST_CLRF == 1'b1 || INST_CLRW == 1'b1) begin
					aluinp1_reg	<= {8{1'b0}};		// 0
				end else begin
					aluinp1_reg	<= w_reg;			// W register
				end

				// 2-3-1-2. Set aluinp2 register (source #2)
				case (inst_reg[9:7])	// construct bit-mask for logical operations/bit test
				3'b000: begin
					mask_node	= 8'b00000001;
				end
				3'b001: begin
					mask_node	= 8'b00000010;
				end
				3'b010: begin
					mask_node	= 8'b00000100;
				end
				3'b011: begin
					mask_node	= 8'b00001000;
				end
				3'b100: begin
					mask_node	= 8'b00010000;
				end
				3'b101: begin
					mask_node	= 8'b00100000;
				end
				3'b110: begin
					mask_node	= 8'b01000000;
				end
				default: begin
					mask_node	= 8'b10000000;
				end
				endcase

				if (INST_DECF == 1'b1 || INST_DECFSZ == 1'b1) begin
					aluinp2_reg	<= {(8 - 0 + 1){1'b1}};	// -1 (for decrement)
				end else if (INST_INCF == 1'b1 || INST_INCFSZ == 1'b1) begin
//> modified ver1.00c, 2002/08/07
//					aluinp2_reg	<= 8'b00000001;		// 1 (for increment)
					aluinp2_reg	<= 9'b000000001;	// 1 (for increment)
				end else if (INST_SUBLW == 1'b1 || INST_SUBWF == 1'b1) begin
//					aluinp2_reg	<= (~w_reg) + 8'b00000001;	// -1 * W register (for subtract)
					aluinp2_reg	<= ({1'b1, ( ~w_reg)}) + 9'b000000001;	// -1 * W register (for subtract)
				end else if (INST_BCF == 1'b1) begin
//					aluinp2_reg	<= ~mask_node;				// mask for BCF: value of only one position is '0'
					aluinp2_reg	<= {1'b0, ( ~mask_node)};	// mask for BCF: value of only one position is '0'
				end else if (INST_BTFSC == 1'b1 || INST_BTFSS == 1'b1 || INST_BSF == 1'b1) begin	// operation of BCF: AND with inverted mask ("1..101..1")
//					aluinp2_reg	<= mask_node;			// operation of BSF: OR with mask_node ("0..010..0")
					aluinp2_reg	<= {1'b0, mask_node};	// operation of BSF: OR with mask_node ("0..010..0")
				end else begin	// operation of FSC and FSS: AND with mask_node and then compare with zero
//					aluinp2_reg	<= w_reg;			// W register
					aluinp2_reg	<= {1'b0, w_reg};	// W register
				end
//<

				// 2-3-1-3. Set stack pointer register (pop stack)
				if (INST_RET == 1'b1 || INST_RETLW == 1'b1 || INST_RETFIE == 1'b1) begin
					if (stack_pnt_reg == 0) begin
						stack_pnt_reg	<= 8 - 1;	// if pointer=0, then next value should be 8-1
					end else begin
						stack_pnt_reg	<= stack_pnt_reg - 1;	// otherwise, current value - 1
					end
				end
			end

			// 2-3-1-4. Set ramadr register (set RAM write address)
//> deleted ver1.00c, 2002/08/07
//			ramadr_reg	<= ramadr_node;		// RAM write address
//<

			// 2-3-2. Change clkout output
			clkout_reg	<= 1'b1;

			// 2-3-3. Check increment-TMR0 request
			if (inctmr_sync_reg == 2'b01) begin
				inctmrhold_reg	<= 1'b1;
			end

			// 2-3-4. Goto next cycle
			if (reset_cond == 1'b1) begin
				state_reg	<= Qreset;
			end else begin
				state_reg	<= Q3;
			end
		end


		// 2-4. Q3 cycle
		Q3: begin
			// 2-4-1. Calculation and store result into alu-output regsiter
			if (exec_op_reg == 1'b1 && intstart_reg == 1'b0) begin	// if NOT STALLED

				// 2-4-1-1. Set aluout register
				if (INST_RLF == 1'b1) begin
					aluout_reg	<= {aluinp1_reg[6:0], status_reg[0]};	// rotate left
				end else if (INST_RRF == 1'b1) begin
					aluout_reg	<= {status_reg[0], aluinp1_reg[7:1]};	// rotate right
				end else if (INST_SWAPF == 1'b1) begin
					aluout_reg	<= {aluinp1_reg[3:0], aluinp1_reg[7:4]};	// swap H-nibble and L-nibble
				end else if (INST_COMF == 1'b1) begin
					aluout_reg	<=  ~aluinp1_reg;	// logical inversion
				end else if (INST_ANDLW == 1'b1 || INST_ANDWF == 1'b1 || INST_BCF == 1'b1 || INST_BTFSC == 1'b1 || INST_BTFSS == 1'b1) begin
//> modified ver1.00c, 2002/08/07
//					aluout_reg	<= aluinp1_reg & aluinp2_reg;		// logical AND/bit clear/bit test
					aluout_reg	<= aluinp1_reg & aluinp2_reg[7:0];	// logical AND/bit clear/bit test
				end else if (INST_BSF == 1'b1 || INST_IORLW == 1'b1 || INST_IORWF == 1'b1) begin
//					aluout_reg	<= aluinp1_reg | aluinp2_reg;		// logical OR/bit set
					aluout_reg	<= aluinp1_reg | aluinp2_reg[7:0];	// logical OR/bit set
				end else if (INST_XORLW == 1'b1 || INST_XORWF == 1'b1) begin
//					aluout_reg	<= aluinp1_reg ^ aluinp2_reg;		// logical XOR
					aluout_reg	<= aluinp1_reg ^ aluinp2_reg[7:0];	// logical XOR
//<
				end else if (INST_ADDLW == 1'b1 || INST_ADDWF == 1'b1 || INST_SUBLW == 1'b1 || INST_SUBWF == 1'b1 || INST_DECF == 1'b1 || INST_DECFSZ == 1'b1 || INST_INCF == 1'b1 || INST_INCFSZ == 1'b1) begin	//<
					aluout_reg	<= add_node[7:0];	// addition/subtraction/increment/decrement
				end else begin
					aluout_reg	<= aluinp1_reg;	// pass through
				end

				// 2-4-1-2. Set C flag and DC flag
//> modified ver1.00c, 2002/08/07
//				if (INST_ADDLW == 1'b1 || INST_ADDWF == 1'b1 || INST_SUBLW == 1'b1 || INST_SUBWF == 1'b1) begin
//					status_reg(1)	<= addLow_node(4);	// DC flag
//					status_reg(0)	<= add_node(8);		// C flag
				if (INST_ADDLW == 1'b1 || INST_ADDWF == 1'b1) begin
					status_reg[1]	<= addLow_node[4];	// DC flag
					status_reg[0]	<= add_node[8];		// C flag
				end else if (INST_SUBLW == 1'b1 || INST_SUBWF == 1'b1) begin
					status_reg[1]	<=  ~addLow_node[4];	// DC flag
					status_reg[0]	<=  ~add_node[8];		// C flag
//<
				end else if (INST_RLF == 1'b1) begin	
					status_reg[0]	<= aluinp1_reg[7];	// C flag
				end else if (INST_RRF == 1'b1) begin
					status_reg[0]	<= aluinp1_reg[0];	// C flag
				end

				// 2-4-1-3. Set data-SRAM write enable (hazard-free)
				if (writeram_node == 1'b1 && ADDR_SRAM == 1'b1) begin
					writeram_reg	<= 1'b1;
				end else begin
					writeram_reg	<= 1'b0;
				end
			end else begin	// (if stalled)
				writeram_reg	<= 1'b0;
			end

			// 2-4-2. Check external interrupt and set interrupt flag / Increment TMR0
			if (intstart_reg == 1'b0) begin
				if (intcon_reg[7] == 1'b1) begin	// GIE
					// PORT-B0 INT
					if (inte_sync_reg == 1'b1) begin
						intcon_reg[1]	<= 1'b1;	// set INTF
						intclr_reg[0]	<= 1'b1;	// clear external int-registers (intrise_reg(0) and intdown_reg(0))
					end
					// PORT-B[4-7] INT
					if (rbint_sync_reg == 1'b1) begin
						intcon_reg[0]	<= 1'b1;	// set RBIF
						intclr_reg[4:1]	<= 4'b1111;	// clear external int-registers (intrise_reg(4-1) and intdown_reg(4-1))
					end
				end
			end

			// Increment TMR0
			if (inctmrhold_reg == 1'b1 || inctmr_sync_reg == 2'b01) begin	// increment trigger comes
				tmr0_reg		<= tmr0_reg + 8'b00000001;	// increment
				inctmrhold_reg	<= 1'b0;

				// if intstart = '0' and GIE = '1' and T0IE = '1' and timer full, then set T0IF
				if (intstart_reg == 1'b0 && intcon_reg[7] == 1'b1 && intcon_reg[5] == 1'b1 && tmr0_reg == 8'b11111111) begin
					intcon_reg[2]	<= 1'b1;	// set T0IF
				end
			end

			// 2-4-3. Goto next cycle
			if (reset_cond == 1'b1) begin
				state_reg	<= Qreset;
			end else begin
				state_reg	<= Q4;
			end
		end


		// 2-5. Q4 cycle
		Q4: begin
			// 2-5-1. Fetch next program-instruction
			inst_reg	<= progdata;

			if (exec_op_reg == 1'b0 && intstart_reg == 1'b0) begin	// if STALLED
				pc_reg	<= incpc_node;	// increment PC
				exec_op_reg	<= 1'b1;	// end of stall

			end else begin	// if NOT stalled (note: if intstart_reg = '1', only stack/pc-operations in this else-clause will be performed)
				// 2-5-2. Store calculation result into distination, set PC and flags, and determine if execute next cycle or not

				// 2-5-2-1. Set W register, if not in stall cycle (intstart_reg = '0') and distination is W
				if (writew_node == 1'b1) begin	// ('0' if intstart_reg = '1')
					w_reg	<= aluout_reg;	// write W reg
				end

				// 2-5-2-2. Set data RAM/special registers, if not in stall cycle (intstart_reg = '0')
				if (writeram_node == 1'b1) begin	// ('0' if intstart_reg = '1')
					if (ADDR_STAT == 1'b1) begin
						status_reg[7:5]	<= aluout_reg[7:5];	// write IRP,RP1,RP0
						// status(4),status(3)...unwritable, see below (/PD,/T0 part)
						status_reg[1:0]	<= aluout_reg[1:0];	// write DC,C
					end
					if (ADDR_FSR == 1'b1) begin
						fsr_reg	<= aluout_reg;			// write FSR
					end
					if (ADDR_PORTA == 1'b1) begin
						portaout_reg	<= aluout_reg[4:0];	// write PORT-A
					end
					if (ADDR_PORTB == 1'b1) begin
						portbout_reg	<= aluout_reg;	// write PORT-B
					end
					if (ADDR_EEDATA == 1'b1) begin
						eedata_reg	<= aluout_reg;		// write EEDATA
					end
					if (ADDR_EEADR == 1'b1) begin
						eeadr_reg	<= aluout_reg;		// write EEADR
					end
					if (ADDR_PCLATH == 1'b1) begin
						pclath_reg	<= aluout_reg[4:0];	// write PCLATH
					end
					if (ADDR_INTCON == 1'b1) begin
						intcon_reg[6:0]	<= aluout_reg[6:0];	// write INTCON (except GIE)
					end
					// intcon(7)...see below (GIE part)
					if (ADDR_OPTION == 1'b1) begin
						option_reg	<= aluout_reg;		// write OPTION
					end
					if (ADDR_TRISA == 1'b1) begin
						trisa_reg	<= aluout_reg[4:0];	// write TRISA
					end
					if (ADDR_TRISB == 1'b1) begin
						trisb_reg	<= aluout_reg;		// write TRISB
					end
					if (ADDR_TMR0 == 1'b1) begin
						tmr0_reg	<= aluout_reg;		// write TMR0
					end
					if (ADDR_EECON1 == 1'b1) begin		// write EECON1
						eecon1_reg[4:3]	<= aluout_reg[4:3];
						eecon1_reg[2]	<= aluout_reg[2] & existeeprom;	// WREN can be set only when EEPROM exists
						if (aluout_reg[2:0] == 3'b110) begin	// if write enabled, write bit = '1', and no current read
							eecon1_reg[1]	<= 1'b1;	// WR: only SET-operation is allowed to user
						end
						if (aluout_reg[1:0] == 2'b01) begin	// if no current write, and read bit = '1'
							eecon1_reg[0]	<= 1'b1;	// RD: only SET-operation is allowed to user
						end
					end
				end

				// 2-5-2-3. Set/clear Z flag, if not in stall cycle (intstart_reg = '0')
				if (intstart_reg == 1'b0) begin
//---> changed v1.00d, 2004/08/26
					// if (ADDR_STAT == 1'b1) begin
					if (writeram_node == 1'b1 && ADDR_STAT == 1'b1 && INST_CLRF == 1'b0) begin
//---< changed v1.00d, 2004/08/26
						status_reg[2]	<= aluout_reg[2];		// (distination is Z flag)
					end else if (INST_ADDLW == 1'b1 || INST_ADDWF == 1'b1 || INST_ANDLW == 1'b1 || INST_ANDWF == 1'b1 || INST_CLRF == 1'b1 || INST_CLRW == 1'b1 || INST_COMF == 1'b1 || INST_DECF == 1'b1 || INST_INCF == 1'b1 || INST_MOVF == 1'b1 || INST_SUBLW == 1'b1 || INST_SUBWF == 1'b1 || INST_XORLW == 1'b1 || INST_XORWF == 1'b1) begin
						status_reg[2]	<= aluout_zero_node;	// Z=1 if result == 0
					end else if (INST_IORLW == 1'b1 || INST_IORWF == 1'b1) begin
// SELECT ONE OF THE FOLLOWING TWO SENTENCES
																// IORLW or IORWF instructions:
						status_reg[2]	<=  ~aluout_zero_node;	// Z=1 if result != 0 (same behavior with PIC16F84 data sheet pp.61-62)
//						status_reg(2)	<= aluout_zero_node;	// Z=1 if resutl == 0 (same behavior with the other instructions)
					end
				end

				// 2-5-2-4. Set PC register and determine if execute next cycle or not
				if (intstart_reg == 1'b1) begin		// After interrupt-stall cycle ends, jump to interrupt vector
					pc_reg	<= 13'b0000000000100;	// (interrupt vector)
					exec_op_reg	<= 1'b0;			// the next cycle is stall cycle
				end else if (INST_RET == 1'b1 || INST_RETLW == 1'b1 || INST_RETFIE == 1'b1) begin	// "return" instructions
					pc_reg	<= stacktop_node;		// pc <= top of poped stack (the stack is poped at Q2 cycle)
					exec_op_reg	<= 1'b0;			// the next cycle is stall cycle
				end else if (INST_GOTO == 1'b1 || INST_CALL == 1'b1) begin	// "goto/call" instructions
					pc_reg	<= {pclath_reg[4:3], inst_reg[10:0]};	// (see pp.18 of PIC16F84 data sheet)
					exec_op_reg	<= 1'b0;
				end else if (((INST_BTFSC == 1'b1 || INST_DECFSZ == 1'b1 || INST_INCFSZ == 1'b1) && aluout_zero_node == 1'b1) || (INST_BTFSS == 1'b1 && aluout_zero_node == 1'b0)) begin
					// bit_test instrcutions
					pc_reg	<= incpc_node;
					exec_op_reg	<= 1'b0;	// the next cycle is stall cycle, if test conditions are met.
				end else if (writeram_node == 1'b1 && ADDR_PCL == 1'b1) begin	// PCL is data-distination
					pc_reg	<= {pclath_reg[4:0], aluout_reg};	// (see pp.18 of PIC16F84 data sheet)
					exec_op_reg	<= 1'b0;
				end else begin
					// this check MUST be located AFTER the above if/elsif sentences
					if (int_node == 1'b0) begin		// check if interrupt trigger comes
						pc_reg	<= incpc_node;		// if not, the next instruction fetch/execution will be performed normally
					end else begin
						pc_reg	<= pc_reg;			// if so, value of PC must be hold (will be pushed into stack at the end of next instruction cycle)
					end
					exec_op_reg	<= 1'b1;
				end

				// 2-5-2-5. Push current PC value into stack, if necessary
				if (INST_CALL == 1'b1 || intstart_reg == 1'b1) begin	// CALL instruction or End of interrupt-stall cycle
					// write PC-value into stack top
					if (stack_pos_node[0] == 1'b1) begin	// check if the stack cell is stack top or not
						stack_reg[0]	<= pc_reg;	// if so, write PC value
					end
					if (stack_pos_node[1] == 1'b1) begin
						stack_reg[1]	<= pc_reg;
					end
					if (stack_pos_node[2] == 1'b1) begin
						stack_reg[2]	<= pc_reg;
					end
					if (stack_pos_node[3] == 1'b1) begin
						stack_reg[3]	<= pc_reg;
					end
					if (stack_pos_node[4] == 1'b1) begin
						stack_reg[4]	<= pc_reg;
					end
					if (stack_pos_node[5] == 1'b1) begin
						stack_reg[5]	<= pc_reg;
					end
					if (stack_pos_node[6] == 1'b1) begin
						stack_reg[6]	<= pc_reg;
					end
					if (stack_pos_node[7] == 1'b1) begin
						stack_reg[7]	<= pc_reg;
					end

					// increment stack pointer
// >> Changed on Dec 10,2000
					stack_full_node	= 8 - 1;
//					if (stack_pnt_reg == 8 - 1) then
					if (stack_pnt_reg == stack_full_node) begin
// << Changed on Dec 10,2000
						stack_pnt_reg	<= 0;
					end else begin
						stack_pnt_reg	<= stack_pnt_reg + 1;
					end
				end

				// 2-5-2-6. Set GIE bit in intcon register (intcon_reg(7))
				if (intstart_reg == 1'b0) begin
					if (int_node == 1'b1) begin		// interrupt trigger comes
						intcon_reg[7]	<= 1'b0;	// clear GIE
						intstart_reg	<= 1'b1;	// the next cycle is interrupt-stall cycle
					end else if (INST_RETFIE == 1'b1) begin	// "return from interrupt" instruction
						intcon_reg[7]	<= 1'b1;
						intstart_reg	<= 1'b0;
					end else if (writeram_node == 1'b1 && ADDR_INTCON == 1'b1) begin	// distination is GIE
						intcon_reg[7]	<= aluout_reg[7];
						intstart_reg	<= 1'b0;
					end else begin
						intstart_reg	<= 1'b0;
					end
				end else begin
					intstart_reg	<= 1'b0;
				end

				// 2-5-2-7. Set/clear /PD and /TO flags
				if (intstart_reg == 1'b0) begin
					if (INST_CLRWDT == 1'b1 || (INST_SLEEP == 1'b1 && (wdtreset_node == 1'b0 && intstart_reg == 1'b0))) begin
						// CLRWDT or (SLEEP and no interrupt trigger)
						// see pp.46,58 and 66 of PIC16F84 data-sheet
						if (INST_SLEEP == 1'b1) begin
							sleepflag_reg	<= 1'b1;
							status_reg[4:3]	<= 2'b10;	// SLEEP: /T0,/PD = 1,0
						end else begin					// (INST_CLRWDT)
							status_reg[4:3]	<= 2'b11;	// CLRWDT: /T0,/PD = 1,1
						end
					end
				end
			end			// (if not stalled)

			// 2-5-3. Clear data-SRAM write enable (hazard-free)
			writeram_reg	<= 1'b0;

			// 2-5-4. Change clkout output
			clkout_reg		<= 1'b0;

			// 2-5-5. Check increment-TMR0 request
			if (inctmr_sync_reg == 2'b01) begin
				inctmrhold_reg	<= 1'b1;
			end

			// 2-5-6. Goto next cycle
			if (reset_cond == 1'b1) begin
				state_reg	<= Qreset;
			end else begin
				state_reg	<= Q1;
			end
		end

		// 2-6. Illegal states (NEVER REACHED in normal execution)
		default: begin
			state_reg	<= Qreset;	// goto reset state
		end
		endcase
	end

	// TMR0 pre-scaler (see pp.27 of PIC16F84 data sheet)
	// select pre-scaler
	assign	psck	= (option_reg[5] == 1'b0) ? (clkout_reg)	// option_reg(5):T0CS
									: (t0cki ^ option_reg[4]);	// option_reg(4):T0SE

	// pre-scaler body
	reg 	[7:0]	rateval;
	always @(posedge psck or negedge ponrst_n) begin
		if (ponrst_n == 1'b0) begin
			pscale_reg	<= 0;
			ps_full_reg	<= 1'b0;
		end else begin
			case (option_reg[2:0])	// select prescaler-full value by PS2-0
			3'b000: begin
				rateval	= 1;
			end
			3'b001: begin
				rateval	= 3;
			end
			3'b010: begin
				rateval	= 7;
			end
			3'b011: begin
				rateval	= 15;
			end
			3'b100: begin
				rateval	= 31;
			end
			3'b101: begin
				rateval	= 63;
			end
			3'b110: begin
				rateval	= 127;
			end
//			3'b111:	rateval = 255;
			default: begin
				rateval	= 255;
			end
			endcase

			if (pscale_reg >= rateval) begin
				pscale_reg	<= 0;
				ps_full_reg	<= 1'b1;
			end else begin
				pscale_reg	<= pscale_reg + 1;
				ps_full_reg	<= 1'b0;
			end
		end
	end

	// select TMR0-increment trigger
	assign	inctmrck	= (option_reg[3] == 1'b1) ? (psck)	// option_reg(3):PSA
										: (ps_full_reg);	// ps_full_reg:output of pre-scaler

// WDT timer body
	reg 	wdtfull_node;

	wire	wdt_reset_n_node;
	assign	wdt_reset_n_node	= (ponrst_n == 1'b0 || mclr_n == 1'b0) ? 1'b0 : 1'b1;

	always @(posedge wdtclk or negedge wdt_reset_n_node) begin
		if (wdt_reset_n_node == 1'b0) begin	// (async reset)
			wdt_reg				<= 0;
			wdt_full_reg		<= 1'b0;
			wdtclr_req_reg		<= 2'b00;
			wdtfullclr_req_reg	<= 2'b00;
		end else begin
			// synchronizers
			// WDT-clear request (CLRWDT/SLEEP instruction)
			wdtclr_req_reg[0]	<= wdt_clr_reg;	// (do not AND with sleepflag_reg, since WDT should be cleared at SLEEP instruction)
			wdtclr_req_reg[1]	<= wdtclr_req_reg[0];
			// WDT-full-clear request (after WDT reset)
			wdtfullclr_req_reg[0]	<= wdtfull_clr_reg & ( ~sleepflag_reg);
			wdtfullclr_req_reg[1]	<= wdtfullclr_req_reg[0];

			// timer/full reg
			if (wdt_reg >= 255) begin
				wdtfull_node	= 1'b1;	// (intermidiate node)
			end else begin
				wdtfull_node	= 1'b0;	// (intermidiate node)
			end

			// wdt_reg(counter) body
			if (wdtclr_req_reg == 2'b01 || wdtena == 1'b0) begin
				wdt_reg	<= 0;
			end else if (wdtfull_node == 1'b1) begin
				wdt_reg	<= 0;
			end else begin
				wdt_reg	<= wdt_reg + 1;
			end

			// wdt_full_reg(interrupt trigger) body
			if (wdtfullclr_req_reg == 2'b01 || wdtena == 1'b0) begin
				wdt_full_reg	<= 1'b0;
			end else if (wdtfull_node == 1'b1) begin
				wdt_full_reg	<= 1'b1;
			end
		end
	end

	assign	wdtclr_ack	= wdtclr_req_reg[1];	// WDT-clear ack signal to CPU
	assign	wdtfull	= wdt_full_reg;	// WDT-full signal (interrupt trigger) to CPU


// WDT controller in CPU-clock line (handshake-interface between WDT and CPU-EFSM)
	always @(posedge clkin) begin
		if (poweron_sync_reg == 1'b0 || mclr_sync_reg == 1'b0) begin
			wdt_clr_reg	<= 1'b0;			// WDT clear request register
			wdt_clr_reqhold_reg	<= 1'b0;	// will be 1 when WDT clear request comes while another clear request is still processed
			wdtfull_clr_reg	<= 1'b0;		// WDT-full clear request register
		end else begin
			// WDT-clear/hold WDT-clear request
			// (handshake)
			if (wdt_clr_reg == 1'b1) begin	// still processing clear-operation
				if (wdtclr_ack_sync_reg == 1'b1) begin	// if ack comes, go down the clear request
					wdt_clr_reg	<= 1'b0;
				end
			end else if (wdt_clr_reqhold_reg == 1'b1 || (state_reg == Q4 && exec_op_reg == 1'b1 && intstart_reg == 1'b0 && (INST_CLRWDT == 1'b1 || INST_SLEEP == 1'b1))) begin
				// clear request comes
				if (wdtclr_ack_sync_reg == 1'b0) begin	// confirm if ack is 0
					wdt_clr_reg	<= 1'b1;
					wdt_clr_reqhold_reg	<= 1'b0;
				end else begin	// (wait until ack becomes 0)
					wdt_clr_reqhold_reg	<= 1'b1;
				end
			end

			// clear WDT-full (CPU reset request)
			// (handshake)
			if (wdtfull_clr_reg == 1'b1) begin	// still processing clear-operation
				if (wdt_full_sync_reg[1] == 1'b0) begin	// if ack comes, go down the clear request
					wdtfull_clr_reg	<= 1'b0;
				end
			end else if (wdt_full_sync_reg[1] == 1'b1) begin	// clear request comes
				// the WDT-full signal does not come so often, so hold-register is not necessary
				wdtfull_clr_reg	<= 1'b1;
			end
		end
	end


// Detect external interrupt requests
	// INT0 I/F
	wire	i0rst_node;
	assign	i0rst_node	= intclr_reg[0];

	always @(posedge int0 or posedge i0rst_node) begin
		if (i0rst_node == 1'b1) begin
			intrise_reg[0]	<= 1'b0;
		end else begin
			// catch positive edge
			intrise_reg[0]	<= 1'b1;
		end
	end

	always @(negedge int0 or posedge i0rst_node) begin
		if (i0rst_node == 1'b1) begin
			intdown_reg[0]	<= 1'b0;
		end else begin
			// catch negative edge
			intdown_reg[0]	<= 1'b1;
		end
	end

	assign	rb0_int	= (option_reg[6] == 1'b1) ? (intrise_reg[0])	// option_reg(6):INTEDG
												: (intdown_reg[0]);

	// INT4 I/F
	wire	i4rst_node;
	assign	i4rst_node	= intclr_reg[1];

	always @(posedge int4 or posedge i4rst_node) begin
		if (i4rst_node == 1'b1) begin
			intrise_reg[1]	<= 1'b0;
		end else begin
			// catch positive edge
			intrise_reg[1]	<= 1'b1;
		end
	end

	always @(negedge int4 or posedge i4rst_node) begin
		if (i4rst_node == 1'b1) begin
			intdown_reg[1]	<= 1'b0;
		end else begin
			// catch negative edge
			intdown_reg[1]	<= 1'b1;
		end
	end

	assign	rb4_int	= intrise_reg[1] | intdown_reg[1];

	// INT5 I/F
	wire	i5rst_node;
	assign	i5rst_node	= intclr_reg[2];

	always @(posedge int5 or posedge i5rst_node) begin
		if (i5rst_node == 1'b1) begin
			intrise_reg[2]	<= 1'b0;
		end else begin
			// catch positive edge
			intrise_reg[2]	<= 1'b1;
		end
	end

	always @(negedge int5 or posedge i5rst_node) begin
		if (i5rst_node == 1'b1) begin
			intdown_reg[2]	<= 1'b0;
		end else begin
			// catch negative edge
			intdown_reg[2]	<= 1'b1;
		end
	end

	assign	rb5_int	= intrise_reg[2] | intdown_reg[2];

	// INT6 I/F
	wire	i6rst_node;
	assign	i6rst_node	= intclr_reg[3];

	always @(posedge int6 or posedge i6rst_node) begin
		if (i6rst_node == 1'b1) begin
			intrise_reg[3]	<= 1'b0;
		end else begin
			// catch positive edge
			intrise_reg[3]	<= 1'b1;
		end
	end

	always @(negedge int6 or posedge i6rst_node) begin
		if (i6rst_node == 1'b1) begin
			intdown_reg[3]	<= 1'b0;
		end else begin
			// catch negative edge
			intdown_reg[3]	<= 1'b1;
		end
	end

	assign	rb6_int	= intrise_reg[3] | intdown_reg[3];

	// INT7 I/F
	wire	i7rst_node;
	assign	i7rst_node	= intclr_reg[4];

	always @(posedge int7 or posedge i7rst_node) begin
		if (i7rst_node == 1'b1) begin
			intrise_reg[4]	<= 1'b0;
		end else begin
			// catch positive edge
			intrise_reg[4]	<= 1'b1;
		end
	end

	always @(negedge int7 or posedge i7rst_node) begin
		if (i7rst_node == 1'b1) begin
			intdown_reg[4]	<= 1'b0;
		end else begin
			// catch negative edge
			intdown_reg[4]	<= 1'b1;
		end
	end

	assign	rb7_int	= intrise_reg[4] | intdown_reg[4];


// Decode INT triggers (do not AND with GIE(intcon_reg(7)), since these signals are also used for waking up from SLEEP)
	assign	inte	= intcon_reg[4] & rb0_int;									// G0IE and raw-trigger signal
	assign	rbint	= intcon_reg[3] & (rb4_int | rb5_int | rb6_int | rb7_int);	// RBIE and raw-trigger signal


// Circuit's output siganals
	assign	progadr	= pc_reg;	// program ROM address

//> modified ver1.00c, 2002/08/07
//	assign	ramadr	= ramadr_reg;					// data RAM address
	// map 0F0-0FF,170-17F, and 1F0-1FF into 070-07F
	assign	ramadr	= (ramadr_node[6:4] != 3'b111) ? (ramadr_node)
				: ({5'b00111, ramadr_node[3:0]});	// data RAM address
//<

	assign	ramdtout	= aluout_reg;		// data RAM write data
//> modified ver1.00c, 2002/08/07
//	assign	readram	= (state_reg[1:0] = 2'b01) ? 1'b1 : 1'b0;	// data RAM read enable	(1 when state_reg = Q2)
	assign	readram	=  ~writeram_reg;
//<
	assign	writeram	= writeram_reg;		// data RAM write enable

	assign	eepadr	= eeadr_reg;			// EEPROM address
	assign	eepdtout	= eedata_reg;		// EEPROM write data
	assign	readeepreq	= eecon1_reg[0];	// EEPROM read request
	assign	writeeepreq	= eecon1_reg[1];	// EEPROM write request

	assign	porta_out	= portaout_reg;		// PORT-A output
	assign	porta_dir	= trisa_reg;		// PORT-A direction

	assign	portb_out	= portbout_reg;		// PORT-B output
	assign	portb_dir	= trisb_reg;		// PORT-B direction
	assign	rbpu	= option_reg[7];		// RBPU: pull-up enable

	assign	clkout	= clkout_reg;			// clkout (clkin/4) output

	assign	powerdown	= sleepflag_reg;	// CPU clock stop indicator
	assign	startclkin	= inte | rbint | wdt_full_reg | ( ~mclr_n) | ( ~ponrst_n);	// CPU clock start indicator

endmodule
