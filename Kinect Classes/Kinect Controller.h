//
//  Kinect Controller.h
//  KinectiCopter
//
//  Created by James Reuss on 28/02/2012.
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
#import <libfreenect/libfreenect.h>

typedef enum {
	rgbMode = 0,
	irMode
} videoMode;
typedef enum {
	normalDepth = 0,
	mmDepth,
	registeredDepth
} depthMode;
typedef enum {
	off = 0,
	green,
	red,
	yellow,
	blinkGreen,
	doNotUse,
	blinkRedAndYellow
} ledMode;

@interface Kinect_Controller : NSObject {
    // Controls.
	BOOL _haltKinect;
    NSDate *_lastFPSCalc;
    
    // Kinect data.
    freenect_device *_kinectDevice;
    uint16_t *_depthBack, *_depthFront;
    uint8_t *_videoBack, *_videoFront;
    int _viewCount, _videoCount, _depthCount;
    BOOL _depthUpdated, _videoUpdated;
	
	// libfreenect settings.
	freenect_video_format _videoFormat;
	freenect_depth_format _depthFormat;
	freenect_led_options  _ledFormat;
    float				  _tiltAmount;
}
@property (assign) IBOutlet NSTextField *viewFPS, *videoFPS, *depthFPS;
@property (assign) IBOutlet NSTextField *kinectStatus;
@property (assign) IBOutlet NSPopUpButton *LEDColourButton;
@property (assign) IBOutlet NSButton *startStopButton;

#pragma mark Initialisation
- (void)setVideoMode:(videoMode)newMode;
- (void)setDepthMode:(depthMode)newMode;
- (void)setLedColour:(ledMode)newMode;
- (void)setTilt:(int)newTilt;

#pragma mark Kinect Control
- (IBAction)startStop:(id)sender;
- (void)startKinect;
- (void)stopKinect;
- (IBAction)updateTilt:(id)sender;
- (IBAction)updateLED:(id)sender;

#pragma mark Kinect Data
- (uint16_t*)getDepthData;
- (uint8_t*)getVideoData;
- (void)setFrameViewed;

@end

#define FREENECT_FRAME_W 640
#define FREENECT_FRAME_H 480
#define FREENECT_FRAME_PIX (FREENECT_FRAME_H*FREENECT_FRAME_W)

#define FREENECT_IR_FRAME_W 640
#define FREENECT_IR_FRAME_H 488
#define FREENECT_IR_FRAME_PIX (FREENECT_IR_FRAME_H*FREENECT_IR_FRAME_W)

#define FREENECT_VIDEO_RGB_SIZE (FREENECT_FRAME_PIX*3)
#define FREENECT_VIDEO_BAYER_SIZE (FREENECT_FRAME_PIX)
#define FREENECT_VIDEO_IR_8BIT_SIZE (FREENECT_IR_FRAME_PIX)
#define FREENECT_VIDEO_IR_10BIT_SIZE (FREENECT_IR_FRAME_PIX*sizeof(uint16_t))
#define FREENECT_VIDEO_IR_10BIT_PACKED_SIZE 390400

#define FREENECT_DEPTH_11BIT_SIZE (FREENECT_FRAME_PIX*sizeof(uint16_t))
#define FREENECT_DEPTH_10BIT_SIZE FREENECT_DEPTH_11BIT_SIZE
#define FREENECT_DEPTH_11BIT_PACKED_SIZE 422400
#define FREENECT_DEPTH_10BIT_PACKED_SIZE 384000
