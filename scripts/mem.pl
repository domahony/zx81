#!/usr/bin/perl -w

my @RAM;
my $MEM;

binmode(STDIN);

while (<STDIN>) {
    $MEM .= $_;
}

@RAM = unpack("(C)*", $MEM);

my %VARS = (
	BERG => [0x401e, 1, undef],
	CDFLAG => [0x403b, 1, undef],
	CH_ADD => [0x4016, 2, 1],
	COORDS => [0x4036, 2, undef],
	D_FILE => [0x400c, 2, 1],
	DB_ST => [0x4027, 1, undef],
	DEST => [0x4012, 2, 1],
	DF_CC => [0x400e, 2, 1],
	DF_SZ => [0x4022, 2, undef],
	E_LINE => [0x4014, 2, 1],
	E_PPC => [0x400A, 2, undef],
	ERR_NR => [0x4000, 1, undef],
	ERR_SP => [0x4002, 2, 1],
	FLAGS => [0x4001, 1, undef],
	FLAGX => [0x402D, 1, undef],
	FRAMES => [0x4034, 2, undef],
	LAST_K => [0x4025, 2, undef],
	MARGIN => [0x4028, 1, undef],
	MEM => [0x401F, 2, undef],
	MEMBOT => [0x405D, 1, undef],
	MODE => [0x4006, 1, undef],
	NXTLIN => [0x4029, 2, 1],
	OLDPPC => [0x402B, 2, undef],
	PPC => [0x4007, 2, undef],
	PR_CC => [0x4038, 1, undef],
	PRBUFF => [0x403c, 2, undef],
	RAMTOP => [0x4004, 2, undef],
	S_POSN => [0x4039, 2, undef],
	S_TOP => [0x4023, 2, undef],
	SEED => [0x4032, 2, undef],
	SPARE1 => [0x4021, 1, undef],
	SPARE2 => [0x407b, 2, undef],
	STKBOT => [0x401a, 2, 1],
	STKEND => [0x401c, 2, 1],
	STRLEN => [0x402e, 2, undef],
	T_ADDR => [0x4030, 2, undef],
	VARS => [0x4010, 2, 1],
	VERSN => [0x4009, 1, undef],
	X_PTR => [0x4018, 2, undef],
);

foreach (sort keys %VARS) {
	print "$_: "; 

	my @d = @{$VARS{$_}};

	my $val = 0;
	for (0 .. ($d[1] - 1)) {
		my $addr = $d[0] + $_;

		my $tmp = $RAM[$addr] << (($_) * 8);
		$val |= $tmp;

		#print 
		#	sprintf("Addr $_: %04x", $addr) . 
		#	sprintf(" %02x", $RAM[$addr]) .
		#	sprintf(" %04x\n", $val);
	}

	my $width = $d[1] * 2;
	print 
			sprintf("%04x", $d[0]) . " -> " .
			sprintf("%0${width}x", $val);

	if (defined $d[2]) {
		print sprintf(" -> %02x", $RAM[$val]);
	}

	print "\n";
}

