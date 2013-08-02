//
//  MPViewController.m
//  Map Pics iOS
//
//  Created by Justin R. Miller on 7/31/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MPViewController.h"

#define kMPAPIKey @"583c362ae5aa9d5c89ddc6103ef201ae"

@interface MPViewController ()

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKMapView *thumbMapView;
@property (nonatomic, strong) NSOperationQueue *actionQueue;

@end

#pragma mark -

@implementation MPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.actionQueue = [NSOperationQueue new];
    self.actionQueue.maxConcurrentOperationCount = 1;

    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.userInteractionEnabled = NO;
    [self.view addSubview:self.mapView];

    MKTileOverlay *satOverlay = [[MKTileOverlay alloc] initWithURLTemplate:@"http://a.tiles.mapbox.com/v3/justin.map-9sbbzbt9/{z}/{x}/{y}.png"];
    satOverlay.minimumZ = 0;
    satOverlay.maximumZ = 19;
    satOverlay.canReplaceMapContent = YES;
    [self.mapView addOverlay:satOverlay];

    self.thumbMapView = [[MKMapView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width  - (self.view.bounds.size.width / 5) - 10,
                                                                    self.view.bounds.size.height - (self.view.bounds.size.width / 5) - 10,
                                                                    self.view.bounds.size.width / 5,
                                                                    self.view.bounds.size.width / 5)];
    self.thumbMapView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    self.thumbMapView.delegate = self;
    self.thumbMapView.userInteractionEnabled = NO;
    self.thumbMapView.layer.borderColor = [[UIColor blackColor] CGColor];
    self.thumbMapView.layer.borderWidth = 1.0;
    self.thumbMapView.region = MKCoordinateRegionForMapRect(MKMapRectWorld);
    self.thumbMapView.alpha = 0.95;
    [self.view insertSubview:self.thumbMapView aboveSubview:self.mapView];

    MKTileOverlay *grayOverlay = [[MKTileOverlay alloc] initWithURLTemplate:@"http://a.tiles.mapbox.com/v3/justin.map-xpollpqm/{z}/{x}/{y}.png"];
    grayOverlay.minimumZ = 0;
    grayOverlay.maximumZ = 19;
    grayOverlay.canReplaceMapContent = YES;
    [self.thumbMapView addOverlay:grayOverlay];

    UIGraphicsBeginImageContext(self.thumbMapView.bounds.size);
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), [[[UIColor redColor] colorWithAlphaComponent:0.25] CGColor]);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 1.0);
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), self.thumbMapView.bounds.size.width / 2, 0);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), self.thumbMapView.bounds.size.width / 2, self.thumbMapView.bounds.size.height);
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), 0, self.thumbMapView.bounds.size.height / 2);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), self.thumbMapView.bounds.size.width, self.thumbMapView.bounds.size.height / 2);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    UIImageView *crosshairs = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
    UIGraphicsEndImageContext();
    crosshairs.frame = self.thumbMapView.frame;
    crosshairs.autoresizingMask = self.thumbMapView.autoresizingMask;
    [self.view insertSubview:crosshairs aboveSubview:self.thumbMapView];

    NSString *baseURLString = [NSString stringWithFormat:@"http://api.flickr.com/services/rest/?method=@@METHOD@@&api_key=%@&format=json&nojsoncallback=1", kMPAPIKey];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];

    configuration.HTTPAdditionalHeaders = @{ @"User-Agent" : @"Map Pics" };

    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    NSURL *searchURL = [NSURL URLWithString:[[baseURLString stringByReplacingOccurrencesOfString:@"@@METHOD@@" withString:@"flickr.photos.search"] stringByAppendingString:@"&tags=unesco,travel&sort=interestingness-desc&has_geo=1&extras=geo,url_s,machine_tags&media=photos&per_page=100"]];

    [[session dataTaskWithURL:searchURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        if (data)
        {
            NSDictionary *searchResults = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

            NSLog(@"search yielded %i results", [searchResults[@"photos"][@"photo"] count]);

            for (NSDictionary *photo in searchResults[@"photos"][@"photo"])
            {
                if (photo[@"place_id"])
                {
                    NSURL *photoURL = [NSURL URLWithString:photo[@"url_s"]];

                    [[session dataTaskWithURL:photoURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                    {
                        if (data)
                        {
                            NSData *imageData = data;

                            NSURL *placeURL = [NSURL URLWithString:[[[baseURLString stringByReplacingOccurrencesOfString:@"@@METHOD@@" withString:@"flickr.places.getInfo"] stringByAppendingString:@"&place_id="] stringByAppendingString:photo[@"place_id"]]];

                            [[session dataTaskWithURL:placeURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                            {
                                if (data)
                                {
                                    NSDictionary *placeResults = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

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

                                    MKPointAnnotation *photoPoint = [MKPointAnnotation new];
                                    photoPoint.coordinate = CLLocationCoordinate2DMake([photo[@"latitude"] doubleValue], [photo[@"longitude"] doubleValue]);
                                    photoPoint.title = photo[@"title"];
                                    photoPoint.subtitle = [imageData base64EncodedStringWithOptions:0];

                                    [self.actionQueue addOperationWithBlock:^(void)
                                    {
                                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                                        {
                                            [self.mapView addOverlay:placePolyline];
                                            [self.mapView setRegion:placeRegion animated:YES];
                                        });

                                        sleep(4);

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

            UIImage *photo = [UIImage imageWithData:[[NSData alloc] initWithBase64EncodedString:point.subtitle options:0]];
            point.subtitle = nil;

            UIGraphicsBeginImageContext(CGSizeMake(photo.size.width, photo.size.height));
            CGContextAddPath(UIGraphicsGetCurrentContext(), [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, photo.size.width, photo.size.height) cornerRadius:10] CGPath]);
            CGContextClip(UIGraphicsGetCurrentContext());
            [photo drawAtPoint:CGPointMake(0, 0)];
            photo = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            UIGraphicsBeginImageContext(CGSizeMake(photo.size.width + 20, photo.size.height + 20));
            CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), CGSizeMake(0, 1), 10, [[UIColor blackColor] CGColor]);
            [photo drawAtPoint:CGPointMake(10, 10)];
            pin.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            pin.alpha = 0;

            [UIView animateWithDuration:1.0
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^(void)
                             {
                                 pin.alpha = 1.0;
                             }
                             completion:nil];

            return pin;
        }
    }

    return nil;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKTileOverlay class]])
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];

    if ([mapView isEqual:self.mapView])
    {
        if ([overlay isKindOfClass:[MKPolyline class]])
        {
            MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];

            renderer.fillColor   = [UIColor blackColor];
            renderer.strokeColor = [UIColor redColor];
            renderer.lineWidth   = 2;

            return renderer;
        }
    }

    return nil;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    if ([mapView isEqual:self.mapView])
        self.thumbMapView.centerCoordinate = self.mapView.centerCoordinate;
}

@end
