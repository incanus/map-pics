//
//  MPViewController.h
//  Map Pics
//
//  Created by Justin R. Miller on 7/31/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import <MapKit/MapKit.h>

#if TARGET_OS_IPHONE
@interface MPViewController : UIViewController <MKMapViewDelegate>
#else
@interface MPViewController : NSViewController <MKMapViewDelegate>
#endif

@end
