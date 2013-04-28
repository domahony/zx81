#!/usr/bin/perl -w

package TV;

use strict;
use OpenGL qw / :all /;
use OpenGL::Shader; 

my $vshader = qq {#version 330
layout(location = 0) in vec4 position;
uniform mat4 matrix;
void main()
{
	gl_Position = transpose(matrix) * position;
}

};

my $fshader1 = qq {#version 330

out vec4 outputColor;

void main()
{
    float lerpValue = gl_FragCoord.y / 500.0f;
    
    outputColor = mix(vec4(1.0f, 1.0f, 1.0f, 1.0f),
        vec4(0.2f, 0.2f, 0.2f, 1.0f), lerpValue);
}
};

my $fshader = qq {#version 330
out vec4 outputColor;
void main()
{
	outputColor = vec4(1.0f, 1.0f, 1.0f, 1.0f);
}

};

my %TV = (
	DATA => [],
	VERTS => undef,
	X => 0,
	Y => 0,
	PW => 2,
	PH => 2,
	RENDER => undef,
);

sub
new 
{
	my $class = shift;
	my $self = {%TV};

	my $ret = bless $self, $class;

	my $width = 32 * 8 * $ret->{PW};
	my $height = (24 + 4 + 4) * 8 * $ret->{PH};

	glutInitWindowSize($width, $height);
	glutCreateWindow("BLAH");
	$ret->ourInit($width, $height);

	return $ret;
}

sub
horiz
{
	my $self = shift;
	$self->{Y} += $self->{PH};
	$self->{X} = 0;

	if (defined $self->{RENDER}) {
			$self->{RENDER} = undef;
			glutPostRedisplay();
	}
}

sub
vert
{
	my $self = shift;
	$self->{Y} = 0; 
	$self->{X} = 0;
	$self->{DATA} = [];
	$self->{VERTS}->assign(0, @{$self->{DATA}});
	#print "Setting X: " . $self->{X} . "\n";
	#print "Setting Y: " . $self->{Y} . "\n";
}

sub
data
{
	my $self = shift;
	my $data = shift;
	
	my $i = 8;
	while ($i--) {
		if (($data >> $i) & 0x1) {
			$self->add_pixel();
			$self->{RENDER} = 1;
		} 
		$self->{X} += $self->{PW};
	}
}

sub
add_pixel
{
	my $self = shift;

	my $x = $self->{X};
	my $y = $self->{Y};
	my $pw = $self->{PW}/2;
	my $ph = $self->{PH}/2;

	print "Adding Point: "
		. "($x, " . ($y + $ph) . "),"
		. "($x, $y), " 
		. "(" . ($x+$pw) . "," . ($y+$pw) . "), "
		. "(" . ($x+$pw) . "," . $y .")\n";

	push @{$self->{DATA}}, 
		$x, $y + $ph, 
		$x, $y, 
		$x+$pw, $y+$pw,
		$x+$pw, $y;

	$self->{VERTS}->assign(0, @{$self->{DATA}});
}

sub
render
{
	my $self = shift;
	print "Render!!\n";
	$self->{SHADER}->Enable();

	$self->{VERTS} = OpenGL::Array->new_list(GL_SHORT, @{$self->{DATA}});
	#$self->{VERTS} = OpenGL::Array->new_list(GL_SHORT, 10,500);
	$self->{VERTS}->bind($self->{VID});
	glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $self->{VERTS}, GL_DYNAMIC_DRAW);
	glVertexPointer_p(2, $self->{VERTS});

	glClearColor(0,0,0,0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glDisable(GL_DEPTH_TEST);
	#glTranslatef(0.375, 0.375, 0);

	glEnableClientState(GL_VERTEX_ARRAY);	
	glBindBufferARB(GL_ARRAY_BUFFER_ARB, $self->{VID});
	glDrawArrays(GL_POINTS, 0, $self->{VERTS}->elements());

	glutSwapBuffers();
	$self->{SHADER}->Disable();
}

sub
getOrthoMatrix
{
	my ($w, $h) = @_; 

	my ($left, $right, $top, $bottom, $near, $far) = (0, $w, 0, $h, 0, 1.0);

    my @matrix = (
        2.0 / ($right - $left), 0, 0, -1 * ($right + $left) / ($right - $left),
        0, 2.0 / ($top - $bottom), 0, -1 * ($top + $bottom) / ($top - $bottom),
        0, 0, -2.0 / ($far - $near), -1 * ($far + $near) / ($far - $near),
        0, 0, 0, 1.0,
    );

    my $matrix = OpenGL::Array->new_list(GL_FLOAT, @matrix);

	return $matrix;
}

sub ourInit
{
	my ($self, $Width, $Height) = @_;
	my $shader = new OpenGL::Shader();

	my ($vid) = glGenBuffersARB_p(1);

	$self->{SHADER} = $shader;
	$self->{VID} = $vid;

	$self->{VERTS} = OpenGL::Array->new_list(GL_SHORT, @{$self->{DATA}});
	$self->{VERTS}->bind($self->{VID});
	glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $self->{VERTS}, GL_DYNAMIC_DRAW);
	glVertexPointer_c(2, GL_SHORT, 0, 0);

	$shader->Load($fshader, $vshader);

	$shader->Enable();
	$shader->SetMatrix("matrix", getOrthoMatrix($Width, $Height));
	$shader->Disable();
}

sub
cbResizeScene
{
	print "Hello!!\n";
	my $self = shift;

	$self->{SHADER}->Enable();

	glClearColor(0,0,0,0);
	glClear(GL_COLOR_BUFFER_BIT);
	glEnableClientState(GL_VERTEX_ARRAY);

	glBindBufferARB(GL_ARRAY_BUFFER_ARB, $self->{VID});
	glDrawARrays(GL_TRIANGLES, 0, 3);

	glutSwapBuffers();

	$self->{SHADER}->Disable();
}

1;
