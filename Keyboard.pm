#!/usr/bin/perl -w

package Keyboard;

use strict;

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
);

sub
new 
{
	my $class = shift;
	my $self = {%KB};

	return bless $self, $class;
}

1;
