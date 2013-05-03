#!/usr/bin/perl -w

# The display2 method routine (L023E) should exit at the RET Z line if there was a key pressed (I think)
# Should return to the CALL L0207 after L0413

package ZX81;

use strict;
use Z80;
use TV;
use Keyboard;
use OpenGL qw / :all /; 

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
	glutMainLoop();
}

sub
new
{
	my $class = shift;
	my $rom = shift;

	my $self = {%ZX81};
	my $ret = bless $self, $class;	

	glutInit();

	my $cpu = Z80->new(sub {$ret->tick();});

	my @PROG = unpack("(C)*", $rom);

	$ret->{PROG} = \@PROG; 

	for (0 .. 64 * 1024) {
    		$ret->{RAM}->[$_] = 0;
	}

	my $tv = new TV();
	my $kb = new Keyboard();

	glutDisplayFunc(sub {$tv->render();});
	glutKeyboardFunc(sub {$kb->keyboard(@_);});
	glutIdleFunc(sub {$cpu->run();});

	$ret->{CPU} = $cpu;
	$ret->{TV} = $tv;
	$ret->{KEYBOARD} = $kb;

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

		if (1 && $cpu->ADDRESS_BUS == 0x023e) {
			$self->dump_ram("mem.bin.0x023e");
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
				$self->get_keyboard_output(
					($cpu->ADDRESS_BUS >> 8) & 0xFF)
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
	my $self = shift;
	my $keyboard_row = shift;
	my $ret = 0;
	$ret |= (get_cassette_input() << 7);
	$ret |= (get_display_refresh() << 6);
	$ret |= (1 << 5);
	$ret |= $self->read_keyboard_row($keyboard_row);
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
	my $self = shift;
	my $row = shift;

	my $cdflag = $self->read_memory(0x403B);
	my $debounce = $self->read_memory(0x4027);

	if (!defined $self->{KEY}) {
		$self->{KEY} = $self->{KEYBOARD}->next_key();
	} elsif ($cdflag & 0x1) {
		$self->{KEY} = $self->{KEYBOARD}->next_key();
	}

	my $ret;
	if (defined $self->{KEY}) {
		$self->{KEYBOARD}->print($self->{KEY});
		$ret = $self->{KEY}->{$row};
	} else {
		$ret = 0x1F;
	}


	print "EXECUTING KEY ROW: " .
		 sprintf("0x%02x", $row) . " " .
		sprintf("0x%02x", $ret) . 
	"\n";

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
