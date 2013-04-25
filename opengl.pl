#!/usr/bin/perl -w
use strict;

use OpenGL qw/ :all /;

eval 'use OpenGL::Image';
my $hasImage = !$@;
my $hasIM_635 = $hasImage && OpenGL::Image::HasEngine('Magick','6.3.5');

eval 'use OpenGL::Shader';
my $hasShader = !$@;

eval 'use Image::Magick';
my $hasIM = !$@;

use Math::Trig;
eval 'use Time::HiRes qw( gettimeofday )';
my $hasHires = !$@;
$|++;


# ----------------------
# Based on a cube demo by
# Chris Halsall (chalsall@chalsall.com) for the
# O'Reilly Network on Linux.com (oreilly.linux.com).
# May 2000.
#
# Translated from C to Perl by J-L Morel <jl_morel@bribes.org>
# ( http://www.bribes.org/perl/wopengl.html )
#
# Updated for FBO, VBO, Vertex/Fragment Program extensions
# and ImageMagick support
# by Bob "grafman" Free <grafman@graphcomp.com>
# ( http://graphcomp.com/opengl )
#


use constant PROGRAM_TITLE => "OpenGL Test App";
use constant DO_TESTS => 0;

# Some global variables.
my $useMipMap = 1;
my $hasFBO = 0;
my $hasVBO = 0;
my $hasFragProg = 0;
my $hasImagePointer = 0;
my $er;

# Window and texture IDs, window width and height.
my $Window_ID;
my $Window_Width = 300;
my $Window_Height = 300;
my $Inset_Width = 90;
my $Inset_Height = 90;
my $Save_Width;
my $Save_Height;

# Texture dimanesions
my $Tex_File = 'test.tga';
my $Tex_Width = 128;
my $Tex_Height = 128;
my $Tex_Format;
my $Tex_Type;
my $Tex_Size;
my $Tex_Image;
my $Tex_Pixels;

# Our display mode settings.
my $Light_On = 0;
my $Blend_On = 0;
my $Texture_On = 1;
my $Alpha_Add = 1;
my $FBO_On = 0;
my $Inset_On = 1;
my $Fullscreen_On = 0;

my $Curr_TexMode = 0;
my @TexModesStr = qw/ GL_DECAL GL_MODULATE GL_BLEND GL_REPLACE /;
my @TexModes = ( GL_DECAL, GL_MODULATE, GL_BLEND, GL_REPLACE );
my($TextureID_image,$TextureID_FBO);
my $FrameBufferID;
my $RenderBufferID;
my $VertexProgID;
my $FragProgID;
my $FBO_rendered = 0;
my $Shader;

# Object and scene global variables.
my $Teapot_Rot = 0.0;

# Cube position and rotation speed variables.
my $X_Rot   = 0.9;
my $Y_Rot   = 0.0;
my $X_Speed = 0.0;
my $Y_Speed = 0.5;
my $Z_Off   =-5.0;

# Settings for our light.  Try playing with these (or add more lights).
my @Light_Ambient  = ( 0.1, 0.1, 0.1, 1.0 );
my @Light_Diffuse  = ( 1.2, 1.2, 1.2, 1.0 );
my @Light_Position = ( 2.0, 2.0, 0.0, 1.0 );

# Vertex Buffer Object data
my($VertexObjID,$NormalObjID,$ColorObjID,$TexCoordObjID,$IndexObjID);

my @verts =
(
  -1.0, -1.3, -1.0,
  1.0, -1.3, -1.0,
  1.0, -1.3,  1.0,
  -1.0, -1.3,  1.0,

  -1.0,  1.3, -1.0,
  -1.0,  1.3,  1.0,
  1.0,  1.3,  1.0,
  1.0,  1.3, -1.0,

  -1.0, -1.0, -1.3,
  -1.0,  1.0, -1.3,
  1.0,  1.0, -1.3,
  1.0, -1.0, -1.3,

  1.3, -1.0, -1.0,
  1.3,  1.0, -1.0,
  1.3,  1.0,  1.0,
  1.3, -1.0,  1.0,

  -1.0, -1.0,  1.3,
  1.0, -1.0,  1.3,
  1.0,  1.0,  1.3,
  -1.0,  1.0,  1.3,

  -1.3, -1.0, -1.0,
  -1.3, -1.0,  1.0,
  -1.3,  1.0,  1.0,
  -1.3,  1.0, -1.0
);
my $verts = OpenGL::Array->new_list(GL_FLOAT,@verts);

# Could calc norms on the fly
my @norms =
(
  0.0, -1.0, 0.0,
  0.0, 1.0, 0.0,
  0.0, 0.0,-1.0,
  1.0, 0.0, 0.0,
  0.0, 0.0, 1.0,
  -1.0, 0.0, 0.0
);
my $norms = OpenGL::Array->new_list(GL_FLOAT,@norms);

my @colors =
(
  0.9,0.2,0.2,.75,
  0.9,0.2,0.2,.75,
  0.9,0.2,0.2,.75,
  0.9,0.2,0.2,.75,

  0.5,0.5,0.5,.5,
  0.5,0.5,0.5,.5,
  0.5,0.5,0.5,.5,
  0.5,0.5,0.5,.5,

  0.2,0.9,0.2,.5,
  0.2,0.9,0.2,.5,
  0.2,0.9,0.2,.5,
  0.2,0.9,0.2,.5,

  0.2,0.2,0.9,.25,
  0.2,0.2,0.9,.25,
  0.2,0.2,0.9,.25,
  0.2,0.2,0.9,.25,

  0.9, 0.2, 0.2, 0.5,
  0.2, 0.9, 0.2, 0.5,
  0.2, 0.2, 0.9, 0.5,
  0.1, 0.1, 0.1, 0.5,

  0.9,0.9,0.2,0.0,
  0.9,0.9,0.2,0.66,
  0.9,0.9,0.2,1.0,
  0.9,0.9,0.2,0.33
);
my $colors = OpenGL::Array->new_list(GL_FLOAT,@colors);

my @rainbow =
(
  0.9, 0.2, 0.2, 0.5,
  0.2, 0.9, 0.2, 0.5,
  0.2, 0.2, 0.9, 0.5,
  0.1, 0.1, 0.1, 0.5
);

my $rainbow = OpenGL::Array->new_list(GL_FLOAT,@rainbow);
my $rainbow_offset = 64;
my @rainbow_inc;

my @texcoords =
(
  0.800, 0.800,
  0.200, 0.800,
  0.200, 0.200,
  0.800, 0.200,

  0.005, 1.995,
  0.005, 0.005,
  1.995, 0.005,
  1.995, 1.995,

  0.995, 0.005,
  2.995, 2.995,
  0.005, 0.995,
  -1.995, -1.995,

  0.995, 0.005,
  0.995, 0.995,
  0.005, 0.995,
  0.005, 0.005,

  -0.5, -0.5,
  1.5, -0.5,
  1.5, 1.5,
  -0.5, 1.5,

  0.005, 0.005,
  0.995, 0.005,
  0.995, 0.995,
  0.005, 0.995
);
my $texcoords = OpenGL::Array->new_list(GL_FLOAT,@texcoords);

my @indices = (0..23);
my $indices = OpenGL::Array->new_list(GL_UNSIGNED_INT,@indices);

my @xform =
(
  1.0, 0.0, 0.0, 0.0,
  0.0, 1.0, 0.0, 0.0,
  0.0, 0.0, 1.0, 0.0,
  0.0, 0.0, 0.0, 1.0
);
my $xform = OpenGL::Array->new_list(GL_FLOAT,@xform);


# ------
# Frames per second (FPS) statistic variables and routine.

use constant CLOCKS_PER_SEC => $hasHires ? 1000 : 1;
use constant FRAME_RATE_SAMPLES => 50;

my $FrameCount = 0;
my $FrameRate = 0;
my $last=0;

sub ourDoFPS
{
  if (++$FrameCount >= FRAME_RATE_SAMPLES)
  {
     my $now = $hasHires ? gettimeofday() : time(); # clock();
     my $delta= ($now - $last);
     $last = $now;

     $FrameRate = FRAME_RATE_SAMPLES / ($delta || 1);
     $FrameCount = 0;
  }
}

# ------
# String rendering routine; leverages on GLUT routine.

sub ourPrintString
{
  my ($font, $str) = @_;
  my @c = split '', $str;

  for(@c)
  {
    glutBitmapCharacter($font, ord $_);
  }
}


# ------
# Does everything needed before losing control to the main
# OpenGL event loop.

sub ourInit
{
  my ($Width, $Height) = @_;

  # Set initial colors for rainbow face
  for (my $i=0; $i<16; $i++)
  {
    $rainbow[$i] = rand(1.0);
    $rainbow_inc[$i] = 0.01 - rand(0.02);
  }

  # Initialize VBOs if supported
  if ($hasVBO)
  {
    ($VertexObjID,$NormalObjID,$ColorObjID,$TexCoordObjID,$IndexObjID) =
      glGenBuffersARB_p(5);

    #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $VertexObjID);
    $verts->bind($VertexObjID);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $verts, GL_STATIC_DRAW_ARB);
    glVertexPointer_c(3, GL_FLOAT, 0, 0);

    if (DO_TESTS)
    {
      print "\nTests:\n";

      my $size = glGetBufferParameterivARB_p(GL_ARRAY_BUFFER_ARB,
        GL_BUFFER_SIZE_ARB);
      print "  Vertex Buffer Size (bytes): $size\n";
      my $count = $verts->elements();
      print "  Vertex Buffer Size (elements): $count\n";

      my $test = glGetBufferSubDataARB_p(GL_ARRAY_BUFFER_ARB,12,3,GL_FLOAT);
      my @test = $test->retrieve(0,3);
      my $ords = join('/',@test);
      print "  glGetBufferSubDataARB_p: $ords\n";
    }

    #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $NormalObjID);
    $norms->bind($NormalObjID);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $norms, GL_STATIC_DRAW_ARB);
    glNormalPointer_c(GL_FLOAT, 0, 0);

    #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $ColorObjID);
    $colors->bind($ColorObjID);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $colors, GL_DYNAMIC_DRAW_ARB);
    $rainbow->assign(0,@rainbow);
    glBufferSubDataARB_p(GL_ARRAY_BUFFER_ARB, $rainbow_offset, $rainbow);
    glColorPointer_c(4, GL_FLOAT, 0, 0);

    #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $TexCoordObjID);
    $texcoords->bind($TexCoordObjID);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $texcoords, GL_STATIC_DRAW_ARB);
    glTexCoordPointer_c(2, GL_FLOAT, 0, 0);

    #glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, $IndexObjID);
    $indices->bind($IndexObjID);
    glBufferDataARB_p(GL_ELEMENT_ARRAY_BUFFER_ARB, $indices, GL_STATIC_DRAW_ARB);
  }
  else
  {
    glVertexPointer_p(3, $verts);
    glNormalPointer_p($norms);
    $colors->assign($rainbow_offset,@rainbow);
    glColorPointer_p(4, $colors);
    glTexCoordPointer_p(2, $texcoords);
  }

  # Build texture.
  ($TextureID_image,$TextureID_FBO) = glGenTextures_p(2);
  ourBuildTextures();
  glTexEnvf(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_DECAL);

  # Initialize shaders.
  ourInitShaders();

  # Initialize rendering parameters
  glEnable(GL_TEXTURE_2D);
  glDisable(GL_LIGHTING);
  glBlendFunc(GL_SRC_ALPHA,GL_ONE);
  #glEnable(GL_BLEND);

  # Color to clear color buffer to.
  glClearColor(0.1, 0.1, 0.1, 0.0);

  # Depth to clear depth buffer to; type of test.
  glClearDepth(1.0);
  glDepthFunc(GL_LESS);

  # Enables Smooth Color Shading; try GL_FLAT for (lack of) fun.
  glShadeModel(GL_SMOOTH);

  # Load up the correct perspective matrix; using a callback directly.
  cbResizeScene($Width, $Height);

  # Set up a light, turn it on.
  glLightfv_p(GL_LIGHT1, GL_POSITION, @Light_Position);
  glLightfv_p(GL_LIGHT1, GL_AMBIENT,  @Light_Ambient);
  glLightfv_p(GL_LIGHT1, GL_DIFFUSE,  @Light_Diffuse);
  glEnable(GL_LIGHT1);

  # A handy trick -- have surface material mirror the color.
  glColorMaterial(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE);
  glEnable(GL_COLOR_MATERIAL);
}


# ------
# Function to build a simple full-color texture with alpha channel,
# and then create mipmaps.
# Also sets up FBO texture and Vertex/Fragment programs.

sub ourBuildTextures
{
  my $gluerr;
  my $tex;

  # Build Image Texture
  ($TextureID_image,$TextureID_FBO) = glGenTextures_p(2);
  print "\n";

  # Use OpenGL::Image to load texture
  if ($hasImage && -e $Tex_File)
  {
    my $img = new OpenGL::Image(source=>$Tex_File);
    my($eng,$ver) = $img->Get('engine','version');
    print "Using OpenGL::Image - $eng v$ver\n";

    ($Tex_Width,$Tex_Height) = $img->Get('width','height');
    my $alpha = $img->Get('alpha') ? 'has' : 'no';
    print "Loading texture: $Tex_File, $Tex_Width x $Tex_Height, $alpha alpha\n";

    ($Tex_Type,$Tex_Format,$Tex_Size) = 
      $img->Get('gl_internalformat','gl_format','gl_type');

    # Use OGA for testing
    $Tex_Image = $img;
    $Tex_Pixels = $img->GetArray();
    print "Using ImageMagick's gaussian blur on inset\n" if ($hasIM_635);
  }
  # Build texture from scratch if OpenGL::Image not available
  else
  {
    my $hole_size = 3300; # ~ == 57.45 ^ 2.
    # Iterate across the texture array.
    for(my $y=0; $y<$Tex_Height; $y++)
    {
      for(my $x=0; $x<$Tex_Width; $x++)
      {
        # A simple repeating squares pattern.
        # Dark blue on white.
        if ( ( ($x+4)%32 < 8 ) && ( ($y+4)%32 < 8))
        {
          $tex .= pack "C3", 0,0,120;       # Dark blue
        }
        else
        {
          $tex .= pack "C3", 240, 240, 240; # White
        }

        # Make a round dot in the texture's alpha-channel.
        # Calculate distance to center (squared).
        my $t = ($x-64)*($x-64) + ($y-64)*($y-64);

        if ( $t < $hole_size)
        {
          $tex .= pack "C", 255;  # The dot itself is opaque.
        }
        elsif ($t < $hole_size + 100)
        {
          $tex .= pack "C", 128;  # Give our dot an anti-aliased edge.
        }
        else
        {
          $tex .= pack "C", 0;    # Outside of the dot, it's transparent.
        }
      }
    }

    $Tex_Pixels = OpenGL::Array->new_scalar(GL_UNSIGNED_BYTE,$tex,length($tex));

    $Tex_Type = GL_RGBA8;
    $Tex_Format = GL_RGBA;
    $Tex_Size =  GL_UNSIGNED_BYTE;
  }
  glBindTexture(GL_TEXTURE_2D, $TextureID_image);

  # Use MipMap
  if ($useMipMap)
  {
    print "Using Mipmap\n";

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,
      GL_NEAREST_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
      GL_NEAREST_MIPMAP_LINEAR);

    # The GLU library helps us build MipMaps for our texture.
    if (($gluerr = gluBuild2DMipmaps_c(GL_TEXTURE_2D, $Tex_Type,
      $Tex_Width, $Tex_Height, $Tex_Format, $Tex_Size,
      $Tex_Pixels->ptr())))
    {
      printf STDERR "GLULib%s\n", gluErrorString($gluerr);
      exit(-1);
    }
  }
  # Use normal texture - Note: dimensions must be power of 2
  else
  {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    glTexImage2D_c(GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height,
      0, $Tex_Format, $Tex_Size, $Tex_Pixels->ptr());
  }

  # Benchmarks for Image Loading
  if (DO_TESTS && $hasIM)
  {
    my $loops = 1000;

    my $im = new Image::Magick();
    $im->Read($Tex_File);
    $im->Set(magick=>'RGBA',depth=>8);
    $im->Negate(channel=>'alpha');


    # Bench ImageToBlob
    my $start = gettimeofday();
    for (my $i=0;$i<$loops;$i++)
    {
      my($blob) = $im->ImageToBlob();

      glTexImage2D_s(GL_TEXTURE_2D, 0, GL_RGBA8, $Tex_Width, $Tex_Height,
        0, GL_RGBA, GL_UNSIGNED_BYTE, $blob);
    }
    my $now = gettimeofday();
    my $fps = $loops / ($now - $start);
    print "ImageToBlob + glTexImage2D_s: $fps\n";


    # Bench GetPixels
    $start = gettimeofday();
    for (my $i=0;$i<$loops;$i++)
    {
      my @pixels = $im->GetPixels(map=>'BGRA',
        width=>$Tex_Width, height=>$Tex_Height, normalize=>'false');

      glTexImage2D_p(GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height,
        0, $Tex_Format, $Tex_Size, @pixels);
    }
    $now = gettimeofday();
    $fps = $loops / ($now - $start);
    print "GetPixels + glTexImage2D_p: $fps\n";


    # Bench OpenGL::Image
    if ($hasIM_635)
    {
      my $start = gettimeofday();
      for (my $i=0;$i<$loops;$i++)
      {
        glTexImage2D_c(GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height,
          0, $Tex_Format, $Tex_Size, $Tex_Pixels->ptr());
      }
      my $now = gettimeofday();
      my $fps = $loops / ($now - $start);
      print "OpenGL::Image + glTexImage2D_c: $fps\n";
    }
  }

  # Build FBO texture
  if ($hasFBO)
  {
    ($FrameBufferID) = glGenFramebuffersEXT_p(1);
    ($RenderBufferID) = glGenRenderbuffersEXT_p(1);

    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, $FrameBufferID);
    glBindTexture(GL_TEXTURE_2D, $TextureID_FBO);

    # Initiate texture
    glTexImage2D_c(GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height,
      0, $Tex_Format, $Tex_Size, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    # Bind texture/frame/render buffers
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT,
      GL_TEXTURE_2D, $TextureID_FBO, 0);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, $RenderBufferID);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT24,
      $Tex_Width, $Tex_Height);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT,
      GL_RENDERBUFFER_EXT, $RenderBufferID);

    # Test status
    if (DO_TESTS)
    {
      my $stat = glCheckFramebufferStatusEXT(GL_RENDERBUFFER_EXT);
      printf("FBO Status: %04X\n",$stat);
    }
  }

  # Select active texture
  ourSelectTexture();

  glTexEnvf(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_DECAL);
}

sub ourSelectTexture
{
    glBindTexture(GL_TEXTURE_2D, $FBO_On ? $TextureID_FBO : $TextureID_image);
}

sub ourInitShaders
{
  # Setup Vertex/Fragment Programs to render FBO texture

  # Use OpenGL::Shader
  if ($hasShader && ($Shader = new OpenGL::Shader()))
  {
    my $type = $Shader->GetType();
    my $ext = lc($type);

    my $stat = $Shader->LoadFiles("fragment.$ext","vertex.$ext");
    if (!$stat)
    {
      my $ver = $Shader->GetVersion();
      print "Using OpenGL::Shader('$type') v$ver\n";
      return;
    }
    else
    {
      print "$stat\n";
    }
  }

  # Fall back to doing it manually
  if ($hasFragProg)
  {
    ($VertexProgID,$FragProgID) = glGenProgramsARB_p(2);

    # NOP Vertex shader
    my $VertexProg = qq
    {!!ARBvp1.0
      PARAM center = program.local[0];
      PARAM xform[4] = {program.local[1..4]};
      TEMP vertexClip;

      # ModelView projection
      DP4 vertexClip.x, state.matrix.mvp.row[0], vertex.position;
      DP4 vertexClip.y, state.matrix.mvp.row[1], vertex.position;
      DP4 vertexClip.z, state.matrix.mvp.row[2], vertex.position;
      DP4 vertexClip.w, state.matrix.mvp.row[3], vertex.position;

      # Additional transform, via matrix variable
      DP4 vertexClip.x, vertexClip, xform[0];
      DP4 vertexClip.y, vertexClip, xform[1];
      DP4 vertexClip.z, vertexClip, xform[2];
      DP4 vertexClip.w, vertexClip, xform[3];

      #SUB result.position, vertexClip, center;
      MOV result.position, vertexClip;

      # Pass through color
      MOV result.color, vertex.color;

      # Pass through texcoords
      SUB result.texcoord[0], vertex.texcoord, center;
      END
    };

    glBindProgramARB(GL_VERTEX_PROGRAM_ARB, $VertexProgID);
    glProgramStringARB_p(GL_VERTEX_PROGRAM_ARB, $VertexProg);

    if (DO_TESTS)
    {
      my $format = glGetProgramivARB_p(GL_VERTEX_PROGRAM_ARB,
        GL_PROGRAM_FORMAT_ARB);
      printf("glGetProgramivARB_p format: '#%04X'\n",$format);

      my @params = glGetProgramEnvParameterdvARB_p(GL_VERTEX_PROGRAM_ARB,0);
      my $params = join(', ',@params);
      print "glGetProgramEnvParameterdvARB_p: $params\n";

      @params = glGetProgramEnvParameterfvARB_p(GL_VERTEX_PROGRAM_ARB,0);
      $params = join(', ',@params);
      print "glGetProgramEnvParameterfvARB_p: $params\n";

      my $vprog = glGetProgramStringARB_p(GL_VERTEX_PROGRAM_ARB);
      print "Vertex Prog: $vprog\n";
    }

    # Lazy Metalic Fragment shader
    my $FragProg = qq
    {!!ARBfp1.0
      PARAM surfacecolor = program.local[5];
      TEMP color;
      MUL color, fragment.texcoord[0].y, 2.0;
      ADD color, 1.0, -color;
      ABS color, color;
      ADD color, 1.01, -color;  #Some cards have a rounding error
      MOV color.a, 1.0;
      MUL color, color, surfacecolor;
      MOV result.color, color;
      END
    };

    glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, $FragProgID);
    glProgramStringARB_p(GL_FRAGMENT_PROGRAM_ARB, $FragProg);

    if (DO_TESTS)
    {
      my $fprog = glGetProgramStringARB_p(GL_FRAGMENT_PROGRAM_ARB);
      print "Fragment Prog: $fprog\n";
    }
  }
}


# ------
# Routine which actually does the drawing

sub cbRenderScene
{
  my $buf; # For our strings.

  # Animated Texture Rendering
  if ($FBO_On && ($FBO_On == 2 || !$FBO_rendered))
  {
    $FBO_rendered = 1;
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, $FrameBufferID);
    glPushMatrix();
    glTranslatef(-0.35, -0.48, -1.5);
    glRotatef($Teapot_Rot--, 0.0, 1.0, 0.0);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glPushAttrib(GL_ENABLE_BIT);
    glEnable(GL_DEPTH_TEST);

    # Run shader programs for texture.
    # If installed, use OpenGL::Shader
    if ($Shader)
    {
      $Shader->Enable();
      $Shader->SetVector('center',0.0,0.0,2.0,0.0);
      $Shader->SetMatrix('xform',$xform);
      $Shader->SetVector('surfacecolor',1.0,0.5,0.0,1.0);
    }
    # Otherwise, do it manually
    elsif ($hasFragProg)
    {
      glEnable(GL_VERTEX_PROGRAM_ARB);
      glEnable(GL_FRAGMENT_PROGRAM_ARB);

      glProgramLocalParameter4fARB(GL_VERTEX_PROGRAM_ARB, 0, 0.0,0.0,2.0,0.0);

      glProgramLocalParameter4fvARB_c(GL_VERTEX_PROGRAM_ARB, 1, $xform->offset(0));
      glProgramLocalParameter4fvARB_c(GL_VERTEX_PROGRAM_ARB, 2, $xform->offset(4));
      glProgramLocalParameter4fvARB_c(GL_VERTEX_PROGRAM_ARB, 3, $xform->offset(8));
      glProgramLocalParameter4fvARB_c(GL_VERTEX_PROGRAM_ARB, 4, $xform->offset(12));

      glProgramLocalParameter4fARB(GL_FRAGMENT_PROGRAM_ARB, 5, 1.0,0.5,0.0,1.0);
    }

    glColor3f(1.0, 1.0, 1.0);
    #glutSolidTeapot(0.125);
    glutWireTeapot(0.125);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

    if ($Shader)
    {
      $Shader->Disable();
    }
    elsif ($hasFragProg)
    {
      glDisable(GL_FRAGMENT_PROGRAM_ARB);
      glDisable(GL_VERTEX_PROGRAM_ARB);
    }

    glPopAttrib();
    glPopMatrix();
  }
  ourSelectTexture();

  # Enables, disables or otherwise adjusts as
  # appropriate for our current settings.

  if ($Texture_On)
  {
    glEnable(GL_TEXTURE_2D);
  }
  else
  {
    glDisable(GL_TEXTURE_2D);
  }
  if ($Light_On)
  {
    glEnable(GL_LIGHTING);
  }
  else
  {
    glDisable(GL_LIGHTING);
  }
  if ($Alpha_Add)
  {
    glBlendFunc(GL_SRC_ALPHA,GL_ONE);
  }
  else
  {
    glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  }
  # If we're blending, we don'$t want z-buffering.
  if ($Blend_On)
  {
    glDisable(GL_DEPTH_TEST);
  }
  else
  {
    glEnable(GL_DEPTH_TEST);
  }

  # Need to manipulate the ModelView matrix to move our model around.
  glMatrixMode(GL_MODELVIEW);

  # Reset to 0,0,0; no rotation, no scaling.
  glLoadIdentity();

  # Move the object back from the screen.
  glTranslatef(0.0,0.0,$Z_Off);

  # Rotate the calculated amount.
  glRotatef($X_Rot,1.0,0.0,0.0);
  glRotatef($Y_Rot,0.0,1.0,0.0);

  # Clear the color and depth buffers.
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


  # Update Rainbow Cube Face
  for (my $i=0; $i<scalar(@rainbow); $i++)
  {
    $rainbow[$i] += $rainbow_inc[$i];
    if ($rainbow[$i] < 0)
    {
      $rainbow[$i] = 0.0;
    }
    elsif ($rainbow[$i] > 1)
    {
      $rainbow[$i] = 1.0;
    }
    else
    {
      next;
    }
    $rainbow_inc[$i] = -$rainbow_inc[$i];
  }

  if ($hasVBO)
  {
    glBindBufferARB(GL_ARRAY_BUFFER_ARB, $ColorObjID);
    my $color_map = glMapBufferARB_p(GL_ARRAY_BUFFER_ARB,
      GL_WRITE_ONLY_ARB,GL_FLOAT);
    my $buffer = glGetBufferPointervARB_p(GL_ARRAY_BUFFER_ARB,
      GL_BUFFER_MAP_POINTER_ARB,GL_FLOAT);
    $color_map->assign($rainbow_offset,@rainbow);
    glUnmapBufferARB(GL_ARRAY_BUFFER_ARB);
  }
  else
  {
    $colors->assign($rainbow_offset,@rainbow);
    glColorPointer_p(4, $colors);
  }


  # Render cube
  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_NORMAL_ARRAY);
  glEnableClientState(GL_COLOR_ARRAY);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);

  for (my $i=0; $i<scalar(@indices); $i+=4)
  {
    glDrawArrays(GL_QUADS, $i, 4);
  }

  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
  glDisableClientState(GL_COLOR_ARRAY);
  glDisableClientState(GL_NORMAL_ARRAY);
  glDisableClientState(GL_VERTEX_ARRAY);


  # Move back to the origin (for the text, below).
  glLoadIdentity();

  # We need to change the projection matrix for the text rendering.
  glMatrixMode(GL_PROJECTION);

  # But we like our current view too; so we save it here.
  glPushMatrix();

  # Now we set up a new projection for the text.
  glLoadIdentity();
  glOrtho(0,$Window_Width,0,$Window_Height,-1.0,1.0);

  # Lit or textured text looks awful.
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_LIGHTING);

  # We don'$t want depth-testing either.
  glDisable(GL_DEPTH_TEST);

  # But, for fun, let's make the text partially transparent too.
  glColor4f(0.6,1.0,0.6,.75);

  # Render our various display mode settings.
  $buf = sprintf "Mode: %s", $TexModesStr[$Curr_TexMode];
  glRasterPos2i(2,2); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  $buf = sprintf "Alpha: %d", $Alpha_Add;
  glRasterPos2i(2,14); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  $buf = sprintf "Blend: %d", $Blend_On;
  glRasterPos2i(2,26); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  $buf = sprintf "Light: %d", $Light_On;
  glRasterPos2i(2,38); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  $buf = sprintf "Tex: %d", $Texture_On;
  glRasterPos2i(2,50); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  $buf = sprintf "FBO: %d", $FBO_On;
  glRasterPos2i(2,62); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  $buf = sprintf "Inset: %d", $Inset_On;
  glRasterPos2i(2,74); ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  # Now we want to render the calulated FPS at the top.
  # To ease, simply translate up.  Note we're working in screen
  # pixels in this projection.
  glTranslatef(6.0,$Window_Height - 14,0.0);

  # Make sure we can read the FPS section by first placing a
  # dark, mostly opaque backdrop rectangle.
  glColor4f(0.2,0.2,0.2,0.75);

  glBegin(GL_QUADS);
  glVertex3f(  0.0, -2.0, 0.0);
  glVertex3f(  0.0, 12.0, 0.0);
  glVertex3f(140.0, 12.0, 0.0);
  glVertex3f(140.0, -2.0, 0.0);
  glEnd();

  glColor4f(0.9,0.2,0.2,.75);
  $buf = sprintf "FPS: %f F: %2d", $FrameRate, $FrameCount;
  glRasterPos2i(6,0);
  ourPrintString(GLUT_BITMAP_HELVETICA_12,$buf);

  # Done with this special projection matrix.  Throw it away.
  glPopMatrix();

  # Do Inset View
  Capture(Inset=>1) if ($Inset_On);

  # All done drawing.  Let's show it.
  glutSwapBuffers();

  # Now let's do the motion calculations.
  $X_Rot+=$X_Speed;
  $Y_Rot+=$Y_Speed;

  # And collect our statistics.
  ourDoFPS();
}

# Capture window
sub Capture
{
  my(%params) = @_;

  my($w) = glutGet( GLUT_WINDOW_WIDTH );
  my($h) = glutGet( GLUT_WINDOW_HEIGHT );
	
  glPushAttrib( GL_ENABLE_BIT | GL_VIEWPORT_BIT |
    GL_TRANSFORM_BIT | GL_COLOR_BUFFER_BIT);
  glDisable( GL_LIGHTING );
  glDisable( GL_FOG );
  glDisable( GL_TEXTURE_2D );
  glDisable( GL_DEPTH_TEST );
  glDisable( GL_CULL_FACE );
  glDisable( GL_STENCIL_TEST );
 
  glViewport( 0, 0, $w, $h );
  glMatrixMode( GL_PROJECTION );
  glPushMatrix();
  glLoadIdentity();
  eval { gluOrtho2D( 0, $w, 0, $h ); 1 } or $er++ or warn "Catched: $@";
  glMatrixMode( GL_MODELVIEW );
  glPushMatrix();
  glLoadIdentity();
  
  glPixelZoom( 1, 1 );

  # Save
  if ($params{Save})
  {
    Save($w,$h,$params{Save});
  }
  # Inset
  elsif ($params{Inset})
  {
    Inset($w,$h);
  }

  glMatrixMode( GL_PROJECTION );
  glPopMatrix();
  glMatrixMode( GL_MODELVIEW );
  glPopMatrix();
  glPopAttrib();
}

# Display inset
sub Inset
{
  my($w,$h) = @_;

  my $Capture_X = int(($w - $Inset_Width) / 2);
  my $Capture_Y = int(($h - $Inset_Height) / 2);
  my $Inset_X = $w - ($Inset_Width + 2);
  my $Inset_Y = $h - ($Inset_Height + 2);

  # Using OpenGL::Image and ImageMagick to read/modify/draw pixels
  if ($hasIM_635)
  {
    my $frame = new OpenGL::Image(engine=>'Magick',
      width=>$Inset_Width, height=>$Inset_Height);
    my($fmt,$size) = $frame->Get('gl_format','gl_type');

    glReadPixels_c( $Capture_X, $Capture_Y, $Inset_Width, $Inset_Height,
      $fmt, $size, $frame->Ptr() );
    $frame->Sync();

    # For grins, use ImageMagick to modify the inset
    $frame->Native->Blur(radius=>2,sigma=>2);

    glRasterPos2f( $Inset_X, $Inset_Y );
    glDrawPixels_c( $Inset_Width, $Inset_Height, $fmt, $size, $frame->Ptr() );
  }
  # Fastest approach
  else
  {
    my $len = $Inset_Width * $Inset_Height * 4;
    my $oga = new OpenGL::Array($len,GL_UNSIGNED_BYTE);

    glReadPixels_c( $Capture_X, $Capture_Y, $Inset_Width, $Inset_Height,
      GL_RGBA, GL_UNSIGNED_BYTE, $oga->ptr() );
    glRasterPos2f( $Inset_X, $Inset_Y );
    glDrawPixels_c( $Inset_Width, $Inset_Height, GL_RGBA, GL_UNSIGNED_BYTE, $oga->ptr() );
  }
}

# Capture/save window
sub Save
{
  my($w,$h,$file) = @_;

  if ($hasImage)
  {
    my $frame = new OpenGL::Image(width=>$w, height=>$h);
    my($fmt,$size) = $frame->Get('gl_format','gl_type');

    glReadPixels_c( 0, 0, $w, $h, $fmt, $size, $frame->Ptr() );
    $frame->Save($file);
  }
  else
  {
    print "Need OpenGL::Image and ImageMagick 6.3.5 or newer for file capture!\n";
  }
}

# Cleanup routine
sub ourCleanup
{
  # Disable app
  glutHideWindow();
  glutKeyboardFunc();
  glutSpecialFunc();
  glutIdleFunc();
  glutReshapeFunc();

  if ($hasFBO)
  {
    # Release resources
    glBindRenderbufferEXT( GL_RENDERBUFFER_EXT, 0 );
    glBindFramebufferEXT( GL_FRAMEBUFFER_EXT, 0 );

    glDeleteRenderbuffersEXT_p( $RenderBufferID ) if ($RenderBufferID);
    glDeleteFramebuffersEXT_p( $FrameBufferID ) if ($FrameBufferID);
  }

  if ($Shader)
  {
    undef($Shader);
  }
  elsif ($hasFragProg)
  {
    glBindProgramARB(GL_VERTEX_PROGRAM_ARB, 0);
    glDeleteProgramsARB_p( $VertexProgID ) if ($VertexProgID);

    glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, 0);
    glDeleteProgramsARB_p( $FragProgID ) if ($FragProgID);
  }

  if ($hasVBO)
  {
    glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
    glDeleteBuffersARB_p($VertexObjID) if ($VertexObjID);
    glDeleteBuffersARB_p($NormalObjID) if ($NormalObjID);
    glDeleteBuffersARB_p($ColorObjID) if ($ColorObjID);
    glDeleteBuffersARB_p($TexCoordObjID) if ($TexCoordObjID);

    glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
    glDeleteBuffersARB_p($IndexObjID) if ($IndexObjID);
  }

  glDeleteTextures_p($TextureID_image,$TextureID_FBO);

  # Now you can destroy window
  glutDestroyWindow($Window_ID);
}

# ------
# Callback function called when a normal $key is pressed.

sub cbKeyPressed
{
  my $key = shift;
  my $c = uc chr $key;
  if ($key == 27 or $c eq 'Q')
  {
    ourCleanup();
    exit(0);
  }
  elsif ($c eq 'B')
  {
    $Blend_On = !$Blend_On;
    if (!$Blend_On)
    {
      glDisable(GL_BLEND);
    }
    else {
      glEnable(GL_BLEND);
    }
  }
  elsif ($c eq 'L')
  {
    $Light_On = !$Light_On;
  }
  elsif ($c eq 'M')
  {
    if ( ++ $Curr_TexMode > 3 )
    {
      $Curr_TexMode=0;
    }
    glTexEnvi(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,$TexModes[$Curr_TexMode]);
  }
  elsif ($c eq 'T')
  {
    $Texture_On = !$Texture_On;
  }
  elsif ($c eq 'A')
  {
    $Alpha_Add = !$Alpha_Add;
  }
  elsif ($c eq 'F' && $hasFBO)
  {
    $FBO_On = ($FBO_On+1) % 3;
    ourSelectTexture();
  }
  elsif ($c eq 'I')
  {
    $Inset_On = !$Inset_On;
  }
  elsif ($c eq 'S' or $key == 32)
  {
    $X_Speed=$Y_Speed=0;
  }
  elsif ($c eq 'R')
  {
    $X_Speed = -$X_Speed;
    $Y_Speed = -$Y_Speed;
  }
  elsif ($c eq 'G')
  {
    $Fullscreen_On = !$Fullscreen_On;
    if ($Fullscreen_On)
    {
      $Save_Width = $Window_Width;
      $Save_Height = $Window_Height;
      glutFullScreen();
    }
    else
    {
      $Window_Width = $Save_Width;
      $Window_Height = $Save_Height;
      glutReshapeWindow($Window_Width,$Window_Height);
    }
  }
  elsif ($c eq 'C' && $hasImage)
  {
    Capture(Save=>'capture.tga');
  }
  else
  {
    printf "KP: No action for %d.\n", $key;
  }
}

# ------
# Callback Function called when a special $key is pressed.

sub cbSpecialKeyPressed
{
  my $key = shift;

  if ($key == GLUT_KEY_PAGE_UP)
  {
    $Z_Off -= 0.05;
  }
  elsif ($key == GLUT_KEY_PAGE_DOWN)
  {
    $Z_Off += 0.05;
  }
  elsif ($key == GLUT_KEY_UP)
  {
    $X_Speed -= 0.01;
  }
  elsif ($key == GLUT_KEY_DOWN)
  {
    $X_Speed += 0.01;
  }
  elsif ($key == GLUT_KEY_LEFT)
  {
    $Y_Speed -= 0.01;
  }
  elsif ($key == GLUT_KEY_RIGHT)
  {
    $Y_Speed += 0.01;
  }
  else
  {
    printf "SKP: No action for %d.\n", $key;
  }
}

# ------
# Callback routine executed whenever our window is resized.  Lets us
# request the newly appropriate perspective projection matrix for
# our needs.  Try removing the gluPerspective() call to see what happens.

sub cbResizeScene
{
  my ($Width, $Height) = @_;

  # Let's not core dump, no matter what.
  $Height = 1 if ($Height == 0);

  glViewport(0, 0, $Width, $Height);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluPerspective(45.0,$Width/$Height,0.1,100.0);

  glMatrixMode(GL_MODELVIEW);

  $Window_Width  = $Width;
  $Window_Height = $Height;
}




# ------
# The main() function.  Inits OpenGL.  Calls our own init function,
# then passes control onto OpenGL.

eval {glutInit(); 1} or die qq
{
This test requires GLUT:
If you have X installed, you can try the scripts in ./examples/
Most of them do not use GLUT.

It is recommended that you install GLUT for improved Makefile.PL
configuration, installation and debugging.
};

# To see OpenGL drawing, take out the GLUT_DOUBLE request.
glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH | GLUT_ALPHA);
glutInitWindowSize($Window_Width, $Window_Height);

# Open a window
if (!glutGet(GLUT_DISPLAY_MODE_POSSIBLE)) {
	die ":-(";
}
$Window_ID = glutCreateWindow( PROGRAM_TITLE );

# Get OpenGL Info
print "\n";
print PROGRAM_TITLE;
print ' (using hires timer)' if ($hasHires);
print "\n\n";
my $version = glGetString(GL_VERSION);
my $vendor = glGetString(GL_VENDOR);
my $renderer = glGetString(GL_RENDERER);
print "Using POGL v$OpenGL::BUILD_VERSION\n";
print "OpenGL installation: $version\n$vendor\n$renderer\n\n";

print "Installed extensions (* implemented in the module):\n";
my $extensions = glGetString(GL_EXTENSIONS);
my @extensions = split(' ',$extensions);
foreach my $ext (sort @extensions)
{
  my $stat = OpenGL::glpCheckExtension($ext);
  printf("%s $ext\n",$stat?' ':'*');
  print("    $stat\n") if ($stat && $stat !~ m|^$ext |);
}

if (!OpenGL::glpCheckExtension('GL_ARB_vertex_buffer_object'))
{
  $hasVBO = 1;
}

if (!OpenGL::glpCheckExtension('GL_EXT_framebuffer_object'))
{
  $hasFBO = 1;
  $FBO_On = 1;

  if (!OpenGL::glpCheckExtension('GL_ARB_fragment_program'))
  {
    $hasFragProg = 1;
    $FBO_On++;
  }
}


# Register the callback function to do the drawing.
glutDisplayFunc(\&cbRenderScene);

# If there's nothing to do, draw.
glutIdleFunc(\&cbRenderScene);

# It's a good idea to know when our window's resized.
glutReshapeFunc(\&cbResizeScene);

# And let's get some keyboard input.
glutKeyboardFunc(\&cbKeyPressed);
glutSpecialFunc(\&cbSpecialKeyPressed);

# OK, OpenGL's ready to go.  Let's call our own init function.
ourInit($Window_Width, $Window_Height);

# Print out a bit of help dialog.
print qq
{
Hold down arrow keys to rotate, 'r' to reverse, 's' to stop.
Page up/down will move cube away from/towards camera.
Use first letter of shown display mode settings to alter.
Press 'c' to capture/save a RGBA targa file.
'q' or [Esc] to quit; OpenGL window must have focus for input.

};

# Pass off control to OpenGL.
# Above functions are called as appropriate.
glutMainLoop();

__END__

