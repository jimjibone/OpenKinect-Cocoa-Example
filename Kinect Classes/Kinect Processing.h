//
//  Kinect Processing.h
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

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import "Kinect Controller.h"

@interface Kinect_Processing : NSOpenGLView {
	IBOutlet Kinect_Controller *controller;
    IBOutlet NSWindow *window;
	
	// Alignment Variables.
	int	  frameWidth;
	int	  frameHeight;
	float aspectRatio;
	int   minDepth;
	float scaleFactor;
	
	// Point Cloud Data.
    BOOL _usePCF;
    float pointCloud[640][480][3+3];
	
	// Processing
	
	
	// Processed View.
	CVDisplayLinkRef displayLink;
	NSPoint lastPosition;
    float offsetPosition[3];
    float angle, tilt;
	int pointSkip;
}

- (void)stopProcessing;

// Processed View Controls.
- (IBAction)resetView:(id)sender;
- (IBAction)topView:(id)sender;

// Point Cloud File Methods
- (void)openWithFile:(NSURL*)path;
- (IBAction)importPointCloud:(id)sender;
- (IBAction)exportPointCloud:(id)sender;
- (IBAction)stopImportedPointCloud:(id)sender;

@end
