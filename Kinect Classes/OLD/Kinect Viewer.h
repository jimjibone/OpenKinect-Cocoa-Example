//
//  Kinect Viewer.h
//  KinectiCopter
//
//  Created by James Reuss on 29/02/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//
//	All included libraries are property of their respective owners.
//

#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#import <CoreVideo/CoreVideo.h>
#import "Kinect Controller.h"
#import "GLProgram.h"

@interface Kinect_Viewer : NSOpenGLView {
	// Kinect Controls.
	IBOutlet Kinect_Controller *controller;
	
	// View.
	CVDisplayLinkRef displayLink;
    GLuint depthTexture, videoTexture, depthColourTexture;
    GLuint pointBuffer;
    GLuint *indicies;
    int nTriIndicies;
	int mode;	// 0 = Flat Mode. 1 = Point Cloud Mode.
	float regOffset, regScale, regSecondScale;
    
    // 3D Navigation.
    NSPoint lastPosition;
    float offsetPosition[3];
    float angle, tilt;
	
	// Display Programs.
	GLProgram *regProgram;
	GLProgram *pointProgram;
    GLProgram *depthProgram;
}
@property (assign) IBOutlet NSButton *useNormals, *useNatural, *useMMDepth;
@property (assign) IBOutlet NSSegmentedControl *viewMode;
@property (assign) IBOutlet NSSlider *naturalScale, *naturalX, *naturalY;
@property (assign) IBOutlet NSTextField *naturalScaleVal, *naturalXVal, *naturalYVal;
@property (assign) IBOutlet NSTextField *midPointDepth, *scaleEquation;
@property (assign) IBOutlet NSTextField *red, *green, *blue;

- (IBAction)changeRegOffset:(id)sender;
- (IBAction)changeRegScale:(id)sender;
- (IBAction)changeRegSecondScale:(id)sender;

@end
