/*
 * トランジスタ技術 連載「HDLによる大規模ディジタル回路設計入門」
 * Convert IntelHEX into PIC ROM description in ALTERA MIF (ver1.00a, Nov/01/1999)
 * Copyright(c)1999 Sumio Morioka
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXFNAMESIZE 1024
#define MAXLINESIZE 8192

#define ADDRWIDTH 13	/* YOU CAN CHANGE IF TOTAL # OF DATA IS SMALL */
#define DATAWIDTH 14	/* DO NOT CHANGE */

unsigned int powerof2(int size)
{
	int i;
	unsigned int retval;
	for (retval = 1, i = 0; i < size; i++)
		retval *= 2;
	return (retval);
}

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
	char *cp;
	unsigned int romsize;

	if (argc < 2) {
		fprintf(stderr, "usage: hex2mif input_filename\n");
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
	sprintf(infname,  "%s.hex", modulepath);	/* input file name */
	sprintf(outfname, "%s.mif", modulepath);	/* output file name */

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

/* write MIF header */
	romsize = 0;
	fprintf(stderr, "ROM ADDRESS WIDTH? (enter 0 for using default value %d): ", ADDRWIDTH);
	fscanf(stdin, "%ud", &romsize);
	fprintf(stderr, "\n");
	if (romsize == 0) {
		romsize = ADDRWIDTH;
	}

	fprintf(fpout, "DEPTH = %d;\n", powerof2(romsize));
	fprintf(fpout, "WIDTH = %d;\n", DATAWIDTH);
	fprintf(fpout, "ADDRESS_RADIX = DEC\n");
	fprintf(fpout, "DATA_RADIX    = BIN\n");
	fprintf(fpout, "\n");
	fprintf(fpout, "CONTENT\n");
	fprintf(fpout, "BEGIN\n");
	fprintf(fpout, "[0..%d]:\t", powerof2(romsize) - 1);
	writebin(fpout, 0, DATAWIDTH);
	fprintf(fpout, ";\n");

/* read hex file and write output file */
	while (1) {		/* 1 loop = 1 line of HEX files */
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

		datanum	= read8bit(fpin) / 2;	/* 1. read # of data */
		addr	= readaddr(fpin);		/* 2. read data address */
		read8bit(fpin);					/* 3. read "00" */

		/* 4. read data contents */
		for (datacnt = 0; datacnt < datanum; datacnt++, addr++) {
			data = readpicdata(fpin);

			fprintf(fpout, "%d\t:\t", addr);
			writebin(fpout, data, DATAWIDTH);
			fprintf(fpout, ";\t\t%% addr %04X: data %04X %%\n", addr, data);
		}

		read8bit(fpin);					/* 5. read check sum */
	}
    fclose(fpin);

	fprintf(fpout, "END;\n");

    fclose(fpout);
    exit(0);
}

/* end of file */
