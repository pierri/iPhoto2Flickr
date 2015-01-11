//
//  TestiPhoto2Flickr.m
//  TestiPhoto2Flickr
//
//  Created by Pierri on 09/01/2015.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "FlickrClient.h"

@interface TestiPhoto2Flickr : XCTestCase

@end

@implementation TestiPhoto2Flickr

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCleanTag {
    XCTAssertEqualObjects([FlickrClient cleanTag:@""], @"");
    
    XCTAssertEqualObjects([FlickrClient cleanTag:@"X4AphRP0TL+%i7WxRlahZg"], @"x4aphrp0tli7wxrlahzg");
    
    XCTAssertEqualObjects([FlickrClient cleanTag:@"x4aphrp0tli7wxrlahzg"], @"x4aphrp0tli7wxrlahzg");
    
    XCTAssertEqualObjects([FlickrClient cleanTag:@"EC9E86EB-2E50-43E5-AAD8-AAD52B8D08D6"], @"ec9e86eb2e5043e5aad8aad52b8d08d6");
    
}


@end
