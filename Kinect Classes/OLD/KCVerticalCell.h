//
//  KCVerticalCell.h
//  KinectiCopter
//
//  Created by James Reuss on 13/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//
//	All included libraries are property of their respective owners.
//

#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>

typedef struct {
	float x;
	float y;
	float z;
} KCPoint;

@interface KCVerticalCell : NSObject {
	float centerX, centerZ;
	float widthX, depthZ;
	float minimumY;
	float highestY;
	float colourR, colourG, colourB;
	
	KCPoint linearPoint;
	
	// Alignment Variables.
	int	  frameWidth;
	int	  frameHeight;
	float aspectRatio;
	int   minDepth;
	float scaleFactor;
}

// Initialisation
- (id)initWithCenterX:(float)x CenterZ:(float)z WidthX:(float)width DepthZ:(float)depth MinimumY:(float)minY;
- (void)initAlignmentValuesFrameW:(int)fw FrameH:(int)fh AspectRatio:(float)ar MinDepth:(int)md ScaleFactor:(float)sf;

// Setters
- (void)setCenterX:(float)value;
- (void)setCenterZ:(float)value;
- (void)setWidthX:(float)value;
- (void)setDepthZ:(float)value;
- (void)setMinimumY:(float)value;
- (void)setHighestY:(float)value;
- (void)changeLineColour;

// Processing
- (void)checkPointWithX:(float)x Y:(float)y Z:(float)z;
- (float)getCenterX;
- (float)getCenterZ;
- (float)getHighestY;
- (KCPoint)getLinearPoint;
- (void)resetCell;

// Drawing
- (void)drawCell;

@end
