//
//  AppDelegate.h
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

#import <Cocoa/Cocoa.h>
#import "Kinect Controller.h"
#import "Kinect Processing.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet Kinect_Controller *kinectController;
@property (assign) IBOutlet Kinect_Processing *kinectProcessing;

@end
