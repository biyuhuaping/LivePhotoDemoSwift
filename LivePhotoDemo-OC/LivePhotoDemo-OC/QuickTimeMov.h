//
//  QuickTimeMov.h
//  LivePhotoDemo-OC
//
//  Created by Lcrnice on 2018/7/2.
//  Copyright © 2018年 Lcrnice. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QuickTimeMov : NSObject

- (instancetype)initWithPath:(NSString *)path;
- (void)writeToDestPath:(NSString *)destPath withAssetIdentifier:(NSString *)assetIdentifier;

@end
