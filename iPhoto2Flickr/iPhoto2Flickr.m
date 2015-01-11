//
//  iPhoto2Flickr.m
//  iPhoto2Flickr
//
//  Created by Pierri on 09/01/2015.
//

#import "iPhoto2Flickr.h"


@interface iPhoto2Flickr()

// iPhoto Library
@property (nonatomic) NSArray *iPhotoRolls;
@property (nonatomic) NSDictionary *iPhotoMasters;
@property (nonatomic) NSDictionary *iPhotoFaces;

// Flickr contents
@property (nonatomic) FlickrClient *flickrClient;
@property (nonatomic) NSMutableDictionary *mapFlickrPhotoForIPhotoMaster;
@property (nonatomic) NSArray *flickrPhotosets;

@end

@implementation NSArray (Reverse)

- (NSArray *)reversedArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self count]];
    NSEnumerator *enumerator = [self reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
    return array;
}

@end

@implementation iPhoto2Flickr

-(void) uploadRollsToFlickr:(FlickrClient*) flickrClient {
    NSLog(@"Getting Flickr image list");
    _flickrClient = flickrClient;
    _mapFlickrPhotoForIPhotoMaster = [_flickrClient getAllImages];
    
    NSLog(@"Getting Flickr photosets");
    _flickrPhotosets = [_flickrClient getAllPhotosets];
    
    NSLog(@"Reading iPhoto Album Data");
    NSDictionary *iPhotoAlbumData = [self readiPhotoAlbumData];
    _iPhotoRolls = [iPhotoAlbumData valueForKey:@"List of Rolls"];
    _iPhotoRolls = [_iPhotoRolls reversedArray];
    _iPhotoMasters = [iPhotoAlbumData valueForKey:@"Master Image List"];
    _iPhotoFaces = [iPhotoAlbumData valueForKey:@"List of Faces"];
    
    for (NSDictionary *iPhotoRoll in _iPhotoRolls) {
        NSString *flickrPhotosetId = [self uploadiPhotoAlbumToFlickr:iPhotoRoll];
    }
    
    // TODO flickr.photosets.orderSets

}

- (NSDictionary*)readiPhotoAlbumData {
    NSString *albumDataXml = [@"~/Pictures/iPhoto Library/AlbumData.xml" stringByExpandingTildeInPath];
    NSDictionary *albumData = [NSDictionary dictionaryWithContentsOfFile:albumDataXml];
    return albumData;
}

- (NSString*)uploadiPhotoAlbumToFlickr:(NSDictionary *)iPhotoRoll {
    NSString *iPhotoAlbumName = [iPhotoRoll objectForKey:@"RollName"];
    NSLog(@"- Processing album %@", iPhotoAlbumName);

    NSString *iPhotoAlbumKeyPhotoId = [iPhotoRoll objectForKey:@"KeyPhotoKey"];
    NSString *iPhotoAlbumComment = @""; // TODO read description (not available in AlbumData.xml...)
    
    NSMutableArray *flickrPhotoIds = [[NSMutableArray alloc]init];
    
    NSArray *iPhotoRollMasterIds = [iPhotoRoll objectForKey:@"KeyList"];
    for (NSString *iPhotoMasterId in iPhotoRollMasterIds) {
        NSDictionary *iPhotoMaster = [_iPhotoMasters objectForKey:iPhotoMasterId];
        NSString *flickrPhotoId = [self uploadiPhotoMasterToFlickr:iPhotoMaster];
        
        if (flickrPhotoId != nil) {
            NSDictionary *flickrPhoto = [NSDictionary dictionaryWithObjectsAndKeys:flickrPhotoId, @"id", nil];
            [_mapFlickrPhotoForIPhotoMaster setObject:flickrPhoto forKey:iPhotoMasterId];
            [flickrPhotoIds addObject:flickrPhotoId];
        }
    }
    
    // Check if photoset exists
    NSDictionary *flickrPhotoset = [self getFlickrPhotosetForiPhotoAlbum:iPhotoRoll];
    
    NSString *flickrPrimaryPhotoId = [self getFlickrPhotoIdForiPhotoMasterGuid:iPhotoAlbumKeyPhotoId];
    NSString *flickrPhotosetId;

    if (flickrPhotoset) {
        flickrPhotosetId = [flickrPhotoset objectForKey:@"id"];

        NSString *currentPrimaryPhotoId = [flickrPhotoset objectForKey:@"primary"];
        int currentPhotoCount = [[flickrPhotoset objectForKey:@"photos"] intValue];
        int currentVideoCount = [[flickrPhotoset objectForKey:@"videos"] intValue];
        
        if ([currentPrimaryPhotoId isEqualToString:flickrPrimaryPhotoId] && currentPhotoCount + currentVideoCount == [flickrPhotoIds count]) {
            NSLog(@"  - Photoset %@ already up-to-date", flickrPhotosetId);
            return flickrPhotosetId;
        }
        
        NSLog(@"  - Updating photoset %@", flickrPhotosetId);
    } else {
        flickrPhotosetId = [_flickrClient createPhotosetTitle:iPhotoAlbumName description:iPhotoAlbumComment primaryPhotoId:flickrPrimaryPhotoId];
        NSLog(@"  - Created photoset %@", flickrPhotosetId);
    }
    
    NSString *flickrPhotoIdsStr = [flickrPhotoIds componentsJoinedByString:@","];
    
    [_flickrClient editPhotoset:flickrPhotosetId primaryPhotoId:flickrPrimaryPhotoId photoIds:flickrPhotoIdsStr];
    return flickrPhotosetId;
}

- (NSString *)uploadiPhotoMasterToFlickr:(NSDictionary *)iPhotoMaster {
    NSString *iPhotoMasterCaption = [iPhotoMaster objectForKey:@"Caption"];
    
    iPhotoMasterCaption = [iPhotoMasterCaption stringByReplacingOccurrencesOfString:@"~" withString:@"_"]; // tildes in the caption generate an invalid XML upload reponse (ObjectiveFlickr error 2147418115)
    
    NSString *iPhotoMasterComment = [iPhotoMaster objectForKey:@"Comment"];
    NSString *iPhotoMasterImagePath = [iPhotoMaster objectForKey:@"ImagePath"];
    
    NSString *flickrPhotoTags = [self buildFlickrPhotoTagsForiPhotoMaster:iPhotoMaster];
    
    NSString *iPhotoMasterGuid = [iPhotoMaster objectForKey:@"GUID"];
    NSString *flickrPhotoId = [self getFlickrPhotoIdForiPhotoMasterGuid:iPhotoMasterGuid];
    if (flickrPhotoId != nil) { // TODO check that no change happened in iPhoto since last time
        NSLog(@"  - %@ found on Flickr (%@)", iPhotoMasterCaption, flickrPhotoId);
    } else {
        NSLog(@"  - Uploading %@", iPhotoMasterCaption);
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                iPhotoMasterCaption, @"title",
                                iPhotoMasterComment, @"description",
                                flickrPhotoTags, @"tags",
                                @"2", @"hidden",
                                @"0", @"is_public",
                                @"0", @"is_friend",
                                @"0", @"is_family",
                                nil];
        flickrPhotoId = [_flickrClient uploadImage:iPhotoMasterImagePath params:params];
    }
    return flickrPhotoId;
}

- (NSString *)buildFlickrPhotoTagsForiPhotoMaster:(NSDictionary *)iPhotoMaster {
    
    NSString *iPhotoMasterGuid = [iPhotoMaster objectForKey:@"GUID"];
    
    NSString *machineTagForFlickrPhoto = [NSString stringWithFormat:@"iPhoto2Flickr:masterGuid=%@ ", iPhotoMasterGuid];
    
    NSString *facesTagForFlickrPhoto = [self buildFacesTagForiPhotoMaster:iPhotoMaster];
    
    NSString *flickrPhotoTags = [machineTagForFlickrPhoto stringByAppendingString:facesTagForFlickrPhoto];
    
    return flickrPhotoTags;
}

- (NSString *)buildFacesTagForiPhotoMaster:(NSDictionary *)iPhotoMaster {
    NSString *facesTag = @"";
    NSArray *facesInPic = [iPhotoMaster objectForKey:@"Faces"];
    for (NSDictionary *faceInPic in facesInPic) {
        NSString *faceKey = [faceInPic objectForKey:@"face key"];
        
        NSDictionary *face = [_iPhotoFaces objectForKey:faceKey];
        NSString *faceName = [face objectForKey:@"name"];
        
        NSString *faceTag = [NSString stringWithFormat:@"\"%@\" ", faceName];
        
        facesTag = [facesTag stringByAppendingString:faceTag];
    }
    return facesTag;
}

- (NSString *)getFlickrPhotoIdForiPhotoMasterGuid:(NSString *)iPhotoMasterGuid {
    NSString *guidForSearch = [FlickrClient cleanTag:iPhotoMasterGuid];
    NSDictionary *flickrPhoto = [_mapFlickrPhotoForIPhotoMaster objectForKey:guidForSearch];
    NSString *flickrPhotoId = [flickrPhoto objectForKey:@"id"];
    return flickrPhotoId;
}

- (NSDictionary *)getFlickrPhotosetForiPhotoAlbum:(NSDictionary *)iPhotoRoll {
    NSString *iPhotoAlbumName = [iPhotoRoll objectForKey:@"RollName"];

    NSDictionary *flickrPhotoset = nil;
    for (flickrPhotoset in _flickrPhotosets) {
        NSDictionary *titleDict = [flickrPhotoset objectForKey:@"title"];
        NSString *photosetTitle = [titleDict objectForKey:@"_text"];
        
        if ([photosetTitle isEqualToString:iPhotoAlbumName]) {
            break;
        }
    }
    return flickrPhotoset;
}

@end
