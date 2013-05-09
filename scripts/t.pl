#!/usr/bin/perl -w

use OpenGL qw / :all /;

use strict;

glutInit();

sub
key
{
	my $key = shift;

	print "$key " . chr($key) . "\n";
}

sub
display
{
	glClearColor(0,0,0,0);
	glClear(GL_COLOR_BUFFER_BIT);
	glutSwapBuffers();
}

glutInitWindowSize(640,480);
glutCreateWindow("blah");
glutDisplayFunc(\&display);
glutKeyboardFunc(\&key);
glutMainLoop();

