//
//  QuickTimeMov.m
//  LivePhotoDemo-OC
//
//  Created by Lcrnice on 2018/7/2.
//  Copyright © 2018年 Lcrnice. All rights reserved.
//

#import "QuickTimeMov.h"

@import AVFoundation;

static NSString const *kKeyContentIdentifier = @"com.apple.quicktime.content.identifier";
static NSString const *kKeyStillImageTime = @"com.apple.quicktime.still-image-time";
static NSString const *kKeySpaceQuickTimeMetadata = @"mdta";

@interface QuickTimeMov()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) CMTimeRange dummyTimeRange;
@property (nonatomic, strong) AVURLAsset *asset;

@end

@implementation QuickTimeMov

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
        _dummyTimeRange = CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(200, 3000));
        _asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:_path]];
    }
    return self;
}

- (NSString *)readAssetIdentifier {
    for (AVMetadataItem *item in [self metadata]) {
        if (item.key == kKeyContentIdentifier && item.keySpace == kKeySpaceQuickTimeMetadata) {
            return (NSString *)item.value;
        }
    }
    return nil;
}

- (NSNumber *)readStillImageTime {
    AVAssetTrack *track = [self track:AVMediaTypeVideo];
    if (track) {
        AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:@{(__bridge_transfer  NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]}];
        NSError *error;
        AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
        if ([reader canAddOutput:output]) {
            [reader addOutput:output];
        }
        [reader startReading];
        
        while (YES) {
            CMSampleBufferRef buffer = output.copyNextSampleBuffer;
            if (!buffer) {
                return nil;
            }
            if (CMSampleBufferGetNumSamples(buffer) != 0) {
                AVTimedMetadataGroup *group = [[AVTimedMetadataGroup alloc] initWithSampleBuffer:buffer];
                for (AVMetadataItem *item in group.items) {
                    if (item.key == kKeyStillImageTime && item.keySpace == kKeySpaceQuickTimeMetadata) {
                        return item.numberValue;
                    }
                }
            }
        }
    }
    return nil;
}

- (void)writeToDestPath:(NSString *)destPath withAssetIdentifier:(NSString *)assetIdentifier {
    AVAssetReader *audioReader;
    AVAssetWriterInput *audioWriterInput;
    AVAssetReaderOutput *audioReaderOutput;
    @try {
        // --------------------------------------------------
        // reader for source video
        // --------------------------------------------------
        AVAssetTrack *track = [self track:AVMediaTypeVideo];
        if (!track) {
            NSLog(@"not found video track");
            return;
        }
        
        AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:@{(__bridge_transfer  NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]}];
        NSError *error;
        AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
        if ([reader canAddOutput:output]) {
            [reader addOutput:output];
        }
        
        // --------------------------------------------------
        // writer for mov
        // --------------------------------------------------
        AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:destPath] fileType:AVFileTypeQuickTimeMovie error:&error];
        writer.metadata = @[[self metadataFor:assetIdentifier]];
        
        // video track
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[self videoSettings:track.naturalSize]];
        input.expectsMediaDataInRealTime = YES;
        input.transform = [track preferredTransform];
        if ([writer canAddInput:input]) {
            [writer addInput:input];
        }
        
        
        NSURL *url = [NSURL fileURLWithPath:self.path];
        AVAsset *aAudioAsset = [AVAsset assetWithURL:url];
        
        if (aAudioAsset.tracks.count > 1) {
            NSLog(@"Has Audio");
            // setup audio writer
            audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];
            
            audioWriterInput.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:audioWriterInput]) {
                [writer addInput:audioWriterInput];
            }
            // setup audio reader
            AVAssetTrack *audioTrack = [aAudioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
            audioReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
            
            @try {
                audioReader = [AVAssetReader assetReaderWithAsset:aAudioAsset error:&error];
            } @catch (NSException *exception) {
                NSLog(@"Unable to read Asset: %@", error.description);
            } @finally {
            }
            
            if ([audioReader canAddOutput:audioReaderOutput]) {
                [audioReader addOutput:audioReaderOutput];
            } else {
                NSLog(@"can add audio reader");
            }
        }
        
        // metadata track
        AVAssetWriterInputMetadataAdaptor *adapter = [self metadataAdapter];
        [writer addInput:adapter.assetWriterInput];
        
        // --------------------------------------------------
        // creating video
        // --------------------------------------------------
        [writer startWriting];
        [reader startReading];
        [writer startSessionAtSourceTime:kCMTimeZero];
        
        // write metadata track
        [adapter appendTimedMetadataGroup:[[AVTimedMetadataGroup alloc] initWithItems:@[[self metadataForStillImageTime]] timeRange:self.dummyTimeRange]];
        
        // write video track
        [input requestMediaDataWhenReadyOnQueue:dispatch_queue_create("assetVideoWriterQueue", DISPATCH_QUEUE_SERIAL) usingBlock:^{
            while (input.isReadyForMoreMediaData) {
                if (reader.status == AVAssetReaderStatusReading) {
                    CMSampleBufferRef buffer = output.copyNextSampleBuffer;
                    if (buffer) {
                        if (![input appendSampleBuffer:buffer]) {
                            NSLog(@"cannot write: %@", writer.error.localizedDescription);
                            [reader cancelReading];
                        }
                    }
                } else {
                    [input markAsFinished];
                    if (reader.status == AVAssetReaderStatusCompleted && aAudioAsset.tracks.count > 1) {
                        [audioReader startReading];
                        [writer startSessionAtSourceTime:kCMTimeZero];
                        dispatch_queue_t media_queue = dispatch_queue_create("assetAudioWriterQueue", DISPATCH_QUEUE_SERIAL);
                        [audioWriterInput requestMediaDataWhenReadyOnQueue:media_queue usingBlock:^{
                            while ([audioWriterInput isReadyForMoreMediaData]) {
                                NSLog(@"Second loop");
                                CMSampleBufferRef sampleBuffer2 = audioReaderOutput.copyNextSampleBuffer;
                                if (audioReader.status == AVAssetReaderStatusReading && sampleBuffer2) {
                                    if (![audioWriterInput appendSampleBuffer:sampleBuffer2]) {
                                        [audioReader cancelReading];
                                    }
                                } else {
                                    [audioWriterInput markAsFinished];
                                    NSLog(@"Audio writer finish");
                                    [writer finishWritingWithCompletionHandler:^{
                                        NSError *e = writer.error;
                                        if (e) {
                                            NSLog(@"cannot write: %@", e.localizedDescription);
                                        } else {
                                            NSLog(@"finish writing.");
                                        }
                                    }];
                                }
                            }
                        }];
                    } else {
                        NSLog(@"Video Reader not completed");
                        [writer finishWritingWithCompletionHandler:^{
                            NSError *e = writer.error;
                            if (e) {
                                NSLog(@"cannot write: %@", e.localizedDescription);
                            } else {
                                NSLog(@"finish writing.");
                            }
                        }];
                    }
                }
            }
        }];
        while (writer.status == AVAssetWriterStatusWriting) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        }
        NSError *e = writer.error;
        if (e) {
            NSLog(@"cannot write: %@", e.localizedDescription);
        }
    } @catch (NSException *exception) {
        NSLog(@"error");
    } @finally { }
}

#pragma mark - fileprivate
- (NSArray <AVMetadataItem *>*)metadata {
    return [self.asset metadataForFormat:AVMetadataFormatQuickTimeMetadata];
}

- (AVAssetTrack *)track:(AVMediaType)mediaType {
    return [self.asset tracksWithMediaType:mediaType].firstObject;
}

- (AVAssetWriterInputMetadataAdaptor *)metadataAdapter {
    NSDictionary *spec = @{
                           (__bridge_transfer NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: [NSString stringWithFormat:@"%@/%@", kKeySpaceQuickTimeMetadata, kKeyStillImageTime],
                           (__bridge_transfer NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: @"com.apple.metadata.datatype.int8"
                           };
    CMFormatDescriptionRef desc;
    CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)@[spec], &desc);
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:desc];
    CFRelease(desc);
    return [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
}

- (NSDictionary <NSString *, id> *)videoSettings:(CGSize)size {
    return @{
             AVVideoCodecKey: AVVideoCodecTypeH264,
             AVVideoWidthKey: @(size.width),
             AVVideoHeightKey: @(size.height)
             };
}

- (AVMetadataItem *)metadataFor:(NSString *)assetIdentifier {
    AVMutableMetadataItem *item = [AVMutableMetadataItem new];
    item.key = kKeyContentIdentifier;
    item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    item.value = assetIdentifier;
    item.dataType = @"com.apple.metadata.datatype.UTF-8";
    return item;
}

- (AVMetadataItem *)metadataForStillImageTime {
    AVMutableMetadataItem *item = [AVMutableMetadataItem new];
    item.key = kKeyStillImageTime;
    item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    item.value = @(0);
    item.dataType = @"com.apple.metadata.datatype.int8";
    return item;
}

@end
