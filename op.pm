#!/usr/bin/perl -w

package op;

use strict;

my %OP = (
	start_tick => undef,
	line_no => undef,
	code => undef,
	mnemonic => undef,
);

sub
to_string
{
	my $self = shift;
	my $tick = shift;
	my $R = shift;
	my $duration = $tick - $self->{start_tick};
	return "L" . sprintf("%04x", $self->{line_no}) 
		. "| $self->{mnemonic}"
		. "| " . sprintf("%02x", $self->{code})
		. "| " . sprintf("%02x", $R)
		. "| $duration"; 
}

sub
new 
{
	my $class = shift;
	my $cpu = shift;
	my $self = {%OP};

	$self->{line_no} = $cpu->{PC};
	$self->{start_tick} = $cpu->{tick_count};

	return bless $self, $class;
}

sub
mnemonic
{
	my $self = shift;	
	$self->{mnemonic} = shift;
}

sub
code
{
	my $self = shift;	
	$self->{code} = shift;
}

sub
line_no
{
	my $self = shift;	
	$self->{line_no} = shift;
}

sub
start_tick
{
	my $self = shift;	
	$self->{start_tick} = shift;
}

1;
