#!/usr/bin/perl -w

package TEST;
my $CMASK = 0x1;
my $HMASK = 0x2;
my $PVMASK = 0x4;
my $NMASK = 0x10;
my $ZMASK = 0x40;
my $SMASK = 0x80;

my $t = new TEST;


$t->calculate_add_flags(6, 3, 0, 8);

sub
new
{
	my $class = shift;

	my $self = {};

	return bless $self, $class;
}

sub
calculate_add_flags
{
    my ($self, $a, $b, $use_carry, $WIDTH) = @_;
    my $res;
    my $carry = 0;

    my $MASK = 0;
    for (1 .. $WIDTH) {
        $MASK = ($MASK << 1) | 0x1;
    }

	#print sprintf("MASK: %04x\n", $MASK);

    if ($use_carry && ($self->{F} & $CMASK)) {
        $carry = 1 if ($a >= $MASK - $b);
        $res = $a + $b + 1;
    } else {
        $carry = 1 if ($a > $MASK - $b);
        $res = $a + $b;
    }

    my $oshift = $WIDTH - 1;
    my $hshift = $WIDTH - 4;

    my $carryIns = $res ^ $a ^ $b;
    $self->{F} = ($self->{F} & ~($CMASK | $PVMASK | $HMASK)) & $MASK;

    $self->{F} |= $PVMASK if ((($carryIns >> $oshift) ^ $carry) & 0x1);
    $self->{F} |= $HMASK if (($carryIns >> $hshift) & 0x1);
    $self->{F} |= $CMASK if ($carry);

	if ($res < 0) {
		$self->flag("S", 1);
	} else {
		$self->flag("S", 0);
	}

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("N", 0);
}

sub
flag
{
	my $self = shift;
	my $arg = shift;
	my $val = shift;

	if ($arg eq "C") {
	}
	if ($arg eq "H") {
	}
	if ($arg eq "PV") {
	}
	if ($arg eq "N") {
	}
	if ($arg eq "Z") {
	}
	if ($arg eq "S") {
	}


	$self->{$arg} = $val;
}
