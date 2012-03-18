//
//  KCVerticalCell.m
//  KinectiCopter
//
//  Created by James Reuss on 13/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//
//	All included libraries are property of their respective owners.
//

#import "KCVerticalCell.h"

@interface KCVerticalCell (Private)
- (void)drawCellRangeWithFrontMin:(float)xFrontMin FrontMax:(float)xFrontMax BackMin:(float)xBackMin BackMax:(float)xBackMax;
- (void)drawCenterPoint;
@end

@implementation KCVerticalCell

// For a cell of certain size and position it should find the highest (y) point in that region.
// So this class will be passed a point (x, y, z) and it will determine if this point is in its range and whether it is the highest point in that range it has came across.

//------------------------------------------------------------
// Initialisation
//------------------------------------------------------------
- (id)initWithCenterX:(float)x CenterZ:(float)z WidthX:(float)width DepthZ:(float)depth MinimumY:(float)minY {
	self = [super init];
    if (self) {
        centerX = x;
		centerZ = z;
		widthX = width;
		depthZ = depth;
		minimumY = minY;
		highestY = minY;
		
		colourR = rand() % 256;
		colourG = rand() % 256;
		colourB = rand() % 256;
		colourR = colourR / 255;
		colourG = colourG / 255;
		colourB = colourB / 255;
		
		linearPoint.x = 0;
		linearPoint.y = 0;
		linearPoint.z = 0;
    }
    return self;
}
- (id)init {
	NSLog(@"For best performance do not use [KCVerticalCell init], use [KCVerticalCell initWithCenterX:].");
	return [self initWithCenterX:0 CenterZ:0 WidthX:0 DepthZ:0 MinimumY:0];
}
- (void)initAlignmentValuesFrameW:(int)fw FrameH:(int)fh AspectRatio:(float)ar MinDepth:(int)md ScaleFactor:(float)sf {
	frameWidth = fw;
	frameHeight = fh;
	aspectRatio = ar;
	minDepth = md;
	scaleFactor = sf;
}

//------------------------------------------------------------
// Setters
//------------------------------------------------------------
- (void)setCenterX:(float)value {
	centerX = value;
}
- (void)setCenterZ:(float)value {
	centerZ = value;
}
- (void)setWidthX:(float)value {
	widthX = value;
}
- (void)setDepthZ:(float)value {
	depthZ = value;
}
- (void)setMinimumY:(float)value {
	minimumY = value;
}
- (void)setHighestY:(float)value {
	highestY = value;
}
- (void)changeLineColour {
	colourR = rand() % 256;
	colourG = rand() % 256;
	colourB = rand() % 256;
	NSLog(@"R:%f G:%f B:%f", colourR, colourG, colourB);
	colourR = colourR / 255;
	colourG = colourG / 255;
	colourB = colourB / 255;
	NSLog(@"R:%f G:%f B:%f", colourR, colourG, colourB);
}

//------------------------------------------------------------
// Processing
//------------------------------------------------------------
- (void)checkPointWithX:(float)x Y:(float)y Z:(float)z {
	if (z >= centerZ-depthZ && z <= centerZ+depthZ) {
		// Get the x bounds for depth.
		float xmin = ((centerX-widthX)-frameWidth/2)*(z+minDepth)*scaleFactor*aspectRatio;
		float xmax = ((centerX+widthX)-frameWidth/2)*(z+minDepth)*scaleFactor*aspectRatio;
		if (x >= xmin && x <= xmax) {
			if (y > highestY) {
				highestY = y;
			}
		}
	}
}
- (float)getCenterX {
	return centerX;
}
- (float)getCenterZ {
	return centerZ;
}
- (float)getHighestY {
	return highestY;
}
- (KCPoint)getLinearPoint {
	// First get the actual center point in the cell and return it.
	linearPoint.x = ((centerX-widthX)-frameWidth/2)*(centerZ+minDepth)*scaleFactor*aspectRatio;
	linearPoint.y = highestY;
	linearPoint.z = centerZ;
	return linearPoint;
}
- (void)resetCell {
	highestY = minimumY;
}

//------------------------------------------------------------
// Drawing
//------------------------------------------------------------
- (void)drawCell {
	// Get the cell corners.
	float xFrontMin = ((centerX-widthX)-frameWidth/2)*((centerZ-depthZ)+minDepth)*scaleFactor*aspectRatio;
	float xFrontMax = ((centerX+widthX)-frameWidth/2)*((centerZ-depthZ)+minDepth)*scaleFactor*aspectRatio;
	float xBackMin = ((centerX-widthX)-frameWidth/2)*((centerZ+depthZ)+minDepth)*scaleFactor*aspectRatio;
	float xBackMax = ((centerX+widthX)-frameWidth/2)*((centerZ+depthZ)+minDepth)*scaleFactor*aspectRatio;
	glLineWidth(2.0f);
	glBegin(GL_LINE_LOOP);
	glColor3f(colourR, colourG, colourB);
	glVertex3f(xBackMin, highestY, -centerZ-depthZ);
	glVertex3f(xBackMax, highestY, -centerZ-depthZ);
	glVertex3f(xFrontMax, highestY, -centerZ+depthZ);
	glVertex3f(xFrontMin, highestY, -centerZ+depthZ);
	glEnd();
	
	//[self drawCellRangeWithFrontMin:xFrontMin FrontMax:xFrontMax BackMin:xBackMin BackMax:xBackMax];
	//[self drawCenterPoint];
}
- (void)drawCellRangeWithFrontMin:(float)xFrontMin FrontMax:(float)xFrontMax BackMin:(float)xBackMin BackMax:(float)xBackMax {
	glLineWidth(1.0f);
	// Front
	glBegin(GL_LINE_LOOP);
	glColor4f(255, 255, 255, 0);
	glVertex3f(xBackMin, highestY-400, -centerZ-depthZ);
	glVertex3f(xBackMax, highestY-400, -centerZ-depthZ);
	glColor4f(255, 255, 255, 1);
	glVertex3f(xBackMax, highestY, -centerZ-depthZ);
	glVertex3f(xBackMin, highestY, -centerZ-depthZ);
	glEnd();
	// Back
	glBegin(GL_LINE_LOOP);
	glColor4f(255, 255, 255, 0);
	glVertex3f(xFrontMax, highestY-400, -centerZ+depthZ);
	glVertex3f(xFrontMin, highestY-400, -centerZ+depthZ);
	glColor4f(255, 255, 255, 1);
	glVertex3f(xFrontMin, highestY, -centerZ+depthZ);
	glVertex3f(xFrontMax, highestY, -centerZ+depthZ);
	glEnd();
}
- (void)drawCenterPoint {
	glPointSize(3.0f);
	glBegin(GL_POINTS);
	glColor3f(colourR, colourG, colourB);
	glVertex3f((centerX-frameWidth/2)*(centerZ+minDepth)*scaleFactor*aspectRatio, highestY, -centerZ);
	glEnd();
}

@end
