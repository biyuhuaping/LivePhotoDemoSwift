//
//  JPEG.h
//  LivePhotoDemo-OC
//
//  Created by Lcrnice on 2018/7/2.
//  Copyright © 2018年 Lcrnice. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JPEG : NSObject

- (instancetype)initWithPath:(NSString *)path;
- (NSString *)read;
- (void)writeToDest:(NSString *)destPath withAssetIdentifier:(NSString *)assetIdentifier;

@end
