#!/usr/bin/perl -w

package TEST;
my $CMASK = 0x1;
my $HMASK = 0x2;
my $PVMASK = 0x4;
my $NMASK = 0x10;
my $ZMASK = 0x40;
my $SMASK = 0x80;

my $t = new TEST;
$t->flag("C", 1);
$t->print;
$t->calculate_sub_flags(hex($ARGV[0]), hex($ARGV[1]), 16);
$t->print;

sub
print
{
	my $self = shift;

	foreach ("C","H","PV","N","Z","S") {
		my $f = $_;
		my $v = $self->flag($f);

		print "$f: $v\n";
	}
	print "\n";
}

sub
new
{
	my $class = shift;

	my $self = {F => 0x0};
	return bless $self, $class;
}

sub
calculate_add_flags
{
    my ($self, $a, $b, $WIDTH) = @_;
    my $res;
    my $carry = 0;

    my $MASK = 0;
    for (1 .. $WIDTH) {
        $MASK = ($MASK << 1) | 0x1;
    }

	#print sprintf("MASK: %04x\n", $MASK);

    if (($self->{F} & $CMASK)) {
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

	my $ret;
	my $mask;

	if ($arg eq "C") {
		$mask = $CMASK;
	}
	if ($arg eq "H") {
		$mask = $HMASK;
	}
	if ($arg eq "PV") {
		$mask = $PVMASK;
	}
	if ($arg eq "N") {
		$mask = $NMASK;
	}
	if ($arg eq "Z") {
		$mask = $ZMASK;
	}
	if ($arg eq "S") {
		$mask = $SMASK;
	}

	$ret = ($self->{F} & $mask) != 0 ? 1 : 0;

	if (defined $val) {
		if ($val == 1) {
			$self->{F} |= $mask;
		} else {
			$self->{F} &= ((~$mask) & 0xFF);
		}
	}

	return $ret;
}

sub
calculate_sub_flags
{
    my ($self, $a, $b, $WIDTH) = @_;

	exit unless defined $b;

    my $MASK = 0;
    for (1 .. $WIDTH) {
        $MASK = ($MASK << 1) | 0x1;
    }

	print "MASK $MASK\n";

	
	if (!looks_like_number($b)) {
		$self->show_mem();
		print "$b is not a number!!\n";
		exit;
	}
	if (!looks_like_number(~(0+$b))) {
		$self->show_mem();
		my $str = sprintf("%04x", ~(0+$b));
		print "$str is not a number ($b)!!\n";
		exit;
	}

    	$self->{F} = ($self->{F} ^ $CMASK) & 0xFF;
    	$self->calculate_add_flags($a, ~(0+$b) & $MASK, $WIDTH);
    	$self->{F} = ($self->{F} ^ $CMASK) & 0xFF;

	my $res = $a - $b - $self->flag("C");
	print sprintf("%04x\n", $res & $MASK);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	if ($res < 0) {
		$self->flag("S", 1);
	} else {
		$self->flag("S", 0);
	}

	$self->flag("N", 1);
}

sub
looks_like_number
{
	return 1;
}
