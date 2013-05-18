#!/usr/bin/perl -w

package Z80;

use strict;
use OpcodeLogger;
use Time::HiRes qw(tv_interval gettimeofday usleep);
use Scalar::Util qw(looks_like_number);

my %Z80 = (

	A => 0x0, F => 0x0,
	Ap => 0x0, Fp => 0x0,

	B => 0xFF, C => 0xFF,
	D => 0xFF, E => 0xFF,
	H => 0xFF, L => 0xFF,

	Bp => 0x0, Cp => 0x0,
	Dp => 0x0, Ep => 0x0,
	Hp => 0x0, Lp => 0x0,

	S => 0xFF, P => 0xFF,

	IX => 0xFFFF, IY => 0xFFFF,

	R => 0x0,
	I => 0x0,
	PC => 0x0,

	IFF1 => 0x0, IFF2 => 0x0,

	ADDRESS_BUS => 0xFFFF,
	DATA_BUS => 0xFF,
	I_MODE => 0,

	OPBANK => 0x0,
	tickfn => undef,
	tick_count => 0x0,

	INT => undef,
	HALT => undef,

	OP => undef,

);

my $SMASK =  0x80;
my $ZMASK =  0x40;
my $NMASK =  0x10;
my $PVMASK = 0x04;
my $HMASK =  0x02;
my $CMASK =  0x01;

my %FLAGS = (
	S => {MASK => $SMASK, BIT => 7},
	Z => {MASK => $ZMASK, BIT => 6},
	N => {MASK => $NMASK, BIT => 4},
	PV => {MASK => $PVMASK, BIT => 2},
	H => {MASK => $HMASK, BIT => 1},
	C => {MASK => $CMASK, BIT => 0},
);


my %REGPAIR = (
		0x0 => ["B", "C"], 
		0x1 => ["D", "E"], 
		0x2 => ["H", "L"], 
		0x3 => ["P", "S"], 
);

my %REGPAIR2 = (
		0x0 => ["B", "C"], 
		0x1 => ["D", "E"], 
		0x2 => ["H", "L"], 
		0x3 => ["A", "F"], 
);

my %REG = (
	0x7 => "A", #111
	0x0 => "B", #000
	0x1 => "C", #001
	0x2 => "D", #010
	0x3 => "E", #011
	0x4 => "H", #100
	0x5 => "L", #101
);

my $CB = 0x1;
my $FD = 0x2;
my $DD = 0x4;
my $ED = 0x8;

my $FDCB_OFFSET = undef;

my %DD_OP = (
	0xE1 => [\&POP_IX, "POP IX"],
	0xE9 => [\&JP_IX, "JP (IX)"],
);

my %ED_OP = (
	0x42 => [\&SBC_HL_SS, "SBC HL, BC"],
	0x43 => [\&LD_NN_DD, "LD (nn), BC"],
	0x47 => [\&LD_I_A, "LD I, A"],
	0x4A => [\&ADC_HL_SS, "ADC HL, BC"],
	0x4B => [\&LD_DD_pNNp, "LD BC, (nn)"],
	0x4F => [\&LD_R_A, "LD R, A"],
	0x52 => [\&SBC_HL_SS, "SBC HL, DE"],
	0x53 => [\&LD_NN_DD, "LD (nn), DE"],
	0x56 => [\&IM_1, "IM 1"],
	0x5B => [\&LD_DD_pNNp, "LD DE, (nn)"],
	0x5F => [\&LD_A_R, "LD A,R"],
	#0x3B => [\&SRL_m,"SRL E"],
	0x72 => [\&SBC_HL_SS, "SBC HL, SP"],
	0x78 => [\&IN_r_C, "IN A, (C)"],
	0x7B => [\&LD_DD_pNNp, "LD BC, (nn)"],
	0xB0 => [\&LDIR, "LDIR"],
	0xB1 => [\&CPIR, "CPIR"],
	0xB8 => [\&LDDR, "LDDR"],
);

my %FDCB_OP = (
	0x46 => [\&BIT_B_IYd, "BIT 0, (IY+d)"],
	0x4E => [\&BIT_B_IYd, "BIT 1, (IY+d)"],
	0x56 => [\&BIT_B_IYd, "BIT 2, (IY+d)"],
	0x6E => [\&BIT_B_IYd, "BIT 5, (IY+d)"],
	0x76 => [\&BIT_B_IYd, "BIT 6, (IY+d)"],
	0x7E => [\&BIT_B_IYd, "BIT 7, (IY+d)"],
	0x86 => [\&RES_B_IYd, "RES 0, (IY+d)"],
	0x8E => [\&RES_B_IYd, "RES 1, (IY+d)"],
	0x96 => [\&RES_B_IYd, "RES 2, (IY+d)"],
	0xAE => [\&RES_B_IYd, "RES 5, (IY+d)"],
	0xC6 => [\&SET_B_IYd, "SET 0, (IY+d)"],
	0xD6 => [\&SET_B_IYd, "SET 2, (IY+d)"],
	0xF6 => [\&SET_B_IYd, "SET 6, (IY+d)"],
	0xFE => [\&SET_B_IYd, "SET 7, (IY+d)"],
);

my %CB_OP = (
	0x00 => [\&RLC_r, "RLC B"],
	0x10 => [\&RL_r, "RL B"],
	0x12 => [\&RL_r, "RL D"],
	0x13 => [\&RL_r, "RL E"],
	0x14 => [\&RL_r, "RL H"],
	0x16 => [\&RL_HL, "RL (HL)"],
	0x19 => [\&RR_r, "RR C"],
	0x1A => [\&RR_r, "RR D"],
	0x21 => [\&SLA_m, "SLA C"],
	0x28 => [\&SRA_m, "SRA B"],
	0x2D => [\&SRA_m, "SRA L"],
	0x38 => [\&SRL_m,"SRL B"],
	0x3B => [\&SRL_m,"SRL E"],
	0x46 => [\&BIT_HL, "BIT 0, (HL)"],
	0x6E => [\&BIT_HL, "BIT 5, (HL)"],
	0x77 => [\&BIT_b_r, "BIT 6, A"],
	0x78 => [\&BIT_b_r, "BIT 7, B"],
	0x79 => [\&BIT_b_r, "BIT 7, C"],
	0x7A => [\&BIT_b_r, "BIT 7, D"],
	0x7B => [\&BIT_b_r, "BIT 7, E"],
	0x7E => [\&BIT_HL, "BIT 7, (HL)"],
	0x7F => [\&BIT_b_r, "BIT 7, A"],
	0x86 => [\&RES_b_pHLp,"RES b,(HL)"],
	0xB6 => [\&RES_b_pHLp,"RES b,(HL)"],
	0xC6 => [\&SET_b_pHLp,"SET 0,(HL)"],
	0xD9 => [\&SET_b_r,"SET b,C"],
	0xF6 => [\&SET_b_pHLp,"SET 6,(HL)"],
	0xFC => [\&SET_b_r,"SET 7,H"],
	0xFE => [\&SET_b_pHLp,"SET b,(HL)"],
	0xFF => [\&SET_b_r,"SET 7,A"],
);

my %FD_OP = (
	0x21 => [\&LD_IY_NN, "LD IY, NN"],
	0x35 => [\&DEC_IYd, "DEC (IY+d)"],
	0x36 => [\&LD_IYd_N, "LD (IY+d), N"],
	0x73 => [\&LD_IYd_R, "LD (IY+d), E"],
	0x75 => [\&LD_IYd_R, "LD (IY+d), L"],
	0x77 => [\&LD_IYd_R, "LD (IY+d), A"],
	0x46 => [\&LD_r_IYd, "LD B, (IY + d)"],
	0x4E => [\&LD_r_IYd, "LD C, (IY + d)"],
	0xAE => [\&XOR_IYd,"XOR (IY +d)"],
	0xBE => [\&CP_IYd, "CP (IY + d)"],
	0xCB => [\&FDCB, "**** FDCB ****"],
);

my %OP = (
	0x00 => [\&NOP,"NOP"],
	0x01 => ["LD_DD_NN","LD BC, nn"],
	0x02 => [\&LD_BC_A,"LD (BC), A"],
	0x03 => [\&INC_SS,"INC BC"],
	0x04 => [\&INC_R,"INC B"],
	0x05 => [\&DEC8,"DEC B"],
	0x06 => [\&LD_R_N,"LD B, n"],
	0x07 => [\&RLCA,"RLCA"],
	0x08 => [\&EX_AF_AFp,"EX AF, AF'"],
	0x09 => [\&ADD_HL_SS,"ADD HL,BC"],
	0x0A => [\&LD_A_BC,"LD A,(BC)"],
	0x0B => [\&DEC16,"DEC BC"],
	0x0C => [\&INC_R,"INC C"],
	0x0D => [\&DEC8,"DEC C"],
	0x0F => [\&RRCA,"RRCA"],
	0x0E => [\&LD_R_N,"LD C,n"],
	0x10 => [\&DJNZ_E,"DJNZ, e"],
	0x11 => ["LD_DD_NN","LD DE, nn"],
	0x12 => [\&LD12,"LD (DE), A"],
	0x13 => [\&INC_SS,"INC DE"],
	0x15 => [\&DEC8,"DEC D"],
	0x16 => [\&LD_R_N,"LD D, n"],
	0x17 => [\&RLA,"RLA"],
	0x18 => [\&JR_E,"JR e"],
	0x19 => [\&ADD_HL_SS,"ADD HL,DE"],
	0x1A => [\&LD_A_DE,"LD A,(DE)"],
	0x1C => [\&INC_R,"INC E"],
	0x1E => [\&LD_R_N,"LD E,n"],
	0x1F => [\&RRA,"RRA"],
	0x20 => [\&JR_NZ_E,"JR NZ, (nn)"],
	0x21 => ["LD_DD_NN","LD HL, nn"],
	0x22 => [\&LD_NN_HL,"LD (nn), HL"],
	0x23 => [\&INC_SS,"INC HL"],
	0x25 => [\&DEC8,"DEC H"],
	0x26 => [\&LD_R_N,"LD H,n"],
	0x28 => [\&JR_Z_E,"JR Z,e"],
	0x29 => [\&ADD_HL_SS,"ADD HL,HL"],
	0x2A => [\&LD_HL_NN,"LD HL, (nn)"],
	0x2B => [\&DEC16,"DEC HL"],
	0x2C => [\&INC_R,"INC L"],
	0x2D => [\&DEC8,"DEC L"],
	0x2E => [\&LD_R_N,"LD L,n"],
	0x2F => [\&CPL,"CPL"],
	0x30 => [\&JR_NC_E,"JR NC E"],
	0x32 => [\&LD_NN_A,"LD (nn), A"],
	0x34 => [\&INC_pHLp,"INC (HL)"],
	0x35 => [\&DEC_pHLp,"DEC (HL)"],
	0x36 => [\&LD36,"LD (HL), N"],
	0x37 => [\&SCF,"SCF"],
	0x38 => [\&JR_C_E,"JR C,e"],
	0x3A => [\&LD_A_pNNp,"LD A,(nn)"],
	0x3B => [\&DEC16,"DEC SP"],
	0x3C => [\&INC_R,"INC A"],
	0x3D => [\&DEC8,"DEC A"],
	0x3E => [\&LD_R_N,"LD A, n"],
	0x3F => [\&CCF,"CCF"],
	0x40 => [\&LD_R_RP,"LD B,B"],
	0x41 => [\&LD_R_RP,"LD B,C"],
	0x42 => [\&LD_R_RP,"LD B,D"],
	0x44 => [\&LD_R_RP,"LD B,H"],
	0x46 => [\&LD_R_HL,"LD, B,(HL)"],
	0x47 => [\&LD_R_RP,"LD B,A"],
	0x48 => [\&LD_R_RP,"LD C,B"],
	0x4D => [\&LD_R_RP,"LD C,L"],
	0x4E => [\&LD_R_HL,"LD, C,(HL)"],
	0x4F => [\&LD_R_RP,"LD C,A"],
	0x51 => [\&LD_R_RP,"LD D,C"],
	0x54 => [\&LD_R_RP,"LD D,H"],
	0x55 => [\&LD_R_RP,"LD D,L"],
	0x56 => [\&LD_R_HL,"LD, D,(HL)"],
	0x57 => [\&LD_R_RP,"LD D,A"],
	0x58 => [\&LD_R_RP,"LD E,B"],
	0x5D => [\&LD_R_RP,"LD E,L"],
	0x5E => [\&LD_R_HL,"LD, E,(HL)"],
	0x5F => [\&LD_R_RP,"LD E,A"],
	0x60 => [\&LD_R_RP,"LD H,B"],
	0x61 => [\&LD_R_RP,"LD H,C"],
	0x62 => [\&LD_R_RP,"LD H,D"],
	0x67 => [\&LD_R_RP,"LD, H,A"],
	0x68 => [\&LD_R_RP,"LD, L,B"],
	0x69 => [\&LD_R_RP,"LD, L,C"],
	0x6B => [\&LD_R_RP,"LD, L,E"],
	0x6E => [\&LD_R_HL,"LD, L,(HL)"],
	0x6F => [\&LD_R_RP, "LD, L,A"],
	0x70 => [\&LD_pHLp_R, "LD, (HL),B"],
	0x71 => [\&LD_pHLp_R, "LD, (HL),C"],
	0x72 => [\&LD_pHLp_R, "LD, (HL),D"],
	0x73 => [\&LD_pHLp_R, "LD, (HL),E"],
	0x76 => [\&HALT, "HALT"],
	0x77 => [\&LD_pHLp_R,"LD, (HL),A"],
	0x78 => [\&LD_R_RP,"LD, A,B"],
	0x79 => [\&LD_R_RP,"LD, A,C"],
	0x7A => [\&LD_R_RP,"LD, A,D"],
	0x7B => [\&LD_R_RP,"LD, A,E"],
	0x7C => [\&LD_R_RP,"LD, A,H"],
	0x7D => [\&LD_R_RP,"LD, A,L"],
	0x7E => [\&LD_R_HL,"LD, A,(HL)"],
	0x80 => [\&ADD_A_r,"ADD A,B"],
	0x81 => [\&ADD_A_r,"ADD A,C"],
	0x82 => [\&ADD_A_r,"ADD A,D"],
	0x83 => [\&ADD_A_r,"ADD A,E"],
	0x84 => [\&ADD_A_r,"ADD A,H"],
	0x85 => [\&ADD_A_r,"ADD A,L"],
	0x86 => [\&ADD_A_HL,"ADD A,(HL)"],
	0x87 => [\&ADD_A_r,"ADD A,A"],
	0x8D => [\&ADC_A_r,"ADC A,L"],
	0x90 => [\&SUB_S,"SUB A,B"],
	0x91 => [\&SUB_S,"SUB A,C"],
	0x95 => [\&SUB_S,"SUB A,L"],
	0x9F => [\&SBC_A_r,"SBC A,r"],
	0xA0 => [\&AND_S,"AND B"],
	0xA2 => [\&AND_S,"AND D"],
	0xA4 => [\&AND_S,"AND H"],
	0xA5 => [\&AND_S,"AND L"],
	0xA6 => [\&AND_HL,"AND (HL)"],
	0xA7 => [\&AND_S,"AND A"],
	0xAD => [\&XOR_S,"XOR L"],
	0xAE => [\&XOR_HL,"XOR_HL"],
	0xAF => [\&XOR_S,"XOR A"],
	0xB0 => [\&OR_S,"OR B"],
	0xB1 => [\&OR_S,"OR C"],
	0xB4 => [\&OR_S,"OR H"],
	0xB5 => [\&OR_S,"OR L"],
	0xB6 => [\&OR_pHLp,"OR (HL)"],
	0xB8 => [\&CP_S,"CP B"],
	0xBA => [\&CP_S,"CP D"],
	0xBC => [\&CP_S,"CP H"],
	0xBE => [\&CP_HL,"CP (HL)"],
	0xBF => [\&CP_S,"CP A"],
	0xC0 => [\&RET_CC,"RET NZ"],
	0xC1 => [\&POP_QQ,"POP BC"],
	0xC2 => [\&JP_CC,"JP NZ, CC"],
	0xC3 => [\&JP,"JP (nn)"],
	0xC4 => [\&CALL_CC,"CALL NZ, CC"],
	0xC5 => [\&PUSH_QQ,"PUSH BC"],
	0xC6 => [\&ADD_A_n,"ADD A,n"],
	0xC8 => [\&RET_CC,"RET Z"],
	0xC9 => [\&RET,"RET"],
	0xCA => [\&JP_CC,"JP Z, CC"],
	0xCB => [\&CB,"**** CB ****"],
	0xCC => [\&CALL_CC,"CALL Z, CC"],
	0xCD => [\&CALL_NN,"CALL (nn)"],
	0xCE => [\&ADC_A_n,"ADC A,n"],
	0xCF => [\&RST,"RST 0x0008"],
	0xD0 => [\&RET_CC,"RET NC"],
	0xD1 => [\&POP_QQ,"POP DE"],
	0xD3 => ["OUT","OUT (n), A"],
	0xD5 => [\&PUSH_QQ,"PUSH DE"],
	0xDD => [\&DD,"**** DD ****"],
	0xD6 => [\&SUB_N,"SUB n"],
	0xD7 => [\&RST,"RST 0x0010"],
	0xD8 => [\&RET_CC,"RET C"],
	0xD9 => [\&EXX,"EXX"],
	0xDA => [\&JP_CC,"JP C, CC"],
	0xDF => [\&RST,"RST 0x0018"],
	0xE0 => [\&RET_CC,"RET PO"],
	0xE1 => [\&POP_QQ,"POP HL"],
	0xE3 => [\&EX_SP_HL,"EX (SP), HL"],
	0xE5 => [\&PUSH_QQ,"PUSH HL"],
	0xE6 => [\&AND_n,"AND n"],
	0xE7 => [\&RST,"RST 0x0020"],
	0xE9 => [\&JP_HL,"JP (HL)"],
	0xEA => [\&JP_CC,"JP PE, CC"],
	0xEB => [\&EX_DE_HL,"EX DE,HL"],
	0xED => [\&ED,"**** ED ****"],
	0xEF => [\&RST,"RST 0x0028"],
	0xF1 => [\&POP_QQ,"POP AF"],
	0xF2 => [\&JP_CC,"JP P, CC"],
	0xF5 => [\&PUSH_QQ,"PUSH AF"],
	0xF6 => [\&OR_n,"OR n"],
	0xF9 => [\&LD_SP_HL,"LD SP, HL"],
	0xFA => [\&JP_CC,"JP M, CC"],
	0xFB => [\&EI,"EI"],
	0xFC => [\&CALL_CC,"CALL M, CC"],
	0xFD => [\&FD,"**** FD ****"],
	0xFE => [\&CP_N,"CP n"],
	0xFF => [\&RST,"RST 0x0038"],
);

sub 
REGPAIR
{
	my $self = shift;
	my $code = shift;

	my $pair = $REGPAIR{$code};

	return [\$self->{$pair->[0]}, \$self->{$pair->[1]}];
}

sub 
REGPAIR2
{
	my $self = shift;
	my $code = shift;

	my $pair = $REGPAIR2{$code};
	return [\$self->{$pair->[0]}, \$self->{$pair->[1]}];
}


sub
REG
{
	my $self = shift;
	my $code = shift;

	my $reg = $REG{$code};
	return \$self->{$reg};
}

sub
FLAG_FN
{
	my ($self, $code) = @_;

	my %fn = (
		0x0 => sub {$self->flag("Z") == 0}, 
		0x1 => sub {$self->flag("Z") != 0}, 
		0x2 => sub {$self->flag("C") == 0}, 
		0x3 => sub {$self->flag("C") != 0}, 
		0x4 => sub {$self->flag("PV") == 0}, 
		0x5 => sub {$self->flag("PV") != 0}, 
		0x6 => sub {$self->flag("S") == 0}, 
		0x7 => sub {$self->flag("S") != 0}, 
	);

	return $fn{$code}->();
}

sub 
new {

	my $class = shift; 
	my $fn = shift;

	my $self = {%Z80};

	$self->{tickfn} = $fn;

	bless $self, $class;

	return $self;
}

sub 
run {

	my $self = shift;


	$self->{OP} = new OpcodeLogger($self);

	my $handled = $self->handle_interrupt();
	if (!defined $handled) {
		my $opcode = $self->opcode_fetch();
		$self->{OP}->code($opcode);
		$self->execute($opcode);
	}

	if (1 || ($self->{PC} >= 0x02BB && $self->{PC} < 0x02e7))  {
		my $op = $self->{OP}->to_string($self->{tick_count}, $self->{R});
		print "$op\n";
		$self->show_mem();
	}

	$self->int_delay();
}


sub
sample_nmi
{
	my $self = shift;

	return undef unless (defined $self->{NMI} && $self->{NMI} == 1);

	$self->{IFF1} = 0;
	$self->{IFF2} = 0;
	$self->{NMI} = undef;
	$self->{INT} = undef;
	$self->{HALT} = undef;

	print "Execute NMI (ignoring)\n";
	return undef;

	return 0x66;
}

sub
sample_int
{
	my $self = shift;

	return undef if defined $self->{INT_DELAY};

	return undef unless (defined $self->{INT} && $self->{INT} == 1);

	print "Execute Maskable Interrupt!!!\n";

	$self->{IFF1} = 0;
	$self->{IFF2} = 0;
	$self->{INT} = undef;
	$self->{HALT} = undef;

	return 0x38;
}

sub
NMI
{
	my $self = shift;
	print "Calling NMI!!!\n";
	$self->{NMI} = 1;
}

sub
INT
{
	my $self = shift;

	print "Maskable Interrupt Called\n";

	#return if defined $self->{INT_DELAY};
	return unless ($self->{IFF1} == 1);

	print "Maskable Interrupts Enabled\n";
	$self->{INT} = 1;
}

sub
PC_INC
{
	my $self = shift;
	my $ret = $self->{PC}++;

	return $ret;			
}

sub
handle_interrupt
{
	my $self = shift;

	my $nmi = $self->sample_nmi();

	if (defined $nmi) {

		$self->{ADDRESS_BUS} = $self->{PC};
		$self->{M1} = 1;
		$self->tick(2);

		$self->{WAIT} = 1;
		$self->{IORQ} = 1; 
		$self->tick(2);

		$self->memory_refresh();
		$self->{ADDRESS_BUS} = ($self->{I} << 8) | $self->{R};
		$self->{RFSH} = 1;
		$self->{IORQ} = undef; 
		$self->{MREQ} = undef;
		$self->tick(1);

		$self->{MREQ} = 1;
		$self->tick(1);

		$self->{OP}->code(0xFFFF);
		$self->{OP}->mnemonic("NMI");

		$self->RST(0x0, undef, 0x66);
		return 1;
	}

	my $int = $self->sample_int();

	if (defined $int) {

		$self->{ADDRESS_BUS} = $self->{PC};
		$self->{MREQ} = undef;
		$self->{IORQ} = undef;
		$self->{M1} = 1;
		$self->tick(2);
		#$self->tick(1);

		$self->{WAIT} = 1;
		$self->{IORQ} = 1; 
		$self->tick(2);
		#$self->tick(1);

		$self->memory_refresh();
		$self->{ADDRESS_BUS} = ($self->{I} << 8) | $self->{R};
		$self->{WAIT} = undef;
		$self->{RFSH} = 1;
		$self->{MREQ} = undef;
		$self->tick(1);

		$self->{IORQ} = undef; 
		$self->{MREQ} = 1;
		$self->tick(1);

		$self->{M1} = undef;
		$self->{MREQ} = undef;
		$self->{IORQ} = undef;
		$self->{WAIT} = undef;
		$self->{RFSH} = undef;

		$self->{OP}->code(0xFF);

		$self->tick(4);
		$self->execute(0xFF);

		return 1;
	} 

	return undef;	
}

sub
opcode_fetch
{
	my $self = shift;

	my $pc = $self->{PC};
	if (!defined $self->{HALT}) {
		$pc = $self->PC_INC;
	} 

	$self->{ADDRESS_BUS} = $pc; 
	$self->{M1} = 1;
	$self->tick(1);
	$self->{MREQ} = 1;
	$self->{RD} = 1;
	$self->{RFSH} = undef;
	$self->tick(1);

	$self->{MREQ} = undef;
	$self->{RD} = undef;
	$self->{M1} = undef;

	my $data = $self->{DATA_BUS};
	$self->memory_refresh();
	$self->{ADDRESS_BUS} = ($self->{I} << 8) | $self->{R};
	$self->{RFSH} = 1;
	$self->tick(1);

	$self->{MREQ} = 1;
	$self->tick(1);

	$self->{RFSH} = undef;
	$self->{MREQ} = undef;

	if (defined $self->{HALT}) {
		return 0x0;
	}

	return $data;
}

sub
ADDRESS_BUS
{
	my $self = shift;

	return $self->{ADDRESS_BUS};
}

sub
DATA_BUS
{
	my $self = shift;

	if (@_) {
		$self->{DATA_BUS} = shift;
	}

	return $self->{DATA_BUS};
}


sub
dec_R
{
	my $self = shift;

	my $tmp = $self->{R} & 0x7F;				
	my $hi_bit = ($self->{R} >> 7) & 0x1;
	$tmp = ($tmp - 1) & 0x7F;
	$self->{R} = $tmp | ($hi_bit << 7);
}

sub
memory_refresh
{
	my $self = shift;

	my $tmp = $self->{R} & 0x7F;				
	my $hi_bit = ($self->{R} >> 7) & 0x1;
	$tmp = ($tmp + 1) & 0x7F;
	$self->{R} = $tmp | ($hi_bit << 7);
}

sub
execute
{
	my $self = shift;
	my $opcode = shift;

	my $opflags = $self->{OPBANK};
	$self->{OPBANK} = 0;

	my $o;

	if ($CB & $opflags) {

		if ($FD & $opflags) {
			$o = \%FDCB_OP;
		} else {
			$o = \%CB_OP;
		}
	} elsif ($ED & $opflags) {
			$o = \%ED_OP;
	} elsif ($FD & $opflags) {
			$o = \%FD_OP;
	} elsif ($DD & $opflags) {
			$o = \%DD_OP;
	} else {
		$o = \%OP;
	}

	if (!defined(${$o}{$opcode})) {
		print "ZZZZZZZZ\n";
		$o = \%OP;
	}

	my $fn = $o->{$opcode}[0];

	if (!defined(&{$fn})) {
		$self->{tickfn}->("DUMP_RAM");
		print "BBBBBBBB " . sprintf("%02x", $opcode) . "\n";
		$self->show_mem();
	}

	$self->{OP}->mnemonic($o->{$opcode}[1]);

	$self->$fn($opcode, $opflags);
}

sub
int_delay
{
	my $self = shift;
	return unless defined $self->{INT_DELAY};

	$self->{INT_DELAY}--;

	if ($self->{INT_DELAY} == 0) {
		$self->{INT_DELAY} = undef;
	}
}

sub
next_pc
{
	my $self = shift;
	return $self->mem_read($self->PC_INC);
}

sub
mem_read
{
	my $self = shift;
	my $addr = shift;

	$self->{ADDRESS_BUS} = $addr;
	$self->tick(1);
	$self->{MREQ} = 1;
	$self->tick(1);
	$self->{RD} = 1;
	$self->tick(1);

	$self->{MREQ} = undef;
	$self->{RD} = undef;

	return $self->DATA_BUS();
}

sub
mem_write
{
	my $self = shift;
	my $addr = shift;
	my $value = shift;

	$self->{MREQ} = 1;
	$self->{ADDRESS_BUS} = $addr;
	$self->{DATA_BUS} = $value;

	$self->tick(2);

	$self->{WR} = 1;
	$self->tick(1);
	
	$self->{MREQ} = undef;
	$self->{WR} = undef;
}

sub
io_read
{
	my $self = shift;
	my $addr = shift;

	$self->{ADDRESS_BUS} = $addr;
	$self->tick(1);

	$self->{IORQ} = 1;
	$self->{RD} = 1;
	$self->tick(1);

	$self->{WAIT} = 1;
	$self->tick(1);

	$self->{IORQ} = undef;
	$self->{WR} = undef;
	$self->{WAIT} = undef;
	my $ret =  $self->{DATA_BUS};
	$self->tick(1);

	return $ret;
}

sub
io_write
{
	my $self = shift;
	my $addr = shift;
	my $data = shift;

	$self->{ADDRESS_BUS} = $addr;
	$self->{DATA_BUS} = $data;
	$self->tick(3);
	$self->{IORQ} = 1;
	$self->{WR} = 1;
	$self->tick(1);
	
	$self->{IORQ} = undef;
	$self->{WR} = undef;
}

sub
tick
{
	my $self = shift;
	my $count = shift;

	while ($count--) {
		$self->{tickfn}->();
		$self->{tick_count}++;
		#usleep(1000 * 1000);
	}
}

sub
get_value
{
	my ($l, $h) = @_;

	if (!defined $h) {
	    die "get_value h not defined\n";
	}

	$l &= 0xff;
	$h &= 0xff;

	return ($h << 8) | $l;
}

sub
set_value
{
	my ($lref, $href, $val) = @_;

	${$href} = ($val >> 8) & 0xFF;
	${$lref} = $val & 0xFF;
}

sub
complement
{
	my $in = shift;
	return (~$in) & 0xFF;
}

sub
swap_pair
{
	my ($self, $m1, $m2) = @_;

	my $p1 = "${m1}p";
	my $p2 = "${m2}p";

	my $t1 = "$self->{$m1}";
	my $t2 = "$self->{$m2}";

	$self->{$m1} = "$self->{$p1}";
	$self->{$m2} = "$self->{$p2}";

	$self->{$p1} = $t1;
	$self->{$p2} = $t2;
}

sub
calculate_parity
{
	my ($val, $size) = @_;

	my $ret = 0x1;
	for (0 .. $size - 1) {
	    if ((($val >> $_) & 0x1) == 1)   {
	        $ret = (~$ret) & 0x1;
	    }
	}

	return $ret;
}

sub
flag
{
	my $self = shift;
	my $flag = shift;

	if (@_) {
		my $bit = shift;
		if ($bit == 0) {
			$self->{F} &= complement($FLAGS{$flag}->{MASK});
		} else {
			$self->{F} |= $FLAGS{$flag}->{MASK};
		}
	}

	return ($self->{F} >> $FLAGS{$flag}->{BIT}) & 0x1;
}

sub
show_mem
{
	my $self = shift;
	my $pc = sprintf "%04x", $self->{PC};
	
	print "A : " . sprintf("%02x", $self->{A}) . " ";
	print "F : " . sprintf("%02x", $self->{F}) . " ";
	print "B : " . sprintf("%02x", $self->{B}) . " ";
	print "C : " . sprintf("%02x", $self->{C}) . " ";
	print "D : " . sprintf("%02x", $self->{D}) . " ";
	print "E : " . sprintf("%02x", $self->{E}) . " ";
	print "H : " . sprintf("%02x", $self->{H}) . " ";
	print "L : " . sprintf("%02x", $self->{L}) . " ";
	print "S: " . sprintf("%02x", $self->{S}) . " ";
	print "P: " . sprintf("%02x", $self->{P}) . " ";
	print "PC: " . sprintf("%04x", $self->{PC}) . "\n";

	print "Ap: " . sprintf("%02x", $self->{Ap}) . " ";
	print "Fp: " . sprintf("%02x", $self->{Fp}) . " ";
	print "Bp: " . sprintf("%02x", $self->{Bp}) . " ";
	print "Cp: " . sprintf("%02x", $self->{Cp}) . " ";
	print "Dp: " . sprintf("%02x", $self->{Dp}) . " ";
	print "Ep: " . sprintf("%02x", $self->{Ep}) . " ";
	print "Hp: " . sprintf("%02x", $self->{Hp}) . " ";
	print "Lp: " . sprintf("%02x", $self->{Lp}) . "\n";

	print "I: " . sprintf("%02x", $self->{I}) . " ";
	print "R: " . sprintf("%02x", $self->{R}) . " ";
	print "IX: " . sprintf("%04x", $self->{IX}) . " ";
	print "IY: " . sprintf("%04x", $self->{IY}) . "\n";

	print "(S: " . $self->flag('S') . " ";
	print "Z: " . $self->flag('Z') . " ";
	print "H: " . $self->flag('H') . " ";
	print "PV: " . $self->flag('PV') . " ";
	print "N: " . $self->flag('N') . " ";
	print "C: " . $self->flag('C') . " ";
	print "IFF1: " . $self->{IFF1} . " "; 
	print "IFF2: " . $self->{IFF2} . ")\n";
}

sub
calculate_sub_flags_1
{
	my ($self, $a, $b, $use_carry, $WIDTH) = @_;

	my $c = 0;		
	$c = 1 if $use_carry;

	my $MASK = 0;
	for (1 .. $WIDTH) {
	    $MASK = ($MASK << 1) | 0x1;
	}

	my $ret = ($a - $b - $c) & $MASK; 

	$self->flag("C", ($ret >> ($WIDTH - 1)) & $MASK);
	$self->flag("Z", $ret == 0);
	$self->flag("PV", ($ret > ($MASK >> 1)) || ($ret < (~($MASK >> 1) & $MASK)));
	$self->flag("S", ($ret > ($MASK >> 1)) && ($ret < $MASK));
	$self->flag("N", 1); 
	$self->flag("H", 0); ## to do
}


sub
calculate_add_flags_1
{
	my ($self, $a, $b, $use_carry, $WIDTH) = @_;

	my $c = 0;		
	$c = 1 if $use_carry;

	my $MASK = 0;
	for (1 .. $WIDTH) {
	    $MASK = ($MASK << 1) | 0x1;
	}

	my $ret = ($a + $b + $c) & $MASK; 

	$self->flag("C", $ret > $MASK);
	$self->flag("Z", $ret == 0);
	$self->flag("PV", ($ret > ($MASK >> 1)) || $ret < ((~($MASK >> 1))& $MASK));

	$self->flag("S", ($ret > ($MASK >> 1)) && ($ret < ($MASK + 1)));
	$self->flag("N", 0); 
	$self->flag("H", 0); ## to do
}

sub
calculate_sub_flags
{
	my ($self, $a, $b, $WIDTH) = @_;

	die "calculate_sub_flags b not defined\n" unless defined $b;

	my $MASK = 0;
	for (1 .. $WIDTH) {
	    $MASK = ($MASK << 1) | 0x1;
	}

	print "MASK $MASK\n";

	
	if (!looks_like_number($b)) {
		$self->show_mem();
		print "$b is not a number!!\n";
		die "calculate_sub_flags b not a number\n";
	}
	if (!looks_like_number(~(0+$b))) {
		$self->show_mem();
		my $str = sprintf("%04x", ~(0+$b));
		print "$str is not a number ($b)!!\n";
		die "$str is not a number ($b)!!\n";
	}

	my $res = ($a - $b - $self->flag("C")) & 0xFF;
		$self->{F} = ($self->{F} ^ $CMASK) & 0xFF;
		$self->calculate_add_flags($a, ~(0+$b) & $MASK, $WIDTH);
		$self->{F} = ($self->{F} ^ $CMASK) & 0xFF;

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("S", ($res >> ($WIDTH - 1)) & 0x1);

	$self->flag("N", 1);
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

	if ($self->{F} & $CMASK) {
	    $carry = 1 if ($a >= $MASK - $b);
	    $res = $a + $b + 1;
	} else {
	    $carry = 1 if ($a > $MASK - $b);
	    $res = $a + $b;
	}

	$res &= $MASK;

	my $oshift = $WIDTH - 1;
	my $hshift = $WIDTH - 4;

	my $carryIns = $res ^ $a ^ $b;
	$self->{F} = ($self->{F} & ~($CMASK | $PVMASK | $HMASK)) & $MASK;

	$self->{F} |= $PVMASK if ((($carryIns >> $oshift) ^ $carry) & 0x1);
	$self->{F} |= $HMASK if (($carryIns >> $hshift) & 0x1);
	$self->{F} |= $CMASK if ($carry);

	$self->flag("S", ($res >> ($WIDTH - 1)) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("N", 0);
}

sub
EXX
{
	my $self = shift;

	$self->swap_pair("B", "C");
	$self->swap_pair("D", "E");
	$self->swap_pair("H", "L");
}

sub
EX_AF_AFp
{
	my $self = shift;

	my $At = $self->{A};
	my $Ft = $self->{F};

	$self->{A} = $self->{Ap};
	$self->{F} = $self->{Fp};

	$self->{Ap} = $At;
	$self->{Fp} = $Ft;
}

sub
EX_SP_HL
{
	my $self = shift;	
	my $l_orig = $self->{L};
	my $h_orig = $self->{H};

	my $sp = get_value($self->{S}, $self->{P});

	$self->{L} = $self->mem_read($sp);
	$self->{H} = $self->mem_read($sp + 1);
	$self->tick(1);

	$self->mem_write($sp, $l_orig);
	$self->mem_write($sp + 1, $h_orig);
	$self->tick(2);
}

sub
EX_DE_HL
{
	my $self = shift;

	my $Dt = $self->{D};
	my $Et = $self->{E};

	$self->{D} = $self->{H};
	$self->{E} = $self->{L};

	$self->{H} = $Dt;
	$self->{L} = $Et;
}

sub
LD_R_RP
{
	my $self = shift;
	my $opcode = shift;

	my $r = ($opcode >> 3) & 0x7;
	my $rp = $opcode & 0x7;

	${$self->REG($r)} = ${$self->REG($rp)};
}


sub
LD_A_BC
{
	my $self = shift;

	my ($bc) = get_value($self->{C}, $self->{B});

	$self->{A} = $self->mem_read($bc);
}


sub
LD_A_DE
{
	my $self = shift;

	my ($de) = get_value($self->{E}, $self->{D});

	$self->{A} = $self->mem_read($de);
}

sub
LD_R_HL
{
	my $self = shift;
	my $opcode = shift;

	my $r = ($opcode >> 3) & 0x7;

	my ($hl) = get_value($self->{L}, $self->{H});

	${$self->REG($r)} = $self->mem_read($hl);
}

sub
LD_R_N
{
	my $self = shift;
	my $opcode = shift;

	my $dd = ($opcode >> 3) & 0x7;

	${$self->REG($dd)} = $self->next_pc();
 
}

sub
LD_A_R
{
	my $self = shift;

	$self->{A} = $self->{R};

	$self->flag("S", ($self->{R} >> 7) & 0x1);
	$self->flag("Z", $self->{R} == 0);
	$self->flag("H", 0);
	$self->flag("PV", $self->{IFF2});
	$self->flag("N", 0);

	$self->tick(1);
}

sub
LD_A_pNNp
{
	my $self = shift;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $nn = get_value($low, $high);

	$self->{A} = $self->mem_read($nn);
}

sub
LD_NN_A
{
	my $self = shift;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $nn = get_value($low, $high);
	$self->mem_write($nn, $self->{A});
}


sub
LD_I_A
{
	my $self = shift;
	$self->{I} = $self->{A};
	$self->tick(5);
}

sub
LD_R_A
{
	my $self = shift;
	$self->{R} = $self->{A};
	$self->tick(1);
}



sub
LD_DD_NN
{

	my $self = shift;
	my $opcode = shift;

	my $dd = ($opcode >> 4) & 0x3;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $regpair = $self->REGPAIR($dd);

	${$regpair->[0]} = $high;
	${$regpair->[1]} = $low;

}

sub
LD_pHLp_R
{
	my $self = shift;
	my $opcode = shift;

	my $r = $opcode & 0x7;
	my $hl = get_value($self->{L}, $self->{H});

	$self->mem_write($hl, ${$self->REG($r)});
}

sub
LD_DD_pNNp
{
	my $self = shift;
	my $opcode = shift;

	my $dd = ($opcode >> 4) & 0x3;

	my $low = $self->next_pc(); 
	my $high = $self->next_pc();

	my $nn = get_value($low, $high);

	my $regpair = $self->REGPAIR($dd);

	${$regpair->[1]} = $self->mem_read($nn);
	${$regpair->[0]} = $self->mem_read($nn + 1);
}

sub
LD_NN_DD
{
	my $self = shift;
	my $opcode = shift;

	my $dd = ($opcode >> 4) & 0x3;
	my $regpair = $self->REGPAIR($dd);

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $nn = get_value($low, $high);

	$self->mem_write($nn, ${$regpair->[1]});
	$self->mem_write($nn + 1, ${$regpair->[0]});
}

sub
LD_NN_HL
{
	my $self = shift;
	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $nn = get_value($low, $high);
	my $hl = get_value($self->{L}, $self->{H});

	$self->mem_write($nn, $self->{L});
	$self->mem_write($nn + 1, $self->{H});
}

sub
LD_HL_NN
{
	my $self = shift;
	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $nn = get_value($low, $high);

	print sprintf("YYYYY: LOW n: %02x HIGH n: %02x Value: %04x\n", $low, $high, $nn);

	$self->{L} = $self->mem_read($nn);
	$self->{H} = $self->mem_read($nn + 1);

	print sprintf("YYYYY: READ low: %02x from %04x\n", $self->{L}, $nn);
	print sprintf("YYYYY: READ high: %02x from %04x\n", $self->{H}, $nn + 1);

	my $val = get_value($self->{L}, $self->{H});
	print "YYYY LOW: " . $self->{L} . "\n";
	print "YYYY HIGH: " . $self->{H} . "\n";
	print "YYYY NN: " . $nn . "\n";
	print "YYYY VAL: " . $val . "\n";

	print sprintf("YYYYY: NN: %04x VAL: %04x\n", $nn, $val);

	die if ($nn == 0x4010 && $val == 0x0);
}

sub
LD_SP_HL
{
	my $self = shift;
	$self->{P} = $self->{H};
	$self->tick(1);
	$self->{S} = $self->{L};
	$self->tick(1);
}

sub
LD_IY_NN
{
	my $self = shift;
	my $low = $self->next_pc();
	my $high = $self->next_pc();

	$self->{IY} = get_value($low, $high);
}

sub
LD_IYd_N
{
	my $self = shift;

	my $offset = unpack('c', pack('C', $self->next_pc()));
	my $value = $self->next_pc();

	my ($loc) = $self->{IY} + $offset;
	$self->tick(2);
	$self->mem_write($loc, $value);
}

sub
LD_r_IYd
{
	my $self = shift;
	my $opcode = shift;

	my $r = ($opcode >> 3) & 0x7;

	my $offset = unpack('c', pack('C', $self->next_pc()));
	my ($loc) = $self->{IY} + $offset;
	$self->tick(5);

	${$self->REG($r)} = $self->mem_read($loc);
}

sub
LD_IYd_R
{
	my $self = shift;
	my $opcode = shift;
	my $r = $opcode & 0x7;

	my $offset = unpack('c', pack('C', $self->next_pc()));
	my ($loc) = $self->{IY} + $offset;

	$self->tick(2);
	$self->mem_write($loc, ${$self->REG($r)});
	$self->tick(3);
}

sub
LD12
{
	my $self = shift;
	my $addr = get_value($self->{E}, $self->{D});

	$self->mem_write($addr, $self->{A});
}

sub
LD36
{
	my $self = shift;
	my $addr = get_value($self->{L}, $self->{H});

	my $value = $self->next_pc();

	$self->mem_write($addr, $value);
}

sub
DEC8
{
	my $self = shift;
	my $opcode = shift;
	my $r = ($opcode >> 3) & 0x7;

	my $orig = ${$self->REG($r)};

	my $ret = (${$self->REG($r)} - 1) & 0xFF;
	$self->flag("C", 0);
	$self->calculate_sub_flags(${$self->REG($r)}, 1, 8);

	${$self->REG($r)} = $ret;

	$self->flag("PV", 0);
	if ($orig == 0x80) {
		$self->flag("PV", 1);
	}
}


sub
INC_pHLp
{
	my $self = shift;
	my ($hl) = get_value($self->{L}, $self->{H});

	my $val = $self->mem_read($hl);
	my $c = $self->flag("C");
	$self->flag("C", 0);
	$self->calculate_add_flags($val, 1, 8);
	$self->flag("C", $c);


	if ($val == 0x7f) {
		$self->flag("PV", 1);
	} else {
		$self->flag("PV", 0);
	}

	$val = ($val + 1) & 0xff;
	$self->mem_write($hl, $val);
}

sub
DEC_pHLp
{
	my $self = shift;
	my ($hl) = get_value($self->{L}, $self->{H});

	my $val = $self->mem_read($hl);
	my $c = $self->flag("C");
	$self->flag("C", 0);
	$self->calculate_sub_flags($val, 1, 8);
	$self->flag("C", $c);

	if ($val == 0x80) {
		$self->flag("PV", 1);
	} else {
		$self->flag("PV", 0);
	}

	$val = ($val - 1) & 0xff;
	$self->mem_write($hl, $val);
}

sub
DEC_IYd
{
	my $self = shift;
	my $offset = unpack('c', pack('C', $self->next_pc()));

	my $val = $self->mem_read($self->{IY} + $offset);
	$self->flag("C", 0);
	$self->calculate_sub_flags($val, 1, 8);
	$self->tick(2);

	if ($val == 0x80) {
		$self->flag("PV", 1);
	} else {
		$self->flag("PV", 0);
	}

	$val = ($val - 1) & 0xff;

	$self->tick(4);
	$self->mem_write($self->{IY} + $offset, $val);
}

sub
DEC16
{
	my $self = shift;
	my $opcode = shift;

	my $ss = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR($ss);

	my $high = ${$regpair->[0]};
	my $low = ${$regpair->[1]};

	my $hl = get_value($low, $high);
	$self->tick(1);

	set_value($regpair->[1], $regpair->[0], ($hl - 1) & 0xFFFF);
	$self->tick(1);
}

sub
INC_R
{
	my $self = shift;
	my $opcode = shift; 

	my $r = ($opcode >> 3) & 0x7;

	my $orig_c = $self->flag("C");
	$self->flag("C", 0);
	$self->calculate_add_flags(${$self->REG($r)}, 1, 8);
	$self->flag("C", $orig_c);

	${$self->REG($r)} = (${$self->REG($r)} + 1) & 0xFF;
}

sub
INC_SS
{
	my $self = shift;
	my $opcode = shift;

	my $ss = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR($ss);

	my $high = ${$regpair->[0]};
	my $low = ${$regpair->[1]};

	my $val = get_value($low, $high);
	$self->tick(1);

	set_value($regpair->[1], $regpair->[0], $val + 1);
	$self->tick(1);
}

sub
CP_S
{
	my $self = shift;
	my $opcode = shift;

	my $s = $opcode & 0x7;

		$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, ${$self->REG($s)}, 8);
}

sub
CP_N
{
	my $self = shift;
	my $opcode = shift;

	my $n = $self->next_pc();

	$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, $n, 8);
}

sub
SUB_N
{
	my $self = shift;
	my $opcode = shift;

	my $n = $self->next_pc();

	$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, $n, 8);
	$self->{A} = ($self->{A} - $n) & 0xFF;
}

sub
CP_HL
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H});
	my $value = $self->mem_read($hl);

		$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, $value, 8);
}


sub
CP_IYd
{
	my $self = shift;
	my $offset = unpack('c', pack('C', $self->next_pc()));

	$self->tick(5);
	my $val = $self->mem_read($self->{IY} + $offset);

		$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, $val, 8);
}

sub
CPIR
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H});
	my $bc = get_value($self->{C}, $self->{B});

	my $val = $self->mem_read($hl);
	$self->tick(5);

	print "Comparing A: $self->{A} with $val\n";

	my $c = $self->flag("C");
	$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, $val, 8);
	$self->flag("C", $c);
	$self->flag("N", 1);

	$hl++;
	set_value(\$self->{L}, \$self->{H}, $hl);
	$bc--;
	set_value(\$self->{C}, \$self->{B}, $bc);

	$self->flag("PV", ($bc != 0));

	if ($self->flag("Z")||$bc == 0) {
		return;
	}

	$self->tick(5);
	$self->{PC} -= 2;

}

sub
LDDR
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H});
	my $de = get_value($self->{E}, $self->{D});
	my $bc = get_value($self->{C}, $self->{B});

	$self->mem_write($de, $self->mem_read($hl));

	$bc = ($bc - 1) & 0xffff;
	$hl = ($hl - 1) & 0xffff;
	$de = ($de - 1) & 0xffff;

	set_value(\$self->{L}, \$self->{H}, $hl);
	set_value(\$self->{E}, \$self->{D}, $de);
	set_value(\$self->{C}, \$self->{B}, $bc);

	$self->tick(2);
	if ($bc != 0) {
		$self->tick(5);
		$self->{PC} -= 2;
	}

	$self->flag("H", 0);
	$self->flag("PV", 0);
	$self->flag("N", 0);
}

sub
LDIR
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H});
	my $de = get_value($self->{E}, $self->{D});
	my $bc = get_value($self->{C}, $self->{B});

	$self->mem_write($de, $self->mem_read($hl));

	$hl = ($hl + 1) & 0xffff;
	$de = ($de + 1) & 0xffff;
	$bc = ($bc - 1) & 0xffff;

	set_value(\$self->{L}, \$self->{H}, $hl);
	set_value(\$self->{E}, \$self->{D}, $de);
	set_value(\$self->{C}, \$self->{B}, $bc);

	$self->tick(2);
	if ($bc != 0) {
		$self->tick(5);
		$self->{PC} -= 2;
	}

	$self->flag("H", 0);
	$self->flag("PV", 0);
	$self->flag("N", 0);
}

sub
SUB_S
{
	my $self = shift;
	my $opcode = shift;
	my $ss = $opcode & 0x7;

		$self->flag("C", 0);
	$self->calculate_sub_flags($self->{A}, ${$self->REG($ss)}, 8);

	$self->{A} = $self->{A} - ${$self->REG($ss)};
}

sub
SBC_A_r
{
	my $self = shift;
	my $opcode = shift;

	my $ss = $opcode & 0x7;

	my $ret = ($self->{A} - ${$self->REG($ss)} - $self->flag("C")) & 0xFF;

	$self->calculate_sub_flags($self->{A}, ${$self->REG($ss)}, 8);
	
	$self->{A} = $ret;
}

sub
SBC_HL_SS
{
	my $self = shift;
	my $opcode = shift;

	my $ss = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR($ss);

	my $val = get_value(${$regpair->[1]}, ${$regpair->[0]});
	my $hl = get_value($self->{L}, $self->{H});
	$self->tick(4);	

	my $ret = ($hl - $val - $self->flag("C")) & 0xFFFF;

	set_value(\$self->{L}, \$self->{H}, $ret);
	$self->tick(3);	

	$self->calculate_sub_flags($hl, $val, 16);
}

sub
ADD_HL_SS
{
	my $self = shift;
	my $opcode = shift;

	my $ss = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR($ss);

	my $low = ${$regpair->[1]};
	my $high = ${$regpair->[0]};

	my $val = get_value($low, $high); 
	my $hl = get_value($self->{L}, $self->{H}); 
	$self->tick(4);	

	$self->flag("C", 0);
	$self->calculate_add_flags($hl, $val, 16);

	$hl = ($hl + $val) & 0xFFFF;
	set_value(\$self->{L}, \$self->{H}, $hl);
	$self->tick(3);	

}

sub
ADC_HL_SS
{
	my $self = shift;
	my $opcode = shift;

	my $ss = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR($ss);

	my $low = ${$regpair->[1]};
	my $high = ${$regpair->[0]};

	my $val = get_value($low, $high); 
	my $hl = get_value($self->{L}, $self->{H}); 
	$self->tick(4);	

	my $c = $self->flag("C");
	$self->calculate_add_flags($hl, $val, 16);

	$hl = ($hl + $val + $c) & 0xFFFF;
	set_value(\$self->{L}, \$self->{H}, $hl);
	$self->tick(3);	

}

sub
ADD_A_n
{
	my $self = shift;
		my $n = $self->next_pc();
 
	$self->flag("C", 0);
	$self->calculate_add_flags($self->{A}, $n, 8);

	$self->{A} = ($self->{A} + $n) & 0xFF;
}

sub
ADC_A_n
{
	my $self = shift;
	my $n = $self->next_pc();
 
	$self->calculate_add_flags($self->{A}, $n, 8);

	$self->{A} = ($self->{A} + $n) & 0xFF;
}

sub
ADD_A_r
{
	my $self = shift;
	my $opcode = shift;
		my $s = $opcode & 0x7;

	$self->flag("C", 0);
	$self->calculate_add_flags($self->{A}, ${$self->REG($s)}, 8);

	$self->{A} = ($self->{A} + ${$self->REG($s)}) & 0xFF;
}

sub
ADC_A_r
{
	my $self = shift;
	my $opcode = shift;
	my $s = $opcode & 0x7;

	$self->calculate_add_flags($self->{A}, ${$self->REG($s)}, 8);

	$self->{A} = ($self->{A} + ${$self->REG($s)}) & 0xFF;
}

sub
AND_S
{
	my $self = shift;
	my $opcode = shift;

	my $s = $opcode & 0x7;

	my $res = ($self->{A} & ${$self->REG($s)}) & 0xFF;

	$self->{A} = $res;
	$self->flag("S", ($res >> 7) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("H", 1);
	$self->flag("PV", 0);
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
AND_HL
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H}); 
	my $val = $self->mem_read($hl);

	my $res = ($self->{A} & $val) & 0xFF;

	$self->{A} = $res;
	$self->flag("S", ($res >> 7) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("H", 1);
	$self->flag("PV", 0);
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
AND_n
{
	my $self = shift;
	my $n = $self->next_pc();

	my $res = ($self->{A} & $n) & 0xFF;

	$self->{A} = $res;
	$self->flag("S", ($res >> 7) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("H", 1);
	$self->flag("PV", 0);
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
OR_n
{
	my $self = shift;
	my $n = $self->next_pc();

	my $res = ($self->{A} | $n) & 0xFF;

	$self->{A} = $res;
	$self->flag("S", ($res >> 7) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("H", 0);
	$self->flag("PV", 0);
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
XOR_IYd
{
	my $self = shift;
	my $offset = unpack('c', pack('C', $self->next_pc()));
	$self->tick(5);
	my $value = $self->mem_read($self->{IY} + $offset);

	my $res = ($self->{A} ^ $value) & 0xFF;

	$self->{A} = $res;
	$self->flag("S", ($res >> 7) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("H", 0);
	$self->flag("PV", calculate_parity($self->{A}, 8));
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
OR_pHLp
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H});

	my $value = $self->mem_read($hl);

	my $res = ($self->{A} | $value) & 0xFF;

	$self->{A} = $res;
	$self->flag("S", ($res >> 7) & 0x1);

	if ($res == 0) {
		$self->flag("Z", 1);
	} else {
		$self->flag("Z", 0);
	}

	$self->flag("H", 0);
	$self->flag("PV", 0);
	$self->flag("N", 0);
	$self->flag("C", 0);
}


sub
OR_S
{
	my $self = shift;
	my $opcode = shift;

	my $s = $opcode & 0x7;

	$self->{A} = ($self->{A} | ${$self->REG($s)}) & 0xFF;

	$self->flag("Z", 0);
	if ($self->{A} == 0) {
		$self->flag("Z", 1);
	}

	$self->flag("S", ($self->{A} >> 7) & 0x1); 
	$self->flag("H", 0);
	$self->flag("PV", calculate_parity($self->{A}, 8));
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
XOR_S
{
	my $self = shift;
	my $opcode = shift;

	my $s = $opcode & 0x7;

	$self->{A} = ($self->{A} ^ ${$self->REG($s)}) & 0xFF;

	$self->flag("Z", 0);
	if ($self->{A} == 0) {
		$self->flag("Z", 1);
	}

	$self->flag("S", ($self->{A} >> 7) & 0x1); 
	$self->flag("H", 0);
	$self->flag("PV", calculate_parity($self->{A}, 8));
	$self->flag("N", 0);
	$self->flag("C", 0);
}

sub
XOR_HL
{
	my $self = shift;
	my ($hl) = get_value($self->{L}, $self->{H});

	$self->{A} = (($self->{A} ^ $self->mem_read($hl)) & 0xFF);

	$self->flag("Z", 0);
	if ($self->{A} == 0) {
		$self->flag("Z", 1);
	}

	$self->flag("S", ($self->{A} >> 7) & 0x1); 
	$self->flag("H", 0);
	$self->flag("PV", calculate_parity($self->{A}, 8));
	$self->flag("N", 0);
	$self->flag("C", 0);
}


sub
BIT_b_r
{
	my $self = shift;
	my $opcode = shift;

	my $b = ($opcode >> 3) & 0x7;

	my $r = $opcode & 0x7;

	$self->flag("Z", ((${$self->REG($r)} >> $b) & 0x1) == 0);  
	$self->flag("H", 1);
	$self->flag("N", 0);
}

sub
SET_b_r
{
	my $self = shift;
	my $opcode = shift;

	my $b = ($opcode >> 3) & 0x7;

	my $r = $opcode & 0x7;

	my $mask = 0x1 << $b;

	${$self->REG($r)} |= $mask;
}

sub
SET_b_pHLp
{
	my $self = shift;
	my $opcode = shift;

	my $b = ($opcode >> 3) & 0x7;

	my $hl = get_value($self->{L}, $self->{H});

	my $val = $self->mem_read($hl);
	$self->tick(3);
	$val = ($val | (0x1 << $b)) & 0xFF;
	$self->tick(1);
	$self->mem_write($hl, $val);
	$self->tick(3);
}

sub
RES_b_pHLp
{
	my $self = shift;
	my $opcode = shift;

	my $b = ($opcode >> 3) & 0x7;

	my $hl = get_value($self->{L}, $self->{H});

	my $val = $self->mem_read($hl);
	$self->tick(3);
	$val = ($val & (~(0x1 << $b))) & 0xFF;
	$self->tick(1);
	$self->mem_write($hl, $val);
	$self->tick(3);
}

sub
RES_B_IYd
{
	my $self = shift;
	my $opcode = shift;

	my $bit = (($opcode >> 3) & 0x7);
	my $mask = 0x1 << $bit;
	$mask = (~$mask) & 0xFF;

	my $addr = $self->{IY} + $FDCB_OFFSET;
	print "Using IY + FDCB_OFFSET of " . sprintf("%04x\n", $addr);

	$self->tick(5);
	my $value = $self->mem_read($self->{IY} + $FDCB_OFFSET);
	$value &= $mask;
	$self->tick(1);
	$self->mem_write($self->{IY} + $FDCB_OFFSET, $value);
}

sub
SRL_m
{
	my $self = shift;
	my $opcode = shift;
	my $r = $opcode & 0x7;

	$self->flag("C", ${$self->REG($r)} & 0x1);
	${$self->REG($r)} = (${$self->REG($r)} >> 1) & 0x7F;

	$self->flag("S", 0);
	$self->flag("Z", ${$self->REG($r)} == 0);

	$self->flag("H", 0);
	$self->flag("PV", calculate_parity(${$self->REG($r)}, 8));
	$self->flag("N", 0);
}

sub
SRA_m
{
	my $self = shift;
	my $opcode = shift;
	my $r = $opcode & 0x7;

	my $bit7 = ${$self->REG($r)} & 0x80;

	$self->flag("C", ${$self->REG($r)} & 0x1);
	${$self->REG($r)} = (${$self->REG($r)} >> 1) | $bit7;

	$self->flag("S", $bit7 != 0);
	$self->flag("Z", ${$self->REG($r)} == 0);

	$self->flag("H", 0);
	$self->flag("PV", calculate_parity(${$self->REG($r)}, 8));
	$self->flag("N", 0);
}

sub
SLA_m
{
	my $self = shift;
	my $opcode = shift;
	my $r = $opcode & 0x7;

	my $bit7 = (${$self->REG($r)} >> 7) & 0x1;

	$self->flag("C", $bit7);
	${$self->REG($r)} = (${$self->REG($r)} << 1) & 0xFE;

	$self->flag("S", ${$self->REG($r)} >> 7);
	$self->flag("Z", ${$self->REG($r)} == 0);

	$self->flag("H", 0);
	$self->flag("PV", calculate_parity(${$self->REG($r)}, 8));
	$self->flag("N", 0);
}


sub
BIT_B_IYd
{
	my $self = shift;
	my $opcode = shift;

	$self->tick(1);
	my $bit = (($opcode >> 3) & 0x7);

	my $value = $self->mem_read($self->{IY} + $FDCB_OFFSET);

	my $v = ($value >> $bit) & 0x1;

	if ($v == 1) {
		$self->flag("Z", 0);
	} else {
		$self->flag("Z", 1);
	}

	$self->flag("N", 1);
	$self->flag("H", 0);

	$self->tick(1);
}


sub
BIT_HL
{
	my $self = shift;
	my $opcode = shift;

	my $bit = (($opcode >> 3) & 0x7);

	my $hl = get_value($self->{L}, $self->{H});

	my $value = $self->mem_read($hl);
	$self->tick(1);

	my $v = ($value >> $bit) & 0x1;

	if ($v == 1) {
		$self->flag("Z", 0);
	} else {
		$self->flag("Z", 1);
	}

	$self->flag("N", 1);
	$self->flag("H", 0);

	$self->tick(8);
}

sub
SET_B_IYd
{
	my $self = shift;
	my $opcode = shift;

	$self->tick(1);
	my $bit = (($opcode >> 3) & 0x7);
	my $mask = 0x1 << $bit;

	my $value = $self->mem_read($self->{IY} + $FDCB_OFFSET);
	$self->tick(1);
	$value |= $mask;
	$self->mem_write($self->{IY} + $FDCB_OFFSET, $value);
}

sub
JP
{
	my $self = shift;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	$self->{PC} = ($high << 8) + $low;
}

sub
JP_CC
{
	my $self = shift;
	my $opcode = shift;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $cc = ($opcode >> 3) & 0x7;

	if ($self->FLAG_FN($cc)) {
		$self->{PC} = ($high << 8) + $low;
	}

}

sub
JP_IX
{
	my $self = shift;

	$self->{PC} = $self->{IX};
}

sub
JP_HL
{
	my $self = shift;

	my $hl = get_value($self->{L}, $self->{H});

	$self->{PC} = $hl;
}

sub
JR_E
{
	my $self = shift;

	my $offset = unpack('c', pack('C', $self->next_pc()));

	$self->{PC} += $offset;
	$self->tick(5);
}

sub
JR_NZ_E
{
	my $self = shift;

	my $offset = unpack('c', pack('C', $self->next_pc()));

	if ($self->flag("Z") == 0) {
		$self->{PC} += $offset;
		$self->tick(5);
	}
}


sub
JR_Z_E
{
	my $self = shift;

	my $offset = unpack('c', pack('C', $self->next_pc()));

	if ($self->flag("Z") != 0) {
		$self->{PC} += $offset;
		$self->tick(5);
	}
}

sub
JR_C_E
{
	my $self = shift;
	my $offset = unpack('c', pack('C', $self->next_pc()));

	if ($self->flag("C") == 1) {
		$self->{PC} += $offset;
		$self->tick(5);
	}
}

sub
JR_NC_E
{
	my $self = shift;
	my $offset = unpack('c', pack('C', $self->next_pc()));

	if ($self->flag("C") == 0) {
		$self->{PC} += $offset;
		$self->tick(5);
	}
}

sub
DJNZ_E
{
	my $self = shift;
	$self->tick(1);
	my $offset = unpack('c', pack('C', $self->next_pc()));

	$self->{B} = ($self->{B} - 1) & 0xFF;

	if ($self->{B} != 0) {
	    $self->{PC} += $offset;
		$self->tick(5);
	}
}

sub
RLA
{
	my $self = shift;
	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($orig_c) = $self->flag("C");

	$self->flag("C", ($self->{A} >> 7) & 0x1);

	$self->{A} = (($self->{A} << 1) & 0xFF);

	if ($orig_c != 0) {
	    $self->{A} |= 0x1;
	}
}

sub
RRA
{
	my $self = shift;
	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($new_c) = $self->{A} & 0x1;
	$self->{A} = (($self->{A} >> 1) & 0xFF);

	$self->{A} |= ($self->flag("C") << 7);

	$self->flag("C", $new_c);
}

sub
RRCA
{
	my $self = shift;
	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($new_c) = $self->{A} & 0x1;
	$self->{A} = (($self->{A} >> 1) & 0xFF);

	$self->{A} |= ($new_c << 7);

	$self->flag("C", $new_c);
}

sub
RLCA
{
	my $self = shift;
	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($new_c) = ($self->{A} >> 7) & 0x01;
	$self->{A} = (($self->{A} << 1) & 0xFF);

	$self->flag("C", $new_c);
	$self->{A} |= $new_c;
}

sub
RLC_r
{
	my $self = shift;
	my $opcode = shift;

	my $r = $opcode & 0x7;

	$self->flag("H", 0);
	$self->flag("N", 0);

	$self->flag("C", ((${$self->REG($r)} >> 7) & 0x1));

	${$self->REG($r)} = ((${$self->REG($r)} << 1) & 0xFF);

	${$self->REG($r)} |= $self->flag("C");

	$self->flag("S", (${$self->REG($r)} >> 7) & 0x1);
	$self->flag("Z", ${$self->REG($r)} == 0);
	$self->flag("PV", calculate_parity(${$self->REG($r)}, 8));

	$self->tick(4);
}

sub
RL_HL
{
	my $self = shift;

	my ($hl) = get_value($self->{L}, $self->{H});
	my $val = $self->mem_read($hl);

	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($orig_c) = $self->flag("C");

	$self->flag("C", (($val >> 7) & 0x1));

	$val = (($val << 1) & 0xFF);

	$val |= $orig_c; 

	$self->flag("S", ($val >> 7) & 0x1);
	$self->flag("Z", $val == 0);
	$self->flag("PV", calculate_parity($val, 8));

	$self->mem_write($hl, $val);
	$self->tick(1);
}

sub
RL_r
{
	my $self = shift;
	my $opcode = shift;

	my $r = $opcode & 0x7;

	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($orig_c) = $self->flag("C");

	$self->flag("C", ((${$self->REG($r)} >> 7) & 0x1));

	${$self->REG($r)} = ((${$self->REG($r)} << 1) & 0xFF);

	if ($orig_c != 0) {
		${$self->REG($r)} |= 0x1;
		}

	${$self->REG($r)} |= $orig_c; 

	$self->flag("S", (${$self->REG($r)} >> 7) & 0x1);
	$self->flag("Z", ${$self->REG($r)} == 0);
	$self->flag("PV", calculate_parity(${$self->REG($r)}, 8));
}

sub
RR_r
{
	my $self = shift;
	my $opcode = shift;

	my $r = $opcode & 0x7;

	$self->flag("H", 0);
	$self->flag("N", 0);

	my ($orig_c) = $self->flag("C");

	$self->flag("C", (${$self->REG($r)} & 0x1));

	${$self->REG($r)} = ((${$self->REG($r)} >> 1) & 0xFF);

	if ($orig_c == 0) {
		${$self->REG($r)} &= 0x7F;
	} else {
		${$self->REG($r)} |= 0x80;
	}

	$self->flag("S", (${$self->REG($r)} >> 7) & 0x1);
	$self->flag("Z", ${$self->REG($r)} == 0);
	$self->flag("PV", calculate_parity(${$self->REG($r)}, 8));
}

sub
CALL_NN
{
	my $self = shift;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	my $sp = get_value($self->{S}, $self->{P});

	$self->mem_write(--$sp, ($self->{PC} >> 8) & 0xFF);
	$self->mem_write(--$sp, $self->{PC} & 0xFF);

	set_value(\$self->{S}, \$self->{P}, $sp);
	$self->tick(1);

	$self->{PC} = get_value($low, $high);
}


sub
CALL_CC
{
	my $self = shift;
	my $opcode = shift;
	my $cc = ($opcode >> 3) & 0x7;

	my $low = $self->next_pc();
	my $high = $self->next_pc();

	if ($self->FLAG_FN($cc)) {
		$self->tick(1);
		my $sp = get_value($self->{S}, $self->{P});

		$self->mem_write(--$sp, ($self->{PC} >> 8) & 0xFF);
		$self->mem_write(--$sp, $self->{PC} & 0xFF);

		set_value(\$self->{S}, \$self->{P}, $sp);

		$self->{PC} = get_value($low, $high);
	}

}

sub
RET
{
	my $self = shift;
	my $sp = get_value($self->{S}, $self->{P});
	my $low = $self->mem_read($sp++);
	my $high = $self->mem_read($sp++);
	set_value(\$self->{S}, \$self->{P}, $sp);

	$self->{PC} = get_value($low, $high);
}

sub
RET_CC
{
	my $self = shift;
	my $opcode = shift;
	my $cc = ($opcode >> 3) & 0x7;

	$self->tick(1);
	if ($self->FLAG_FN($cc)) {
	    $self->RET();
	}

}


sub
POP_IX
{
	my $self = shift;

	my $sp = get_value($self->{S}, $self->{P});

	my $low = $self->mem_read($sp++);
	my $high = $self->mem_read($sp++);

	$self->{IX} = get_value($low, $high);

	set_value(\$self->{S}, \$self->{P}, $sp);
}

sub
POP_QQ
{
	my $self = shift;
	my $opcode = shift;

	my $dd = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR2($dd);

	my $sp = get_value($self->{S}, $self->{P});

	${$regpair->[1]} = $self->mem_read($sp++);
	${$regpair->[0]} = $self->mem_read($sp++);

	set_value(\$self->{S}, \$self->{P}, $sp);
}

sub
PUSH_QQ
{
	my $self = shift;
	my $opcode = shift;

	my $dd = ($opcode >> 4) & 0x3;

	my $regpair = $self->REGPAIR2($dd);

	my $high = ${$regpair->[0]};
	my $low = ${$regpair->[1]};

	my $sp = get_value($self->{S}, $self->{P});

	$self->mem_write(--$sp, $high);
	$self->mem_write(--$sp, $low);

	$self->tick(1);
	set_value(\$self->{S}, \$self->{P}, $sp);
}

sub
OUT
{
	my $self = shift; 
	my $n = $self->next_pc();

	my $addr = ($self->{A} << 8) | $n;
	$self->io_write($addr, $self->{A});
}

sub
IN_r_C
{
	my $self = shift; 
	my $opcode = shift;

	my $r = ($opcode >> 3) & 0x7;

	my $addr = ($self->{B} << 8) | $self->{C};

	${$self->REG($r)} = $self->io_read($addr);
}

sub
RST
{
	my $self = shift; 
	my $opcode = shift;
	my $flags = shift;
	my $other = shift;

	my $t = ($opcode >> 3) & 0x7;

	my %addr = (
		0x0 => 0x0,
		0x1 => 0x8,
		0x2 => 0x10,
		0x3 => 0x18,
		0x4 => 0x20,
		0x5 => 0x28,
		0x6 => 0x30,
		0x7 => 0x38,
	);

	my $sp = get_value($self->{S}, $self->{P});

	$self->mem_write(--$sp, ($self->{PC} >> 8) & 0xFF);
	$self->mem_write(--$sp, $self->{PC} & 0xFF);

	set_value(\$self->{S}, \$self->{P}, $sp);

	if (defined $other) {
		$self->{PC} = $other;
	} else {
		$self->{PC} = $addr{$t};
	}

	$self->tick(1);
}

sub
IM_1
{
	my $self = shift;

	$self->{I_MODE} = 1;
	$self->tick(4);
}

sub
EI
{
	my $self = shift;

	$self->{IFF1} = 1;
	$self->{IFF2} = 1;

	$self->{INT_DELAY} = 2;
}

sub
NOP
{

}

sub
HALT
{
	my $self = shift;
	$self->{HALT} = 1;
}

sub
SCF
{
	my $self = shift;

	$self->flag("C", 1);
}

sub
CPL
{
	my $self = shift;

	$self->{A} = (~$self->{A}) & 0xFF;
	$self->flag("H", 1);
	$self->flag("N", 1);
}


sub
CCF
{
	my $self = shift;

	my $c = $self->flag("C");

	if ($c) {
		$c = 0;
	} else {
		$c = 1;
	}

	$self->flag("C", $c);
}

sub
ED
{
	my ($self, $code, $bank) = @_;
	$self->{OPBANK} |= $ED;
}

sub
FD
{
	my ($self, $code, $bank) = @_;
	$self->{OPBANK} = $FD;
}

sub
CB
{
	my ($self, $code, $bank) = @_;
	$self->{OPBANK} = $CB;
}

sub
DD
{
	my ($self, $code, $bank) = @_;
	$self->{OPBANK} = $DD;
}

sub
FDCB
{
	my $self = shift;
	$self->{OPBANK} = $CB|$FD;
	$FDCB_OFFSET = unpack('c', pack('C', $self->next_pc()));
	$self->dec_R();
}


1;
