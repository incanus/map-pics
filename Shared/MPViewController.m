//
//  MPViewController.m
//  Map Pics iOS
//
//  Created by Justin R. Miller on 7/31/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MPViewController.h"

#import <QuartzCore/QuartzCore.h>

#define kMPAPIKey @"583c362ae5aa9d5c89ddc6103ef201ae"

@interface MPViewController ()

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKMapView *thumbMapView;
@property (nonatomic, strong) NSOperationQueue *actionQueue;

@end

#pragma mark -

@implementation MPViewController

#if TARGET_OS_IPHONE
- (void)viewDidLoad
{
    [super viewDidLoad];

    [self performInitialSetup];
}
#else
- (void)awakeFromNib
{
    [self performInitialSetup];
}
#endif

- (void)performInitialSetup
{
    // setup UI event queue
    //
    self.actionQueue = [NSOperationQueue new];
    self.actionQueue.maxConcurrentOperationCount = 1;

    // setup main map view
    //
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
#if TARGET_OS_IPHONE
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
#else
    self.mapView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
#endif
    self.mapView.delegate = self;
    self.mapView.zoomEnabled = self.mapView.scrollEnabled = self.mapView.rotateEnabled = self.mapView.pitchEnabled = NO;
    self.mapView.showsBuildings = self.mapView.showsPointsOfInterest = NO;
    [self.view addSubview:self.mapView];

    // add MapBox Satellite overlay
    //
    MKTileOverlay *satOverlay = [[MKTileOverlay alloc] initWithURLTemplate:@"http://a.tiles.mapbox.com/v3/justin.map-9sbbzbt9/{z}/{x}/{y}.png"];
    satOverlay.minimumZ = 0;
    satOverlay.maximumZ = 19;
    satOverlay.canReplaceMapContent = YES;
    [self.mapView addOverlay:satOverlay];

    // setup thumbnail map view
    //
    self.thumbMapView = [[MKMapView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width  - (self.view.bounds.size.width / 5) - 10,
                                                                    self.view.bounds.size.height - (self.view.bounds.size.width / 5) - 10,
                                                                    self.view.bounds.size.width / 5,
                                                                    self.view.bounds.size.width / 5)];
#if TARGET_OS_IPHONE
    self.thumbMapView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
#else
    self.thumbMapView.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
#endif
    self.thumbMapView.delegate = self;
    self.thumbMapView.zoomEnabled = self.thumbMapView.scrollEnabled = self.thumbMapView.rotateEnabled = self.thumbMapView.pitchEnabled = NO;
#if TARGET_OS_IPHONE
    self.thumbMapView.layer.borderColor = [[UIColor blackColor] CGColor];
#else
    self.thumbMapView.layer.borderColor = [[NSColor blackColor] CGColor];
#endif
    self.thumbMapView.layer.borderWidth = 1.0;
    self.thumbMapView.region = MKCoordinateRegionForMapRect(MKMapRectWorld);
    self.thumbMapView.centerCoordinate = self.mapView.centerCoordinate;
    self.thumbMapView.layer.opacity = 0.95;
    [self.view addSubview:self.thumbMapView];

    // add MapBox light-themed overlay
    //
    MKTileOverlay *grayOverlay = [[MKTileOverlay alloc] initWithURLTemplate:@"http://a.tiles.mapbox.com/v3/justin.map-xpollpqm/{z}/{x}/{y}.png"];
    grayOverlay.minimumZ = 0;
    grayOverlay.maximumZ = 19;
    grayOverlay.canReplaceMapContent = YES;
    [self.thumbMapView addOverlay:grayOverlay];

    // setup initial Flickr details
    //
    NSString *baseURLString = [NSString stringWithFormat:@"http://api.flickr.com/services/rest/?method=@@METHOD@@&api_key=%@&format=json&nojsoncallback=1", kMPAPIKey];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPAdditionalHeaders = @{ @"User-Agent" : @"Map Pics" };
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    // determine photo size
    //
#if TARGET_OS_IPHONE
    NSString *photoURLField = @"url_s";
#else
    NSString *photoURLField = @"url_m";
#endif

    // build search URL
    //
    NSURL *searchURL = [NSURL URLWithString:[[baseURLString stringByReplacingOccurrencesOfString:@"@@METHOD@@" withString:@"flickr.photos.search"] stringByAppendingString:[NSString stringWithFormat:@"&tags=travel&sort=interestingness-desc&has_geo=1&extras=geo,%@&media=photos&per_page=100", photoURLField]]];

    // kick off search
    //
    [[session dataTaskWithURL:searchURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        if (data)
        {
            // parse search results
            //
            NSDictionary *searchResults = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

            for (NSDictionary *photo in searchResults[@"photos"][@"photo"])
            {
                // obtain photos with associated places
                //
                if (photo[@"place_id"])
                {
                    NSURL *photoURL = [NSURL URLWithString:photo[photoURLField]];

                    // kick off photo download
                    //
                    [[session dataTaskWithURL:photoURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                    {
                        if (data)
                        {
                            NSData *imageData = data;
                                
                            NSURL *placeURL = [NSURL URLWithString:[[[baseURLString stringByReplacingOccurrencesOfString:@"@@METHOD@@" withString:@"flickr.places.getInfo"] stringByAppendingString:@"&place_id="] stringByAppendingString:photo[@"place_id"]]];

                            // kick off place info download
                            //
                            [[session dataTaskWithURL:placeURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                            {
                                if (data)
                                {
                                    // parse place results
                                    //
                                    NSDictionary *placeResults = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

                                    // get polyline & its bounding box
                                    //
                                    NSString *polylineString = placeResults[@"place"][@"shapedata"][@"polylines"][@"polyline"][0][@"_content"];
                                    NSArray *points = [polylineString componentsSeparatedByString:@" "];
                                    CLLocationCoordinate2D coordinates[[points count]];
                                    NSUInteger i = 0;
                                    double minLat = 0;
                                    double minLon = 0;
                                    double maxLat = 0;
                                    double maxLon = 0;
                                    for (NSString *point in points)
                                    {
                                        NSArray *pair = [point componentsSeparatedByString:@","];
                                        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([pair[0] doubleValue], [pair[1] doubleValue]);
                                        coordinates[i] = coordinate;
                                        if (coordinates[i].latitude < minLat  || minLat == 0)
                                            minLat = coordinates[i].latitude;
                                        if (coordinates[i].latitude > maxLat  || maxLat == 0)
                                            maxLat = coordinates[i].latitude;
                                        if (coordinates[i].longitude < minLon || minLon == 0)
                                            minLon = coordinates[i].longitude;
                                        if (coordinates[i].longitude > maxLon || maxLon == 0)
                                            maxLon = coordinates[i].longitude;
                                        i++;
                                    }
                                    MKPolyline *placePolyline = [MKPolyline polylineWithCoordinates:coordinates count:[points count]];
                                    placePolyline.title = placeResults[@"place"][@"woe_name"];
                                    MKCoordinateRegion placeRegion = {
                                        .center = {
                                            .latitude  = 0,
                                            .longitude = 0,
                                        },
                                        .span = {
                                            .latitudeDelta  = fabs(maxLat - minLat),
                                            .longitudeDelta = fabs(maxLon - minLon),
                                        },
                                    };
                                    placeRegion.center = CLLocationCoordinate2DMake(minLat + (placeRegion.span.latitudeDelta / 2), minLon + (placeRegion.span.longitudeDelta / 2));

                                    // build photo point & save image into annotation
                                    //
                                    MKPointAnnotation *photoPoint = [MKPointAnnotation new];
                                    photoPoint.coordinate = CLLocationCoordinate2DMake([photo[@"latitude"] doubleValue], [photo[@"longitude"] doubleValue]);
                                    photoPoint.title = photo[@"title"];
                                    photoPoint.subtitle = [imageData base64EncodedStringWithOptions:0];

                                    // enqueue UI actions
                                    //
                                    [self.actionQueue addOperationWithBlock:^(void)
                                    {
                                        // first, show photo place polyline
                                        //
                                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                                        {
                                            [self.mapView addOverlay:placePolyline];
                                            [self.mapView setRegion:placeRegion animated:YES];
                                        });

                                        sleep(4);

                                        // second, add photo point & zoom camera
                                        //
                                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                                        {
                                            [self.mapView addAnnotation:photoPoint];
                                            [self.mapView selectAnnotation:photoPoint animated:NO];
                                            [self.mapView showAnnotations:@[ photoPoint ] animated:YES];

                                            MKMapCamera *camera = [MKMapCamera camera];
                                            camera.centerCoordinate = photoPoint.coordinate;
                                            camera.heading = rand() % 360;
                                            camera.altitude = 100;
                                            camera.pitch = 40;
                                            [self.mapView setCamera:camera animated:YES];
                                        });
                                        
                                        sleep(8);

                                        // third, clean up after this photo
                                        //
                                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                                        {
                                            [self.mapView removeAnnotation:placePolyline];
                                            [self.mapView removeAnnotation:photoPoint];
                                        });
                                    }];
                                }
                                else
                                {
                                    NSLog(@"place error: %@", error);
                                }
                            }] resume];
                        }
                        else
                        {
                            NSLog(@"photo error: %@", error);
                        }
                    }] resume];
                }
            }
        }
        else
        {
            NSLog(@"search error: %@", error);
        }
    }] resume];
}

#pragma mark -

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if ([mapView isEqual:self.mapView])
    {
        if ([annotation isKindOfClass:[MKUserLocation class]])
            return nil;

        if ([annotation isKindOfClass:[MKPointAnnotation class]])
        {
            MKPointAnnotation *point = (MKPointAnnotation *)annotation;
            MKPinAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:point reuseIdentifier:nil];
            pin.canShowCallout = YES;

            // de-encode photo from annotation, round its corners, set to pin image, add a shadow, and animate fade in
            //
#if TARGET_OS_IPHONE
            UIImage *photo = [UIImage imageWithData:[[NSData alloc] initWithBase64EncodedString:point.subtitle options:0]];
            
            UIGraphicsBeginImageContext(CGSizeMake(photo.size.width, photo.size.height));
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextAddPath(context, [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, photo.size.width, photo.size.height) cornerRadius:10] CGPath]);
            CGContextClip(context);
            [photo drawAtPoint:CGPointMake(0, 0)];
            pin.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            pin.layer.shadowColor = [[UIColor blackColor] CGColor];
            pin.layer.shadowOffset = CGSizeMake(0, 1);
            pin.layer.shadowRadius = 10;
            pin.layer.shadowOpacity = 1.0;
            
            pin.alpha = 0;
            [UIView animateWithDuration:1.0
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^(void)
                             {
                                 pin.alpha = 1.0;
                             }
                             completion:nil];
#else
            NSImage *photo = [[NSImage alloc] initWithData:[[NSData alloc] initWithBase64EncodedString:point.subtitle options:0]];
            
            NSImage *roundedImage = [[NSImage alloc] initWithSize:photo.size];
            NSBitmapImageRep *roundedImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                                        pixelsWide:roundedImage.size.width
                                                                                        pixelsHigh:roundedImage.size.height
                                                                                     bitsPerSample:8
                                                                                   samplesPerPixel:4
                                                                                          hasAlpha:YES
                                                                                          isPlanar:NO
                                                                                    colorSpaceName:NSCalibratedRGBColorSpace
                                                                                       bytesPerRow:0
                                                                                      bitsPerPixel:0];
            [roundedImage addRepresentation:roundedImageRep];
            [roundedImage lockFocus];
            [[NSBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, photo.size.width, photo.size.height) xRadius:10 yRadius:10] setClip];
            [photo drawAtPoint:NSMakePoint(0, 0) fromRect:NSMakeRect(0, 0, photo.size.width, photo.size.height) operation:NSCompositeCopy fraction:1.0];
            [roundedImage unlockFocus];
            pin.image = roundedImage;
            
            pin.layer.shadowColor = [[NSColor blackColor] CGColor];
            pin.layer.shadowOffset = CGSizeMake(0, 1);
            pin.layer.shadowRadius = 10;
            pin.layer.shadowOpacity = 1.0;

            pin.alphaValue = 0;
            pin.wantsLayer = YES;
            CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fade.fromValue = @(pin.alphaValue);
            fade.toValue = @1.0;
            fade.duration = 1.0;
            fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            [pin.layer addAnimation:fade forKey:@"opacity"];
            pin.layer.opacity = 1.0;
#endif
            // be sure to clear the encoded image data
            //
            point.subtitle = nil;
            
            return pin;
        }
    }

    return nil;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay
{
    // MapBox tile overlays
    //
    if ([overlay isKindOfClass:[MKTileOverlay class]])
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];

    // photo place polylines
    //
    if ([mapView isEqual:self.mapView])
    {
        if ([overlay isKindOfClass:[MKPolyline class]])
        {
            MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];

#if TARGET_OS_IPHONE
            renderer.fillColor   = [UIColor blackColor];
            renderer.strokeColor = [UIColor redColor];
#else
            renderer.fillColor   = [NSColor blackColor];
            renderer.strokeColor = [NSColor redColor];
#endif
            renderer.lineWidth   = 2;

            return renderer;
        }
    }

    return nil;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    // keep thumbnail map in sync with main map
    //
    if ([mapView isEqual:self.mapView])
        [self.thumbMapView setCenterCoordinate:mapView.centerCoordinate animated:NO];
}

@end
