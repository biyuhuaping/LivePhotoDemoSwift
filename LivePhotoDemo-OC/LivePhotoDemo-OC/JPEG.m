//
//  JPEG.m
//  LivePhotoDemo-OC
//
//  Created by Lcrnice on 2018/7/2.
//  Copyright © 2018年 Lcrnice. All rights reserved.
//

#import "JPEG.h"

@import MobileCoreServices;
@import ImageIO;

static NSString const *kFigAppleMakerNote_AssetIdentifier = @"17";

@interface JPEG()

@property (nonatomic, copy) NSString *path;

@end

@implementation JPEG

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
    }
    return self;
}

- (NSString *)read {
    
    return nil;
}

- (void)writeToDest:(NSString *)destPath withAssetIdentifier:(NSString *)assetIdentifier {
     CGImageDestinationRef dest = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:destPath], kUTTypeJPEG, 1, nil);
    if (!dest) {
        return;
    }
    
    CGImageSourceRef imageSource = [self imageSource];
    NSMutableDictionary *metadata = [self metadata];
    if (!imageSource || !metadata) {
        return;
    }
    
    NSMutableDictionary *makerNote = @{}.mutableCopy;
    [makerNote setObject:assetIdentifier forKey:kFigAppleMakerNote_AssetIdentifier];
    [metadata setObject:makerNote forKey:(__bridge_transfer NSString *)kCGImagePropertyMakerAppleDictionary];
    
    CGImageDestinationAddImageFromSource(dest, imageSource, 0, (CFDictionaryRef)metadata);
    CGImageDestinationFinalize(dest);
    CFRelease(dest);
}

- (NSMutableDictionary *)metadata {
    return [(__bridge_transfer  NSDictionary*)CGImageSourceCopyPropertiesAtIndex([self imageSource], 0, nil) mutableCopy];
}

- (CGImageSourceRef)imageSource {
    return CGImageSourceCreateWithData((CFDataRef)[self data], nil);
}

- (NSData *)data {
    
    return [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:self.path]];
}

@end
