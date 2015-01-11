//
//  FlickrClient.m
//  iPhoto2Flickr
//
//  Created by Pierri on 30/12/2014.
//

#import "FlickrClient.h"
#import <AppKit/AppKit.h>
#import <objectiveflickr/ObjectiveFlickr.h>

// Internal
static NSString * const kOAuthAuth = @"OAuth";
static NSString * const kQueryGuid = @"QueryGuid";
static NSString * const kQueryTag = @"QueryTag";
static NSString * const kCreatePhotoset = @"CreatePhotoset";
static NSString * const kGetPhotosetList = @"GetPhotosetList";
static NSString * const kEditPhotosetPhotos = @"EditPhotosetPhotos";
static NSString * const kDeletePhoto = @"DeletePhoto";

static NSString * const kStoredAuthTokenKeyName = @"FlickrOAuthToken";
static NSString * const kStoredAuthTokenSecretKeyName = @"FlickrOAuthTokenSecret";

static NSString * const kFlickrClientAPIURL   = @"https://api.flickr.com/services/";

static NSString * const kFlickrClientOAuthAuthorizeURL     = @"https://www.flickr.com/services/oauth/authorize";
static NSString * const kFlickrClientOAuthCallbackURL      = @"oob"; // Out-of-band verification: User has to copy/type auth. verifier token

static NSString * const kFlickrClientOAuthRequestTokenPath = @"oauth/request_token";
static NSString * const kFlickrClientOAuthAccessTokenPath  = @"oauth/access_token";

#pragma mark -
@interface FlickrClient() <OFFlickrAPIRequestDelegate>
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *requestToken;
- (id)initWithAPIKey:(NSString *)apiKey secret:(NSString *)secret;
- (NSDictionary *)defaultRequestParameters;
@property (nonatomic) OFFlickrAPIContext *flickrContext;
@property (nonatomic) OFFlickrAPIRequest *flickrRequest;
@property (nonatomic) int pages;
@property (nonatomic) NSDictionary *responseDict;
@end

#pragma mark -

@implementation FlickrClient

#pragma mark Initialization
static FlickrClient *_sharedClient = nil;

+ (instancetype)createWithAPIKey:(NSString *)apiKey secret:(NSString *)secret {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[[self class] alloc] initWithAPIKey:apiKey secret:secret];
    });
    
    return _sharedClient;
}

- (id)initWithAPIKey:(NSString *)apiKey secret:(NSString *)secret {
    self = [super init];
    
    if (self) {
        _apiKey = [apiKey copy];
        
        self.flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:apiKey sharedSecret:secret];
        
        // TODO OAuthToken and OAuthTokenSecret should be stored in the keychain instead of here...
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                     nil, kStoredAuthTokenKeyName,
                                     nil, kStoredAuthTokenSecretKeyName,
                                     nil];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults registerDefaults:appDefaults];
        
        self.flickrContext.OAuthToken = [defaults valueForKey:kStoredAuthTokenKeyName];
        self.flickrContext.OAuthTokenSecret = [defaults valueForKey:kStoredAuthTokenSecretKeyName];
    
        self.flickrRequest = [[OFFlickrAPIRequest alloc] initWithAPIContext:self.flickrContext];
        self.flickrRequest.delegate = self;
        self.flickrRequest.requestTimeoutInterval = 60.0;
    }
    
    return self;
}

+ (instancetype)sharedClient {
    NSAssert(_sharedClient, @"FlickrClient not initialized. [FlickrClient createWithAPIKey:secret:] must be called first.");
    
    return _sharedClient;
}

- (BOOL)isAuthorized {
    if (self.flickrContext.OAuthToken && [self.flickrContext.OAuthToken isNotEqualTo: @""]) {
        return true;
    }
    return false;
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError {
    NSLog(@"Error %@", [inError localizedDescription]);
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret {
    
    NSLog(@"Received request token %@", inRequestToken);
    
    self.flickrContext.OAuthToken = inRequestToken;
    self.flickrContext.OAuthTokenSecret = inSecret;
    
    NSURL *authURL = [self.flickrContext userAuthorizationURLWithRequestToken:inRequestToken requestedPermission:OFFlickrDeletePermission];
    
    if (![[NSWorkspace sharedWorkspace] openURL:authURL])
        NSLog(@"Failed to open url: %@", [authURL description]);
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID {
    
    _flickrContext.OAuthToken = inAccessToken;
    _flickrContext.OAuthTokenSecret = inSecret;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_flickrContext.OAuthToken forKey:kStoredAuthTokenKeyName];
    [defaults setValue:_flickrContext.OAuthTokenSecret forKey:kStoredAuthTokenSecretKeyName];
    
    NSLog(@"Flickr Client Did Log In %@ (%@)", inFullName, inNSID);
}

- (void)requestAuthorization {
    [self.flickrRequest fetchOAuthRequestTokenWithCallbackURL:[NSURL URLWithString:kFlickrClientOAuthCallbackURL]];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
}

- (BOOL)verifyAuthorizationWithToken:(NSString *)verifierToken {
    
    NSLog(@"Verifying auth with request token %@, verifier token %@", self.flickrContext.OAuthToken, verifierToken);
    
    [self.flickrRequest fetchOAuthAccessTokenWithRequestToken:self.flickrContext.OAuthToken verifier:verifierToken];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    
    return true;
}

- (void)deauthorize {
    _flickrContext.OAuthToken = nil;
    _flickrContext.OAuthTokenSecret = nil;
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:kStoredAuthTokenKeyName];
    [defaults setValue:nil forKey:kStoredAuthTokenSecretKeyName];

}

#pragma mark Helpers
- (NSDictionary *)defaultRequestParameters {
    return @{@"api_key":        self.apiKey,
             @"format":         @"json",
             @"nojsoncallback": @(1)};
}

-(void)DoProgress:(char*)label step:(int)step total:(int)total
{
    //progress width
    const int pwidth = 72;
    
    //minus label len
    long width = pwidth - strlen( label );
    long pos = ( step * width ) / total ;
    
    int percent = ( step * 100 ) / total;
    
    printf( "%s[", label );
    
    //fill progress bar with =
    for ( int i = 0; i < pos; i++ )  printf( "%c", '=' );
    
    //fill progress bar with spaces
    printf( "% *c", width - pos + 1, ']' );
    printf( " %3d%%\r", percent );
    
}

- (NSString*)uploadImage:(NSString *)inImagePath params:(NSDictionary*)params {

    NSString *filename = @"dummy";//[inImagePath lastPathComponent];
    
    NSError *error = nil;
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:inImagePath error:&error];
    NSNumber *fileSizeNumber = [fileInfo objectForKey:NSFileSize];
    NSUInteger fileSize = 0;
    if ([fileSizeNumber respondsToSelector:@selector(integerValue)]) {
        fileSize = [fileSizeNumber integerValue];
    }
    else {
        fileSize = [fileSizeNumber intValue];
    }
    
    if ([_flickrRequest uploadImageStream:[NSInputStream inputStreamWithFileAtPath:inImagePath] suggestedFilename:filename MIMEType:@"image/png" arguments:params]) {
        
        //[self DoProgress:"Uploading " step:0 total:fileSize];
        
        while ([self isRunning]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        }
        
        NSDictionary *photoIdDict = [_responseDict objectForKey:@"photoid"];
        NSString *photoId = [photoIdDict objectForKey:@"_text"];
        
        return photoId;
    } else {
        NSLog(@"Cannot upload %@", inImagePath);
        return nil;
    }
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes {
    //TODO display if requested, e.g. with command-line parameter -v
    //[self DoProgress:"Uploading " step:inSentBytes total:inTotalBytes];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary {
    
    _responseDict = inResponseDictionary;
    
    _flickrRequest.sessionInfo = nil;
}

- (BOOL)isRunning {
    return [_flickrRequest isRunning];
}

- (NSMutableDictionary*)getAllImages {
    _pages = 1;
    NSMutableDictionary *photoDict = [[NSMutableDictionary alloc]init];
    NSMutableArray *duplicates = [[NSMutableArray alloc]init];
    
    int pageNo = 1;
    do {
        NSArray *photoArray = [self searchImagesPage:pageNo];
        
        if (photoArray == nil) {
            continue;
        }
        
        for (int i = 0; i < [photoArray count]; i++) {
            NSDictionary *currentPhoto = [photoArray objectAtIndex:i];
            NSString *photoId = [currentPhoto objectForKey:@"id"];

            NSString *tagsString = [currentPhoto objectForKey:@"tags"];
            NSArray *tags = [tagsString componentsSeparatedByString:@" "];
            
            NSString *masterGuid = nil;
            for (int j = 0; j < [tags count]; j++) {
                NSString *tag = [tags objectAtIndex:j];
                if ([tag hasPrefix:@"iphoto2flickr:masterguid="]) {
                    masterGuid = [tag substringFromIndex:[@"iphoto2flickr:masterguid=" length]];
                    break;
                }
            }
            
            if (masterGuid) {
                
                // following transformations already performed by Flickr somehow, just documenting it here...
                masterGuid = [FlickrClient cleanTag:masterGuid];
                
                if ([photoDict objectForKey:masterGuid] != nil) {
                    [duplicates addObject:photoId];
                } else {
                    [photoDict setObject:currentPhoto forKey:masterGuid];
                }
            }
        }
        
        NSLog(@"Page %d: %lu entries", pageNo, (unsigned long)[photoArray count]);
        
        pageNo++;
        
    } while (pageNo <= _pages);
    
    NSLog(@"Found %lu images already uploaded", (unsigned long)[photoDict count]);
    
    [self deleteDuplicates:duplicates];
    
    return photoDict;
}

-(void)deleteDuplicates:(NSArray*)duplicates {
    NSLog(@"Deleting %lu duplicates", (unsigned long)[duplicates count]);
    
    for (int i = 0; i < [duplicates count]; i++) {
        NSString *photoId = [duplicates objectAtIndex:i];
        NSLog(@"- Deleting %@", photoId);
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                photoId, @"photo_id",
                                nil];
        
        _flickrRequest.sessionInfo = kDeletePhoto;
        [_flickrRequest callAPIMethodWithPOST:@"flickr.photos.delete" arguments:params];
        
        while ([self isRunning]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        }
        
    }
}

- (NSArray*)searchImagesPage:(int)pageNo {

    _flickrRequest.sessionInfo = kQueryGuid;
    
    NSDictionary *searchParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                 // @"iphoto2flickr:", @"machine_tags", // This skips images that should be returned?!?
                                  @"last_update, tags, description", @"extras",
                                  @"me", @"user_id",
                                  @"500", @"per_page",
                                  [NSString stringWithFormat:@"%d", pageNo], @"page",
                                  nil];
    
    [_flickrRequest callAPIMethodWithGET:@"flickr.photos.search" arguments:searchParams];
    
    while ([self isRunning]) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
    }

    NSDictionary *photosDict = [_responseDict objectForKey:@"photos"];
    
    _pages = [[photosDict objectForKey:@"pages"] intValue];

    NSArray *photoArray = [photosDict objectForKey:@"photo"];
    
    return photoArray;
}

- (NSString*) createPhotosetTitle:(NSString*)title description:(NSString*)description primaryPhotoId:(NSString*)primaryPhotoId {
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            description, @"description",
                            title, @"title",
                            primaryPhotoId, @"primary_photo_id",
                            nil];
    
    _flickrRequest.sessionInfo = kCreatePhotoset;
    [_flickrRequest callAPIMethodWithPOST:@"flickr.photosets.create" arguments:params];
    
    while ([self isRunning]) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }
    
    NSDictionary *photosetDict = [_responseDict objectForKey:@"photoset"];
    NSString *photosetId = [photosetDict objectForKey:@"id"];
    return photosetId;
}

- (NSArray*) getAllPhotosets {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            nil];
    
    _flickrRequest.sessionInfo = kGetPhotosetList;
    [_flickrRequest callAPIMethodWithGET:@"flickr.photosets.getList" arguments:params];
    
    while ([self isRunning]) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }
    
    NSDictionary *photosetsDict = [_responseDict objectForKey:@"photosets"];
    NSArray *photosetsArray = [photosetsDict objectForKey:@"photoset"];
    return photosetsArray;
}

-(void) editPhotoset:(NSString*)photosetId primaryPhotoId:(NSString*)primaryPhotoId photoIds:(NSString*)photoIds {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            photosetId, @"photoset_id",
                            primaryPhotoId, @"primary_photo_id",
                            photoIds, @"photo_ids",
                            nil];
    
    _flickrRequest.sessionInfo = kEditPhotosetPhotos;
    [_flickrRequest callAPIMethodWithPOST:@"flickr.photosets.editPhotos" arguments:params];
    
    while ([self isRunning]) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }
}

+ (NSString*)cleanTag:(NSString*)rawTag {
    NSString *guid = [rawTag copy];
    guid = [guid lowercaseString];
    guid = [guid stringByReplacingOccurrencesOfString:@"%" withString:@""];
    guid = [guid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    guid = [guid stringByReplacingOccurrencesOfString:@"+" withString:@""];
    return guid;
}

@end
