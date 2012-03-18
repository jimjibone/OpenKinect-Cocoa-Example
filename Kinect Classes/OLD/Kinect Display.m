//
//  Kinect Display.m
//  KinectiCopter
//
//  Created by James Reuss on 05/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//

#import "Kinect Display.h"

@interface Kinect_Display (Private)
// OpenGL Methods.
- (void)frameForTime:(const CVTimeStamp*)outputTime;
- (void)initScene;
- (void)drawScene;
@end

@implementation Kinect_Display

- (void)dealloc {
	CVDisplayLinkRelease(displayLink);
	[pointCloud release];
    [super dealloc];
}

//-------------------------------------------------
// OpenGL Methods.
//-------------------------------------------------
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
	@autoreleasepool {
		[(Kinect_Display*)displayLinkContext frameForTime:outputTime];
	}
	return kCVReturnSuccess;
}
- (void)frameForTime:(const CVTimeStamp *)outputTime {
	[self drawRect:NSZeroRect];
}
- (id)initWithFrame:(NSRect)frameRect {
    NSOpenGLPixelFormatAttribute attributes[] = 
	{
        NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, 32.0,
		NSOpenGLPFADepthSize, 32.0,
        0 
	};
	
    [self setPostsFrameChangedNotifications: YES];
	
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	
    self = [super initWithFrame:frameRect pixelFormat:format];
    [format release];
    
    [[self openGLContext] makeCurrentContext];
	
	// Do all my own initialisations.
	[self initScene];
	[controller setVideoMode:rgbMode];
	[controller setDepthMode:registeredDepth];
	pointCloud = [[Kinect_Cloud alloc] init];
	[pointCloud setUseColourMap:YES];
	
	// Set up orientation.
	offsetPosition[0] = 0;
    offsetPosition[1] = 0;
    offsetPosition[2] = 500;	// 1 metre back.
    angle = 0;
    tilt = -180;
	
    return self;
}
- (void)initScene {
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    
    glClearDepth(1.0f);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
    
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
}
- (void)prepareOpenGL {
	// Synchronise the buffer swaps with the vertical refresh rate.
	GLint swapInt = 1;
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
	
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	CVDisplayLinkSetOutputCallback(displayLink, &displayLinkCallback, self);
	
	// Set the display link for the current renderer.
	CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
	
	CVDisplayLinkStart(displayLink);
}
- (void)drawRect:(NSRect)dirtyRect {
	NSOpenGLContext *context = [self openGLContext];
	CGLLockContext([context CGLContextObj]);
	if ([context view]) {
		[context makeCurrentContext];
		
		[self drawScene];
		
		GLenum error = glGetError();
		if (error != GL_NO_ERROR) {
			//NSLog(@"GLError: %4x", error);
		}
		
		[context flushBuffer];
	}
	
	CGLUnlockContext([context CGLContextObj]);
}
- (void)drawScene {
	[controller setFrameViewed];	// Helps calculate the FPS.
	
	// Get the depth and video data.
	uint16_t *depth = [controller getDepthData];
	uint8_t *video = [controller getVideoData];
	
	[pointCloud setPointCloudWithDepth:depth Video:video];
	
	if (depth) free(depth);
	if (video) free(video);
	
	// Clear the buffers!
	glLoadIdentity();
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(40, NSWidth([self bounds])/NSHeight([self bounds]), 0.05, 5000);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glTranslatef(offsetPosition[0], offsetPosition[1], -offsetPosition[2]);
	glRotatef(angle, 0, 1, 0);
	glRotatef(tilt, -1, 0, 0);
	glScalef(0.5, 0.5, 0.5);
	
	glEnable(GL_DEPTH_TEST);
	
	[pointCloud drawPointCloud];
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
    NSView *view = [context view];
    if(view) {
        NSSize size = [self bounds].size;
        [context makeCurrentContext];
        glViewport(0, 0, size.width, size.height);
    }    
    CGLUnlockContext([context CGLContextObj]);
}

//-------------------------------------------------
// Mouse & Keyboard Events
//-------------------------------------------------
- (BOOL)acceptsFirstResponder {
	return YES;
}
- (void)mouseDown:(NSEvent*)event {
    lastPosition = [self convertPoint:[event locationInWindow] fromView:nil];	
}
- (void)mouseDragged:(NSEvent*)event {
    if (0) {
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
- (void)scrollWheel:(NSEvent*)event {
	if (0) {
		return;
	}
    float d = ([event modifierFlags] & NSShiftKeyMask) ? [event deltaY]*10 : [event deltaY];
    offsetPosition[2] += d*0.1;
    if(offsetPosition[2] < 0.5) offsetPosition[2] = 0.5;
}
- (void)keyDown:(NSEvent*)event {
    if (0) {
		return;
	}
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    switch(key) {
        case 'z':
            offsetPosition[0] = 0;
            offsetPosition[1] = 0;
            offsetPosition[2] = 500;
			angle = 0;
            tilt  = -180;
            break;
		case 's':
            offsetPosition[0] = 0;
            offsetPosition[1] = 0;
            offsetPosition[2] = 2900;
			angle = 90;
            tilt  = -180;
            break;
		case 'p':
            NSLog(@"offset x:%f y:%f z:%f", offsetPosition[0], offsetPosition[1], offsetPosition[2]);
            NSLog(@"angle:%f", angle);
            NSLog(@"tilt:%f", tilt);
            break;
        case NSLeftArrowFunctionKey:  offsetPosition[0]-=10; break;
        case NSRightArrowFunctionKey: offsetPosition[0]+=10; break;
        case NSDownArrowFunctionKey:  offsetPosition[1]-=10; break;
        case NSUpArrowFunctionKey:    offsetPosition[1]+=10; break;
    }
}

@end
