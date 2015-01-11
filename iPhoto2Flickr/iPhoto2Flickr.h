//
//  iPhoto2Flickr.h
//  iPhoto2Flickr
//
//  Created by Pierri on 09/01/2015
//

#import <Foundation/Foundation.h>
#import "FlickrClient.h"

@interface iPhoto2Flickr : NSObject
-(void) uploadRollsToFlickr:(FlickrClient*) flickrClient;
@end
