#!/usr/bin/perl -w

package Keyboard;

use strict;
use OpenGL qw/ glutGetModifiers GLUT_ACTIVE_SHIFT /;

my %KEYS = (
	"SHIFT" => 	[0,0, 0xFE],
	"A" => 		[1,0, 0xFD],
	"Q" => 		[2,0, 0xFB],
	"1" => 		[3,0, 0xF7],
	"0" => 		[4,0, 0xEF],
	"P" => 		[5,0, 0xDF],
	"ENTER" => 	[6,0, 0xBF],
	" " => 		[7,0, 0x7F],

	"Z" => 		[0,1, 0xFE],
	"S" => 		[1,1, 0xFD],
	"W" => 		[2,1, 0xFB],
	"2" => 		[3,1, 0xF7],
	"9" => 		[4,1, 0xEF],
	"O" => 		[5,1, 0xDF],
	"L" => 		[6,1, 0xBF],
	"." => 		[7,1, 0x7F],

	"X" => 		[0,2, 0xFE],
	"D" => 		[1,2, 0xFD],
	"E" => 		[2,2, 0xFB],
	"3" => 		[3,2, 0xF7],
	"8" => 		[4,2, 0xEF],
	"I" => 		[5,2, 0xDF],
	"K" => 		[6,2, 0xBF],
	"M" => 		[7,2, 0x7F],

	"C" => 		[0,3, 0xFE],
	"F" => 		[1,3, 0xFD],
	"R" => 		[2,3, 0xFB],
	"4" => 		[3,3, 0xF7],
	"7" => 		[4,3, 0xEF],
	"U" => 		[5,3, 0xDF],
	"J" => 		[6,3, 0xBF],
	"N" => 		[7,3, 0x7F],

	"V" => 		[0,4, 0xFE],
	"G" => 		[1,4, 0xFD],
	"T" => 		[2,4, 0xFB],
	"5" => 		[3,4, 0xF7],
	"6" => 		[4,4, 0xEF],
	"Y" => 		[5,4, 0xDF],
	"H" => 		[6,4, 0xBF],
	"B" => 		[7,4, 0x7F],
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

my %KB = (
	BUFFER => [],
);

sub
new 
{
	my $class = shift;
	my $self = {%KB};

	return bless $self, $class;
}

sub
keyboard
{
	my $self = shift;
	my ($c, $x, $y) = @_;

	my $char = uc chr $c;

	print "KEYBOARD $char\n";
	if (!defined $KEYS{$char}) {
		return;
	}
	my $key = $KEYS{$char};

	my %key = (
		0xFE => 0x1F,
		0xFD => 0x1F,
		0xFB => 0x1F,
		0xF7 => 0x1F,
		0xEF => 0x1F,
		0xDF => 0x1F,
		0xBF => 0x1F,
		0x7F => 0x1F,
	);

	$key{${$key}[2]} &= ((~(0x1 << ${$key}[1])) & 0x1F);
 
	my $mod = glutGetModifiers();

	if ($mod & GLUT_ACTIVE_SHIFT) {
		my $shift = $KEYS{SHIFT};
		$key{${$shift}[2]} &= ((~(0x1 << ${$shift}[1])) & 0x1F);
	} 

	foreach (keys %key) {
		print 
			sprintf("0x%02x", $_) . 
			" " .	
			sprintf("0x%02x", $key{$_}) . 
			"\n";
	} 

	push @{$self->{BUFFER}}, {%key};
}

sub
next_key
{
	my $self = shift;

	my $ret = shift @{$self->{BUFFER}};

	if (!defined $ret) {

		my %key = (
			0xFE => 0x1F,
			0xFD => 0x1F,
			0xFB => 0x1F,
			0xF7 => 0x1F,
			0xEF => 0x1F,
			0xDF => 0x1F,
			0xBF => 0x1F,
			0x7F => 0x1F,
		);
	
		$ret = {%key};
	}

	return $ret;
}

1;
