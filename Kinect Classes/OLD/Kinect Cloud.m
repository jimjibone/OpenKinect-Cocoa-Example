//
//	Kinect Cloud.m
//	Cloud Viewer
//
//	Created by James Reuss on 07/03/2012.
//	Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Kinect Cloud.h"

@interface Kinect_Cloud (Private)
- (void)setColourMapForI:(uint16_t)i J:(uint16_t)j Value:(uint16_t)value;
@end

@implementation Kinect_Cloud

//------------------------------------------------------------
// Initialisation
//------------------------------------------------------------
- (id)initWithValue:(int)value {
	self = [super init];
	if (self) {
		// Set up the alignment variables.
		frameWidth = FREENECT_FRAME_W;
		frameHeight = FREENECT_FRAME_H;
		aspectRatio = FREENECT_FRAME_W/FREENECT_FRAME_H;
		minDepth = -10;
		scaleFactor = 0.0021;
		
		// Initialise the point cloud.
		for (uint16_t i = 0; i < frameWidth; i++) {
			for (uint16_t j = 0; j < frameHeight; j++) {
				pointCloud[i][j][0] = i;	// x pos.
				pointCloud[i][j][1] = j;	// y pos.
				pointCloud[i][j][2] = 0;	// depth.
				pointCloud[i][j][3] = 255;	// red.
				pointCloud[i][j][4] = 255;	// green.
				pointCloud[i][j][5] = 255;	// blue.
			}
		}
		
		// Initialise the colour map.
		for (int i = 0; i < 10000; i++) {
			float v = i/10000.0;
			v = powf(v, 3)*6;
			colourMap[i] = v*6*256;
		}
		
		// Use the colour map instead of rgb?
		useColourMap = NO;
		useCloudFile = NO;
	}
	return self;
}
- (id)init {
    return [self initWithValue:0];
}

//------------------------------------------------------------
// Point Cloud Methods
//------------------------------------------------------------
- (void)setPointCloudWithDepth:(uint16_t*)depth Video:(uint8_t*)video {
	uint16_t depthValue = 0;
	int videoOffset = 0;
	
	if (!useCloudFile) {
		for (uint16_t i = 0; i < frameWidth; i++) {
			for (uint16_t j = 0; j < frameHeight; j++) {
				// Get the current depth and video points.
				if (depth) {
					depthValue = depth[i+j*frameWidth];
					// Fill the cloud.
					pointCloud[i][j][0] = (i-frameWidth/2)*(depthValue+minDepth)*scaleFactor*aspectRatio;	// x pos.
					pointCloud[i][j][1] = (j-frameHeight/2)*(depthValue+minDepth)*scaleFactor;	// y pos.
					pointCloud[i][j][2] = depthValue;	// depth.
					
					if (useColourMap) {
						[self setColourMapForI:i J:j Value:depthValue];
					}
				}
				if (video && !useColourMap) {
					videoOffset = 3*(i+j*frameWidth);
					// Fill the cloud.
					pointCloud[i][j][3] = video[videoOffset]/255.0;	// red.
					pointCloud[i][j][4] = video[videoOffset+1]/255.0;	// green.
					pointCloud[i][j][5] = video[videoOffset+2]/255.0;	// blue.
				}
			}
		}
	}
}
- (void)setUseColourMap:(BOOL)useit {
	useColourMap = useit;
}

//------------------------------------------------------------
// Cloud File Methods
//------------------------------------------------------------
- (void)importPointCloud:(NSWindow*)window {
	// This will load in a file of a previously captured point cloud
	//  and then set the current point cloud to only display the loaded
	//  data instead of new data (if present).
	
	// Show the open window for the user.
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			NSURL *filePath = [[openPanel URLs] objectAtIndex:0];
			NSData *newPointCloud = [[NSData alloc] initWithContentsOfURL:filePath];
			memcpy(&pointCloud, [newPointCloud bytes], [newPointCloud length]);
			[newPointCloud release];
			
			useCloudFile = YES;
		} else {
			NSLog(@"No import file selected.");
		}
	}];
}
- (void)exportPointCloud:(NSWindow*)window {
	// This will take a snapshot of the current point cloud
	//	and save it to a file that the user selects.
	
	// Copy the point cloud data ready for the file.
	NSData *pointCloudData = [[NSData alloc] initWithBytes:&pointCloud length:sizeof(pointCloud)];
	
	// Get the current date and time for the file.
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyMMdd-HHmmss"];
	NSDate *date = [NSDate date];
	
	// Set up a string for the default file name.
	NSString *defaultName = [NSString stringWithFormat:@"PCF - %@", [dateFormatter stringFromDate:date]];
	defaultName = [defaultName stringByAppendingPathExtension:@"pcf"];
	NSLog(@"defaultName = %@", defaultName);
	
	// Show the save window for the user.
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setNameFieldStringValue:defaultName];
	[savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			// Save the data to the new file to the selected location.
			NSURL *filePath = [savePanel URL];
			NSLog(@"Path - %@", filePath);
			[pointCloudData writeToURL:filePath atomically:NO];
		} else {
			NSLog(@"Cancel Selected.");
		}
	}];
	
	// Clean up.
	[dateFormatter release];
	[pointCloudData release];
}
- (void)stopImportedPointCloud {
	useCloudFile = NO;
}

//------------------------------------------------------------
// Calculation Methods
//------------------------------------------------------------

//------------------------------------------------------------
// Draw Methods
//------------------------------------------------------------
- (void)drawPointCloud {
	glBegin(GL_POINTS);
    for (int i = 0; i < 640; i++) {
        for (int j = 0; j < 480; j++) {
			if (pointCloud[i][j][2] != 0) {
				glColor3f(pointCloud[i][j][3], pointCloud[i][j][4], pointCloud[i][j][5]);
				glVertex3f(pointCloud[i][j][0] , pointCloud[i][j][1], pointCloud[i][j][2]);
			}
        }
    }
    glEnd();
}

//------------------------------------------------------------
// PRIVATE METHODS
//------------------------------------------------------------
- (void)setColourMapForI:(uint16_t)i J:(uint16_t)j Value:(uint16_t)value {
	int ub = colourMap[value];
	int lb = (value >> 8) & 0xff;
	switch (ub >> 8) {
		case 0:
			pointCloud[i][j][3] = 255;
			pointCloud[i][j][4] = 255-lb;
			pointCloud[i][j][5] = 255-lb;
			break;
		case 1:
			pointCloud[i][j][3] = 255;
			pointCloud[i][j][4] = lb;
			pointCloud[i][j][5] = 0;
			break;
		case 2:
			pointCloud[i][j][3] = 255-lb;
			pointCloud[i][j][4] = 255;
			pointCloud[i][j][5] = 0;
			break;
		case 3:
			pointCloud[i][j][3] = 0;
			pointCloud[i][j][4] = 255;
			pointCloud[i][j][5] = lb;
			break;
		case 4:
			pointCloud[i][j][3] = 0;
			pointCloud[i][j][4] = 255-lb;
			pointCloud[i][j][5] = 255;
			break;
		case 5:
			pointCloud[i][j][3] = 0;
			pointCloud[i][j][4] = 0;
			pointCloud[i][j][5] = 255-lb;
			break;
		default:
			pointCloud[i][j][3] = 0;
			pointCloud[i][j][4] = 0;
			pointCloud[i][j][5] = 0;
			break;
	}
}

@end
