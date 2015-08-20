//
//  ExportEffects
//  FunVideoCrop
//
//  Created by Johnny Xu(徐景周) on 5/30/15.
//  Copyright (c) 2015 Future Studio. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ExportEffects.h"
#import "AVAsset+help.h"

#define DefaultOutputVideoName @"outputMovie.mp4"
#define DefaultOutputAudioName @"outputAudio.caf"

@interface ExportEffects ()
{
}

@property (strong, nonatomic) NSTimer *timerEffect;
@property (strong, nonatomic) AVAssetExportSession *exportSession;

@end

@implementation ExportEffects
{

}

+ (ExportEffects *)sharedInstance
{
    static ExportEffects *sharedInstance = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[ExportEffects alloc] init];
    });
    
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        _timerEffect = nil;
        _exportSession = nil;
        
        _filenameBlock = nil;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_exportSession)
    {
        _exportSession = nil;
    }
    
    if (_timerEffect)
    {
        [_timerEffect invalidate];
        _timerEffect = nil;
    }
}

#pragma mark Utility methods
- (NSString*)getOutputFilePath
{
    NSString* mp4OutputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:DefaultOutputVideoName];
    return mp4OutputFile;
}

- (NSString*)getTempOutputFilePath
{
    NSString *path = NSTemporaryDirectory();
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    formatter.dateFormat = @"yyyyMMddHHmmssSSS";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    return fileName;
}

#pragma mark - writeExportedVideoToAssetsLibrary
- (void)writeExportedVideoToAssetsLibrary:(NSString *)outputPath
{
    __unsafe_unretained typeof(self) weakSelf = self;
    NSURL *exportURL = [NSURL fileURLWithPath:outputPath];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:exportURL])
    {
        [library writeVideoAtPathToSavedPhotosAlbum:exportURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             NSString *message;
             if (!error)
             {
                 message = GBLocalizedString(@"MsgSuccess");
             }
             else
             {
                 message = [error description];
             }
             
             NSLog(@"%@", message);
             
             // Output path
             self.filenameBlock = ^(void) {
                 return outputPath;
             };
             
             if (weakSelf.finishVideoBlock)
             {
                 weakSelf.finishVideoBlock(YES, message);
             }
         }];
    }
    else
    {
        NSString *message = GBLocalizedString(@"MsgFailed");;
        NSLog(@"%@", message);
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (_finishVideoBlock)
        {
            _finishVideoBlock(NO, message);
        }
    }
    
    library = nil;
}

#pragma mark - addAudioMixToComposition
- (void)addAudioMixToComposition:(AVMutableComposition *)composition withAudioMix:(AVMutableAudioMix *)audioMix withAsset:(AVURLAsset*)commentary
{
    NSInteger i;
    NSArray *tracksToDuck = [composition tracksWithMediaType:AVMediaTypeAudio];
    
    // 1. Clip commentary duration to composition duration.
    CMTimeRange commentaryTimeRange = CMTimeRangeMake(kCMTimeZero, commentary.duration);
    if (CMTIME_COMPARE_INLINE(CMTimeRangeGetEnd(commentaryTimeRange), >, [composition duration]))
        commentaryTimeRange.duration = CMTimeSubtract([composition duration], commentaryTimeRange.start);
    
    // 2. Add the commentary track.
    AVMutableCompositionTrack *compositionCommentaryTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:TrackIDCustom];
    AVAssetTrack * commentaryTrack = [[commentary tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, commentaryTimeRange.duration) ofTrack:commentaryTrack atTime:commentaryTimeRange.start error:nil];
    
    // 3. Fade in for bgMusic
    CMTime fadeTime = CMTimeMake(1, 1);
    CMTimeRange startRange = CMTimeRangeMake(kCMTimeZero, fadeTime);
    NSMutableArray *trackMixArray = [NSMutableArray array];
    AVMutableAudioMixInputParameters *trackMixComentray = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:commentaryTrack];
    [trackMixComentray setVolumeRampFromStartVolume:0.0f toEndVolume:0.5f timeRange:startRange];
    [trackMixArray addObject:trackMixComentray];
    
    // 4. Fade in & Fade out for original voices
    for (i = 0; i < [tracksToDuck count]; i++)
    {
        CMTimeRange timeRange = [[tracksToDuck objectAtIndex:i] timeRange];
        if (CMTIME_COMPARE_INLINE(CMTimeRangeGetEnd(timeRange), ==, kCMTimeInvalid))
        {
            break;
        }
        
        CMTime halfSecond = CMTimeMake(1, 2);
        CMTime startTime = CMTimeSubtract(timeRange.start, halfSecond);
        CMTime endRangeStartTime = CMTimeAdd(timeRange.start, timeRange.duration);
        CMTimeRange endRange = CMTimeRangeMake(endRangeStartTime, halfSecond);
        if (startTime.value < 0)
        {
            startTime.value = 0;
        }
        
        [trackMixComentray setVolumeRampFromStartVolume:0.5f toEndVolume:0.2f timeRange:CMTimeRangeMake(startTime, halfSecond)];
        [trackMixComentray setVolumeRampFromStartVolume:0.2f toEndVolume:0.5f timeRange:endRange];
        [trackMixArray addObject:trackMixComentray];
    }
    
    audioMix.inputParameters = trackMixArray;
}

#pragma mark - Asset
- (void)addAsset:(AVAsset *)asset toComposition:(AVMutableComposition *)composition withTrackID:(CMPersistentTrackID)trackID withRecordAudio:(BOOL)recordAudio withAssetFilePath:(NSString *)identifier
{
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:trackID];
    AVAssetTrack *assetVideoTrack = asset.firstVideoTrack;
    CMTimeRange timeRange = CMTimeRangeFromTimeToTime(kCMTimeZero, assetVideoTrack.timeRange.duration);
    [videoTrack insertTimeRange:timeRange ofTrack:assetVideoTrack atTime:kCMTimeZero error:nil];
//    [videoTrack setPreferredTransform:assetVideoTrack.preferredTransform];
    
    UIInterfaceOrientation videoOrientation = orientationForTrack(asset);
    NSLog(@"videoOrientation: %ld", (long)videoOrientation);
    if (videoOrientation == UIInterfaceOrientationPortrait)
    {
        // Right rotation 90 degree
        [self setShouldRightRotate90:YES withTrackID:trackID];
    }
    else
    {
        if ([self shouldRightRotate90ByCustom:identifier])
        {
            NSLog(@"shouldRightRotate90ByCustom: %@", identifier);
            [self setShouldRightRotate90:YES withTrackID:trackID];
        }
        else
        {
            [self setShouldRightRotate90:NO withTrackID:trackID];
        }
    }

    
    if (recordAudio)
    {
        AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:trackID];
        if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0)
        {
            AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            [audioTrack insertTimeRange:timeRange ofTrack:assetAudioTrack atTime:kCMTimeZero error:nil];
        }
        else
        {
            NSLog(@"Reminder: video hasn't audio!");
        }
    }
}

#pragma mark - Export Video
- (void)addEffectToVideo:(NSString *)videoFilePath withAudioFilePath:(NSString *)audioFilePath
{
    if (isStringEmpty(videoFilePath))
    {
        NSLog(@"videoFilePath is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }
    
    CGFloat duration = 0;
    NSURL *videoURL = getFileURL(videoFilePath);
    AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    BOOL useAudio = YES;
    if (!isStringEmpty(audioFilePath))
    {
        useAudio = NO;
    }
    
    if (videoAsset)
    {
        // Max duration
        duration = CMTimeGetSeconds(videoAsset.duration);
        
        [self addAsset:videoAsset toComposition:composition withTrackID:TrackIDCustom withRecordAudio:useAudio withAssetFilePath:videoFilePath];
    }
    else
    {
        NSLog(@"videoAsset is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }

    AVAssetTrack *firstVideoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGSize videoSize = CGSizeMake(firstVideoTrack.naturalSize.width, firstVideoTrack.naturalSize.height);
    if (videoSize.width < 10 || videoSize.height < 10)
    {
        NSLog(@"videoSize is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }
    
    BOOL shouldRotate = [self shouldRightRotate90ByTrackID:TrackIDCustom];
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    if (shouldRotate)
    {
        videoComposition.renderSize = CGSizeMake(videoSize.height, videoSize.width);
    }
    else
    {
        videoComposition.renderSize = CGSizeMake(videoSize.width, videoSize.height);
    }
    
    videoComposition.frameDuration = CMTimeMakeWithSeconds(1.0 / firstVideoTrack.nominalFrameRate, firstVideoTrack.naturalTimeScale);
    instruction.timeRange = [composition.tracks.firstObject timeRange];
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] initWithCapacity:1];
    AVMutableVideoCompositionLayerInstruction *video1LayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
    
    video1LayerInstruction.trackID = TrackIDCustom;
    [layerInstructionArray addObject:video1LayerInstruction];
    
    instruction.layerInstructions = layerInstructionArray;
    videoComposition.instructions = @[ instruction ];
    videoComposition.customVideoCompositorClass = [CustomVideoCompositor class];
    
    NSString *exportPath = [self getTempOutputFilePath];
    NSURL *exportURL = [NSURL fileURLWithPath:[self returnFormatString:exportPath]];
    // Delete old file
    unlink([exportPath UTF8String]);

    _exportSession = [AVAssetExportSession exportSessionWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    _exportSession.outputURL = exportURL;
    _exportSession.outputFileType = AVFileTypeMPEG4;
    _exportSession.shouldOptimizeForNetworkUse = YES;
    
    if (videoComposition)
    {
         _exportSession.videoComposition = videoComposition;
    }
    
    // Music effect
    AVMutableAudioMix *audioMix = nil;
    if (!isStringEmpty(audioFilePath))
    {
        NSURL *bgMusicURL = getFileURL(audioFilePath);
        AVURLAsset *assetMusic = [[AVURLAsset alloc] initWithURL:bgMusicURL options:nil];
        
        audioMix = [AVMutableAudioMix audioMix];
        [self addAudioMixToComposition:composition withAudioMix:audioMix withAsset:assetMusic];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Progress monitor
        _timerEffect = [NSTimer scheduledTimerWithTimeInterval:0.3f
                                                        target:self
                                                      selector:@selector(retrievingExportProgress)
                                                      userInfo:nil
                                                       repeats:YES];
    });
    
    __block typeof(self) blockSelf = self;
    [_exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        switch ([_exportSession status])
        {
            case AVAssetExportSessionStatusCompleted:
            {
                // Close timer
                [blockSelf.timerEffect invalidate];
                blockSelf.timerEffect = nil;

                CGRect croppedRect = [self getCroppedRect];
                if (croppedRect.origin.x < 0)
                {
                    croppedRect.origin.x = 0;
                }
                
                if (croppedRect.origin.y < 0)
                {
                    croppedRect.origin.y = 0;
                }
                
                if (CGRectIsEmpty(croppedRect))
                {
                    if (shouldRotate)
                    {
                        croppedRect = CGRectMake(0, 0, videoSize.height, videoSize.width);
                    }
                    else
                    {
                        croppedRect = CGRectMake(0, 0, videoSize.width, videoSize.height);
                    }
                }
                else
                {
                    if (shouldRotate)
                    {
                         croppedRect.origin.y = videoSize.width - croppedRect.origin.y;
                        
                        if (croppedRect.size.width > videoSize.height)
                        {
                            croppedRect.size.width = videoSize.height;
                        }
                        
                        if (croppedRect.size.height > videoSize.width)
                        {
                            croppedRect.size.height = videoSize.width;
                        }
                    }
                    else
                    {
                        croppedRect.origin.y = videoSize.height - croppedRect.origin.y;
                        
                        if (croppedRect.size.width > videoSize.width)
                        {
                            croppedRect.size.width = videoSize.width;
                        }
                        
                        if (croppedRect.size.height > videoSize.height)
                        {
                            croppedRect.size.height = videoSize.height;
                        }
                    }
                }

                CMTimeRange timeRange = CMTimeRangeFromTimeToTime(kCMTimeZero, firstVideoTrack.timeRange.duration);
                AVURLAsset *asset = [AVURLAsset assetWithURL:_exportSession.outputURL];
                dispatch_group_t dispatchGroup = dispatch_group_create();
                NSArray *assetKeysToLoad = @[@"tracks", @"duration", @"composable"];
                [self loadAsset:asset withKeys:assetKeysToLoad usingDispatchGroup:dispatchGroup];
                // Wait until both assets are loaded
                dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^(){
                    
                    [self exportTrimmedVideo:asset timeRange:timeRange cropRegion:croppedRect finishBlock:^(BOOL success, id result)
                     {
                         if (success)
                         {
                             NSLog(@"ExportTrimmedVideo Successful: %@", result);
                             
                             // Save video to Album
                             [self writeExportedVideoToAssetsLibrary:result];
                         }
                         else
                         {
                             // Output path
                             self.filenameBlock = ^(void) {
                                 return @"";
                             };
                             
                             if (self.finishVideoBlock)
                             {
                                 self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
                             }
                         }
                     }];
                });

                NSLog(@"Export Successful: %@", exportPath);
                break;
            }
            case AVAssetExportSessionStatusFailed:
            {
                // Close timer
                [blockSelf.timerEffect invalidate];
                blockSelf.timerEffect = nil;

                // Output path
                self.filenameBlock = ^(void) {
                    return @"";
                };
                
                if (self.finishVideoBlock)
                {
                    self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
                }

                NSLog(@"Export failed: %@, %@", [[blockSelf.exportSession error] localizedDescription], [blockSelf.exportSession error]);
                break;
            }
            case AVAssetExportSessionStatusCancelled:
            {
                NSLog(@"Canceled: %@", blockSelf.exportSession.error);
                break;
            }
            default:
                break;
        }
    }];
}

- (void)loadAsset:(AVAsset *)asset withKeys:(NSArray *)assetKeysToLoad usingDispatchGroup:(dispatch_group_t)dispatchGroup
{
    dispatch_group_enter(dispatchGroup);
    [asset loadValuesAsynchronouslyForKeys:assetKeysToLoad completionHandler:^(){
        for (NSString *key in assetKeysToLoad)
        {
            NSError *error;
            if ([asset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed)
            {
                NSLog(@"Key value loading failed for key:%@ with error: %@", key, error);
                self.filenameBlock = ^(void) {
                    return @"";
                };
                
                if (self.finishVideoBlock)
                {
                    self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
                }
                
                goto bail;
            }
        }
        
        if (![asset isComposable])
        {
            NSLog(@"Asset is not composable");
            self.filenameBlock = ^(void) {
                return @"";
            };
            
            if (self.finishVideoBlock)
            {
                self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
            }
            
            goto bail;
        }
        
    bail:
        {
            dispatch_group_leave(dispatchGroup);
        }
    }];
}

- (void)exportTrimmedVideo:(AVAsset *)asset timeRange:(CMTimeRange)timeRange cropRegion:(CGRect)cropRect finishBlock:(GenericCallback)finishBlock
{
    if (!asset)
    {
        NSLog(@"asset is empty.");
        
        if (finishBlock)
        {
            finishBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
    }
    
    CMTimeRange range = timeRange;
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableCompositionTrack *videoCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    [videoCompositionTrack insertTimeRange:range ofTrack:assetVideoTrack atTime:kCMTimeZero error:nil];
    [videoCompositionTrack setPreferredTransform:assetVideoTrack.preferredTransform];
    
    AVMutableCompositionTrack *audioCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0)
    {
        AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
        [audioCompositionTrack insertTimeRange:range ofTrack:assetAudioTrack atTime:kCMTimeZero error:nil];
    }
    else
    {
        NSLog(@"Reminder: video hasn't audio!");
    }
    
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMakeWithSeconds(1.0 / assetVideoTrack.nominalFrameRate, assetVideoTrack.naturalTimeScale);
    videoComposition.renderSize =  cropRect.size;
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction
                                                                   videoCompositionLayerInstructionWithAssetTrack:videoCompositionTrack];
    
    CGSize videoSize = assetVideoTrack.naturalSize;
    NSLog(@"trimVideoOrigSize: %@", NSStringFromCGSize(videoSize));
    
    // Fix orientation & Crop
    CGFloat cropOffX = cropRect.origin.x;
    CGFloat cropOffY = cropRect.origin.y;
    CGAffineTransform finalTransform = CGAffineTransformMakeTranslation(0 - cropOffX, 0 - cropOffY);
    [layerInstruction setTransform:finalTransform atTime:kCMTimeZero];
    
    instruction.layerInstructions = [NSArray arrayWithObject:layerInstruction];
    videoComposition.instructions = [NSArray arrayWithObject: instruction];
    
    NSString *exportPath = [self getOutputFilePath];
    unlink([exportPath UTF8String]);
    NSURL *exportUrl = [NSURL fileURLWithPath:exportPath];
    
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:composition presetName:AVAssetExportPresetMediumQuality];
    exportSession.outputURL = exportUrl;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    
    if (videoComposition)
    {
        exportSession.videoComposition = videoComposition;
    }
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        
        switch ([exportSession status])
        {
            case AVAssetExportSessionStatusCompleted:
            {
                if (finishBlock)
                {
                    finishBlock(YES, exportPath);
                }
                
                NSLog(@"Export Successful.");
                
                break;
            }
            case AVAssetExportSessionStatusFailed:
            {
                if (finishBlock)
                {
                    finishBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
                }
                
                NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
                break;
            }
            case AVAssetExportSessionStatusCancelled:
            {
                NSLog(@"Export canceled");
                break;
            }
            default:
            {
                NSLog(@"NONE");
                break;
            }
        }
    }];
}

- (UIImageOrientation)getVideoOrientationFromAsset:(AVAsset *)asset
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGSize size = [videoTrack naturalSize];
    CGAffineTransform txf = [videoTrack preferredTransform];
    
    if (size.width == txf.tx && size.height == txf.ty)
        return UIImageOrientationLeft; //return UIInterfaceOrientationLandscapeLeft;
    else if (txf.tx == 0 && txf.ty == 0)
        return UIImageOrientationRight; //return UIInterfaceOrientationLandscapeRight;
    else if (txf.tx == 0 && txf.ty == size.width)
        return UIImageOrientationDown; //return UIInterfaceOrientationPortraitUpsideDown;
    else
        return UIImageOrientationUp;  //return UIInterfaceOrientationPortrait;
}

- (CGRect)getCroppedRect
{
    NSArray *pointsPath = [self getPathPoints];
    return getCroppedBounds(pointsPath);
}

// Convert 'space' char
- (NSString *)returnFormatString:(NSString *)str
{
    return [str stringByReplacingOccurrencesOfString:@" " withString:@""];
}

#pragma mark - Export Progress Callback
- (void)retrievingExportProgress
{
    if (_exportSession && _exportProgressBlock)
    {
        self.exportProgressBlock([NSNumber numberWithFloat:_exportSession.progress]);
    }
}

#pragma mark - NSUserDefaults
#pragma mark - setShouldRightRotate90
- (void)setShouldRightRotate90:(BOOL)shouldRotate withTrackID:(NSInteger)trackID
{
    NSString *identifier = [NSString stringWithFormat:@"TrackID_%ld", (long)trackID];
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    if (shouldRotate)
    {
        [userDefaultes setBool:YES forKey:identifier];
    }
    else
    {
        [userDefaultes setBool:NO forKey:identifier];
    }
    
    [userDefaultes synchronize];
}

- (BOOL)shouldRightRotate90ByTrackID:(NSInteger)trackID
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [NSString stringWithFormat:@"TrackID_%ld", (long)trackID];
    BOOL result = [[userDefaultes objectForKey:identifier] boolValue];
    NSLog(@"shouldRightRotate90ByTrackID %@ : %@", identifier, result?@"Yes":@"No");
    
    if (result)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - ShouldRightRotate90ByCustom
- (BOOL)shouldRightRotate90ByCustom:(NSString *)identifier
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    BOOL result = [[userDefaultes objectForKey:identifier] boolValue];
    NSLog(@"shouldRightRotate90ByCustom %@ : %@", identifier, result?@"Yes":@"No");
    
    if (result)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - PathPoints
- (NSArray *)getPathPoints
{
    NSArray *arrayResult = nil;
    NSString *flag = @"ArrayPathPoints";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSData *dataPathPoints = [userDefaultes objectForKey:flag];
    if (dataPathPoints)
    {
        arrayResult = [NSKeyedUnarchiver unarchiveObjectWithData:dataPathPoints];
        if (arrayResult && [arrayResult count] > 0)
        {
            //             NSLog(@"points has content.");
        }
    }
    else
    {
        NSLog(@"getPathPoints is empty.");
    }
    
    return arrayResult;
}

@end
