#!/usr/bin/perl -w

package Keyboard;

use strict;
use OpenGL qw/ glutGetModifiers GLUT_ACTIVE_SHIFT /;

my @SHIFT = (0, 0, 0xFE); 

my %KEYS = (
	"SHIFT" => 	[0,0, 0xFE, undef],
	ord("a") => 		[1,0, 0xFD, undef],
	ord("q") => 		[2,0, 0xFB, undef],
	ord("1") => 		[3,0, 0xF7, undef],
	ord("0") => 		[4,0, 0xEF, undef],
	ord("p") => 		[5,0, 0xDF, undef],
	ord('"') => 		[5,0, 0xDF, \@SHIFT],
	13 => 	[6,0, 0xBF, undef],
	ord(" ") => 		[7,0, 0x7F, undef],

	ord("z") => 		[0,1, 0xFE, undef],
	ord(":") => 		[0,1, 0xFE, \@SHIFT],
	ord("s") => 		[1,1, 0xFD, undef],
	ord("w") => 		[2,1, 0xFB, undef],
	ord("2") => 		[3,1, 0xF7, undef],
	ord("9") => 		[4,1, 0xEF, undef],
	ord("o") => 		[5,1, 0xDF, undef],
	ord(")") => 		[5,1, 0xDF, \@SHIFT],
	ord("l") => 		[6,1, 0xBF, undef],
	ord("=") => 		[6,1, 0xBF, \@SHIFT],
	ord(".") => 		[7,1, 0x7F, undef],
	ord(",") => 		[7,1, 0x7F, \@SHIFT],

	ord("x") => 		[0,2, 0xFE, undef],
	ord(";") => 		[0,2, 0xFE, \@SHIFT],
	ord("d") => 		[1,2, 0xFD, undef],
	ord("e") => 		[2,2, 0xFB, undef],
	ord("3") => 		[3,2, 0xF7, undef],
	ord("8") => 		[4,2, 0xEF, undef],
	ord("i") => 		[5,2, 0xDF, undef],
	ord("(") => 		[5,2, 0xDF, \@SHIFT],
	ord("k") => 		[6,2, 0xBF, undef],
	ord("+") => 		[6,2, 0xBF, \@SHIFT],
	ord("m") => 		[7,2, 0x7F, undef],
	ord(">") => 		[7,2, 0x7F, \@SHIFT],

	ord("c") => 		[0,3, 0xFE, undef],
	ord("?") => 		[0,3, 0xFE, \@SHIFT],
	ord("f") => 		[1,3, 0xFD, undef],
	ord("r") => 		[2,3, 0xFB, undef],
	ord("4") => 		[3,3, 0xF7, undef],
	ord("7") => 		[4,3, 0xEF, undef],
	ord("&") => 		[4,3, 0xEF, \@SHIFT],
	ord("u") => 		[5,3, 0xDF, undef],
	ord('$') => 		[5,3, 0xDF, \@SHIFT],
	ord("j") => 		[6,3, 0xBF, undef],
	ord("-") => 		[6,3, 0xBF, \@SHIFT],
	ord("n") => 		[7,3, 0x7F, undef],
	ord("<") => 		[7,3, 0x7F, \@SHIFT],

	ord("v") => 		[0,4, 0xFE, undef],
	ord("/") => 		[0,4, 0xFE, \@SHIFT],
	ord("g") => 		[1,4, 0xFD, undef],
	ord("t") => 		[2,4, 0xFB, undef],
	ord("5") => 		[3,4, 0xF7, undef],
	ord("%") => 		[3,4, 0xF7, \@SHIFT],
	ord("6") => 		[4,4, 0xEF, undef],
	ord("^") => 		[4,4, 0xEF, \@SHIFT],
	ord("y") => 		[5,4, 0xDF, undef],
	ord("h") => 		[6,4, 0xBF, undef],
	ord("b") => 		[7,4, 0x7F, undef],
	ord("*") => 		[7,4, 0x7F, \@SHIFT],
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

	my $char = $c;

	print "KEYBOARD PRESS $char " . chr($char) . "\n";
	if (!defined $KEYS{$char}) {
		print "KEYBOARD NO KEY MAPPED!!!\n";
		return;
	}
	my $key = $KEYS{$char};

	my %TPL = (
		0xFE => 0x1F,
		0xFD => 0x1F,
		0xFB => 0x1F,
		0xF7 => 0x1F,
		0xEF => 0x1F,
		0xDF => 0x1F,
		0xBF => 0x1F,
		0x7F => 0x1F,
	);

	$TPL{${$key}[2]} &= ((~(0x1 << ${$key}[1])) & 0x1F);

	my $shift = ${$key}[3];
	if (defined $shift) {
		print "KEYLINE: ${$shift}[2]\n";
		$TPL{${$shift}[2]} &= ((~(0x1 << ${$shift}[1])) & 0x1F);
	}
 
	my $mod = glutGetModifiers();

	#if ($mod & GLUT_ACTIVE_SHIFT) {
	#my $shift = $KEYS{SHIFT};
	#$key{${$shift}[2]} &= ((~(0x1 << ${$shift}[1])) & 0x1F);
	#}	 

	foreach (keys %TPL) {
		print 
			"KEYKEY: '$_' " .
			sprintf("0x%02x", $_) . 
			" " .	
			sprintf("0x%02x", $TPL{$_}) . 
			"\n";
	} 

	push @{$self->{BUFFER}}, {%TPL};
}

sub
next_key
{
	my $self = shift;

	my $ret = shift @{$self->{BUFFER}};

	if (!defined $ret) {

		return undef;
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

sub
print
{
	my $self = shift;
	my $k = shift;

	foreach (keys %{$k}) {
		print "KEYBOARD DBG " 
			. sprintf("0x%02x", $_) 
			. ": " 
			. sprintf("0x%02x", $k->{$_}) . "\n";
	} 
}

1;
