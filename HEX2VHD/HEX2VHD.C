/*
 * トランジスタ技術 連載「HDLによる大規模ディジタル回路設計入門」
 * Convert IntelHEX into PIC ROM description in VHDL (ver1.00a, Nov/01/1999)
 * Copyright(c)1999 Sumio Morioka
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXFNAMESIZE 1024
#define MAXLINESIZE 8192

#define ADDRWIDTH 13	/* YOU CAN CHANGE IF TOTAL # OF DATA IS SMALL */
#define DATAWIDTH 14	/* DO NOT CHANGE */

unsigned int hex2int(char ch)
{
	switch (toupper(ch)) {
	case '0':	return (0);
	case '1':	return (1);
	case '2':	return (2);
	case '3':	return (3);
	case '4':	return (4);
	case '5':	return (5);
	case '6':	return (6);
	case '7':	return (7);
	case '8':	return (8);
	case '9':	return (9);
	case 'A':	return (10);
	case 'B':	return (11);
	case 'C':	return (12);
	case 'D':	return (13);
	case 'E':	return (14);
	case 'F':	return (15);
	default:	return (0);
	}
}

unsigned int  read8bit(FILE *fpin)
{
	int		chint;
	unsigned int retval;
	chint = fgetc(fpin);
	retval = hex2int((char)chint);
	chint = fgetc(fpin);
	retval = (retval * 16) + hex2int((char)chint);
	return (retval);
}

unsigned int  readaddr(FILE *fpin)
{
	unsigned int highdigit, lowdigit;
	highdigit = read8bit(fpin);
	lowdigit  = read8bit(fpin);
	return (((highdigit * 256) + lowdigit) / 2);
}

unsigned int  readpicdata(FILE *fpin)
{
	unsigned int highdigit, lowdigit;
	lowdigit  = read8bit(fpin);
	highdigit = read8bit(fpin);
	return ((highdigit * 256) + lowdigit);
}

void writebin(FILE *fpout, unsigned int data, int bitwidth)
{
	int i;
	unsigned int mask = 1;
	for (i = 1; i < bitwidth; i++)
		mask *= 2;
	for (i = 0; i < bitwidth; i++) {
		if ((mask & data) != 0)
			fprintf(fpout, "1");
		else
			fprintf(fpout, "0");
		mask /= 2;
	}
}

void main(int argc, char *argv[])
{
	FILE *fpin;
    FILE *fpout;
	char modulepath[MAXFNAMESIZE];
	char infname[MAXFNAMESIZE];
	char outfname[MAXFNAMESIZE];
	char *cp, *modulename;
	unsigned int romsize;

	if (argc < 2) {
		fprintf(stderr, "usage: hex2vhd input_filename\n");
		exit(1);
	}

/* make input/output filename */
	strcpy(modulepath, argv[1]);
	cp = modulepath + (strlen(modulepath) - 1);
	while (cp != modulepath && *cp != '.')
		cp--;
	if (strcmp(cp, ".hex") && strcmp(cp, ".HEX")) {
		fprintf(stderr, "Input file should be HEX file.\n");
		exit(1);
	}
	*cp = '\0';
	if (cp != modulepath) {
		cp--;
		while (cp != modulepath && *cp != '\\')
			cp--;
	}
	if (*cp == '\\')
		cp++;
	modulename = cp;
	sprintf(infname,  "%s.hex", modulepath);		/* input file name */
	sprintf(outfname, "%s.vhd", modulepath);		/* output file name */
	for (cp = modulename; *cp != '\0';) {
		*cp++ = tolower(*cp);
	}

/* open files */
	if ((fpin = fopen(infname, "rt")) == (FILE *)NULL) {
        fprintf(stderr, "can not open input file %s\n", infname);
		getchar();
		exit(1);
	}
    if ((fpout = fopen(outfname, "wt")) == (FILE *)NULL) {
        fprintf(stderr, "can not create output file %s\n", outfname);
        fclose(fpin);
		getchar();
        exit(1);
    }

/* write VHDL header */
	romsize = 0;
	fprintf(stderr, "ROM ADDRESS WIDTH? (enter 0 for using default value %d): ", ADDRWIDTH);
	fscanf(stdin, "%ud", &romsize);
	fprintf(stderr, "\n");
	if (romsize == 0)
		romsize = ADDRWIDTH;

	fprintf(fpout, "library ieee;\n");
	fprintf(fpout, "use ieee.std_logic_1164.all;\n");
	fprintf(fpout, "\n");
	fprintf(fpout, "entity %s is\n", modulename);
	fprintf(fpout, "\tport (\n");
	fprintf(fpout, "\t\tromaddr\t: in  std_logic_vector(%d downto 0);\n", romsize - 1);
	fprintf(fpout, "\t\tromout\t: out std_logic_vector(%d downto 0)\n", DATAWIDTH - 1);
	fprintf(fpout, "\t);\n");
	fprintf(fpout, "end %s;\n", modulename);
	fprintf(fpout, "\n");
	fprintf(fpout, "architecture RTL of %s is\n", modulename);
	fprintf(fpout, "begin\n");
	fprintf(fpout, "\tprocess (romaddr)\n");
	fprintf(fpout, "\tbegin\n");
	fprintf(fpout, "\t\tcase romaddr is\n");

/* read hex file and write output file */
	while (1) {		/* 1 loop = 1 line of HEX file */
		int		chint;
		int		datanum, datacnt;
		unsigned int	addr;
		unsigned int	data;

		if (feof(fpin))
			break;
		if ((chint = fgetc(fpin)) == EOF)
			break;
		if ((char)chint == '\n')
			continue;
		if ((char)chint != ':')
			break;

		datanum	= read8bit(fpin) / 2;		/* 1. read # of data */
		addr	= readaddr(fpin);			/* 2. read data address */
		read8bit(fpin);						/* 3. read "00" */

		/* 4. read data contents */
		for (datacnt = 0; datacnt < datanum; datacnt++, addr++) {
			data = readpicdata(fpin);

			fprintf(fpout, "\t\twhen \"");
			writebin(fpout, addr, romsize);
			fprintf(fpout, "\" => romout <= \"");
			writebin(fpout, data, DATAWIDTH);
			fprintf(fpout, "\";\t-- addr %04X: data %04X\n", addr, data);
		}

		read8bit(fpin);						/* 5. read check sum */
	}
    fclose(fpin);

/* write VHDL closing */
	fprintf(fpout, "\t\twhen others => romout <= \"");
	writebin(fpout, 0, DATAWIDTH);
	fprintf(fpout, "\";\n");
	fprintf(fpout, "\t\tend case;\n");
	fprintf(fpout, "\tend process;\n");
	fprintf(fpout, "\nend RTL;\n");

    fclose(fpout);
    exit(0);
}

/* end of file */
