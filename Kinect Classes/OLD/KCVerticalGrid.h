//
//  KCVerticalGrid.h
//  KinectiCopter
//
//  Created by James Reuss on 15/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KCVerticalCell.h"

#define XCELLS 2
#define ZCELLS 2

@interface KCVerticalGrid : NSObject {
	float xLeft, xRight, zFront, zBack, yMinimum;
    
    float xSpacing, zSpacing;
    
    KCVerticalCell *grid[XCELLS][ZCELLS];
	
	// Alignment Variables.
	int	  frameWidth;
	int	  frameHeight;
	float aspectRatio;
	int   minDepth;
	float scaleFactor;
}

// Initialisation
- (id)initGridWithXLeft:(float)xleft XRight:(float)xright ZFront:(float)zfront ZBack:(float)zback AndMinY:(float)ymin;
- (void)initAlignmentValuesFrameW:(int)fw FrameH:(int)fh AspectRatio:(float)ar MinDepth:(int)md ScaleFactor:(float)sf;

// Setters
- (void)setXLeft:(float)value;
- (void)setXRight:(float)value;
- (void)setZFront:(float)value;
- (void)setZBack:(float)value;
- (void)setYMinimum:(float)value;
- (void)shiftXBy:(float)value;
- (void)shiftZBy:(float)value;

// Processing
- (void)checkGridWithX:(float)xvalue Y:(float)yvalue Z:(float)zvalue;
- (void)resetGrid;

// Draw
- (void)drawGrid;

@end
