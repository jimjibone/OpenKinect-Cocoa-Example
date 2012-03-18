//
//  KCVerticalGrid.m
//  KinectiCopter
//
//  Created by James Reuss on 15/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//

#import "KCVerticalGrid.h"

@interface KCVerticalGrid (Private)
- (void)setupGrid;
// Draw
- (void)drawBounds;
@end

@implementation KCVerticalGrid

- (void)dealloc {
	for (int i = 0; i < XCELLS; i++) {
		for (int j = 0; j < ZCELLS; j++) {
			[grid[i][j] release];
		}
	}
	
	[super dealloc];
}

//------------------------------------------------------------
// Initialisation
//------------------------------------------------------------
- (id)initGridWithXLeft:(float)xleft XRight:(float)xright ZFront:(float)zfront ZBack:(float)zback AndMinY:(float)ymin {
	self = [super init];
    if (self) {
        xLeft = xleft;
		xRight = xright;
		zFront = zfront;
		zBack = zback;
		yMinimum = ymin;
		
		// Find the increments of Center X/Z to use with the cells. And the spacings of X/Z.
		xSpacing = (xRight - xLeft) / 2;
		zSpacing = (zBack - zFront) / 2;
		
		for (int i = 0; i < XCELLS; i++) {
			for (int j = 0; j < ZCELLS; j++) {
				grid[i][j] = [[KCVerticalCell alloc] initWithCenterX:(xLeft + xSpacing * (i)) 
															 CenterZ:(zFront + zSpacing * (j)) 
															  WidthX:xSpacing 
															  DepthZ:zSpacing 
															MinimumY:yMinimum];
			}
		}
    }
    return self;
}
- (id)init {
    return [self initGridWithXLeft:-100 XRight:100 ZFront:100 ZBack:1000 AndMinY:-1000];
}
- (void)initAlignmentValuesFrameW:(int)fw FrameH:(int)fh AspectRatio:(float)ar MinDepth:(int)md ScaleFactor:(float)sf {
	frameWidth = fw;
	frameHeight = fh;
	aspectRatio = ar;
	minDepth = md;
	scaleFactor = sf;
	for (int i = 0; i < XCELLS; i++) {
		for (int j = 0; j < ZCELLS; j++) {
			[grid[i][j] initAlignmentValuesFrameW:frameWidth 
										   FrameH:frameHeight 
									  AspectRatio:aspectRatio 
										 MinDepth:minDepth 
									  ScaleFactor:scaleFactor];
		}
	}
}

//------------------------------------------------------------
// Setters
//------------------------------------------------------------
- (void)setXLeft:(float)value {
	xLeft = value;
	[self setupGrid];
}
- (void)setXRight:(float)value {
	xRight = value;
	[self setupGrid];
}
- (void)setZFront:(float)value {
	zFront = value;
	[self setupGrid];
}
- (void)setZBack:(float)value {
	zBack = value;
	[self setupGrid];
}
- (void)setYMinimum:(float)value {
	yMinimum = value;
	[self setupGrid];
}
- (void)shiftXBy:(float)value {
	xLeft += value;
	xRight += value;
	[self setupGrid];
}
- (void)shiftZBy:(float)value {
	zFront += value;
	zBack += value;
	[self setupGrid];
}
- (void)setupGrid {
	// Find the increments of Center X/Z to use with the cells. And the spacings of X/Z.
	xSpacing = (xRight - xLeft) / XCELLS;
	zSpacing = (zBack - zFront) / ZCELLS;
	
	for (int i = 0; i < XCELLS; i++) {
		for (int j = 0; j < ZCELLS; j++) {
			[grid[i][j] setCenterX:(xLeft + xSpacing * i)];
			[grid[i][j] setCenterZ:(zFront + zSpacing *j)];
			[grid[i][j] setWidthX:xSpacing];
			[grid[i][j] setDepthZ:zSpacing];
			[grid[i][j] setMinimumY:yMinimum];
		}
	}
}

//------------------------------------------------------------
// Processing
//------------------------------------------------------------
- (void)checkGridWithX:(float)xvalue Y:(float)yvalue Z:(float)zvalue {
	for (int i = 0; i < XCELLS; i++) {
		for (int j = 0; j < ZCELLS; j++) {
			[grid[i][j] checkPointWithX:xvalue Y:yvalue Z:zvalue];
		}
	}
}
- (void)resetGrid {
	for (int i = 0; i < XCELLS; i++) {
		for (int j = 0; j < ZCELLS; j++) {
			[grid[i][j] resetCell];
		}
	}
}

//------------------------------------------------------------
// Draw
//------------------------------------------------------------
- (void)drawGrid {
	for (int i = 0; i < XCELLS; i++) {
		for (int j = 0; j < ZCELLS; j++) {
			[grid[i][j] drawCell];
		}
	}
	
	[self drawBounds];
}
- (void)drawBounds {
	// Get the cell corners.
	float xFrontLeft  = (xLeft-frameWidth/2)*(zFront+minDepth)*scaleFactor*aspectRatio;
	float xFrontRight = (xRight-frameWidth/2)*(zFront+minDepth)*scaleFactor*aspectRatio;
	float xBackLeft   = (xLeft-frameWidth/2)*(zBack+minDepth)*scaleFactor*aspectRatio;
	float xBackRight  = (xRight-frameWidth/2)*(zBack+minDepth)*scaleFactor*aspectRatio;
	glLineWidth(4.0f);
	glBegin(GL_LINE_LOOP);
	glColor3f(0, 255, 0);
	glVertex3f(xFrontLeft,  0, -zFront);
	glVertex3f(xFrontRight, 0, -zFront);
	glVertex3f(xBackRight,  0, -zBack);
	glVertex3f(xBackLeft,   0, -zBack);
	glEnd();
}

@end
