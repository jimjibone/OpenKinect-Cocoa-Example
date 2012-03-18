//
//	Kinect Cloud.h
//	Cloud Viewer
//
//	Created by James Reuss on 07/03/2012.
//	Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>

#define FREENECT_FRAME_W 640
#define FREENECT_FRAME_H 480

@interface Kinect_Cloud : NSObject {
	// Settings Variables.
	BOOL useColourMap;
	BOOL useCloudFile;
	
	// Alignment Variables.
	int	  frameWidth;
	int	  frameHeight;
	float aspectRatio;
	int   minDepth;
	float scaleFactor;
	
	// Calculation Variables.
	
	// Point Cloud Variables.
	float pointCloud[640][480][3+3];
	uint16_t colourMap[10000];
}

// Initialisation
- (id)initWithValue:(int)value;
- (id)init;

// Point Cloud Methods
- (void)setPointCloudWithDepth:(uint16_t*)depth Video:(uint8_t*)video;
- (void)setUseColourMap:(BOOL)useit;

// Cloud File Methods
- (void)importPointCloud:(NSWindow*)window;
- (void)exportPointCloud:(NSWindow*)window;
- (void)stopImportedPointCloud;

// Calculation Methods

// Draw Methods
- (void)drawPointCloud;

@end
