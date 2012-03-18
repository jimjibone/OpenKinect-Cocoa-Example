//
//  Kinect Viewer.m
//  KinectiCopter
//
//  Created by James Reuss on 29/02/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//
//	All included libraries are property of their respective owners.
//

#import "Kinect Viewer.h"

typedef struct KCCube_ {
	CGFloat x, y, z, width, height, length;
} KCCube;

static void gluPerspectivef(GLfloat fovy, GLfloat aspect, GLfloat zNear, GLfloat zFar) {
    GLfloat f = 1.0f / tanf(fovy * (M_PI/360.0));
	GLfloat m[16];
    
	m[0] = f / aspect;
	m[1] = 0.0;
	m[2] = 0.0;
	m[3] = 0.0;
    
	m[4] = 0.0;
	m[5] = f;
	m[6] = 0.0;
	m[7] = 0.0;
    
	m[8] = 0.0;
	m[9] = 0.0;
	m[10] = (zFar + zNear) / (zNear - zFar);
	m[11] = -1.0;
    
	m[12] = 0.0;
	m[13] = 0.0;
	m[14] = 2.0 * zFar * zNear / (zNear - zFar);
	m[15] = 0.0;
    
	glMultMatrixf(m);
}

@interface Kinect_Viewer (Private)
- (void)initScene;
- (void)closeScene;
- (void)drawScene;
- (void)drawFrustrum;
- (void)drawCube:(KCCube)cube;
- (void)frameForTime:(const CVTimeStamp*)outputTime;
@end

@implementation Kinect_Viewer
@synthesize useNormals, useNatural, useMMDepth;
@synthesize viewMode;
@synthesize naturalScale, naturalX, naturalY;
@synthesize naturalScaleVal, naturalXVal, naturalYVal;
@synthesize midPointDepth;
@synthesize red, green, blue;

- (void)dealloc {
    CVDisplayLinkRelease(displayLink);
    [self closeScene];
    [super dealloc];
}

//-------------------------------------------------
// CoreVideo Methods.
//-------------------------------------------------
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [(Kinect_Viewer*)displayLinkContext frameForTime:outputTime];
    [pool release];
    return kCVReturnSuccess;
}

//-------------------------------------------------
// OpenGL Methods.
//-------------------------------------------------
- (id)initWithFrame:(NSRect)frameRect {
	NSOpenGLPixelFormatAttribute attributes[] = {
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAColorSize, 32,
		NSOpenGLPFADepthSize, 32,//24
		0
	};
	NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	if (self = [super initWithFrame:frameRect pixelFormat:[format autorelease]]) {
		// It worked. Well done.
	}
	
	// Initialise the Natural View settings.
	[naturalScale setFloatValue:0.0023];
	[naturalX setFloatValue:-2.43];
	[naturalY setFloatValue:6.78];
	
	return self;
}
- (void)prepareOpenGL {
	// Synchronise the buffer swaps with the vertical refresh rate.
	GLint swapInt = 1;
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
	
	[self initScene];
	
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, &displayLinkCallback, self);
	
	// Set the display link for the current renderer.
	CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
	
	CVDisplayLinkStart(displayLink);
}
- (void)update {
	NSOpenGLContext *context = [self openGLContext];
	CGLLockContext([context CGLContextObj]);
	[super update];
	CGLUnlockContext([context CGLContextObj]);
}
- (void)reshape {
	NSOpenGLContext *context = [self openGLContext];
    CGLLockContext([context CGLContextObj]);
    if([context view]) {
        [context makeCurrentContext];
		glViewport(0, 0, NSWidth([self bounds]), NSHeight([self bounds]));
    }    
    CGLUnlockContext([context CGLContextObj]);
}
- (void)drawRect:(NSRect)dirtyRect {
	NSOpenGLContext *context = [self openGLContext];
	CGLLockContext([context CGLContextObj]);
	if ([context view]) {
		[context makeCurrentContext];
		
		[self drawScene];
		
		GLenum error = glGetError();
		if (error != GL_NO_ERROR) {
			NSLog(@"GLError %4x", error);
		}
		
		[context flushBuffer];
	}
	
	CGLUnlockContext([context CGLContextObj]);
}

//-------------------------------------------------
// Private Methods.
//-------------------------------------------------
@synthesize scaleEquation;
- (void)updateScaleEquation {
	[scaleEquation setStringValue:[NSString stringWithFormat:@"nd = %.3f + %.3fd + d^%.3f", regOffset, regScale, regSecondScale]];
}
- (IBAction)changeRegOffset:(id)sender {
	regOffset = [sender floatValue];
	[self updateScaleEquation];
}
- (IBAction)changeRegScale:(id)sender {
	regScale = [sender floatValue];
	[self updateScaleEquation];
}
- (IBAction)changeRegSecondScale:(id)sender {
	regSecondScale = [sender floatValue];
	[self updateScaleEquation];
}
- (void)initScene {
	regOffset = 0;
	regScale = 2;
	regSecondScale = 0;
	// Prepare the textures.
	uint8_t *empty = (uint8_t*)malloc(FREENECT_FRAME_W * FREENECT_FRAME_H * 3);
    bzero(empty, FREENECT_FRAME_W * FREENECT_FRAME_H * 3);
    
	glGenTextures(1, &depthTexture);
	glBindTexture(GL_TEXTURE_2D, depthTexture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE16, FREENECT_FRAME_W, FREENECT_FRAME_H, 0, GL_LUMINANCE, GL_UNSIGNED_SHORT, empty);
    
	glGenTextures(1, &videoTexture);
	glBindTexture(GL_TEXTURE_2D, videoTexture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, FREENECT_FRAME_W, FREENECT_FRAME_H, 0, GL_RGB, GL_UNSIGNED_BYTE, empty);
    
    free(empty);
	
	// Prepare the Depth Colour Texture.
	uint8_t map[2048*3];
    for(int i = 0; i < 2048; i++) {
        float v = i/2048.0;
		v = powf(v, 3)* 6;
        uint16_t gamma = v*6*256;
        
        int lb = gamma & 0xff;
		switch (gamma>>8) {
			case 0: // white -> red
                map[i*3+0] = 255;
				map[i*3+1] = 255-lb;
				map[i*3+2] = 255-lb;
				break;
			case 1: // red -> orange
				map[i*3+0] = 255;
				map[i*3+1] = lb;
				map[i*3+2] = 0;
				break;
			case 2: // orange -> green 
				map[i*3+0] = 255-lb;
				map[i*3+1] = 255;
				map[i*3+2] = 0;
				break;
			case 3: // green -> cyan
				map[i*3+0] = 0;
				map[i*3+1] = 255;
				map[i*3+2] = lb;
				break;
			case 4: // cyan -> blue
				map[i*3+0] = 0;
				map[i*3+1] = 255-lb;
				map[i*3+2] = 255;
				break;
			case 5: // blue -> black
				map[i*3+0] = 0;
				map[i*3+1] = 0;
				map[i*3+2] = 255-lb;
				break;
			default: // black
				map[i*3+0] = 0;
				map[i*3+1] = 0;
				map[i*3+2] = 0;
				break;
		}
	}
    glGenTextures(1, &depthColourTexture);
    glBindTexture(GL_TEXTURE_1D, depthColourTexture);
    glTexImage1D(GL_TEXTURE_1D, 0, GL_RGB8, 2048, 0, GL_RGB, GL_UNSIGNED_BYTE, map);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	
	
	// Initialise the GLProgram classes.
	depthProgram = [[GLProgram alloc] initWithName:@"depth"
												VS:
					"void main() {\n"
					"	gl_TexCoord[0] = gl_MultiTexCoord0;\n"
					"	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;\n"
					"}\n"
												FS:
					"uniform sampler1D colormap;\n"
					"uniform sampler2D depth;\n"
					"uniform sampler2D video;\n"
					"uniform int normals;\n"
					"uniform int natural;\n"
					""
					"const float kMinDistance = -10.0;\n"
					"const float kDepthScale  = 0.0021;\n"
					"uniform float kColorScale;\n"
					"uniform float kColorX;\n"
					"uniform float kColorY;\n"
					""
					"void main() {\n"
					"	float z  = texture2D(depth, gl_TexCoord[0].st).r*32.0;\n" 
					"   vec4 rgba;\n"
					"   if(natural > 0) {\n"
					""
					"      vec2 pos = gl_TexCoord[0].st*2.0-vec2(1.0);\n" // -1..+1
					"      float d = z*2048.0;\n" // 0..2048
					""
					"      float zd = (d > 1.0 && d < 1800.0) ? (100.0/(-0.00307 * d + 3.33)) : 100000.0;\n"
					""
					"      float zs = (zd+kMinDistance)*kDepthScale;\n"
					"      vec4 world = vec4(pos.x*320.0*zs, pos.y*240.0* zs, 200.0-zd, 1.0);\n"
					""
					"      float cs = 1.0/((zd+kMinDistance)*kColorScale);\n"
					"	   vec2 st = vec2( ((world.x+kColorX)*cs)/640.0 + 0.5,   ((world.y+kColorY)*cs)/480.0 + 0.5);\n"
					""
					"      rgba = texture2D(video, st);\n"
					"   } else {\n"
					"      rgba = texture1D(colormap, z);\n" // scale to 0..1 range
					"   }\n"
					""
					"   if(normals > 0) {\n"
					"      float zx =  texture2D(depth, gl_TexCoord[0].st+vec2(2.0/640.0, 0.0)).r*32.0;\n"
					"      float zy =  texture2D(depth, gl_TexCoord[0].st+vec2(0.0, 2.0/480.0)).r*32.0;\n"
					"      vec3 n = vec3(zx-z, zy-z, -0.0005);\n"
					"      n = normalize(n);\n"
					"      rgba *= max(0.1, dot(vec3(0.0, -0.3, -0.95), n));\n"
					"   }\n"
					""
					"   gl_FragColor = rgba;\n"
					"}\n"
					];
    [depthProgram bind];
    [depthProgram setUniformInt:0 forName:@"video"];
    [depthProgram setUniformInt:1 forName:@"depth"];
    [depthProgram setUniformInt:2 forName:@"colormap"];
    [depthProgram unbind];
	
    // create grid of points
    struct glf2 {
        GLfloat x,y;
    } *verts = (struct glf2*)malloc(FREENECT_FRAME_W*FREENECT_FRAME_H*sizeof(struct glf2));
    for(int x = 0; x < FREENECT_FRAME_W; x++) {
        for(int y = 0; y < FREENECT_FRAME_H; y++) {
            struct glf2 *v = verts+x+y*FREENECT_FRAME_W;
            v->x = (x+0.5)/(FREENECT_FRAME_W*0.5) - 1.0;
            v->y = (y+0.5)/(FREENECT_FRAME_H*0.5) - 1.0;
        }
    }
    glGenBuffers(1, &pointBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, pointBuffer);
    glBufferData(GL_ARRAY_BUFFER, FREENECT_FRAME_W*FREENECT_FRAME_H*sizeof(struct glf2), verts, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    free(verts);
    
    pointProgram = [[GLProgram alloc] initWithName:@"point"
												VS:
					"uniform sampler2D depth;\n"
					""
					"const float kMinDistance = -10.0;\n"
					"const float kDepthScale  = 0.0021;\n"
					"uniform float kColorScale;\n"
					"uniform float kColorX;\n"
					"uniform float kColorY;\n"
					""
					"void main() {\n"
					"   vec3 pos = gl_Vertex.xyz;\n"
					"   vec2 xy = (vec2(1.0)+pos.xy)*0.5;\n" // 0..1
					"   float d = texture2D(depth, xy).r*32.0*2048.0;\n" // 0..2048
					""
					"   float z = (d > 1.0 && d < 1800.0) ? (100.0/(-0.00307 * d + 3.33)) : 100000.0;\n"
					""
					"   float zs = (z+kMinDistance)*kDepthScale;\n"
					"   vec4 world = vec4(pos.x*320.0*zs, pos.y*240.0* zs, 200.0-z, 1.0);\n"
					""
					"   float cs = 1.0/((z+kMinDistance)*kColorScale);\n"
					"	gl_TexCoord[1].st = vec2( ((world.x+kColorX)*cs)/640.0 + 0.5,   ((world.y+kColorY)*cs)/480.0 + 0.5);\n"
					"	gl_TexCoord[0].st = xy;\n"
					""
					"	gl_Position = gl_ModelViewProjectionMatrix * world;\n"
					"}\n"
												FS:
					"uniform sampler1D colormap;\n"
					"uniform sampler2D depth;\n"
					"uniform sampler2D video;\n"
					"uniform int normals;\n"
					"uniform int natural;\n"
					""
					"void main() {\n"
					"	float z  = texture2D(depth, gl_TexCoord[0].st).r*32.0;\n" // 0..1
					"   vec4 rgba = (natural > 0) ? texture2D(video, gl_TexCoord[1].st) : texture1D(colormap, z);\n" 
					""
					"   if(normals > 0) {\n"
					"      float zx =  texture2D(depth, gl_TexCoord[0].st+vec2(2.0/640.0, 0.0)).r*32.0;\n"
					"      float zy =  texture2D(depth, gl_TexCoord[0].st+vec2(0.0, 2.0/480.0)).r*32.0;\n"
					"      vec3 n = vec3(zx-z, zy-z, -0.0005);\n"
					"      n = normalize(n);\n"
					"      rgba *= max(0.1, dot(vec3(0.0, -0.3, -0.95), n));\n"
					"   }\n"
					""
					"   gl_FragColor = rgba;\n"
					"}\n"
					];
    [pointProgram bind];
    [pointProgram setUniformInt:0 forName:@"video"];
    [pointProgram setUniformInt:1 forName:@"depth"];
    [pointProgram setUniformInt:2 forName:@"colormap"];
    [pointProgram unbind];
	
	regProgram = [[GLProgram alloc] initWithName:@"registered" 
											  VS:
				  "uniform sampler2D depth;\n"
				  ""
				  "const float kMinDistance = -10.0;\n"
				  "const float kDepthScale  = 0.0021;\n"
				  "uniform float kColorScale;\n"
				  "uniform float kColorX;\n"
				  "uniform float kColorY;\n"
				  ""
				  "void main() {\n"
				  "   vec3 pos = gl_Vertex.xyz;\n"
				  "   vec2 xy = (vec2(1.0)+pos.xy)*0.5;\n" // 0..1
				  "   float d = texture2D(depth, xy).r*32.0*2048.0;\n" // 0..2048
				  ""
				  "   float z = (d > 1.0 && d < 1800.0) ? (100.0/(-0.00307 * d + 3.33)) : 100000.0;\n"
				  ""
				  "   float zs = (z+kMinDistance)*kDepthScale;\n"
				  //"   vec4 world = vec4(pos.x*320.0*zs, pos.y*240.0* zs, 200.0-z, 1.0);\n"
				  "   vec4 world = vec4(pos.x*320.0*zs, pos.y*240.0* zs, z, 1.0);\n"
				  ""
				  "   float cs = 1.0/((z+kMinDistance)*kColorScale);\n"
				  "	gl_TexCoord[1].st = vec2( ((world.x+kColorX)*cs)/640.0 + 0.5,   ((world.y+kColorY)*cs)/480.0 + 0.5);\n"
				  "	gl_TexCoord[0].st = xy;\n"
				  ""
				  "	gl_Position = gl_ModelViewProjectionMatrix * world;\n"
				  "}\n" 
											  FS:
				  "uniform sampler1D colormap;\n"
				  "uniform sampler2D depth;\n"
				  "uniform sampler2D video;\n"
				  "uniform int normals;\n"
				  "uniform int natural;\n"
				  ""
				  "void main() {\n"
				  "	float z  = texture2D(depth, gl_TexCoord[0].st).r*32.0;\n" // 0..1
				  "   vec4 rgba = (natural > 0) ? texture2D(video, gl_TexCoord[1].st) : texture1D(colormap, z);\n" 
				  ""
				  "   if(normals > 0) {\n"
				  "      float zx =  texture2D(depth, gl_TexCoord[0].st+vec2(2.0/640.0, 0.0)).r*32.0;\n"
				  "      float zy =  texture2D(depth, gl_TexCoord[0].st+vec2(0.0, 2.0/480.0)).r*32.0;\n"
				  "      vec3 n = vec3(zx-z, zy-z, -0.0005);\n"
				  "      n = normalize(n);\n"
				  "      rgba *= max(0.1, dot(vec3(0.0, -0.3, -0.95), n));\n"
				  "   }\n"
				  ""
				  "   gl_FragColor = rgba;\n"
				  "}\n"
				  ];
	[regProgram bind];
    [regProgram setUniformInt:0 forName:@"video"];
    [regProgram setUniformInt:1 forName:@"depth"];
    [regProgram setUniformInt:2 forName:@"colormap"];
    [regProgram unbind];
    
    // create indicies for mesh
    indicies = (GLuint*)malloc(FREENECT_FRAME_W*FREENECT_FRAME_H*6*sizeof(GLuint));
    nTriIndicies = 0;
	
    offsetPosition[0] = 0;
    offsetPosition[1] = 0;
    offsetPosition[2] = 5;
    angle = 0;
    tilt = 0;
    
    // set up texture units 0,1,2 permantely and only bind the textures once
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_1D, depthColourTexture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, depthTexture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, videoTexture);
}
- (void)closeScene {
	glDeleteTextures(1, &depthTexture);
    glDeleteTextures(1, &videoTexture);
    glDeleteTextures(1, &depthColourTexture);
	
	free(indicies);
    
	[regProgram release];
    [depthProgram release];
    [pointProgram release];
}
- (void)drawScene {
	[controller setFrameViewed];
	static int count = 0;
	int midDepth = 0;
	int midVideoR = 0, midVideoG = 0, midVideoB = 0;
	// 0 = Flat Mode. 1 = Point Cloud Mode. 2 = Registered Cloud Mode.
	if ([viewMode isSelectedForSegment:0]) {
		mode = 0;
	} else if ([viewMode isSelectedForSegment:1]) {
		mode = 1;
	} else if ([viewMode isSelectedForSegment:2]) {
		mode = 2;
	}
	
	// Get depth.
	uint16_t *depth = [controller getDepthData];
	if (depth) {
		// Do calculations.
		if (count >= 100) {
			midDepth = depth[640*480/2+320];
			if (midDepth >= 2047) {
				// Out of bounds.
				[midPointDepth setStringValue:@"Out Of Range"];
			} else {
				[midPointDepth setIntValue:depth[640*480/2+320]];
			}
		}
		
		// Remap the depth if using registered depth.
		if (mode == 2) {
			float newOffset = (regOffset == 0)?10:regOffset;
			float newScale = (regScale == 0)?10:regScale;
			float newSecScale = (regSecondScale == 0)?10:regSecondScale;
			//uint16_t *newDepth = malloc(sizeof(depth));
			for (int i = 0; i < FREENECT_FRAME_W*FREENECT_FRAME_H; i++) {
				depth[i] = newOffset + depth[i]/newScale;
			}
		}
		
		// Add the depth to OpenGL.
		glActiveTexture(GL_TEXTURE1);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, FREENECT_FRAME_W, FREENECT_FRAME_H, GL_LUMINANCE, GL_UNSIGNED_SHORT, depth);
        glActiveTexture(GL_TEXTURE0);
		
        free(depth);
	}
	
	// Get video.
	uint8_t *video = [controller getVideoData];
	if (video) {
		if (count >= 100) {
			midVideoR = video[640*480/2+320+2] & 0xFF;
			midVideoG = video[640*480/2+320+1] & 0xFF;
			midVideoB = video[640*480/2+320+0] & 0xFF;
			[red setIntValue:(midVideoR)];
			[green setIntValue:(midVideoG)];
			[blue setIntValue:(midVideoB)];
		}
		
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, FREENECT_FRAME_W, FREENECT_FRAME_H, GL_RGB, GL_UNSIGNED_BYTE, video);
        free(video);
	}
	
	if (count >= 100) {
		count = 0;
	} else {
		count++;
	}
	
	glClearColor(0.0, 0.0, 0.0, 1.0);	//Black
	//glClearColor(255, 255, 255, 1);		//White
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	
	if (mode == 0) {
		// Flat Mode.
		// Set up ortho.
		glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0.0f, NSWidth([self bounds]), NSHeight([self bounds]), 0.0f, -1.0f, 1.0f); // y-flip
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        glDisable(GL_DEPTH_TEST);
        
        glColor4f(1.0, 1.0, 1.0, 1.0);
		
		GLfloat flatWidth = NSWidth([self bounds])/2;
		GLfloat flatHeight = NSHeight([self bounds]);
        
		// Draw the RGB viewport.
		glEnable(GL_TEXTURE_2D);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(0,			0);
        glTexCoord2f(1, 0); glVertex2f(flatWidth,	0);
        glTexCoord2f(1, 1); glVertex2f(flatWidth,	flatHeight);
        glTexCoord2f(0, 1); glVertex2f(0,			flatHeight);
        glEnd();
        glDisable(GL_TEXTURE_2D);
		
        glTranslatef(flatWidth, 0, 0);
		
		// Draw the Depth viewport.
		glEnable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE2);
        glEnable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glEnable(GL_TEXTURE_2D);
		
		[depthProgram bind];
        [depthProgram setUniformInt:([useNormals intValue]?1:0) forName:@"normals"];
        [depthProgram setUniformInt:([useNatural intValue]?1:0) forName:@"natural"];
        [depthProgram setUniformFloat:[naturalScale floatValue] forName:@"kColorScale"];
        [depthProgram setUniformFloat:[naturalX floatValue] forName:@"kColorX"];
        [depthProgram setUniformFloat:[naturalY floatValue] forName:@"kColorY"];
		
		glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(0,               0);
        glTexCoord2f(1, 0); glVertex2f(flatWidth,0);
        glTexCoord2f(1, 1); glVertex2f(flatWidth,flatHeight);
        glTexCoord2f(0, 1); glVertex2f(0,flatHeight);
        glEnd();
		
		[depthProgram unbind]; 
		
		// End
		glActiveTexture(GL_TEXTURE2);
        glDisable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glDisable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE0);
        glDisable(GL_TEXTURE_2D);
	} else if (mode >= 1) {
		// Point Cloud Mode.
		glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspectivef(40, NSWidth([self bounds])/NSHeight([self bounds]), 0.05, 1000);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        glTranslatef(offsetPosition[0], offsetPosition[1], -offsetPosition[2]);
        glRotatef(angle, 0, 1, 0);
        glRotatef(tilt, -1, 0, 0);
        
        float s = 0.02;
        glScalef(s, -s, s); // flip y,  flipping the scene x is an incredibly stupid way to mirror
        
        glEnable(GL_DEPTH_TEST);
        
        glEnable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE2);
        glEnable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glEnable(GL_TEXTURE_2D);
        
        [pointProgram bind];
        [pointProgram setUniformInt:([useNormals intValue]?1:0) forName:@"normals"];
        [pointProgram setUniformInt:([useNatural intValue]?1:0) forName:@"natural"];
        [pointProgram setUniformFloat:[naturalScale floatValue] forName:@"kColorScale"];
        [pointProgram setUniformFloat:[naturalX floatValue] forName:@"kColorX"];
        [pointProgram setUniformFloat:[naturalY floatValue] forName:@"kColorY"];
        
        glEnableClientState(GL_VERTEX_ARRAY);
        glBindBuffer(GL_ARRAY_BUFFER, pointBuffer);
        glVertexPointer(2, GL_FLOAT, 0, NULL);
		glDrawArrays(GL_POINTS, 0, FREENECT_FRAME_W*FREENECT_FRAME_H);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDisableClientState(GL_VERTEX_ARRAY);
        
        [pointProgram unbind]; 
        
        glActiveTexture(GL_TEXTURE2);
        glDisable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glDisable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE0);
        glDisable(GL_TEXTURE_2D);
	} else if (mode >= 2) {
		// Registered Point Cloud Mode.
		glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspectivef(40, NSWidth([self bounds])/NSHeight([self bounds]), 0.05, 1000);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        glTranslatef(offsetPosition[0], offsetPosition[1], -offsetPosition[2]);
        glRotatef(angle, 0, 1, 0);
        glRotatef(tilt, -1, 0, 0);
        
        float s = 0.02;
        glScalef(s, -s, s); // flip y,  flipping the scene x is an incredibly stupid way to mirror
        
        glEnable(GL_DEPTH_TEST);
        
        glEnable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE2);
        glEnable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glEnable(GL_TEXTURE_2D);
        
        [regProgram bind];
        [regProgram setUniformInt:([useNormals intValue]?1:0) forName:@"normals"];
        [regProgram setUniformInt:([useNatural intValue]?1:0) forName:@"natural"];
        [regProgram setUniformFloat:[naturalScale floatValue] forName:@"kColorScale"];
        [regProgram setUniformFloat:[naturalX floatValue] forName:@"kColorX"];
        [regProgram setUniformFloat:[naturalY floatValue] forName:@"kColorY"];
        
        glEnableClientState(GL_VERTEX_ARRAY);
        glBindBuffer(GL_ARRAY_BUFFER, pointBuffer);
        glVertexPointer(2, GL_FLOAT, 0, NULL);
		glDrawArrays(GL_POINTS, 0, FREENECT_FRAME_W*FREENECT_FRAME_H);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDisableClientState(GL_VERTEX_ARRAY);
        
        [regProgram unbind]; 
        
        glActiveTexture(GL_TEXTURE2);
        glDisable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glDisable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE0);
        glDisable(GL_TEXTURE_2D);
	}
	
	// Draw objects to the scene if we are in a point cloud view.
	if (mode >= 1) {
		[self drawFrustrum];
		[self drawCube:(KCCube){0, 0, -100, 20, 20, 20}];
	}
	
	// Log errors.
	GLint e = glGetError();
    if(e != 0) NSLog(@"GLERROR: %04x", e);
}
- (void)drawFrustrum {
    struct glf3 {
        GLfloat x,y,z;
    } verts[] = {
        {0,    0,  30},
        {640,  0,  30},
        {640,480,  30},
        {0,  480,  30},
        {0,    0,2048},
        {640,  0,2048},
        {640,480,2048},
        {0,  480,2048}
    };
    for(int i = 0; i < sizeof(verts)/sizeof(verts[0]); i++) {
        struct glf3 *v = verts+i;
        const float KinectMinDistance = -10;
        const float KinectDepthScaleFactor = .0021f;
        v->x = (v->x - FREENECT_FRAME_W/2) * (v->z + KinectMinDistance) * KinectDepthScaleFactor ;
        v->y = (v->y - FREENECT_FRAME_H/2) * (v->z + KinectMinDistance) * KinectDepthScaleFactor ;
        v->z = 200 - v->z;
    }
    GLubyte inds[] = {0,1, 1,2 , 2,3, 3,0,   4,5, 5,6, 6,7, 7,4, 0,4,   1,5, 2,6, 3, 7}; // front, back, side
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glColor4f(1, 1, 1, 0.5);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(3, GL_FLOAT, sizeof(verts[0]), &verts->x); 
    glDrawElements(GL_LINES, sizeof(inds)/sizeof(inds[0]), GL_UNSIGNED_BYTE, inds);
    glDisableClientState(GL_VERTEX_ARRAY);
    
    glDisable(GL_BLEND);
}
- (void)drawCube:(KCCube)cube {
	struct glf3 {
        GLfloat x,y,z;
    } verts[] = {
        {cube.x,			cube.y,				cube.z},			//1						  ___________
		{cube.x+cube.width,	cube.y,				cube.z},			//2						8/			 \7
        {cube.x+cube.width,	cube.y+cube.height,	cube.z},			//3						 |			 |
        {cube.x,			cube.y+cube.height,	cube.z},			//4		  _______		 |	  Back	 |
        {cube.x,			cube.y,				cube.z+cube.length},//5		4/		 \3		 |			 |
        {cube.x+cube.width,	cube.y,				cube.z+cube.length},//6		 | Front |		5\___________/6
        {cube.x+cube.width,	cube.y+cube.height,	cube.z+cube.length},//7		 |		 |
        {cube.x,			cube.y+cube.height,	cube.z+cube.length}	//8		1\_______/2
    };
    /*for(int i = 0; i < sizeof(verts)/sizeof(verts[0]); i++) {
        struct glf3 *v = verts+i;
        const float KinectMinDistance = -10;
        const float KinectDepthScaleFactor = .0021f;
        v->x = (v->x - FREENECT_FRAME_W/2) * (v->z + KinectMinDistance) * KinectDepthScaleFactor ;
        v->y = (v->y - FREENECT_FRAME_H/2) * (v->z + KinectMinDistance) * KinectDepthScaleFactor ;
        v->z = 200 - v->z;
    }*/
    GLubyte inds[] = {0,1, 1,2 , 2,3, 3,0,   4,5, 5,6, 6,7, 7,4, 0,4,   1,5, 2,6, 3, 7}; // front, back, side
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glColor4f(1, 1, 1, 0.5);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(3, GL_FLOAT, sizeof(verts[0]), &verts->x); 
    glDrawElements(GL_LINES, sizeof(inds)/sizeof(inds[0]), GL_UNSIGNED_BYTE, inds);
    glDisableClientState(GL_VERTEX_ARRAY);
    
    glDisable(GL_BLEND);
}
- (void)frameForTime:(const CVTimeStamp *)outputTime {
	[self drawRect:NSZeroRect];
}

// Mouse & Keyboard Events
- (BOOL)acceptsFirstResponder {
	return YES;
}
- (void)mouseDown:(NSEvent*)event {
    lastPosition = [self convertPoint:[event locationInWindow] fromView:nil];	
}
- (void)mouseDragged:(NSEvent*)event {
    if ([viewMode isSelectedForSegment:0]) {
		return;
	}
    NSPoint pos = [self convertPoint:[event locationInWindow] fromView:nil];
    NSPoint delta = NSMakePoint((pos.x-lastPosition.x)/[self bounds].size.width, (pos.y-lastPosition.y)/[self bounds].size.height);
    lastPosition = pos;
    
    if([event modifierFlags] & NSShiftKeyMask) {
        offsetPosition[0] += 2*delta.x;
        offsetPosition[1] += 2*delta.y;
    } else {
        angle += 50*delta.x;
        tilt  += 50*delta.y;
    }
}
- (void)scrollWheel:(NSEvent *)event {
	if ([viewMode isSelectedForSegment:0]) {
		return;
	}
    float d = ([event modifierFlags] & NSShiftKeyMask) ? [event deltaX] : [event deltaY];
    offsetPosition[2] += d*0.1;
    if(offsetPosition[2] < 0.5) offsetPosition[2] = 0.5;
}
- (void)keyDown:(NSEvent *)event {
    if ([viewMode isSelectedForSegment:0]) {
		return;
	}
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    switch(key) {
        case 'c': case 'C':
            angle = 0;
            tilt  = 0;
            break;
        case 'z': case 'Z':
            offsetPosition[0] = 0;
            offsetPosition[1] = 0;
            offsetPosition[2] = 5;
            break;
        case NSLeftArrowFunctionKey:  offsetPosition[0]-=0.1; break;
        case NSRightArrowFunctionKey: offsetPosition[0]+=0.1; break;
        case NSDownArrowFunctionKey:  offsetPosition[1]-=0.1; break;
        case NSUpArrowFunctionKey:    offsetPosition[1]+=0.1; break;
    }
}

@end
