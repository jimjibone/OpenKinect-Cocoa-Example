//
//  AppDelegate.m
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

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize kinectController;
@synthesize kinectProcessing;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
	NSString *filePath = [[NSString alloc] initWithString:[filenames objectAtIndex:0]];
	NSURL *fileURL = [NSURL fileURLWithPath:filePath];
	[kinectProcessing openWithFile:fileURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[kinectProcessing stopProcessing];
    [kinectController stopKinect];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    return YES;
}

@end
