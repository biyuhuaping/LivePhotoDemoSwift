//
//  MediaViewController.m
//  LivePhotoDemo-OC
//
//  Created by Lcrnice on 2018/7/5.
//  Copyright © 2018年 Lcrnice. All rights reserved.
//

#import "MediaViewController.h"

@import Photos;
@import AVFoundation;

typedef void(^Result)(NSData *fileData, NSString *fileName);
typedef void(^ResultPath)(NSString *filePath, NSString *fileName);

@interface MediaViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (nonatomic, strong) AVPlayer *player;

@end

@implementation MediaViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    PHFetchResult <PHAssetCollection *>*livePhotoAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumLivePhotos options:nil];
    PHAssetCollection *assetCollection = livePhotoAlbums.firstObject;
    PHFetchResult <PHAsset *>*fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
    PHAsset *livePhotoAsset = fetchResult.lastObject;
    
    [MediaViewController getImageFromPHAsset:livePhotoAsset Complete:^(NSData *fileData, NSString *fileName) {
        NSLog(@"image file name:%@", fileName);
        UIImage *img = [UIImage imageWithData:fileData];
        self.imageView.image = img;
    }];
    
    [MediaViewController getVideoFromPHAsset:livePhotoAsset Complete:^(NSData *fileData, NSString *fileName) {
    }];
    
    [MediaViewController getVideoPathFromPHAsset:livePhotoAsset Complete:^(NSString *filePath, NSString *fileName) {
        NSLog(@"video file name:%@", fileName);
        self.player = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filePath]]];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        layer.frame = self.playerView.layer.bounds;
        [self.playerView.layer addSublayer:layer];
        [self.player play];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
    }];
}

+ (void)getImageFromPHAsset:(PHAsset *)asset Complete:(Result)result {
    __block NSData *data;
    PHAssetResource *resource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    if (asset.mediaType == PHAssetMediaTypeImage && asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.synchronous = YES;
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
             data = [NSData dataWithData:imageData];
         }];
    }
    
    if (data.length <= 0) {
        !result ?: result(nil, nil);
    } else {
        !result ?: result(data, resource.originalFilename);
    }
}

+ (void)getVideoFromPHAsset:(PHAsset *)asset Complete:(Result)result {
    NSArray *assetResources = [PHAssetResource assetResourcesForAsset:asset];
    PHAssetResource *resource;
    
    for (PHAssetResource *assetRes in assetResources) {
        if (assetRes.type == PHAssetResourceTypePairedVideo ||
            assetRes.type == PHAssetResourceTypeVideo) {
            resource = assetRes;
        }
    }
    NSString *fileName = @"tempAssetVideo.mov";
    if (resource.originalFilename) {
        fileName = resource.originalFilename;
    }
    
    if (asset.mediaType == PHAssetMediaTypeVideo || asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        
        NSString *PATH_MOVIE_FILE = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:PATH_MOVIE_FILE error:nil];
        [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resource toFile:[NSURL fileURLWithPath:PATH_MOVIE_FILE] options:nil completionHandler:^(NSError * _Nullable error) {
            if (error) {
                !result ?: result(nil, nil);
            } else {
                NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:PATH_MOVIE_FILE]];
                !result ?: result(data, fileName);
            }
            [[NSFileManager defaultManager] removeItemAtPath:PATH_MOVIE_FILE  error:nil];
        }];
    } else {
        !result ?: result(nil, nil);
    }
}

+ (void)getVideoPathFromPHAsset:(PHAsset *)asset Complete:(ResultPath)result {
    NSArray *assetResources = [PHAssetResource assetResourcesForAsset:asset];
    PHAssetResource *resource;
    
    for (PHAssetResource *assetRes in assetResources) {
        if (assetRes.type == PHAssetResourceTypePairedVideo ||
            assetRes.type == PHAssetResourceTypeVideo) {
            resource = assetRes;
        }
    }
    NSString *fileName = @"tempAssetVideo.mov";
    if (resource.originalFilename) {
        fileName = resource.originalFilename;
    }
    
    if (asset.mediaType == PHAssetMediaTypeVideo || asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        
        NSString *PATH_MOVIE_FILE = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:PATH_MOVIE_FILE error:nil];
        [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resource toFile:[NSURL fileURLWithPath:PATH_MOVIE_FILE] options:nil completionHandler:^(NSError * _Nullable error) {
            if (error) {
                !result ?: result(nil, nil);
            } else {
                !result ?: result(PATH_MOVIE_FILE, fileName);
            }
        }];
    } else {
        !result ?: result(nil, nil);
    }
}

#pragma mark - AVPlayer
-(void)playbackFinished:(NSNotification *)notification{
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player play];
}

@end
