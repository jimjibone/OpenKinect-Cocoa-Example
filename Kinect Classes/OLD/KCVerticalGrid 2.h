//
//  KCVerticalGrid.h
//  KinectiCopter
//
//  Created by James Reuss on 15/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

typedef struct {
	float x;
    float y;
    float z;
    GLfloat colour[3];
    float frontLeft, frontRight, backRight, backLeft;
} KCPointCell;

/* THE GRID
    Back
 | A3 | B3 | C3 |
 | A2 | B2 | C2 |
 | A1 | B1 | C1 |
    Front */

@interface KCVerticalGrid : NSObject {
	// Bounds
    float front, back, left, right;
    float zSpacing, xSpacing;
    float zBound1, zBound2, zBound3, zBound4;   // Front --to-- Back
    float xBound1, xBound2, xBound3, xBound4;   // Left  --to-- Right
    
    // Grid
    KCPointCell C1, C2, C3;
    KCPointCell B1, B2, B3;
    KCPointCell A1, A2, A3;
    
    // Drawing
    KCPointCell frontLeft, frontRight, backLeft, backRight;
	
	// Alignment Variables.
	int	  frameWidth;
	int	  frameHeight;
	float aspectRatio;
	int   minDepth;
	float scaleFactor;
}

- (id)initGridWithFront:(float)zfront Back:(float)zback Left:(float)xleft Right:(float)xright;

- (void)shiftGridXBy:(float)value;
- (void)shiftGridZBy:(float)value;

- (void)checkGridWithX:(float)xpoint Y:(float)ypoint Z:(float)zpoint;

- (void)drawGrid;

@end
