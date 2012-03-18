//
//  Kinect Processing.m
//  KinectiCopter
//
//  Created by James Reuss on 12/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//	https://github.com/jimjibone
//	http://jamesreuss.wordpress.com/
//
//	All included libraries are property of their respective owners.
//	Feel free to take this code and use it yourself :) If you do
//	use the code exactly as you see it here though please keep me
//	referenced. Thanks :)
//

#import "Kinect Processing.h"

@interface Kinect_Processing (Private)
// Processing
- (void)initialiseProcessing;
- (void)processCloud;

// Point Cloud
- (void)populatePointCloudWithDepth:(uint16_t*)depth Video:(uint8_t*)video;

// OpenGL Methods
- (void)initOpenGL;
- (void)frameForTime:(const CVTimeStamp*)outputTime;
- (void)drawBegin;
- (void)drawPointCloud;
- (void)drawFrustum;
@end

@implementation Kinect_Processing

- (void)dealloc {
	[self stopProcessing];
	[super dealloc];
}

//------------------------------------------------------------
// Processing Methods
//------------------------------------------------------------
- (void)initialiseProcessing {
	// Set up the alignment variables.
	frameWidth = FREENECT_FRAME_W;
	frameHeight = FREENECT_FRAME_H;
	aspectRatio = FREENECT_FRAME_W/FREENECT_FRAME_H;
	minDepth = -10;
	scaleFactor = 0.0021;
	
	// Initialise the point cloud.
	_usePCF = NO;
	for (int i = 0; i < frameWidth; i++) {
		for (int j = 0; j < frameHeight; j++) {
			pointCloud[i][j][0] = i;	// x pos.
			pointCloud[i][j][1] = j;	// y pos.
			pointCloud[i][j][2] = 0;	// depth.
			pointCloud[i][j][3] = 255;	// red.
			pointCloud[i][j][4] = 255;	// green.
			pointCloud[i][j][5] = 255;	// blue.
		}
	}
	
	// Initialise things...
	
	pointSkip = 1;
}
- (void)processCloud {
	// Get the Kinect data.
	[controller setFrameViewed];
	uint16_t *depth = [controller getDepthData];
	uint8_t *video = [controller getVideoData];
	
	// Put the Kinect data into the relevant places for processing.
	if (!_usePCF) {
		[self populatePointCloudWithDepth:depth Video:video];
		// Fill OpenCV video variable to be used for point tracking.
	}
	
	// Free the Kinect data.
	free(depth);
	free(video);
	
	// Process the Kinect data that has been collected.
	
	// Draw the Processed data to the screen.
	[self drawPointCloud];
	
	[self drawFrustum];
}
- (void)stopProcessing {
	// Stop Drawing.
	CVDisplayLinkRelease(displayLink);
	
	// Release processing objects.
}

//------------------------------------------------------------
// Point Cloud Methods
//------------------------------------------------------------
- (void)populatePointCloudWithDepth:(uint16_t*)depth Video:(uint8_t*)video {
	uint16_t depthValue;
	int videoOffset;
	
	for (uint16_t i = 0; i < frameWidth; i++) {
		for (uint16_t j = 0; j < frameHeight; j++) {
			// Get the current depth and video points.
			if (depth) {
				depthValue = depth[i+j*frameWidth];
				// Fill the cloud.
				pointCloud[i][j][0] = (i-frameWidth/2)*(depthValue+minDepth)*scaleFactor*aspectRatio;	// x pos.
				pointCloud[i][j][1] = -(j-frameHeight/2)*(depthValue+minDepth)*scaleFactor;	// y pos. (invert as it comes in upside-down)
				pointCloud[i][j][2] = depthValue;	// depth.
			}
			if (video) {
				videoOffset = 3*(i+j*frameWidth);
				// Fill the cloud.
				pointCloud[i][j][3] = video[3*(i+j*frameWidth)]/255.0;	// red.
				pointCloud[i][j][4] = video[3*(i+j*frameWidth)+1]/255.0;	// green.
				pointCloud[i][j][5] = video[3*(i+j*frameWidth)+2]/255.0;	// blue.
			}
		}
	}
}

//------------------------------------------------------------
// Processed View Controls
//------------------------------------------------------------
- (IBAction)resetView:(id)sender {
	offsetPosition[0] = 0;
	offsetPosition[1] = 0;
	offsetPosition[2] = 500;
	angle = 0;
	tilt  = 0;
}
- (IBAction)topView:(id)sender {
	offsetPosition[0] = 0;
	offsetPosition[1] = -160;
	offsetPosition[2] = 1460;
	angle = 0;
	tilt  = -75;
}

//------------------------------------------------------------
// Point Cloud File Methods
//------------------------------------------------------------
- (void)openWithFile:(NSURL*)path {
	// This will load in a file of a previously captured point cloud
	//  and then set the current point cloud to only display the loaded
	//  data instead of new data (if present).
	if (path) {
		NSData *newPointCloud = [[NSData alloc] initWithContentsOfURL:path];
		memcpy(&pointCloud, [newPointCloud bytes], [newPointCloud length]);
		[newPointCloud release];
		
		_usePCF = YES;
	}
}
- (IBAction)importPointCloud:(id)sender {
	// This will load in a file of a previously captured point cloud
	//  and then set the current point cloud to only display the loaded
	//  data instead of new data (if present).
	
	// Show the open window for the user.
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			NSURL *filePath = [[openPanel URLs] objectAtIndex:0];
			NSData *newPointCloud = [[NSData alloc] initWithContentsOfURL:filePath];
			memcpy(&pointCloud, [newPointCloud bytes], [newPointCloud length]);
			[newPointCloud release];
			
			_usePCF = YES;
		}
	}];
}
- (IBAction)exportPointCloud:(id)sender {
	// This will take a snapshot of the current point cloud
	//	and save it to a file that the user selects.
	
	// Copy the point cloud data ready for the file.
	NSData *pointCloudData = [[NSData alloc] initWithBytes:&pointCloud length:sizeof(pointCloud)];
	
	/*// Get the current date and time for the file.
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyMMdd-HHmmss"];
	NSDate *date = [NSDate date];*/
	
	// Set up a string for the default file name.
	NSString *defaultName = [NSString stringWithString:@"Kinect Point Cloud"];
	defaultName = [defaultName stringByAppendingPathExtension:@"pcf"];
	
	// Show the save window for the user.
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setNameFieldStringValue:defaultName];
	[savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			// Save the data to the new file to the selected location.
			NSURL *filePath = [savePanel URL];
			[pointCloudData writeToURL:filePath atomically:NO];
		}
	}];
	
	// Clean up.
	//[dateFormatter release];
	[pointCloudData release];
}
- (IBAction)stopImportedPointCloud:(id)sender {
	_usePCF = NO;
}

//------------------------------------------------------------
// OpenGL Initialisation Methods
//------------------------------------------------------------
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
	@autoreleasepool {
		[(Kinect_Processing*)displayLinkContext frameForTime:outputTime];
	}
	return kCVReturnSuccess;
}
- (id)initWithFrame:(NSRect)frameRect {
	NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, 32.0,
		NSOpenGLPFADepthSize, 32.0,
        0 
	};
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	self = [super initWithFrame:frameRect pixelFormat:format];
    [format release];
	
	[[self openGLContext] makeCurrentContext];
    
	// Initialise.
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClearDepth(1.0f);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
	
	glViewport(0, 0, NSWidth([self bounds]), NSHeight([self bounds]));
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(45, NSWidth([self bounds])/NSHeight([self bounds]), 0.1, 5000);
    glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	pointSkip = 1; // Can never be less than 1!
	
	// Set up orientation.
	[self resetView:nil];
	
	[self initialiseProcessing];
	
	return self;
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

//------------------------------------------------------------
// OpenGL Methods
//------------------------------------------------------------
- (void)frameForTime:(const CVTimeStamp *)outputTime {
	[self drawRect:NSZeroRect];
}
- (void)drawRect:(NSRect)dirtyRect {
	NSOpenGLContext *context = [self openGLContext];
	CGLLockContext([context CGLContextObj]);
	if ([context view]) {
		[context makeCurrentContext];
		
		[self drawBegin];
		[self processCloud];
		
		GLenum error = glGetError();
		if (error != GL_NO_ERROR) {
			NSLog(@"GLError: %4x", error);
		}
		
		glDisable(GL_BLEND);
		[context flushBuffer];
	}
	
	CGLUnlockContext([context CGLContextObj]);
}
- (void)drawBegin {
	[[self openGLContext] makeCurrentContext];
	
	glLoadIdentity();
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(40, NSWidth([self bounds])/NSHeight([self bounds]), 0.05, 5000);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glTranslatef(offsetPosition[0], offsetPosition[1], -offsetPosition[2]);
	glTranslatef(0, 0, -500);
	glRotatef(angle, 0, 1, 0);
	glRotatef(tilt, -1, 0, 0);
	glTranslatef(0, 0, 500);
	glScalef(0.25, 0.25, 0.25);
	
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}
- (void)drawPointCloud {
	if (pointSkip < 1) pointSkip = 1;
	glPointSize(pointSkip);
	glBegin(GL_POINTS);
    for (int i = 0; i < 640; i += pointSkip) {
        for (int j = 0; j < 480; j += pointSkip) {
			if (pointCloud[i][j][2] != 0) {
				glColor3f(pointCloud[i][j][3], pointCloud[i][j][4], pointCloud[i][j][5]);
				glVertex3f(pointCloud[i][j][0] , pointCloud[i][j][1], -pointCloud[i][j][2]);
			}
        }
    }
    glEnd();
}
- (void)drawFrustum {
	float xLeft	  = (0-frameWidth/2)*(2000+minDepth)*scaleFactor*aspectRatio;
	float xRight  = (frameWidth-frameWidth/2)*(2000+minDepth)*scaleFactor*aspectRatio;
	float yTop    = -(frameHeight-frameHeight/2)*(2000+minDepth)*scaleFactor;
	float yBottom = -(0-frameHeight/2)*(2000+minDepth)*scaleFactor;
	
	glLineWidth(1.0f);
	glBegin(GL_LINES);
	glColor3f(255, 0, 0);
	// Left Bottom
	glVertex3f(0,		0,			0);
	glVertex3f(xLeft,	yBottom,	-2000);
	// Left Top
	glVertex3f(0,		0,			0);
	glVertex3f(xLeft,	yTop,		-2000);
	// Right Top
	glVertex3f(0,		0,			0);
	glVertex3f(xRight,	yTop,		-2000);
	// Right Bottom
	glVertex3f(0,		0,			0);
	glVertex3f(xRight,	yBottom,	-2000);
	glEnd();
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
		case 's':
			NSLog(@"ERR - Shift Z.");
			break;
		case 'w':
			NSLog(@"ERR + Shift Z.");
			break;
		case 'a':
			NSLog(@"ERR - Shift X.");
			break;
		case 'd':
			NSLog(@"ERR + Shift X.");
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
