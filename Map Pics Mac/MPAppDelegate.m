//
//  MPAppDelegate.m
//  Map Pics Mac
//
//  Created by Justin R. Miller on 7/31/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MPAppDelegate.h"

#define kMPAPIKey @"583c362ae5aa9d5c89ddc6103ef201ae"

@implementation MPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSString *baseURLString = [NSString stringWithFormat:@"http://api.flickr.com/services/rest/?method=@@METHOD@@&api_key=%@&format=json&nojsoncallback=1", kMPAPIKey];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];

    configuration.HTTPAdditionalHeaders = @{ @"User-Agent" : @"Map Pics" };

    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    NSURL *searchURL = [NSURL URLWithString:[[baseURLString stringByReplacingOccurrencesOfString:@"@@METHOD@@" withString:@"flickr.photos.search"] stringByAppendingString:@"&tags=unesco,travel&sort=interestingness-desc&has_geo=1&extras=geo,url_o,machine_tags"]];

    [[session dataTaskWithURL:searchURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSLog(@"data:  %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSLog(@"error: %@", error);
    }] resume];
}

@end
