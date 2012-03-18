//
//  Kinect Controller.m
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

#import "Kinect Controller.h"

@interface Kinect_Controller (Private)
// Kinect Thread.
- (void)kinectThread;
- (void)calculateFPS;
- (void)setStatus:(NSString*)newString;
- (void)safeSetStatus:(NSString*)newString;

// Callback Methods.
- (void)depthCallback:(uint16_t*)buffer;
- (void)rgbCallback:(uint8_t*)buffer;
- (void)irCallback:(uint8_t*)buffer;
@end

// C-Type Functions for callbacks from libfreenect.
static void depthCallback(freenect_device *dev, void *depth, uint32_t timestamp) {
	[(Kinect_Controller*)freenect_get_user(dev) depthCallback:(uint16_t*)depth];
}
static void rgbCallback(freenect_device *dev, void *video, uint32_t timestamp) {
    [(Kinect_Controller*)freenect_get_user(dev) rgbCallback:(uint8_t*)video];
}
static void irCallback(freenect_device * dev, void *video, uint32_t timestamp) {
    [(Kinect_Controller*)freenect_get_user(dev) irCallback:(uint8_t*)video];
}

@implementation Kinect_Controller
@synthesize LEDColourButton, startStopButton;

- (void)awakeFromNib {
	// Initialise the View.
	[LEDColourButton removeAllItems];
	[LEDColourButton addItemsWithTitles:[NSArray arrayWithObjects:  @"Off", 
                                                                    @"Green", 
                                                                    @"Red", 
                                                                    @"Yellow", 
                                                                    @"Blink Green", 
                                                                    @"Blink Red & Yellow", 
                                                                    nil]];
	[startStopButton setTitle:@"Stop"];
	
	// Initialise the data buffers.
	_depthFront = (uint16_t*)malloc(FREENECT_DEPTH_11BIT_SIZE);
	_depthBack = (uint16_t*)malloc(FREENECT_DEPTH_11BIT_SIZE);
	_videoFront = (uint8_t*)malloc(FREENECT_VIDEO_RGB_SIZE);
	_videoBack = (uint8_t*)malloc(FREENECT_VIDEO_RGB_SIZE);
	
	// Initialise the libfreenect settings.
    _videoFormat = FREENECT_VIDEO_RGB;
    _depthFormat = FREENECT_DEPTH_11BIT_PACKED;
	
	// Start the FPS calculator.
	_lastFPSCalc = [[NSDate date] retain];
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(calculateFPS) userInfo:nil repeats:YES];
	
	// Start up the Kinect.
	[self startKinect];
}

//-------------------------------------------------
// Initialisation Methods.
//-------------------------------------------------
- (void)setVideoMode:(videoMode)newMode {
    switch (newMode) {
        case rgbMode:
            _videoFormat = FREENECT_VIDEO_RGB;
            break;
        case irMode:
            _videoFormat = FREENECT_VIDEO_IR_8BIT;
        default:
            _videoFormat = FREENECT_VIDEO_RGB;
            break;
    }
}
- (void)setDepthMode:(depthMode)newMode {
    switch (newMode) {
        case normalDepth:
            _depthFormat = FREENECT_DEPTH_11BIT;
            break;
        case mmDepth:
            _depthFormat = FREENECT_DEPTH_MM;
            break;
        case registeredDepth:
            _depthFormat = FREENECT_DEPTH_REGISTERED;
            break;
        default:
            _depthFormat = FREENECT_DEPTH_11BIT;
            break;
    }
}
- (void)setLedColour:(ledMode)newMode {
    switch (newMode) {
        case off:
            _ledFormat = LED_OFF;
            break;
        case green:
            _ledFormat = LED_GREEN;
            break;
        case red:
            _ledFormat = LED_RED;
            break;
        case yellow:
            _ledFormat = LED_YELLOW;
            break;
        case blinkGreen:
            _ledFormat = LED_BLINK_GREEN;
            break;
        case blinkRedAndYellow:
            _ledFormat = LED_BLINK_RED_YELLOW;
            break;
        default:
            _ledFormat = LED_BLINK_RED_YELLOW;
            break;
    }
}
- (void)setTilt:(int)newTilt {
    _tiltAmount = newTilt;
}

//-------------------------------------------------
// Kinect Control Methods.
//-------------------------------------------------
- (IBAction)startStop:(id)sender {
	if (_kinectDevice) {
		[self stopKinect];
		[startStopButton setTitle:@"Start"];
	} else {
		[self startKinect];
		[startStopButton setTitle:@"Stop"];
	}
}
- (void)startKinect {
	[self safeSetStatus:@"Kinect Starting..."];
	_haltKinect = NO;
	[NSThread detachNewThreadSelector:@selector(kinectThread) toTarget:self withObject:nil];
}
- (void)stopKinect {
	_haltKinect = YES;
	while (_kinectDevice != NULL) {
		[NSThread sleepForTimeInterval:1];	// Crude waiting implementaion.
	}
}
- (IBAction)updateTilt:(id)sender {
	[self setTilt:[sender intValue]];
}
- (IBAction)updateLED:(id)sender {
    if ([LEDColourButton indexOfSelectedItem] <= 4) {
        // Off, Green, Red, Yellow, Blink Green.
        [self setLedColour:(ledMode)[LEDColourButton indexOfSelectedItem]];
    } else {
        // Blink Red & Yellow.
        [self setLedColour:(ledMode)[LEDColourButton indexOfSelectedItem]+1];
    }
    
}

//-------------------------------------------------
// Kinect Data Methods.
//-------------------------------------------------
- (uint16_t*)getDepthData {
	// Safely return the front buffer and create a new buffer to take it's place.
	uint16_t *depth = NULL;
	@synchronized (self) {
		if (_depthUpdated) {
			_depthUpdated = NO;
			depth = _depthFront;
			_depthFront = (uint16_t*)malloc(FREENECT_DEPTH_11BIT_SIZE);
		}
	}
	return depth;
}
- (uint8_t*)getVideoData {
	// Safely return the front buffer and create a new buffer to take it's place.
	uint8_t *video = NULL;
	@synchronized (self) {
		if (_videoUpdated) {
			_videoUpdated = NO;
			video = _videoFront;
			_videoFront = (uint8_t*)malloc(FREENECT_VIDEO_RGB_SIZE);
		}
	}
	return video;
}
- (void)setFrameViewed {
	@synchronized (self) {
		_viewCount++;
	}
}

//-------------------------------------------------
// (PRIVATE) Kinect Methods
//-------------------------------------------------
@synthesize viewFPS, videoFPS, depthFPS;
@synthesize kinectStatus;
- (void)kinectThread {
	freenect_context *context;
	if (freenect_init(&context, NULL) >= 0) {
		if (freenect_num_devices(context) == 0) {
			[self safeSetStatus:@"No Kinect"];
			[startStopButton setTitle:@"Start"];
		} else if (freenect_open_device(context, &_kinectDevice, 0) >= 0) {
			freenect_set_user(_kinectDevice, self);
			freenect_set_depth_callback(_kinectDevice, depthCallback);
			freenect_set_video_callback(_kinectDevice, rgbCallback);
			freenect_set_video_mode(_kinectDevice, freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, FREENECT_VIDEO_RGB));
			freenect_set_depth_mode(_kinectDevice, freenect_find_depth_mode(FREENECT_RESOLUTION_MEDIUM, FREENECT_DEPTH_REGISTERED));
			freenect_start_depth(_kinectDevice);
			freenect_start_video(_kinectDevice);
			
			[self safeSetStatus:@"Running"];
            
			freenect_video_format previousVideoFormat = FREENECT_VIDEO_RGB;
			freenect_depth_format previousDepthFormat = FREENECT_DEPTH_11BIT_PACKED;
            freenect_led_options  previousLedFormat   = LED_GREEN;
            float                 previousTiltAmount  = 0;
			
			// This while loop runs for the whole time the Kinect is running.
			// Once we are done the device is closed and libfreenect is shutdown.
			while (!_haltKinect && freenect_process_events(context) >= 0) {
				// Change the Video Format if changed.
				if (_videoFormat != previousVideoFormat) {
					previousVideoFormat = _videoFormat;
					freenect_stop_video(_kinectDevice);
                    if (previousVideoFormat == FREENECT_VIDEO_RGB) {
                        freenect_set_video_callback(_kinectDevice, rgbCallback);
                    } else if (previousVideoFormat == FREENECT_VIDEO_IR_8BIT) {
                        freenect_set_video_callback(_kinectDevice, irCallback);
                    }
                    freenect_set_video_mode(_kinectDevice, freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, previousVideoFormat));
					freenect_start_video(_kinectDevice);
				}
				// Change the Depth Format if changed.
				if (_depthFormat != previousDepthFormat) {
					previousDepthFormat = _depthFormat;
					freenect_stop_depth(_kinectDevice);
                    freenect_set_depth_mode(_kinectDevice, freenect_find_depth_mode(FREENECT_RESOLUTION_MEDIUM, previousDepthFormat));
					freenect_start_depth(_kinectDevice);
				}
                // Change LED colour if changed.
				if (_ledFormat != previousLedFormat) {
					previousLedFormat = _ledFormat;
					freenect_set_led(_kinectDevice, previousLedFormat);
				}
				// Change tilt amount if changed.
				if (_tiltAmount != previousTiltAmount) {
					previousTiltAmount = _tiltAmount;
					freenect_set_tilt_degs(_kinectDevice, previousTiltAmount);
				}
			}
			
			// Now we're done with the Kinect let's close it all down.
			freenect_close_device(_kinectDevice);
			_kinectDevice = NULL;
			[self safeSetStatus:@"Stopped"];
		} else {
			[self safeSetStatus:@"Could not open Kinect"];
			[startStopButton setTitle:@"Start"];
		}
		
		freenect_shutdown(context);
	} else {
		[self safeSetStatus:@"Could not init Kinect"];
		[startStopButton setTitle:@"Start"];
	}
}
- (void)calculateFPS {
	NSDate *currentDate = [NSDate date];
	NSTimeInterval time = [currentDate timeIntervalSinceDate:_lastFPSCalc];
	if (time > 0.5) {
		[_lastFPSCalc release];
		_lastFPSCalc = [currentDate retain];
		
		int viewc, videoc, depthc;
		@synchronized (self) {
			viewc = _viewCount;
			videoc = _videoCount;
			depthc = _depthCount;
			_viewCount = 0;
			_videoCount = 0;
			_depthCount = 0;
		}
		[viewFPS setStringValue:[NSString stringWithFormat:@"%.2f", viewc/time]];
		[videoFPS setStringValue:[NSString stringWithFormat:@"%.2f", videoc/time]];
		[depthFPS setStringValue:[NSString stringWithFormat:@"%.2f", depthc/time]];
	}
}
- (void)setStatus:(NSString*)newString {
	[kinectStatus setStringValue:newString];
}
- (void)safeSetStatus:(NSString *)newString {
	[self performSelectorOnMainThread:@selector(setStatus:) withObject:newString waitUntilDone:NO];
}

//-------------------------------------------------
// (PRIVATE) Callback Methods
//-------------------------------------------------
- (void)depthCallback:(uint16_t*)buffer {
	// Update the back buffer, then safely swap it with the front buffer.
	memcpy(_depthBack, buffer, FREENECT_DEPTH_11BIT_SIZE);
	@synchronized (self) {
		uint16_t *hold = _depthBack;
		_depthBack = _depthFront;
		_depthFront = hold;
		_depthCount++;
		_depthUpdated = YES;
	}
}
- (void)rgbCallback:(uint8_t*)buffer {
	// Update the back buffer, then safely swap it with the front buffer.
	memcpy(_videoBack, buffer, FREENECT_VIDEO_RGB_SIZE);
	@synchronized (self) {
		uint8_t *hold = _videoBack;
		_videoBack = _videoFront;
		_videoFront = hold;
		_videoCount++;
		_videoUpdated = YES;
	}
}
- (void)irCallback:(uint8_t*)buffer {
	// Update the back buffer with the relevant data, then safely swap it with the front buffer.
	for (int i = 0; i < FREENECT_FRAME_PIX; i++) {
		int pval = buffer[i];
		_videoBack[3*i+0] = pval;
		_videoBack[3*i+1] = pval;
		_videoBack[3*i+2] = pval;
	}
	@synchronized (self) {
		uint8_t *hold = _videoBack;
		_videoBack = _videoFront;
		_videoFront = hold;
		_videoCount++;
		_videoUpdated = YES;
	}
}

@end
