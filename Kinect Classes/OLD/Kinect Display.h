//
//  Kinect Display.h
//  KinectiCopter
//
//  Created by James Reuss on 05/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/glu.h>
#import "Kinect Controller.h"
#import "Kinect Cloud.h"

@interface Kinect_Display : NSOpenGLView {
	// Kinect Controls.
	IBOutlet Kinect_Controller *controller;
	
	// View.
	CVDisplayLinkRef displayLink;
	Kinect_Cloud *pointCloud;
	
	// Point Cloud Navigation.
    NSPoint lastPosition;
    float offsetPosition[3];
    float angle, tilt;
}

@end
