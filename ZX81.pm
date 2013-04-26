#!/usr/bin/perl -w

#problem prior to L0940.... BC is zero when this is called causes the loop to go for FF iterations
package ZX81;

use strict;
use z80;
use TV;

my %ZX81 = (

	CPU => undef,

	RAM => undef,
	PROG => undef,

	hblank => 0,
	hdisplay => 0,
	hretrace => 0,
	vblank => 0,
	display => 0,
	binno => 0,

	count => 0,
	MI_ENABLED => undef,
	LINECNTR => 0,
	CASSETTE_OUT => undef,
	R_REGISTER => 0xFF,

	VBLANK => undef,
	VERTICAL_RETRACE => undef,
	VDISPLAY => undef,

	HBLANK => undef,
	HDISPLAY => undef,
	HRETRACE => undef,

	KEY_BUFFER => [],
);

my %KEYS = (
	"SHIFT" => 	[0,0, 0xFEFE],
	"A" => 		[1,0, 0xFDFE],
	"Q" => 		[2,0, 0xFBFE],
	"1" => 		[3,0, 0xF7FE],
	"0" => 		[4,0, 0xEFFE],
	"P" => 		[5,0, 0xDFFE],
	"ENTER" => 	[6,0, 0xBFFE],
	" " => 		[7,0, 0x7FFE],

	"Z" => 		[0,1, 0xFEFE],
	"S" => 		[1,1, 0xFDFE],
	"W" => 		[2,1, 0xFBFE],
	"2" => 		[3,1, 0xF7FE],
	"9" => 		[4,1, 0xEFFE],
	"O" => 		[5,1, 0xDFFE],
	"L" => 		[6,1, 0xBFFE],
	"." => 		[7,1, 0x7FFE],

	"X" => 		[0,2, 0xFEFE],
	"D" => 		[1,2, 0xFDFE],
	"E" => 		[2,2, 0xFBFE],
	"3" => 		[3,2, 0xF7FE],
	"8" => 		[4,2, 0xEFFE],
	"I" => 		[5,2, 0xDFFE],
	"K" => 		[6,2, 0xBFFE],
	"M" => 		[7,2, 0x7FFE],

	"C" => 		[0,3, 0xFEFE],
	"F" => 		[1,3, 0xFDFE],
	"R" => 		[2,3, 0xFBFE],
	"4" => 		[3,3, 0xF7FE],
	"7" => 		[4,3, 0xEFFE],
	"U" => 		[5,3, 0xDFFE],
	"J" => 		[6,3, 0xBFFE],
	"N" => 		[7,3, 0x7FFE],

	"V" => 		[0,4, 0xFEFE],
	"G" => 		[1,4, 0xFDFE],
	"T" => 		[2,4, 0xFBFE],
	"5" => 		[3,4, 0xF7FE],
	"6" => 		[4,4, 0xEFFE],
	"Y" => 		[5,4, 0xDFFE],
	"H" => 		[6,4, 0xBFFE],
	"B" => 		[7,4, 0x7FFE],
);

sub
tick
{
	horiz_line(@_);
	tick1(@_);
}

sub
start
{
	my $self = shift;
	$self->{TV}->start();
}

sub
new
{
	my $class = shift;
	my $rom = shift;

	my $self = {%ZX81};
	my $ret = bless $self, $class;	

	my $cpu = z80->new(sub {$ret->tick();});

	my @PROG = unpack("(C)*", $rom);

	$ret->{PROG} = \@PROG; 

	for (0 .. 64 * 1024) {
    	$ret->{RAM}->[$_] = 0;
	}

	my $tv = TV->new(sub {$cpu->run();});

	$ret->{CPU} = $cpu;
	$ret->{TV} = $tv;

	return $ret;
}

my %VARS = (
0x401e	=> ["BERG", 1, undef],
0x403b	=> ["CDFLAG", 1, undef],
0x4016	=> ["CH_ADD", 2, 1],
0x4036	=> ["COORDS", 2, undef],
0x400c	=> ["D_FILE", 2, 1],
0x4027	=> ["DB_ST", 1, undef],
0x4012	=> ["DEST", 2, 1],
0x400e	=> ["DF_CC", 2, 1],
0x4022	=> ["DF_SZ", 2, undef],
0x4014	=> ["E_LINE", 2, 1],
0x400A	=> ["E_PPC", 2, undef],
0x4000	=> ["ERR_NR", 1, undef],
0x4002	=> ["ERR_SP", 2, 1],
0x4001	=> ["FLAGS", 1, undef],
0x402D	=> ["FLAGX", 1, undef],
0x4034	=> ["FRAMES", 2, undef],
0x4025	=> ["LAST_K", 2, undef],
0x4028	=> ["MARGIN", 1, undef],
0x401F	=> ["MEM", 2, undef],
0x405D	=> ["MEMBOT", 1, undef],
0x4006	=> ["MODE", 1, undef],
0x4029	=> ["NXTLIN", 2, 1],
0x402B	=> ["OLDPPC", 2, undef],
0x4007	=> ["PPC", 2, undef],
0x4038	=> ["PR_CC", 1, undef],
0x403c	=> ["PRBUFF", 2, undef],
0x4004	=> ["RAMTOP", 2, undef],
0x4039	=> ["S_POSN", 2, undef],
0x4023	=> ["S_TOP", 2, undef],
0x4032	=> ["SEED", 2, undef],
0x4021	=> ["SPARE1", 1, undef],
0x407b	=> ["SPARE2", 2, undef],
0x401a	=> ["STKBOT", 2, 1],
0x401c	=> ["STKEND", 2, 1],
0x402e	=> ["STRLEN", 2, undef],
0x4030	=> ["T_ADDR", 2, undef],
0x4010	=> ["VARS", 2, 1],
0x4009	=> ["VERSN", 1, undef],
0x4018	=> ["X_PTR", 2, undef],
);


my @KEYBOARD_ROW = (
	(~0x1) & 0xFF, 	#bit 0
	(~0x2) & 0xFF, 	#bit 1
	(~0x4) & 0xFF,	#bit 2
	(~0x8) & 0xFF,	#bit 3
	(~0x10) & 0xFF,	#bit 4
	(~0x20) & 0xFF,	#bit 5
	(~0x40) & 0xFF,	#bit 6
	(~0x80) & 0xFF,	#bit 7
);


sub
get_memory_array
{
	my $self = shift;
	my $addr = shift;

	if ((($addr >> 14) & 0x1) == 0) {
		return $self->{PROG};
	}

	return $self->{RAM};
}

sub
read_memory
{
	my $self = shift;
	my $addr = shift;

	if (!defined $addr) {
		exit;
	}

	my $a = $self->get_memory_array($addr);

	return $a->[$addr];
}

sub
write_memory
{
	my $self = shift;
	my $addr = shift;
	my $value = shift;

	my $a = $self->get_memory_array($addr);

	$a->[$addr] = $value;

	if (defined $VARS{$addr} || defined $VARS{$addr - 1}) {
		$self->print_var($addr);
	}

}

sub
dump_ram
{
	my $self = shift;
	my $fname_root = shift;

	$fname_root = "mem.bin" unless defined $fname_root;

	my ($fname) = $fname_root;

	while (-e $fname) {
		$self->{binno}++;
		$fname = $fname_root . "." .$self->{binno};
	}

		my $mem = pack("(C)*", @{$self->{RAM}});
		open (MEM, ">$fname");
		print MEM $mem;
		close MEM;
}

sub
horiz_line
{
	my $self = shift;
	my $cpu = $self->{CPU};
	if (!defined $self->{VERTICAL_RETRACE}) {

		my $mcount = $self->{count}++ % 207;

		if (0) {
			print "HBLANK: " . $self->{hblank}++ . "\n" if defined $self->{HBLANK};
			print "HDISPLAY: " . $self->{hdisplay}++ . "\n" if defined $self->{HDISPLAY};
			print "HRETRACE: " . $self->{hretrace}++ . "\n" if defined $self->{HRETRACE};

			print "LINECNTR: $self->{LINECNTR}\n";
		}

		if ($self->{count} == 0) {
			$self->{VBLANK} = 1;
			$self->{VDISPLAY} = undef;

			$self->{vblank} = 0;
			$self->{vdisplay} = 0;
		}

		if ($self->{count} == 6624) {
			$self->{VBLANK} = undef;
			$self->{VDISPLAY} = 1;
		}

		if ($self->{count} == 6624 + 39744) {
			$self->{VBLANK} = 1;
			$self->{VDISPLAY} = undef;
			$self->{TV}->vert();
			$self->{vblank} = 0;
		}

		if ($mcount == 0) {

			print "HORIZ\n";
			$self->{LINECNTR} = ($self->{LINECNTR} + 1) & 0x7;

			$self->{hblank} = 0;
			$self->{hdisplay} = 0;
			$self->{hretrace} = 0;

			$self->{HBLANK} = undef;
			$self->{HDISPLAY} = undef;
			$self->{HRETRACE} = 1;
			$cpu->NMI if defined $self->{NMI_ENABLED};

		}

		if (${mcount} == 16) {
			$self->{HBLANK} = 1;
			$self->{HDISPLAY} = undef;
			$self->{HRETRACE} = undef;
		}

		if (${mcount} == (16 + 39)) {
			$self->{HBLANK} = undef;
			$self->{HDISPLAY} = 1;
			$self->{HRETRACE} = undef;
			print "Starting display\n";
		}

		if (${mcount} == (16 + 39 + 128)) {
			$self->{HBLANK} = 1;
			$self->{TV}->horiz();
			$self->{HDISPLAY} = undef;
			$self->{HRETRACE} = undef;
			print "Ending display\n";
		}
	}
}

sub
tick1
{
	my $self = shift;
	my $cpu = $self->{CPU};

	if (!defined $cpu->{HALT} && defined $cpu->{M1} && defined $cpu->{MREQ}) {

		if (0) {
			print "Reading OP: " . sprintf("0x%02x", $cpu->ADDRESS_BUS);
			print " " . sprintf("0x%02x", 
				$self->read_memory($cpu->ADDRESS_BUS)) . "\n";
		}

		#the problem appears after L0419 in the call at L0433

		if (0 && $cpu->ADDRESS_BUS == 0x07f5) {
			$self->dump_ram("mem.bin.0x07f5");
		}

		if (0 && $cpu->ADDRESS_BUS == 0x0846) {
			$self->dump_ram("mem.bin.0x0846");
		}

		if (0 && $cpu->ADDRESS_BUS == 0x079d) {
			$self->dump_ram("mem.bin.0x079d");
		}

		if (0 && $cpu->ADDRESS_BUS == 0x003e) {
			$self->dump_ram("mem.bin.0x003e");
		}

		if (($cpu->ADDRESS_BUS >> 15) && 0x1) {
			$self->execute_video($cpu);
		} else {
			$cpu->DATA_BUS($self->read_memory($cpu->ADDRESS_BUS));
		}

		return;
	}

	if (defined $cpu->{RD} && defined $cpu->{MREQ}) {

		if (0) {
			print "Reading MEM: " . sprintf("0x%02x", $cpu->ADDRESS_BUS);
		}

		exit unless defined $self->read_memory($cpu->ADDRESS_BUS);

		if (0) {
			print " " . sprintf("0x%02x", 
				$self->read_memory($cpu->ADDRESS_BUS)) . "\n";
		}

		$cpu->DATA_BUS($self->read_memory($cpu->ADDRESS_BUS));
		return;
	}

	if (defined $cpu->{WR} && defined $cpu->{IORQ}) {

		if (0) {
			print "Writing: " . sprintf("0x%02x", $cpu->DATA_BUS);
			print " to " . sprintf("0x%04x", $cpu->ADDRESS_BUS) . "\n";
		}

		$self->terminate_vertical_retrace();

		if (($cpu->ADDRESS_BUS & 0xFF) == 0xFE) {
			$self->{NMI_ENABLED} = 1;
		} elsif (($cpu->ADDRESS_BUS & 0xFF) == 0xFD) {
			$self->{NMI_ENABLED} = undef;
		}

		return;
	}

	if (!defined $cpu->{WAIT} && defined $cpu->{RD} && defined $cpu->{IORQ}) {

		if (0) {
			print "Reading IO: " 
				. sprintf("0x%04x", $cpu->ADDRESS_BUS) . "\n";
		}

		if (($cpu->ADDRESS_BUS & 0x1) == 0x0) {
			$self->init_vertical_retrace();
		}

		if (($cpu->ADDRESS_BUS & 0xFF) == 0xFE) {

			$self->{CASSETTE_OUT} = "LOW";
			$self->{LINECNTR} = 0;

			$cpu->DATA_BUS(
				$self->get_keyboard_output(($cpu->ADDRESS_BUS >> 8) & 0xFF)
			);

		} 

		return;
	}

	if (defined $cpu->{WR} && defined $cpu->{MREQ}) {
		if (0) {
			print "Writing: " . sprintf("0x%02x", $cpu->DATA_BUS);
			print " to " . sprintf("0x%04x", $cpu->ADDRESS_BUS) . "\n";
		}

		$self->write_memory($cpu->ADDRESS_BUS, $cpu->DATA_BUS);
		return;
	}

	if (defined $cpu->{RFSH} && defined $cpu->{MREQ}) {

		my $prev_bit6 = (($self->{R_REGISTER} >> 5) & 0x1);

		$self->{R_REGISTER} = $cpu->ADDRESS_BUS & 0xFF;

		my $cur_bit6 = (($self->{R_REGISTER} >> 5) & 0x1);

		if ($prev_bit6 && !$cur_bit6) {
			$cpu->INT;
		}
	}

}

sub
get_keyboard_output
{
	my $keyboard_row = shift;
	my $ret = 0;
	$ret |= (get_cassette_input() << 7);
	$ret |= (get_display_refresh() << 6);
	$ret |= (1 << 5);
	$ret |= read_keyboard_row($keyboard_row);
	return $ret;

}

sub
get_cassette_input
{
	return 0; #normal 1=pulse
}

sub
get_display_refresh
{
	return 0; #60hz 1=50hz
}

sub
read_keyboard_row
{
	my $row = shift;
	my $ret = 0x1F;

	if (0 && $row == 0xFB) {
		$ret &= ((~(0x1 << 1)) & 0x1F); 
	}

	print "Executing Keyboard Row: " . sprintf("0x%02x", $ret) . "\n";

	return $ret;
}

sub
terminate_vertical_retrace
{
	my $self = shift;
	print "END_VERT_RT\n";
	$self->{VERTICAL_RETRACE} = undef;
	$self->{count} = 13;
			$self->{VBLANK} = 1;
			$self->{VDISPLAY} = undef;

			$self->{vblank} = 0;
			$self->{vdisplay} = 0;
}

sub
init_vertical_retrace
{
	my $self = shift;
	if (!defined $self->{VERTICAL_RETRACE}) {
		print "START_VERT_RT\n";
		$self->{VERTICAL_RETRACE} = 1;
		$self->{count} = 0;
	}
}

sub
execute_video
{
	my $self = shift;
	my $cpu = shift;
	my $code = $self->read_memory($cpu->ADDRESS_BUS & 0x7FFF);

	#print "Testing Code: " . sprintf("0x%02x", $code) . "\n";

	if ((($code >> 6) & 0x1) == 0x1) {
		$cpu->DATA_BUS($code);
		return;
	}

	my $char = ($cpu->{I} * 0x100) + (($code & 0x3F) * 8) + $self->{LINECNTR};
	my $data = $self->read_memory($char);

	if ((($code >> 7) & 0x1) == 0x1) {
		print "Was: " . sprintf("0x%02x", $data) . " ";
		$data = (~$data) & 0xFF;
		print "Is: " . sprintf("0x%02x", $data) . "\n";
	}

	$self->{TV}->data($data);
	#print "Executing CHAR: " . sprintf("0x%02x", $data) . "\n";

	$cpu->DATA_BUS(0x0);
}

sub
print_var
{
	return;
	my $self = shift;
	my $vaddr = shift;

	my $d = $VARS{$vaddr};
	my $d1 = $VARS{$vaddr - 1};

	return if defined $d && $d->[1] > 1; 
	return if defined $d1 && $d1->[1] == 1;

	my @d;
	if (defined $d) {
		@d = @{$d};
	} elsif (defined $d1) {
		@d = @{$d1};
		$vaddr--;
	} else {
		return;
	}	

	print "VAR $d[0]: "; 

	my $val = 0;
	for (0 .. ($d[1] - 1)) {
		my $addr = $vaddr + $_;

		my $tmp = $self->{RAM}->[$addr] << (($_) * 8);
		$val |= $tmp;

	}

	my $width = $d[1] * 2;
	print 
			sprintf("%04x", $vaddr) . " -> " .
			sprintf("%0${width}x", $val);

	if (defined $d[2]) {
		print sprintf(" -> %02x", $self->{RAM}->[$val]);
	}

	print "\n";
}

1;
