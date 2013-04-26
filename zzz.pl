#!/usr/bin/perl -w 

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

print $fshader;

glutInit();

#glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH | GLUT_ALPHA);
glutInitWindowSize(512, 512);
glutCreateWindow("blah");


	my ($left, $right, $top, $bottom, $near, $far) = 
		(0, 512.0, 0, 512.0, 0, 1.0);
	
	my @matrix = (
		2.0 / ($right - $left), 0, 0, -1 * ($right + $left) / ($right - $left),
		0, 2.0 / ($top - $bottom), 0, -1 * ($top + $bottom) / ($top - $bottom),
		0, 0, -2.0 / ($far - $near), -1 * ($far + $near) / ($far - $near),
		0, 0, 0, 1.0,
	);

	my $matrix = OpenGL::Array->new_list(GL_FLOAT, @matrix);

my $shader = new OpenGL::Shader();
my $vid;
my $verts;
init();

glutDisplayFunc(\&display);

glutMainLoop();

sub
init
{
	$shader->Load($fshader, $vshader);

	($vid) = glGenBuffersARB_p(1);

	#my $verts = OpenGL::Array->new_list(GL_FLOAT, 
	#	0.75, 0.75, 0.0, #1.0,
	#	0.75, -0.75, 0.0, #1.0,
	#	-0.75, -0.75, 0.0, #1.0,
	#);

	$verts = OpenGL::Array->new_list(GL_SHORT,
		2, 500,
		2, 498,
		4, 500,
		4, 498,
		10, 500,
		10, 498,
		12, 500,
		12, 498,
		2, 502,
		2, 500,
		4, 502,
		4, 500,	
		8, 502,
		8, 500,
		10, 502,
		10, 500,
		2, 504,
		2, 502,
		4, 504,
		4, 502,
		#0, 500,
		#500, 500,
		#500, 0,
	);

	$verts->bind($vid);

	glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $verts, GL_STATIC_DRAW);
	glVertexPointer_p(2, $verts);
}

sub
display
{
	print "Hello!\n";
	$shader->Enable();
	$shader->SetMatrix("matrix", $matrix);


    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glDisable(GL_DEPTH_TEST);

	glEnableClientState(GL_VERTEX_ARRAY);
	glBindBufferARB(GL_ARRAY_BUFFER_ARB, $vid);

	#my $location = glGetUniformLocationARB_p($shader, "xmatrix");
	#my $transpose = 1;


	#glUniformMatrix4fvARB_p($location, $transpose, @matrix);

    #glMatrixMode(GL_PROJECTION);
    #glLoadIdentity();
    #glOrtho(0, 100, 100, 0, 0, 1);
    #glTranslatef(0.375, 0.375, 0);

	glDrawArrays(GL_POINTS, 0, $verts->elements());
	glutSwapBuffers();
	$shader->Disable();
}
