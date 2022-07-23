-- PICCORE.vhd
-- CPU core of CQPIC (PIC16F84/16F84A)
-- (1) Version 1.00a		Nov 1  1999
-- (2) Version 1.00b		Dec 10 2000		made a patch for BUG in MAX+plus2 VHDL compiler
-- (3) Version 1.00c		Aug 07 2002		made a patch for carry flag operations at substraction operations
-- (4) Version 1.00d		Aug 26 2004		debugged Z flag behavior (in case such that distinations are same as them)
--
-- Copyright(c)1999-2004 Sumio Morioka
-- e-mail:morioka@fb3.so-net.ne.jp, URL:http://www02.so-net.ne.jp/~morioka/cqpic.htm

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity piccore is
	generic (
		-- You can change the following parameters as you would like
		STACK_SIZE	: integer := 8;									-- Size of PC stack
		WDT_SIZE	: integer := 255								-- Size of watch dog timer (WDT)
	);
	port (
	-- program ROM data bus/address bus
		progdata	: in  std_logic_vector(13 downto 0);			-- ROM read data
		progadr		: out std_logic_vector(12 downto 0);			-- ROM address

	-- data RAM data bus/address bus/control signals
		ramdtin		: in  std_logic_vector(7 downto 0);				-- RAM read data
		ramdtout	: out std_logic_vector(7 downto 0);				-- RAM write data
		ramadr		: out std_logic_vector(8 downto 0);				-- RAM address; ramadr(8..7) indicates RAM-BANK
		readram		: out std_logic;								-- RAM read strobe (H active)
		writeram	: out std_logic;								-- RAM write strobe (H active)

	-- EEPROM data bus/address bus
		existeeprom	: in  std_logic;								-- Set to '1' if EEPROM is implemented.
		eepdtin		: in  std_logic_vector(7 downto 0);				-- EEPROM read data
		eepdtout	: out std_logic_vector(7 downto 0);				-- EEPROM write data
		eepadr		: out std_logic_vector(7 downto 0);				-- EEPROM address
		readeepreq	: out std_logic;								-- EEPROM read request (H active)
		readeepack	: in  std_logic;								-- EEPROM read acknowledge (H active)
		writeeepreq	: out std_logic;								-- EEPROM write request (H active)
		writeeepack	: in  std_logic;								-- EEPROM write acknowledge (H active)

	-- I/O ports
		porta_in	: in  std_logic_vector(4 downto 0);				-- PORT-A input data
		porta_out	: out std_logic_vector(4 downto 0);				-- PORT-A output data
		porta_dir	: out std_logic_vector(4 downto 0);				-- TRISA: PORT-A signal direction (H:input, L:output)

		portb_in	: in  std_logic_vector(7 downto 0);				-- PORT-B input data
		portb_out	: out std_logic_vector(7 downto 0);				-- PORT-B output data
		portb_dir	: out std_logic_vector(7 downto 0);				-- TRISB: PORT-B signal direction (H:input, L:output)

		rbpu		: out std_logic;								-- PORT_B pull-up enable (usually not used)

	-- PORT-B interrupt input
		int0		: in  std_logic;								-- PORT-B(0) INT
		int4		: in  std_logic;								-- PORT-B(4) INT
		int5		: in  std_logic;								-- PORT-B(5) INT
		int6		: in  std_logic;								-- PORT-B(6) INT
		int7		: in  std_logic;								-- PORT-B(7) INT

	-- TMR0 Control
		t0cki		: in  std_logic;								-- T0CKI (PORT-A(4))

	-- Watch Dog Timer Control
		wdtena		: in  std_logic;								-- WDT enable (H active)
		wdtclk		: in  std_logic;								-- WDT clock
		wdtfull		: out std_logic;								-- WDT-full indicator (H active)

	-- CPU clock stop/start indicators
		powerdown	: out std_logic;								-- SLEEP-mode; if H, you can stop system clock clkin
		startclkin	: out std_logic;								-- WAKEUP; if H, you should turn on clock for waking up from sleep-mode

	-- CPU reset
		ponrst_n	: in  std_logic;								-- Power-on reset (L active)
		mclr_n		: in  std_logic;								-- Normal reset (L active)

	-- CPU clock
		clkin		: in  std_logic;								-- Clock input
		clkout		: out std_logic									-- Clock output (clkin/4)
	);
end piccore;

architecture RTL of piccore is
	-- User registers
	signal w_reg			: std_logic_vector(7 downto 0);			-- W

	signal tmr0_reg			: std_logic_vector(7 downto 0);			-- TMR0
	signal pc_reg			: std_logic_vector(12 downto 0);		-- PCH/PCL
	signal status_reg		: std_logic_vector(7 downto 0);			-- STATUS
	signal fsr_reg			: std_logic_vector(7 downto 0);			-- FSR
	signal portain_sync_reg	: std_logic_vector(4 downto 0);			-- PORTA IN (synchronizer)
	signal portaout_reg		: std_logic_vector(4 downto 0);			-- PORTA OUT
	signal portbin_sync_reg	: std_logic_vector(7 downto 0);			-- PORTB IN (synchronizer)
	signal portbout_reg		: std_logic_vector(7 downto 0);			-- PORTB OUT
	signal eedata_reg		: std_logic_vector(7 downto 0);			-- EEDATA
	signal eeadr_reg		: std_logic_vector(7 downto 0);			-- EEADR
	signal pclath_reg		: std_logic_vector(4 downto 0);			-- PCLATH
	signal intcon_reg		: std_logic_vector(7 downto 0);			-- INTCON
	signal option_reg		: std_logic_vector(7 downto 0);			-- OPTION
	signal trisa_reg		: std_logic_vector(4 downto 0);			-- TRISA
	signal trisb_reg		: std_logic_vector(7 downto 0);			-- TRISB
	signal eecon1_reg		: std_logic_vector(4 downto 0);			-- EECON1

	-- Internal registers for controlling instruction execution
	signal inst_reg			: std_logic_vector(13 downto 0);		-- Hold fetched op-code/operand
	signal aluinp1_reg		: std_logic_vector(7 downto 0);			-- data source (1 of 2)
--> changed ver1.00c, 2002/08/07
--	signal aluinp2_reg		: std_logic_vector(7 downto 0);			-- data source (2 of 2)
	signal aluinp2_reg		: std_logic_vector(8 downto 0);			-- data source (2 of 2)
--<
	signal aluout_reg		: std_logic_vector(7 downto 0);			-- result of calculation
	signal exec_op_reg		: std_logic;							-- if L (i.e. GOTO instruction etc), stall exec of instruction
	signal intstart_reg 	: std_logic;							-- if H (i.e. interrupt), stall exec of instruction
	signal sleepflag_reg	: std_logic;							-- if H, sleeping

	-- Stack
	type STACK_TYPE is array (STACK_SIZE - 1 downto 0) of std_logic_vector(12 downto 0);
	signal stack_reg		: STACK_TYPE;							-- stack body (array of data-registers)
	signal stack_pnt_reg	: integer range 0 to STACK_SIZE - 1;	-- stack pointer (binary encoded)
	signal stack_pos_node	: std_logic_vector(STACK_SIZE - 1 downto 0);	-- same with stack pointer, but one-hot encoded
	signal stacktop_node	: std_logic_vector(12 downto 0);		-- data value of stack-top

	-- WDT register and its control
	signal wdt_reg				: integer range 0 to WDT_SIZE;		-- WDT counter
	signal wdt_full_reg			: std_logic;						-- WDT->CPU; hold WDT-full signal until CPU is reset
	signal wdt_full_sync_reg	: std_logic_vector(2 downto 0);		-- CPU; synchronizer for wdt_full_reg

	signal wdt_clr_reg			: std_logic;						-- CPU->WDT; request to zero-clear wdt_reg
	signal wdt_clr_reqhold_reg	: std_logic;						-- CPU; hold a clear-request if previous request is still processing
	signal wdtclr_req_reg		: std_logic_vector(1 downto 0);		-- WDT; synchronizer for wdt_clr_reg
	signal wdtclr_ack			: std_logic;						-- WDT->CPU; ack to wdt_clr_reg (same with wdtclr_req_reg(1))
	signal wdtclr_ack_sync_reg	: std_logic;						-- CPU; synchronizer for wdtclr_ack

	signal wdtfull_clr_reg		: std_logic;						-- CPU->WDT; requst to clear wdt_full_reg
	signal wdtfullclr_req_reg	: std_logic_vector(1 downto 0);		-- WDT; synchronizer for wdtfull_clr_reg

	-- TMR0 prescaler
	signal psck				: std_logic;							-- clock for prescaler
	signal pscale_reg		: integer range 0 to 255;				-- prescaler
	signal ps_full_reg		: std_logic;							-- clock for TMR0, from prescaler
	signal inctmrck			: std_logic;							-- clock for TMR0
	signal inctmrhold_reg	: std_logic;							-- hold TMR0 increment request

	-- Interrupt registers/nodes
	signal intrise_reg		: std_logic_vector(4 downto 0);			-- detect positive edge of PORT-B inputs
	signal intdown_reg		: std_logic_vector(4 downto 0);			-- detect negative edge of PORT-B inputs
	signal rb0_int, rb4_int, rb5_int, rb6_int, rb7_int	: std_logic;-- interrupt trigger
	signal rbint			: std_logic;							-- RB4-7 interrupt trigger
	signal inte				: std_logic;							-- RB0   interrupt trigger
	signal intclr_reg		: std_logic_vector(4 downto 0);			-- CPU; clear intrise_reg and intdown_reg

	-- State register
	constant STATEBIT_SIZE	: integer := 3;
	signal state_reg		: std_logic_vector(STATEBIT_SIZE - 1 downto 0);
	constant Qreset			: std_logic_vector(STATEBIT_SIZE - 1 downto 0) := "100";		-- reset state
	constant Q1				: std_logic_vector(STATEBIT_SIZE - 1 downto 0) := "000";		-- state Q1
	constant Q2				: std_logic_vector(STATEBIT_SIZE - 1 downto 0) := "001";		-- state Q2
	constant Q3				: std_logic_vector(STATEBIT_SIZE - 1 downto 0) := "011";		-- state Q3
	constant Q4				: std_logic_vector(STATEBIT_SIZE - 1 downto 0) := "010";		-- state Q4

	-- Result of decoding instruction
	signal INST_ADDLW, INST_ADDWF, INST_ANDLW, INST_ANDWF, INST_BCF, INST_BSF, INST_BTFSC, INST_BTFSS	: std_logic;
	signal INST_CALL, INST_CLRF, INST_CLRW, INST_CLRWDT, INST_COMF, INST_DECF, INST_DECFSZ				: std_logic;
	signal INST_GOTO, INST_INCF, INST_INCFSZ, INST_IORLW, INST_IORWF, INST_MOVLW, INST_MOVF, INST_MOVWF	: std_logic;
	signal INST_RETFIE, INST_RETLW, INST_RET, INST_RLF, INST_RRF										: std_logic;
	signal INST_SLEEP, INST_SUBLW, INST_SUBWF, INST_SWAPF, INST_XORLW, INST_XORWF						: std_logic;

	-- Result of calculating RAM access address
	signal ramadr_node		: std_logic_vector(8 downto 0);			-- RAM access address

	signal ADDR_TMR0, ADDR_PCL, ADDR_STAT, ADDR_FSR, ADDR_PORTA, ADDR_PORTB								: std_logic;
	signal ADDR_EEDATA, ADDR_EEADR, ADDR_PCLATH, ADDR_INTCON, ADDR_OPTION, ADDR_TRISA, ADDR_TRISB		: std_logic;
--	signal ADDR_EECON1, ADDR_EECON2, ADDR_SRAM															: std_logic;
	signal ADDR_EECON1, ADDR_SRAM																		: std_logic;

	-- Other output registers (for removing hazards)
	signal writeram_reg		: std_logic;							-- data-sram write strobe
--> deleted ver1.00c, 2002/08/07
--	signal ramadr_reg		: std_logic_vector(8 downto 0);			-- data-sram address
--<
	signal clkout_reg		: std_logic;							-- clkout output

	-- Synchronizers
	signal inte_sync_reg	: std_logic;
	signal rbint_sync_reg	: std_logic;
	signal inctmr_sync_reg	: std_logic_vector(1 downto 0);
	signal rdeep_sync_reg	: std_logic;
	signal wreep_sync_reg	: std_logic;
	signal mclr_sync_reg	: std_logic;
	signal poweron_sync_reg	: std_logic;

begin
-- CPU synchronizers
	u0:process (clkin)
	begin
		if (clkin'event and clkin = '1') then
			inte_sync_reg			<= inte;
			rbint_sync_reg			<= rbint;
			wdtclr_ack_sync_reg		<= wdtclr_ack;
			mclr_sync_reg			<= mclr_n;
			poweron_sync_reg		<= ponrst_n;
			rdeep_sync_reg			<= readeepack;
			wreep_sync_reg			<= writeeepack;
			inctmr_sync_reg(0)		<= inctmrck;
			inctmr_sync_reg(1)		<= inctmr_sync_reg(0);
			if (poweron_sync_reg = '0' or mclr_sync_reg = '0') then
				wdt_full_sync_reg		<= "000";
			else
				wdt_full_sync_reg(0)	<= wdt_full_reg;
				wdt_full_sync_reg(1)	<= wdt_full_sync_reg(0);	-- (remove meta-stable)
				wdt_full_sync_reg(2)	<= wdt_full_sync_reg(1);	-- (detect positive edge)
			end if;
		end if;
	end process;


-- Decode OPcode	(see pp.54 of PIC16F84 data sheet)
	-- only 1 signal of the following signals will be '1'
	INST_CALL		<= '1' when inst_reg(13 downto 11) = "100"				else '0';
	INST_GOTO		<= '1' when inst_reg(13 downto 11) = "101"				else '0';
	INST_BCF		<= '1' when inst_reg(13 downto 10) = "0100"				else '0';
	INST_BSF		<= '1' when inst_reg(13 downto 10) = "0101"				else '0';
	INST_BTFSC		<= '1' when inst_reg(13 downto 10) = "0110"				else '0';
	INST_BTFSS		<= '1' when inst_reg(13 downto 10) = "0111"				else '0';
	INST_MOVLW		<= '1' when inst_reg(13 downto 10) = "1100"				else '0';
	INST_RETLW		<= '1' when inst_reg(13 downto 10) = "1101"				else '0';
	INST_SUBLW		<= '1' when inst_reg(13 downto 9)  = "11110"			else '0';
	INST_ADDLW		<= '1' when	inst_reg(13 downto 9)  = "11111"			else '0';
	INST_IORLW		<= '1' when inst_reg(13 downto 8)  = "111000"			else '0';
	INST_ANDLW		<= '1' when inst_reg(13 downto 8)  = "111001"			else '0';
	INST_XORLW		<= '1' when inst_reg(13 downto 8)  = "111010"			else '0';
	INST_SUBWF		<= '1' when inst_reg(13 downto 8)  = "000010"			else '0';
	INST_DECF		<= '1' when inst_reg(13 downto 8)  = "000011"			else '0';
	INST_IORWF		<= '1' when inst_reg(13 downto 8)  = "000100"			else '0';
	INST_ANDWF		<= '1' when inst_reg(13 downto 8)  = "000101"			else '0';
	INST_XORWF		<= '1' when inst_reg(13 downto 8)  = "000110"			else '0';
	INST_ADDWF		<= '1' when inst_reg(13 downto 8)  = "000111"			else '0';
	INST_MOVF		<= '1' when inst_reg(13 downto 8)  = "001000"			else '0';
	INST_COMF		<= '1' when inst_reg(13 downto 8)  = "001001"			else '0';
	INST_INCF		<= '1' when inst_reg(13 downto 8)  = "001010"			else '0';
	INST_DECFSZ		<= '1' when inst_reg(13 downto 8)  = "001011"			else '0';
	INST_RRF		<= '1' when inst_reg(13 downto 8)  = "001100"			else '0';
	INST_RLF		<= '1' when inst_reg(13 downto 8)  = "001101"			else '0';
	INST_SWAPF		<= '1' when inst_reg(13 downto 8)  = "001110"			else '0';
	INST_INCFSZ		<= '1' when inst_reg(13 downto 8)  = "001111"			else '0';
	INST_MOVWF		<= '1' when inst_reg(13 downto 7)  = "0000001"			else '0';
	INST_CLRW		<= '1' when inst_reg(13 downto 7)  = "0000010"			else '0';
	INST_CLRF		<= '1' when inst_reg(13 downto 7)  = "0000011"			else '0';
	INST_RET		<= '1' when inst_reg(13 downto 0)  = "00000000001000"	else '0';
	INST_RETFIE		<= '1' when inst_reg(13 downto 0)  = "00000000001001"	else '0';
	INST_SLEEP		<= '1' when inst_reg(13 downto 0)  = "00000001100011"	else '0';
	INST_CLRWDT		<= '1' when inst_reg(13 downto 0)  = "00000001100100"	else '0';


-- Calculate RAM access address	(see pp.19 of PIC16F84 data sheet)

	-- if "d"=0, indirect addressing is used, so RAM address is BANK+FSR
	-- otherwise, RAM address is BANK+"d"
	-- (see pp.19 of PIC16F84 data sheet)
	ramadr_node <=	status_reg(7) & fsr_reg(7 downto 0)		when inst_reg(6 downto 0) = "0000000"	else
					status_reg(6 downto 5) & inst_reg(6 downto 0);

	-- check if this is an access to external RAM or not
	ADDR_SRAM		<= '1' when ramadr_node(6 downto 0) > "0001011"	else '0';	-- 0CH-7FH, 8CH-FFH

	-- check if this is an access to special register or not
	-- only 1 signal of the following signals will be '1'
	ADDR_TMR0		<= '1' when ramadr_node(7 downto 0) = "00000001"		else '0';	-- 01H
	ADDR_PCL		<= '1' when ramadr_node(6 downto 0) =  "0000010"		else '0';	-- 02H, 82H
	ADDR_STAT		<= '1' when ramadr_node(6 downto 0) =  "0000011"		else '0';	-- 03H, 83H
	ADDR_FSR		<= '1' when ramadr_node(6 downto 0) =  "0000100"		else '0';	-- 04H, 84H
	ADDR_PORTA		<= '1' when ramadr_node(7 downto 0) = "00000101"		else '0';	-- 05H
	ADDR_PORTB		<= '1' when ramadr_node(7 downto 0) = "00000110"		else '0';	-- 06H
	ADDR_EEDATA		<= '1' when ramadr_node(7 downto 0) = "00001000"		else '0';	-- 08H
	ADDR_EEADR		<= '1' when ramadr_node(7 downto 0) = "00001001"		else '0';	-- 09H
	ADDR_PCLATH		<= '1' when ramadr_node(6 downto 0) =  "0001010"		else '0';	-- 0AH, 8AH
	ADDR_INTCON		<= '1' when ramadr_node(6 downto 0) =  "0001011"		else '0';	-- 0BH, 8BH
	ADDR_OPTION		<= '1' when ramadr_node(7 downto 0) = "10000001"		else '0';	-- 81H
	ADDR_TRISA		<= '1' when ramadr_node(7 downto 0) = "10000101"		else '0';	-- 85H
	ADDR_TRISB		<= '1' when ramadr_node(7 downto 0) = "10000110"		else '0';	-- 86H
	ADDR_EECON1		<= '1' when ramadr_node(7 downto 0) = "10001000"		else '0';	-- 88H
--	ADDR_EECON2		<= '1' when ramadr_node(7 downto 0) = "10001001"		else '0';	-- 89H


-- Read value of PC-STACK top
	-- convert binary value of stack pointer into onehot value (for reducing circuit)
	ND1: for I in 0 to STACK_SIZE - 1 generate
		stack_pos_node(I)	<= '1' when stack_pnt_reg = I	else '0';
	end generate ND1;

	-- pick up value of stack-top from stack cells
	u1:process (stack_reg, stack_pos_node)
		variable stack_cell		: STACK_TYPE;						-- value of each stack cell
		variable top			: std_logic_vector(12 downto 0);	-- value of stack top
	begin
		for I in 0 to STACK_SIZE - 1 loop
			if (stack_pos_node(I) = '1') then		-- (if the position is stack top)
				stack_cell(I) := stack_reg(I);
			else
				stack_cell(I) := "0000000000000";
			end if;
		end loop;

		top	:= stack_cell(0);
		for I in 1 to STACK_SIZE - 1 loop
			top	:= top or stack_cell(I);
		end loop;
		stacktop_node <= top;
	end process;


-- MAIN EFSM: description of register value changes in each clock cycle
	u2:process (clkin)
		-- Intermidiate nodes used for resource sharing
		variable ramin_node			: std_logic_vector(7 downto 0);		-- result of reading RAM/Special registers
		variable incpc_node			: std_logic_vector(12 downto 0);	-- value of PC + 1
		variable mask_node 			: std_logic_vector(7 downto 0);		-- bit mask for logical operations
		variable add_node			: std_logic_vector(8 downto 0);		-- result of 8bit addition (std_logic_vector)
		variable addLow_node		: std_logic_vector(4 downto 0);		-- reulst of low-4bit addition (std_logic_vector)
		variable aluout_zero_node	: std_logic;						-- H if ALUOUT = 0
		variable writew_node		: std_logic;						-- H if destination is W register
		variable writeram_node		: std_logic;						-- H if destination is RAM/Special registers
		variable int_node			: std_logic;						-- H if interrupt request comes
		variable wdtreset_node		: std_logic;						-- H if WDT-reset request comes
		variable reset_cond			: std_logic;						-- H if any reset request comes (jump to Qreset state)
-- >> added on Dec 10,2000
		variable stack_full_node	: integer range 0 to STACK_SIZE - 1;
-- << added on Dec 10,2000
--> added ver1.00c, 2002/08/07
		variable extbit_node		: std_logic;
--<
	begin
		if (clkin'event and clkin = '1') then

		-- 1. Intermidiate nodes for resource sharing

			-- 1-1. Result of reading RAM; one of data sources	(see pp.13 of PIC16F84 data sheet)
			if (ADDR_SRAM = '1') then
				ramin_node	:= ramdtin;						-- data bus output of external SRAM
			elsif (ADDR_EEDATA = '1') then
				ramin_node	:= eedata_reg;					-- data bus output of external EEPROM
			elsif (ADDR_TMR0 = '1') then
				ramin_node	:= tmr0_reg;					-- TMR0
			elsif (ADDR_PCL = '1') then
				ramin_node	:= pc_reg(7 downto 0);			-- PCL
			elsif (ADDR_STAT = '1') then
				ramin_node	:= status_reg;					-- STATUS
			elsif (ADDR_FSR = '1') then
				ramin_node	:= fsr_reg;						-- FSR
			elsif (ADDR_PORTA = '1') then
				for I in 0 to 4 loop
					if (trisa_reg(I) = '1') then
						ramin_node(I)	:= portain_sync_reg(I);		-- PORT B (when input mode)
					else
						ramin_node(I)	:= portaout_reg(I);			-- PORT B (when output mode)
					end if;
				end loop;
				ramin_node(7 downto 5)	:= "000";
			elsif (ADDR_PORTB = '1') then
				for I in 0 to 7 loop
					if (trisb_reg(I) = '1') then
						ramin_node(I)	:= portbin_sync_reg(I);		-- PORT B (when input mode)
					else
						ramin_node(I)	:= portbout_reg(I);			-- PORT B (when output mode)
					end if;
				end loop;
			elsif (ADDR_EEADR = '1') then
				ramin_node	:= eeadr_reg;					-- EEADR
			elsif (ADDR_PCLATH = '1') then
				ramin_node	:= "000" & pclath_reg;			-- PCLATH (5bit)
			elsif (ADDR_INTCON = '1') then
				ramin_node	:= intcon_reg;					-- INTCON
			elsif (ADDR_OPTION = '1') then
				ramin_node	:= option_reg;					-- OPTION
			elsif (ADDR_TRISA = '1') then
				ramin_node	:= "000" & trisa_reg;			-- TRISA
			elsif (ADDR_TRISB = '1') then
				ramin_node	:= trisb_reg;					-- TRISB
			elsif (ADDR_EECON1 = '1') then
				ramin_node	:= "000" & eecon1_reg;			-- EECON1 (5bit)
			else
				ramin_node	:= (others => '0');
			end if;

			-- 1-2. PC + 1
			incpc_node	:= pc_reg + "0000000000001";

			-- 1-3. Adder (ALU)
--> changed ver1.00c, 2002/08/07
			-- full 8bit-addtion
--			add_node		:= ("0" & aluinp1_reg) + ("0" & aluinp2_reg);
			add_node		:= ("0" & aluinp1_reg) + aluinp2_reg;
			-- lower 4bit-addtion
			if (INST_SUBLW = '1' or INST_SUBWF = '1') then
				extbit_node	:= aluinp2_reg(4);
			else
				extbit_node	:= '0';
			end if;
--			addLow_node		:= ("0" & aluinp1_reg(3 downto 0)) + ("0" & aluinp2_reg(3 downto 0));
			addLow_node		:= ("0" & aluinp1_reg(3 downto 0)) + (extbit_node & aluinp2_reg(3 downto 0));
--<

			-- 1-4. Test if aluout = 0
			if (aluout_reg = "00000000") then
				aluout_zero_node	:= '1';
			else
				aluout_zero_node	:= '0';
			end if;

			-- 1-5. Determine destination
			if (intstart_reg = '1') then
				writew_node		:= '0';
				writeram_node	:= '0';
			elsif (INST_MOVWF = '1' or INST_BCF = '1' or INST_BSF = '1' or INST_CLRF = '1') then
				writew_node		:= '0';
				writeram_node	:= '1';
			elsif (INST_MOVLW = '1' or INST_ADDLW = '1' or INST_SUBLW = '1' or INST_ANDLW = '1' or INST_IORLW = '1'
					or INST_XORLW = '1' or INST_RETLW = '1' or INST_CLRW = '1') then
				writew_node		:= '1';
				writeram_node	:= '0';
			elsif (INST_MOVF = '1' or INST_SWAPF = '1' or INST_ADDWF = '1' or INST_SUBWF = '1' or INST_ANDWF = '1'
					or INST_IORWF = '1' or INST_XORWF = '1' or INST_DECF = '1' or INST_INCF = '1' or INST_RLF = '1'
					or INST_RRF = '1' or INST_DECFSZ = '1' or INST_INCFSZ = '1' or INST_COMF = '1') then
				writew_node		:= not inst_reg(7);		-- ("d" field of fetched instruction)
				writeram_node	:= inst_reg(7);			-- ("d" field of fetched instruction)
			else
				writew_node		:= '0';
				writeram_node	:= '0';
			end if;

			-- 1-6. Interrupt request	(see pp.17 of PIC16F84 data sheet)
			int_node	:= intcon_reg(7)									-- GIE
							and ( (intcon_reg(3) and intcon_reg(0))			-- RBIE and RBIF
									or (intcon_reg(4) and intcon_reg(1))	-- INTE and INTF
									or (intcon_reg(5) and intcon_reg(2))	-- T0IE and T0IF
									or (intcon_reg(6) and eecon1_reg(4))	-- EEIE and EEIF(EECON1)
								);

			-- 1-7. Reset conditions
			wdtreset_node	:= wdt_full_sync_reg(1) and (not wdt_full_sync_reg(2));			-- WDT

			if (poweron_sync_reg = '0' or mclr_sync_reg = '0' or wdtreset_node = '1') then	-- (all of reset triggers)
				reset_cond	:= '1';
			else
				reset_cond	:= '0';
			end if;


		-- 2. EFSM body
			case state_reg is

		-- 2-1. Reset state (see pp.14 and pp.42 of PIC16F84 data sheet)
			when Qreset =>
				pc_reg					<= (others => '0');		-- 0
				status_reg(7 downto 5)	<= "000";
				pclath_reg				<= (others => '0');		-- 0
				intcon_reg(7 downto 1)	<= "0000000";
				option_reg				<= (others => '1');
				trisa_reg				<= (others => '1');
				trisb_reg				<= (others => '1');
				tmr0_reg				<= (others => '0');		-- (specification: don't care)
				exec_op_reg				<= '0';
				intclr_reg				<= (others => '1');		-- clear int
				intstart_reg 			<= '0';
				writeram_reg			<= '0';
				sleepflag_reg			<= '0';

				-- (set /T0 and /PD properly; see pp.42 and pp.46 of data sheet)
				if (poweron_sync_reg = '0') then	-- Power-on Reset
					status_reg(4)		<= '1';					-- /T0 = 1
					status_reg(3)		<= '1';					-- /PD = 1
				elsif (mclr_sync_reg = '0') then	-- MCLR reset/MCLR wake up from sleep
					status_reg(4)		<= '1';					-- /T0 = 1
					status_reg(3)		<= not sleepflag_reg;	-- /PD = 1 if normal reset, /PD = 0 if wake up
				elsif (wdtreset_node = '1') then	-- WDT reset/WDT wake up from sleep
					status_reg(4)		<= '0';					-- /T0 = 0
					status_reg(3)		<= not sleepflag_reg;	-- /PD = 1 if normal reset, /PD = 0 if wake up
				end if;

				eecon1_reg(4)			<= '0';
				-- (set WRERR bit in EECON1 properly; see pp.33 and pp.34 of data sheet)
				if (poweron_sync_reg = '0') then
					eecon1_reg(3)		<= '0';				-- clear WRERR
				else
					eecon1_reg(3)		<= eecon1_reg(1);	-- substitute WR into WRERR
				end if;
				eecon1_reg(2 downto 0)	<= "000";

				if (poweron_sync_reg = '0') then
					-- NOTICE: do NOT clear stack pointer for MCLR reset or WDT reset (the value must be hold)
					stack_pnt_reg		<= 0;
				end if;

				if (reset_cond = '0') then		-- go to Q1 if reset signal is disasserted.
					state_reg 			<= Q1;
				end if;

		-- 2-2. Q1 cycle
			when Q1 =>
			-- 2-2-1. Clear external interrupt registers if GIE=0
				if (intcon_reg(7) = '1') then
					intclr_reg		<= (others => '0');
				else										-- GIE = 0
					intclr_reg		<= (others => '1');		-- clear interrupt
				end if;

			-- 2-2-2. Read I/O port
				portain_sync_reg	<= porta_in;
				portbin_sync_reg	<= portb_in;

			-- 2-2-3. Read/Write EEPROM, if necessary
				if (intstart_reg = '0') then
					if (eecon1_reg(0) = '1' and rdeep_sync_reg = '1') then		-- reading EEPROM complete
						eedata_reg		<= eepdtin;
						eecon1_reg(0)	<= '0';			-- clear EECON1_RD
					end if;
					if (eecon1_reg(1) = '1' and wreep_sync_reg = '1') then		-- writing EEPROM complete
						if (intcon_reg(7) = '1' and intcon_reg(6) = '1') then
							eecon1_reg(4)	<= '1';		-- INT (EE write complete)
						end if;
						eecon1_reg(1)	<= '0';			-- clear EECON1_WR
					end if;

--> deleted ver1.00c, 2002/08/07
--					if (exec_op_reg = '1') then
--						ramadr_reg			<= ramadr_node;		-- RAM read address
--					end if;
--<
				end if;

			-- 2-2-4. Check increment-TMR0 request
				if (inctmr_sync_reg = "01") then
					inctmrhold_reg	<= '1';
				end if;

			-- 2-2-5. Goto next cycle
				if (reset_cond = '1') then
					state_reg 	<= Qreset;
				else
					-- if in the sleep mode, wait until wake-up triggers comes
					if (sleepflag_reg = '1' and intstart_reg = '0') then
						if (inte_sync_reg = '1' or rbint_sync_reg = '1') then	-- if PORT-B interrupts come, then resume execution
																				-- otherwise, if WDT reset/MCLR reset come, then goto Qreset
							sleepflag_reg	<= '0';
							state_reg 		<= Q2;
						end if;
					else
						state_reg 	<= Q2;
					end if;
				end if;

		-- 2-3. Q2 cycle
			when Q2 =>
			-- 2-3-1. Read data-RAM and substitute source values to alu-input registers
				if (exec_op_reg = '1' and intstart_reg = '0') then	-- if NOT STALLED

				-- 2-3-1-1. Set aluinp1 register (source #1)
					if (INST_MOVF = '1' or INST_SWAPF = '1' or INST_ADDWF = '1' or INST_SUBWF = '1'
							or INST_ANDWF = '1' or INST_IORWF = '1' or INST_XORWF = '1' or INST_DECF = '1'
							or INST_INCF = '1' or INST_RLF = '1' or INST_RRF = '1' or INST_BCF = '1'
							or INST_BSF = '1' or INST_BTFSC = '1' or INST_BTFSS = '1' or INST_DECFSZ = '1'
							or INST_INCFSZ = '1' or INST_COMF = '1') then
						aluinp1_reg		<= ramin_node;				-- RAM/Special registers
					elsif (INST_MOVLW = '1' or INST_ADDLW = '1' or INST_SUBLW = '1' or INST_ANDLW = '1'
							or INST_IORLW = '1' or INST_XORLW = '1' or INST_RETLW = '1') then
						aluinp1_reg		<= inst_reg(7 downto 0);	-- Immidiate value ("k")
					elsif (INST_CLRF = '1' or INST_CLRW = '1') then
						aluinp1_reg		<= (others => '0');			-- 0
					else
						aluinp1_reg		<= w_reg;					-- W register
					end if;

				-- 2-3-1-2. Set aluinp2 register (source #2)
					case inst_reg(9 downto 7) is					-- construct bit-mask for logical operations/bit test
					when "000" =>	mask_node := "00000001";
					when "001" =>	mask_node := "00000010";
					when "010" =>	mask_node := "00000100";
					when "011" =>	mask_node := "00001000";
					when "100" =>	mask_node := "00010000";
					when "101" =>	mask_node := "00100000";
					when "110" =>	mask_node := "01000000";
--					when "111" =>	mask_node := "10000000";
					when others =>	mask_node := "10000000";
					end case;

					if (INST_DECF = '1' or INST_DECFSZ = '1') then
						aluinp2_reg		<= (others => '1');				-- -1 (for decrement)
					elsif (INST_INCF = '1' or INST_INCFSZ = '1') then
--> modified ver1.00c, 2002/08/07
--						aluinp2_reg		<= "00000001";	-- 1 (for increment)
						aluinp2_reg		<= "000000001";	-- 1 (for increment)
					elsif (INST_SUBLW = '1' or INST_SUBWF = '1') then
--						aluinp2_reg		<= (not w_reg) + "00000001";	-- -1 * W register (for subtract)
						aluinp2_reg		<= ("1" & (not w_reg)) + "000000001";	-- -1 * W register (for subtract)
					elsif (INST_BCF = '1') then
--						aluinp2_reg		<= not mask_node;				-- mask for BCF: value of only one position is '0'
						aluinp2_reg		<= "0" & (not mask_node);		-- mask for BCF: value of only one position is '0'
																		-- operation of BCF: AND with inverted mask ("1..101..1")
					elsif (INST_BTFSC = '1' or INST_BTFSS = '1' or INST_BSF = '1') then
--						aluinp2_reg		<= mask_node;					-- operation of BSF: OR with mask_node ("0..010..0")
						aluinp2_reg		<= "0" & mask_node;				-- operation of BSF: OR with mask_node ("0..010..0")
																		-- operation of FSC and FSS: AND with mask_node and then compare with zero
					else
--						aluinp2_reg		<= w_reg;						-- W register
						aluinp2_reg		<= "0" & w_reg;					-- W register
--<
					end if;

				-- 2-3-1-3. Set stack pointer register (pop stack)
					if (INST_RET = '1' or INST_RETLW = '1' or INST_RETFIE = '1') then
						if (stack_pnt_reg = 0) then
							stack_pnt_reg	<= STACK_SIZE - 1;			-- if pointer=0, then next value should be STACK_SIZE-1
						else
							stack_pnt_reg	<= stack_pnt_reg - 1;		-- otherwise, current value - 1
						end if;
					end if;

				-- 2-3-1-4. Set ramadr register (set RAM write address)
--> deleted ver1.00c, 2002/08/07
--					ramadr_reg	<= ramadr_node;		-- RAM write address
--<
				end if;

			-- 2-3-2. Change clkout output
				clkout_reg	<= '1';

			-- 2-3-3. Check increment-TMR0 request
				if (inctmr_sync_reg = "01") then
					inctmrhold_reg	<= '1';
				end if;

			-- 2-3-4. Goto next cycle
				if (reset_cond = '1') then
					state_reg 	<= Qreset;
				else
					state_reg 	<= Q3;
				end if;

		-- 2-4. Q3 cycle
			when Q3 =>
			-- 2-4-1. Calculation and store result into alu-output regsiter
				if (exec_op_reg = '1' and intstart_reg = '0') then	-- if NOT STALLED

				-- 2-4-1-1. Set aluout register
					if (INST_RLF = '1') then
						aluout_reg	<= aluinp1_reg(6 downto 0) & status_reg(0);				-- rotate left
					elsif (INST_RRF = '1') then
						aluout_reg	<= status_reg(0) & aluinp1_reg(7 downto 1);				-- rotate right
					elsif (INST_SWAPF = '1') then
						aluout_reg	<= aluinp1_reg(3 downto 0) & aluinp1_reg(7 downto 4);	-- swap H-nibble and L-nibble
					elsif (INST_COMF = '1') then
						aluout_reg	<= not aluinp1_reg;										-- logical inversion
					elsif (INST_ANDLW = '1' or INST_ANDWF = '1' or INST_BCF = '1' or INST_BTFSC = '1' or INST_BTFSS = '1') then
--> modified ver1.00c, 2002/08/07
--						aluout_reg	<= aluinp1_reg and aluinp2_reg;							-- logical AND/bit clear/bit test
						aluout_reg	<= aluinp1_reg and aluinp2_reg(7 downto 0);				-- logical AND/bit clear/bit test
					elsif (INST_BSF = '1' or INST_IORLW = '1' or INST_IORWF = '1') then
--						aluout_reg	<= aluinp1_reg or aluinp2_reg;							-- logical OR/bit set
						aluout_reg	<= aluinp1_reg or aluinp2_reg(7 downto 0);				-- logical OR/bit set
					elsif (INST_XORLW = '1' or INST_XORWF = '1') then
--						aluout_reg	<= aluinp1_reg xor aluinp2_reg;							-- logical XOR
						aluout_reg	<= aluinp1_reg xor aluinp2_reg(7 downto 0);				-- logical XOR
--<
					elsif (INST_ADDLW = '1' or INST_ADDWF = '1' or INST_SUBLW = '1' or INST_SUBWF = '1'
							or INST_DECF = '1' or INST_DECFSZ = '1' or INST_INCF = '1' or INST_INCFSZ = '1') then
						aluout_reg	<= add_node(7 downto 0);								-- addition/subtraction/increment/decrement
					else
						aluout_reg	<= aluinp1_reg;											-- pass through
					end if;

				-- 2-4-1-2. Set C flag and DC flag
--> modified ver1.00c, 2002/08/07
--					if (INST_ADDLW = '1' or INST_ADDWF = '1' or INST_SUBLW = '1' or INST_SUBWF = '1') then
--						status_reg(1)	<= addLow_node(4);			-- DC flag
--						status_reg(0)	<= add_node(8);				-- C flag
					if (INST_ADDLW = '1' or INST_ADDWF = '1') then
						status_reg(1)	<= addLow_node(4);			-- DC flag
						status_reg(0)	<= add_node(8);				-- C flag
					elsif (INST_SUBLW = '1' or INST_SUBWF = '1') then
						status_reg(1)	<= not addLow_node(4);		-- DC flag
						status_reg(0)	<= not add_node(8);			-- C flag
--<
					elsif (INST_RLF = '1') then
						status_reg(0)	<= aluinp1_reg(7);			-- C flag
					elsif (INST_RRF = '1') then
						status_reg(0)	<= aluinp1_reg(0);			-- C flag
					end if;

				-- 2-4-1-3. Set data-SRAM write enable (hazard-free)
					if (writeram_node = '1' and ADDR_SRAM = '1') then
						writeram_reg	<= '1';
					else
						writeram_reg	<= '0';
					end if;

				else	-- (if stalled)
					writeram_reg		<= '0';
				end if;

			-- 2-4-2. Check external interrupt and set interrupt flag / Increment TMR0
				if (intstart_reg = '0') then
					if (intcon_reg(7) = '1') then				-- GIE
						-- PORT-B0 INT
						if (inte_sync_reg = '1') then
							intcon_reg(1)			<= '1';		-- set INTF
							intclr_reg(0)			<= '1';		-- clear external int-registers (intrise_reg(0) and intdown_reg(0))
						end if;
						-- PORT-B[4-7] INT
						if (rbint_sync_reg = '1') then
							intcon_reg(0)			<= '1';		-- set RBIF
							intclr_reg(4 downto 1)	<= "1111";	-- clear external int-registers (intrise_reg(4-1) and intdown_reg(4-1))
						end if;
					end if;

				end if;

				-- Increment TMR0
				if (inctmrhold_reg = '1' or inctmr_sync_reg = "01") then		-- increment trigger comes
					tmr0_reg		<= tmr0_reg + "00000001";	-- increment
					inctmrhold_reg	<= '0';

					-- if intstart = '0' and GIE = '1' and T0IE = '1' and timer full, then set T0IF
					if (intstart_reg = '0' and intcon_reg(7) = '1' and intcon_reg(5) = '1' and tmr0_reg = "11111111") then
						intcon_reg(2)	<= '1';				-- set T0IF
					end if;
				end if;

			-- 2-4-3. Goto next cycle
				if (reset_cond = '1') then
					state_reg 	<= Qreset;
				else
					state_reg 	<= Q4;
				end if;

		-- 2-5. Q4 cycle
			when Q4 =>
			-- 2-5-1. Fetch next program-instruction
				inst_reg	<= progdata;

				if (exec_op_reg = '0' and intstart_reg = '0') then		-- if STALLED
					pc_reg			<= incpc_node;		-- increment PC
					exec_op_reg		<= '1';				-- end of stall

				else	-- if NOT stalled (note: if intstart_reg = '1', only stack/pc-operations in this else-clause will be performed)
			-- 2-5-2. Store calculation result into distination, set PC and flags, and determine if execute next cycle or not

				-- 2-5-2-1. Set W register, if not in stall cycle (intstart_reg = '0') and distination is W
					if (writew_node = '1') then		-- ('0' if intstart_reg = '1')
						w_reg	<= aluout_reg;									-- write W reg
					end if;

				-- 2-5-2-2. Set data RAM/special registers, if not in stall cycle (intstart_reg = '0')
					if (writeram_node = '1') then	-- ('0' if intstart_reg = '1')
						if (ADDR_STAT = '1') then
							status_reg(7 downto 5)	<= aluout_reg(7 downto 5);		-- write IRP,RP1,RP0
							-- status(4),status(3)...unwritable, see below (/PD,/T0 part)
							status_reg(1 downto 0)	<= aluout_reg(1 downto 0);		-- write DC,C
						end if;
						if (ADDR_FSR = '1') then
							fsr_reg			<= aluout_reg;							-- write FSR
						end if;
						if (ADDR_PORTA = '1') then
							portaout_reg	<= aluout_reg(4 downto 0);				-- write PORT-A
						end if;
						if (ADDR_PORTB = '1') then
							portbout_reg	<= aluout_reg;							-- write PORT-B
						end if;
						if (ADDR_EEDATA = '1') then
							eedata_reg		<= aluout_reg;							-- write EEDATA
						end if;
						if (ADDR_EEADR = '1') then
							eeadr_reg		<= aluout_reg;							-- write EEADR
						end if;
						if (ADDR_PCLATH = '1') then
							pclath_reg		<= aluout_reg(4 downto 0);				-- write PCLATH
						end if;
						if (ADDR_INTCON = '1') then
							intcon_reg(6 downto 0)	<= aluout_reg(6 downto 0);		-- write INTCON (except GIE)
							-- intcon(7)...see below (GIE part)
						end if;
						if (ADDR_OPTION = '1') then
							option_reg		<= aluout_reg;							-- write OPTION
						end if;
						if (ADDR_TRISA = '1') then
							trisa_reg		<= aluout_reg(4 downto 0);				-- write TRISA
						end if;
						if (ADDR_TRISB = '1') then
							trisb_reg		<= aluout_reg;							-- write TRISB
						end if;
						if (ADDR_TMR0 = '1') then
							tmr0_reg		<= aluout_reg;							-- write TMR0
						end if;
						if (ADDR_EECON1 = '1') then									-- write EECON1
							eecon1_reg(4 downto 3)	<= aluout_reg(4 downto 3);
							eecon1_reg(2)			<= aluout_reg(2) and existeeprom;	-- WREN can be set only when EEPROM exists
							if (aluout_reg(2 downto 0) = "110") then	-- if write enabled, write bit = '1', and no current read
								eecon1_reg(1)	<= '1';								-- WR: only SET-operation is allowed to user
							end if;
							if (aluout_reg(1 downto 0) = "01") then		-- if no current write, and read bit = '1'
								eecon1_reg(0)	<= '1';								-- RD: only SET-operation is allowed to user
							end if;
						end if;
					end if;

				-- 2-5-2-3. Set/clear Z flag, if not in stall cycle (intstart_reg = '0')
					if (intstart_reg = '0') then
-----> changed v1.00d, 2004/08/26
						-- if (ADDR_STAT = '1') then
						if (writeram_node = '1' and ADDR_STAT = '1' and INST_CLRF = '0') then
-----< changed v1.00d, 2004/08/26
							 status_reg(2)	<= aluout_reg(2);					-- (distination is Z flag)
						elsif (INST_ADDLW = '1' or INST_ADDWF = '1' or INST_ANDLW = '1' or INST_ANDWF = '1'
								or INST_CLRF = '1' or INST_CLRW = '1' or INST_COMF = '1' or INST_DECF = '1'
								or INST_INCF = '1' or INST_MOVF = '1' or INST_SUBLW = '1' or INST_SUBWF = '1'
								or INST_XORLW = '1' or INST_XORWF = '1') then
							status_reg(2)	<= aluout_zero_node;				-- Z=1 if result == 0
						elsif (INST_IORLW = '1' or INST_IORWF = '1') then
-- SELECT ONE OF THE FOLLOWING TWO SENTENCES
																				-- IORLW or IORWF instructions:
							status_reg(2)	<= not aluout_zero_node;			-- Z=1 if result != 0 (same behavior with PIC16F84 data sheet pp.61-62)
--							status_reg(2)	<= aluout_zero_node;				-- Z=1 if resutl == 0 (same behavior with the other instructions)
						end if;
					end if;

				-- 2-5-2-4. Set PC register and determine if execute next cycle or not
					if (intstart_reg = '1') then								-- After interrupt-stall cycle ends, jump to interrupt vector
						pc_reg			<= "0000000000100";						-- (interrupt vector)
						exec_op_reg 	<= '0';									-- the next cycle is stall cycle
					elsif (INST_RET = '1' or INST_RETLW = '1' or INST_RETFIE = '1') then	-- "return" instructions
						pc_reg			<= stacktop_node;						-- pc <= top of poped stack (the stack is poped at Q2 cycle)
						exec_op_reg 	<= '0';									-- the next cycle is stall cycle
					elsif (INST_GOTO = '1' or INST_CALL = '1') then				-- "goto/call" instructions
						pc_reg			<= pclath_reg(4 downto 3) & inst_reg(10 downto 0);	-- (see pp.18 of PIC16F84 data sheet)
						exec_op_reg 	<= '0';
					elsif ( ((INST_BTFSC = '1' or INST_DECFSZ = '1' or INST_INCFSZ = '1') and aluout_zero_node = '1')
							or (INST_BTFSS = '1' and aluout_zero_node = '0') ) then	-- bit_test instrcutions
						pc_reg			<= incpc_node;
						exec_op_reg 	<= '0';									-- the next cycle is stall cycle, if test conditions are met.
					elsif (writeram_node = '1' and ADDR_PCL = '1') then			-- PCL is data-distination
						pc_reg			<= pclath_reg(4 downto 0) & aluout_reg;	-- (see pp.18 of PIC16F84 data sheet)
						exec_op_reg 	<= '0';
					else
						-- this check MUST be located AFTER the above if/elsif sentences
						if (int_node = '0') then								-- check if interrupt trigger comes
							pc_reg		<= incpc_node;							-- if not, the next instruction fetch/execution will be performed normally
						else
							pc_reg		<= pc_reg;								-- if so, value of PC must be hold (will be pushed into stack at the end of next instruction cycle)
						end if;
						exec_op_reg 	<= '1';
					end if;

				-- 2-5-2-5. Push current PC value into stack, if necessary
					if (INST_CALL = '1' or intstart_reg = '1') then				-- CALL instruction or End of interrupt-stall cycle
						-- write PC-value into stack top
						for I in 0 to STACK_SIZE - 1 loop
							if (stack_pos_node(I) = '1') then		-- check if the stack cell is stack top or not
								stack_reg(I)	<= pc_reg;			-- if so, write PC value
							end if;
						end loop;
						-- increment stack pointer
-- >> Changed on Dec 10,2000
						stack_full_node	:= STACK_SIZE - 1;
--						if (stack_pnt_reg = STACK_SIZE - 1) then
						if (stack_pnt_reg = stack_full_node) then
-- << Changed on Dec 10,2000
							stack_pnt_reg	<= 0;
						else
							stack_pnt_reg	<= stack_pnt_reg + 1;
						end if;
					end if;

				-- 2-5-2-6. Set GIE bit in intcon register (intcon_reg(7))
					if (intstart_reg = '0') then
						if (int_node = '1') then					-- interrupt trigger comes
							intcon_reg(7)	<= '0';					-- clear GIE
							intstart_reg	<= '1';					-- the next cycle is interrupt-stall cycle
						elsif (INST_RETFIE = '1') then				-- "return from interrupt" instruction
							intcon_reg(7)	<= '1';
							intstart_reg	<= '0';
						elsif (writeram_node = '1' and ADDR_INTCON = '1') then	-- distination is GIE
							intcon_reg(7)	<= aluout_reg(7);
							intstart_reg	<= '0';
						else
							intstart_reg	<= '0';
						end if;
					else
						intstart_reg	<= '0';
					end if;

				-- 2-5-2-7. Set/clear /PD and /TO flags
					if (intstart_reg = '0') then
						if (INST_CLRWDT	= '1'
								or (INST_SLEEP = '1' and (wdtreset_node = '0' and intstart_reg = '0')) ) then	-- CLRWDT or (SLEEP and no interrupt trigger)
							-- see pp.46,58 and 66 of PIC16F84 data-sheet
							if (INST_SLEEP = '1') then
								sleepflag_reg			<= '1';
								status_reg(4 downto 3)	<= "10";	-- SLEEP: /T0,/PD = 1,0
							else		-- (INST_CLRWDT)
								status_reg(4 downto 3)	<= "11";	-- CLRWDT: /T0,/PD = 1,1
							end if;
						end if;
					end if;

				end if;		-- (if not stalled)

			-- 2-5-3. Clear data-SRAM write enable (hazard-free)
				writeram_reg	<= '0';

			-- 2-5-4. Change clkout output
				clkout_reg		<= '0';

			-- 2-5-5. Check increment-TMR0 request
				if (inctmr_sync_reg = "01") then
					inctmrhold_reg	<= '1';
				end if;

			-- 2-5-6. Goto next cycle
				if (reset_cond = '1') then
					state_reg 	<= Qreset;
				else
					state_reg 	<= Q1;
				end if;

		-- 2-6. Illegal states (NEVER REACHED in normal execution)
			when others =>
				state_reg 	<= Qreset;		-- goto reset state
			end case;
		end if;
	end process;


-- TMR0 pre-scaler (see pp.27 of PIC16F84 data sheet)
	-- select pre-scaler
	psck	<=	clkout_reg						when option_reg(5) = '0'	else		-- option_reg(5):T0CS
				t0cki xor option_reg(4);												-- option_reg(4):T0SE

	-- pre-scaler body
	u3:process (psck, ponrst_n)
		variable rateval	: integer range 0 to 255;
	begin
		if (ponrst_n = '0') then
			pscale_reg			<= 0;
			ps_full_reg			<= '0';
		elsif (psck'event and psck = '1') then
			case option_reg(2 downto 0) is		-- select prescaler-full value by PS2-0
			when "000" =>	rateval := 1;
			when "001" =>	rateval := 3;
			when "010" =>	rateval := 7;
			when "011" =>	rateval := 15;
			when "100" =>	rateval := 31;
			when "101" =>	rateval := 63;
			when "110" =>	rateval := 127;
--			when "111" =>	rateval := 255;
			when others =>	rateval := 255;
			end case;

			if (pscale_reg >= rateval) then
				pscale_reg		<= 0;
				ps_full_reg		<= '1';
			else
				pscale_reg		<= pscale_reg + 1;
				ps_full_reg		<= '0';
			end if;
		end if;
	end process;

	-- select TMR0-increment trigger
	inctmrck	<= 	psck			when option_reg(3) = '1'	else	-- option_reg(3):PSA
					ps_full_reg;										-- ps_full_reg:output of pre-scaler


-- WDT timer body
	u4:process (wdtclk, ponrst_n, mclr_n)
		variable	wdtfull_node	: std_logic;
	begin
		if (ponrst_n = '0' or mclr_n = '0') then		-- (async reset)
			wdt_reg				<= 0;
			wdt_full_reg		<= '0';
			wdtclr_req_reg		<= "00";
			wdtfullclr_req_reg	<= "00";
		elsif (wdtclk'event and wdtclk = '1') then
			-- synchronizers
			-- WDT-clear request (CLRWDT/SLEEP instruction)
			wdtclr_req_reg(0)		<= wdt_clr_reg;		-- (do not AND with sleepflag_reg, since WDT should be cleared at SLEEP instruction)
			wdtclr_req_reg(1)		<= wdtclr_req_reg(0);
			-- WDT-full-clear request (after WDT reset)
			wdtfullclr_req_reg(0)	<= wdtfull_clr_reg and (not sleepflag_reg);
			wdtfullclr_req_reg(1)	<= wdtfullclr_req_reg(0);

			-- timer/full reg
			if (wdt_reg >= WDT_SIZE) then
				wdtfull_node	:= '1';		-- (intermidiate node)
			else
				wdtfull_node	:= '0';		-- (intermidiate node)
			end if;

			-- wdt_reg(counter) body
			if (wdtclr_req_reg = "01" or wdtena = '0') then
				wdt_reg			<= 0;
			elsif (wdtfull_node = '1') then
				wdt_reg			<= 0;
			else
				wdt_reg 		<= wdt_reg + 1;
			end if;

			-- wdt_full_reg(interrupt trigger) body
			if (wdtfullclr_req_reg = "01" or wdtena = '0') then
				wdt_full_reg	<= '0';
			elsif (wdtfull_node = '1') then
				wdt_full_reg	<= '1';
			end if;
		end if;
	end process;
	wdtclr_ack	<= wdtclr_req_reg(1);		-- WDT-clear ack signal to CPU
	wdtfull		<= wdt_full_reg;			-- WDT-full signal (interrupt trigger) to CPU


-- WDT controller in CPU-clock line (handshake-interface between WDT and CPU-EFSM)
	u5:process (clkin)
	begin
		if (clkin'event and clkin = '1') then
			if (poweron_sync_reg = '0' or mclr_sync_reg = '0') then
				wdt_clr_reg			<= '0';		-- WDT clear request register
				wdt_clr_reqhold_reg	<= '0';		-- will be 1 when WDT clear request comes while another clear request is still processed
				wdtfull_clr_reg		<= '0';		-- WDT-full clear request register
			else
				-- WDT-clear/hold WDT-clear request
				-- (handshake)
				if (wdt_clr_reg = '1') then					-- still processing clear-operation
					if (wdtclr_ack_sync_reg = '1') then		-- if ack comes, go down the clear request
						wdt_clr_reg		<= '0';
					end if;
				elsif (wdt_clr_reqhold_reg = '1'
							or (state_reg = Q4
									and exec_op_reg = '1' and intstart_reg = '0'
									and (INST_CLRWDT = '1' or INST_SLEEP = '1')) ) then		-- clear request comes
					if (wdtclr_ack_sync_reg = '0') then		-- confirm if ack is 0
						wdt_clr_reg			<= '1';
						wdt_clr_reqhold_reg	<= '0';
					else									-- (wait until ack becomes 0)
						wdt_clr_reqhold_reg	<= '1';
					end if;
				end if;

				-- clear WDT-full (CPU reset request)
				-- (handshake)
				if (wdtfull_clr_reg = '1') then				-- still processing clear-operation
					if (wdt_full_sync_reg(1) = '0') then	-- if ack comes, go down the clear request
						wdtfull_clr_reg		<= '0';
					end if;
				elsif (wdt_full_sync_reg(1) = '1') then		-- clear request comes
															-- the WDT-full signal does not come so often, so hold-register is not necessary
					wdtfull_clr_reg		<= '1';
				end if;
			end if;
		end if;
	end process;


-- Detect external interrupt requests
	-- INT0 I/F
	u6:process (int0, intclr_reg)
	begin
		if (intclr_reg(0) = '1') then
			intrise_reg(0)	<= '0';
		elsif (int0'event and int0 = '1') then		-- catch positive edge
			intrise_reg(0)	<= '1';
		end if;
	end process;

	u7:process (int0, intclr_reg)
	begin
		if (intclr_reg(0) = '1') then
			intdown_reg(0)	<= '0';
		elsif (int0'event and int0 = '0') then		-- catch negative edge
			intdown_reg(0)	<= '1';
		end if;
	end process;

	rb0_int	<= intrise_reg(0)	when option_reg(6) = '1'	else	-- option_reg(6):INTEDG
			   intdown_reg(0);

	-- INT4 I/F
	u8:process (int4, intclr_reg)
	begin
		if (intclr_reg(1) = '1') then
			intrise_reg(1)	<= '0';
		elsif (int4'event and int4 = '1') then		-- catch positive edge
			intrise_reg(1)	<= '1';
		end if;
	end process;

	u9:process (int4, intclr_reg)
	begin
		if (intclr_reg(1) = '1') then
			intdown_reg(1)	<= '0';
		elsif (int4'event and int4 = '0') then		-- catch negative edge
			intdown_reg(1)	<= '1';
		end if;
	end process;

	rb4_int	<= intrise_reg(1) or intdown_reg(1);

	-- INT5 I/F
	u10:process (int5, intclr_reg)
	begin
		if (intclr_reg(2) = '1') then
			intrise_reg(2)	<= '0';
		elsif (int5'event and int5 = '1') then		-- catch positive edge
			intrise_reg(2)	<= '1';
		end if;
	end process;

	u11:process (int5, intclr_reg)
	begin
		if (intclr_reg(2) = '1') then
			intdown_reg(2)	<= '0';
		elsif (int5'event and int5 = '0') then		-- catch negative edge
			intdown_reg(2)	<= '1';
		end if;
	end process;

	rb5_int	<= intrise_reg(2) or intdown_reg(2);

	-- INT6 I/F
	u12:process (int6, intclr_reg)
	begin
		if (intclr_reg(3) = '1') then
			intrise_reg(3)	<= '0';
		elsif (int6'event and int6 = '1') then		-- catch positive edge
			intrise_reg(3)	<= '1';
		end if;
	end process;

	u13:process (int6, intclr_reg)
	begin
		if (intclr_reg(3) = '1') then
			intdown_reg(3)	<= '0';
		elsif (int6'event and int6 = '0') then		-- catch negative edge
			intdown_reg(3)	<= '1';
		end if;
	end process;

	rb6_int	<= intrise_reg(3) or intdown_reg(3);

	-- INT7 I/F
	u14:process (int7, intclr_reg)
	begin
		if (intclr_reg(4) = '1') then
			intrise_reg(4)	<= '0';
		elsif (int7'event and int7 = '1') then		-- catch positive edge
			intrise_reg(4)	<= '1';
		end if;
	end process;

	u15:process (int7, intclr_reg)
	begin
		if (intclr_reg(4) = '1') then
			intdown_reg(4)	<= '0';
		elsif (int7'event and int7 = '0') then		-- catch negative edge
			intdown_reg(4)	<= '1';
		end if;
	end process;

	rb7_int	<= intrise_reg(4) or intdown_reg(4);


-- Decode INT triggers (do not AND with GIE(intcon_reg(7)), since these signals are also used for waking up from SLEEP)
	inte	<= intcon_reg(4) and rb0_int;										-- G0IE and raw-trigger signal
	rbint	<= intcon_reg(3) and (rb4_int or rb5_int or rb6_int or rb7_int);	-- RBIE and raw-trigger signal


-- Circuit's output siganals
	progadr		<= pc_reg;								-- program ROM address

--> modified ver1.00c, 2002/08/07
--	ramadr		<= ramadr_reg;							-- data RAM address
	-- map 0F0-0FF,170-17F, and 1F0-1FF into 070-07F
	ramadr		<= ramadr_node	when ramadr_node(6 downto 4) /= "111"	else
					"00111" & ramadr_node(3 downto 0);	-- data RAM address
--<

	ramdtout	<= aluout_reg;							-- data RAM write data
--> modified ver1.00c, 2002/08/07
--	readram		<= '1' when state_reg(1 downto 0) = "01"	else '0';	-- data RAM read enable	(1 when state_reg = Q2)
	readram		<= not writeram_reg;
--<
	writeram	<= writeram_reg;						-- data RAM write enable

	eepadr		<= eeadr_reg;							-- EEPROM address
	eepdtout	<= eedata_reg;							-- EEPROM write data
	readeepreq	<= eecon1_reg(0);						-- EEPROM read request
	writeeepreq	<= eecon1_reg(1);						-- EEPROM write request

	porta_out	<= portaout_reg;						-- PORT-A output
	porta_dir	<= trisa_reg;							-- PORT-A direction

	portb_out	<= portbout_reg;						-- PORT-B output
	portb_dir	<= trisb_reg;							-- PORT-B direction
	rbpu		<= option_reg(7);						-- RBPU: pull-up enable

	clkout 		<= clkout_reg;							-- clkout (clkin/4) output

	powerdown	<= sleepflag_reg;														-- CPU clock stop indicator
	startclkin	<= inte or rbint or wdt_full_reg or (not mclr_n) or (not ponrst_n);		-- CPU clock start indicator

end RTL;
