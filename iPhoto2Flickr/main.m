//
//  main.m
//  iPhoto2Flickr
//
//  Created by Pierri on 22/12/2014.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FlickrClient.h"
#import "iPhoto2Flickr.h"

NSString* requestVerifierTokenFromUser() {
    NSLog(@"Access Token not set, please authorize app in Flickr and type in the token verifier issued by flickr at the end (9 chars, e.g. 123-456-789)");
    
    NSFileHandle *kbd = [NSFileHandle fileHandleWithStandardInput];
    NSData *inputData = [kbd availableData];
    NSString *oAuthVerifierToken = [[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];

    return oAuthVerifierToken;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"", @"apiKey",
                                     @"", @"apiSecret",
                                     nil];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults registerDefaults:appDefaults];
        
        // TODO prompt user for API key and secret on first run
        [defaults setValue:@"1d2a6d5363b9675801b9c3a7d16c4c63" forKey:@"apiKey"];
        [defaults setValue:@"15c50c0b47dea73b" forKey:@"apiSecret"];

        // TODO if called with --reset:
        // [defaults setValue:@"" forKey:@"apiKey"];
        // [defaults setValue:@"" forKey:@"apiSecret"];
        
        NSString *apiKey = [defaults valueForKey:@"apiKey"];
        NSString *secret = [defaults valueForKey:@"apiSecret"];
        
        [FlickrClient createWithAPIKey:apiKey secret:secret];

        FlickrClient *flickrClient = [FlickrClient sharedClient];
        
        // TODO if called with --reset:
        //[flickrClient deauthorize];
        
        if (![flickrClient isAuthorized]) {
            
            [flickrClient requestAuthorization];
            
            NSString* oAuthVerifierToken = requestVerifierTokenFromUser();
            
            [flickrClient verifyAuthorizationWithToken: oAuthVerifierToken];
        }

        iPhoto2Flickr* uploader = [[iPhoto2Flickr alloc]init];
        [uploader uploadRollsToFlickr:flickrClient];
        
    }
    return 0;
}

