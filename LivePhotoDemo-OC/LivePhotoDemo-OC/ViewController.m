//
//  ViewController.m
//  LivePhotoDemo-OC
//
//  Created by Lcrnice on 2018/7/2.
//  Copyright © 2018年 Lcrnice. All rights reserved.
//

#import "ViewController.h"
#import "JPEG.h"
#import "QuickTimeMov.h"

@import Photos;
@import PhotosUI;
@import MobileCoreServices;

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet PHLivePhotoView *livePhotoView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadVideoWithVideoURL:[[NSBundle mainBundle] URLForResource:@"video" withExtension:@"m4v"]];
}

- (void)loadVideoWithVideoURL:(NSURL *)videoURL {
    self.livePhotoView.livePhoto = nil;
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    NSValue *time = [NSValue valueWithCMTime:CMTimeMakeWithSeconds(CMTimeGetSeconds(asset.duration)/2, asset.duration.timescale)];
    [generator generateCGImagesAsynchronouslyForTimes:@[time] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        if (image) {
            NSData *data = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
            NSArray <NSURL *>*urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
            NSURL *imageURL = [urls.firstObject URLByAppendingPathComponent:@"image.heic"];
            [data writeToURL:imageURL atomically:YES];
            
            NSString *image = imageURL.path;
            NSString *mov = videoURL.path;
            NSString *output = [ViewController livePath];
            NSString *assetIdentifier = [[NSUUID UUID] UUIDString];
            [[NSFileManager defaultManager] createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:&error];
            if (!error) {
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/IMG.heic", output] error:&error];
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/IMG.MOV", output] error:&error];
            }
            
            [[[JPEG alloc] initWithPath:image] writeToDest:[NSString stringWithFormat:@"%@/IMG.heic", output] withAssetIdentifier:assetIdentifier];
            [[[QuickTimeMov alloc] initWithPath:mov] writeToDestPath:[NSString stringWithFormat:@"%@/IMG.MOV", output] withAssetIdentifier:assetIdentifier];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:[[ViewController livePath] stringByAppendingString:@"/IMG.MOV"]], [NSURL fileURLWithPath:[[ViewController livePath] stringByAppendingString:@"/IMG.heic"]]] placeholderImage:nil targetSize:self.view.bounds.size contentMode:PHImageContentModeAspectFit resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nonnull info) {
                    self.livePhotoView.livePhoto = livePhoto;
                    [self exportLivePhoto];
                }];
            });
        }
    }];
}

+ (NSString *)livePath {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingString:@"/"];
    return path;
}

- (void)exportLivePhoto {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCreationRequest *createRequest = [PHAssetCreationRequest creationRequestForAsset];
        PHAssetResourceCreationOptions *options = [PHAssetResourceCreationOptions new];
        [createRequest addResourceWithType:PHAssetResourceTypePairedVideo fileURL:[NSURL fileURLWithPath:[[ViewController livePath] stringByAppendingString:@"/IMG.MOV"]] options:options];
        [createRequest addResourceWithType:PHAssetResourceTypePhoto fileURL:[NSURL fileURLWithPath:[[ViewController livePath] stringByAppendingString:@"/IMG.heic"]] options:options];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"%@", error.localizedDescription);
        }
    }];
}

- (IBAction)takePhoto:(UIBarButtonItem *)sender {
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.mediaTypes = @[(__bridge_transfer NSString *)kUTTypeMovie];
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        NSURL *url = info[UIImagePickerControllerMediaURL];
        [self loadVideoWithVideoURL:url];
    }];
}

@end
