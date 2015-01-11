//
//  FlickrClient.h
//  iPhoto2Flickr
//
//  Created by Pierri on 30/12/2014.
//

#import <Foundation/Foundation.h>

@interface FlickrClient : NSObject

@property (nonatomic, assign, readonly, getter = isAuthorized) BOOL authorized;

#pragma mark Initialization
+ (instancetype)createWithAPIKey:(NSString *)apiKey secret:(NSString *)secret;
+ (instancetype)sharedClient;

#pragma mark Authorization
- (BOOL)isAuthorized;
- (void)requestAuthorization;
- (BOOL)verifyAuthorizationWithToken:(NSString *)verifierToken;
- (void)deauthorize;

#pragma mark Upload
- (NSString*)uploadImage:(NSString *)inImagePath params:(NSDictionary*)params;
- (BOOL)isRunning;

#pragma mark Photos
- (NSMutableDictionary*)getAllImages;
+ (NSString*)cleanTag:(NSString*)rawTag;

#pragma mark Photosets
- (NSString*)createPhotosetTitle:(NSString*)title description:(NSString*)description primaryPhotoId:(NSString*)primaryPhotoId;
- (NSArray*)getAllPhotosets;
- (void) editPhotoset:(NSString*)photosetId primaryPhotoId:(NSString*)primaryPhotoId photoIds:(NSString*)photoIds;


@end
