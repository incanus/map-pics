//
//  MPAppDelegate.m
//  Map Pics iOS
//
//  Created by Justin R. Miller on 7/31/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MPAppDelegate.h"

#import "MPViewController.h"

@implementation MPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[MPViewController alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];

    return YES;
}
							
@end
