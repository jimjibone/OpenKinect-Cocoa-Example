//
//  KCVerticalGrid.m
//  KinectiCopter
//
//  Created by James Reuss on 15/03/2012.
//  Copyright (c) 2012 James Reuss. All rights reserved.
//

#import "KCVerticalGrid.h"

@interface KCVerticalGrid (Private)
// Setup
- (void)setupXBounds;
- (void)setupZBounds;
- (KCPointCell)setupCellWithLeft:(float)xleft Right:(float)xright Front:(float)zfront Back:(float)zback;
- (void)setupAllCells;
- (void)setupGridBounds;
- (float)xForZ:(float)zvalue X:(float)xvalue;
- (float)yForZ:(float)zvalue Y:(float)yvalue;

// Draw
- (void)drawCellBoundsForCell:(KCPointCell)cell;
- (void)drawBounds;
@end

@implementation KCVerticalGrid

- (id)initGridWithFront:(float)zfront Back:(float)zback Left:(float)xleft Right:(float)xright {
    self = [super init];
    if (self) {
		// Setup bounds
        front = zfront;
		back = zback;
		left = xleft;
		right = xright;
		zSpacing = (back - front) / 4;
		xSpacing = (right - left) / 4;
		
		// Setup alignment variables.
		frameWidth = 640;
		frameHeight = 480;
		aspectRatio = 640/480;
		minDepth = -10;
		scaleFactor = 0.0021;
		
		[self setupZBounds];
		[self setupXBounds];
		
		// Setup the cells.
		[self setupAllCells];
    }
    return self;
}

- (void)shiftGridXBy:(float)value {
	// Setup bounds
	left += value;
	right += value;
	xSpacing = (right - left) / 4;
	
	[self setupXBounds];
}
- (void)shiftGridZBy:(float)value {
	// Setup bounds
	front += value;
	back += value;
	zSpacing = (back - front) / 4;
	
	[self setupZBounds];
}

- (void)checkGridWithX:(float)xpoint Y:(float)ypoint Z:(float)zpoint {
	// First check that its within the z bounds. Then the x bounds. And which.
	float xvalue = [self xForZ:zpoint X:xpoint];
	float yvalue = [self yForZ:zpoint Y:ypoint];
	
	// Check the row then column.
	if		  (zpoint >= zBound1 && zpoint <= zBound2) {
		// Row 1.
		if (xvalue >= xBound1 && xvalue <= xBound2) A1.y = yvalue;
		if (xvalue >= xBound2 && xvalue <= xBound3) A2.y = yvalue;
		if (xvalue >= xBound3 && xvalue <= xBound4) A3.y = yvalue;
	} else if (zpoint >= zBound2 && zpoint <= zBound3) {
		// Row 2.
		if (xvalue >= xBound1 && xvalue <= xBound2) B1.y = yvalue;
		if (xvalue >= xBound2 && xvalue <= xBound3) B2.y = yvalue;
		if (xvalue >= xBound3 && xvalue <= xBound4) B3.y = yvalue;
	} else if (zpoint >= zBound3 && zpoint <= zBound4) {
		// Row 3.
		if (xvalue >= xBound1 && xvalue <= xBound2) C1.y = yvalue;
		if (xvalue >= xBound2 && xvalue <= xBound3) C2.y = yvalue;
		if (xvalue >= xBound3 && xvalue <= xBound4) C3.y = yvalue;
	}
}

- (void)setupXBounds {
	// Setup the x bounds.
	xBound1 = left;	// The left of the bounding box.
	xBound2 = left + xSpacing * 1;
	xBound3 = left + xSpacing * 2;
	xBound4 = left + xSpacing * 3;	// The right of the bounding box.
	[self setupGridBounds];
}
- (void)setupZBounds {
	// Setup the z bounds.
	zBound1 = front;	// The front of the bounding box.
	zBound2 = front + zSpacing * 1;
	zBound3 = front + zSpacing * 2;
	zBound4 = front + zSpacing * 3;	// The back of the bounding box.
	[self setupGridBounds];
}
- (KCPointCell)setupCellWithLeft:(float)xleft Right:(float)xright Front:(float)zfront Back:(float)zback {
	KCPointCell buffer;
	buffer.y = 0;
	buffer.z = zback - zfront;
	buffer.x = ((xright - xleft)-frameWidth/2)*(buffer.z+minDepth)*scaleFactor*aspectRatio;
	
	buffer.colour[0] = rand() % 256 / 255;
	buffer.colour[1] = rand() % 256 / 255;
	buffer.colour[2] = rand() % 256 / 255;
	
	buffer.frontLeft = [self xForZ:zfront X:xleft];
	buffer.frontRight = [self xForZ:zfront X:xright];
	buffer.backRight = [self xForZ:zback X:xright];
	buffer.backLeft = [self xForZ:zback X:xleft];
	
	return buffer;
}
- (void)setupAllCells {
	A1 = [self setupCellWithLeft:xBound1 Right:xBound2 Front:zBound1 Back:zBound2];
	A2 = [self setupCellWithLeft:xBound1 Right:xBound2 Front:zBound2 Back:zBound3];
	A3 = [self setupCellWithLeft:xBound1 Right:xBound2 Front:zBound3 Back:zBound4];
	
	B1 = [self setupCellWithLeft:xBound2 Right:xBound3 Front:zBound1 Back:zBound2];
	B2 = [self setupCellWithLeft:xBound2 Right:xBound3 Front:zBound2 Back:zBound3];
	B3 = [self setupCellWithLeft:xBound2 Right:xBound3 Front:zBound3 Back:zBound4];
	
	C1 = [self setupCellWithLeft:xBound3 Right:xBound4 Front:zBound1 Back:zBound2];
	C2 = [self setupCellWithLeft:xBound3 Right:xBound4 Front:zBound2 Back:zBound3];
	C3 = [self setupCellWithLeft:xBound3 Right:xBound4 Front:zBound3 Back:zBound4];
}
- (void)setupGridBounds {
	frontLeft.x = [self xForZ:front X:left];
	frontLeft.y = 0;
	frontLeft.z = front;
	
	frontRight.x = [self xForZ:front X:right];
	frontRight.y = 0;
	frontRight.z = front;
	
	backLeft.x = [self xForZ:back X:left];
	backLeft.y = 0;
	backLeft.z = back;
	
	backRight.x = [self xForZ:back X:right];
	backRight.y = 0;
	backRight.z = back;
}

- (float)xForZ:(float)zvalue X:(float)xvalue {
	return (xvalue-frameWidth/2)*(zvalue+minDepth)*scaleFactor*aspectRatio;
}
- (float)yForZ:(float)zvalue Y:(float)yvalue {
	return -(yvalue-frameHeight/2)*(zvalue+minDepth)*scaleFactor;
}

- (void)drawGrid {
	[self drawCellBoundsForCell:A1];
	[self drawCellBoundsForCell:A2];
	[self drawCellBoundsForCell:A3];
	
	[self drawCellBoundsForCell:B1];
	[self drawCellBoundsForCell:B2];
	[self drawCellBoundsForCell:B3];
	
	[self drawCellBoundsForCell:C1];
	[self drawCellBoundsForCell:C2];
	[self drawCellBoundsForCell:C3];
	
	[self drawBounds];
}
- (void)drawCellBoundsForCell:(KCPointCell)cell {
	glLineWidth(2.0f);
	glBegin(GL_LINE_LOOP);
	glColor3f(255, 0, 0);
	glVertex3f(cell.frontLeft, cell.y, -cell.z);
	glVertex3f(cell.frontRight, cell.y, -cell.z);
	glVertex3f(cell.backRight, cell.y, -cell.z);
	glVertex3f(cell.backLeft, cell.y, -cell.z);
	glEnd();
}
- (void)drawBounds {
	glLineWidth(2.0f);
	glBegin(GL_LINE_LOOP);
	glColor3f(0, 255, 0);
	glVertex3f(frontLeft.x, frontLeft.y, -frontLeft.z);
	glColor3f(255, 0, 0);
	glVertex3f(frontRight.x, frontRight.y, -frontRight.z);
	glColor3f(0, 0, 255);
	glVertex3f(backRight.x, backRight.y, -backRight.z);
	glColor3f(255, 255, 255);
	glVertex3f(backLeft.x, backLeft.y, -backLeft.z);
	glEnd();
}

@end
