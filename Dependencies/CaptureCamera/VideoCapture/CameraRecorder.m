
#import "CameraRecorder.h"
#import "CaptureDefine.h"
#import "CaptureToolKit.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface VideoData: NSObject

@property (assign, nonatomic) CGFloat duration;
@property (strong, nonatomic) NSURL *fileURL;

@end

@implementation VideoData

@end

#define COUNT_DUR_TIMER_INTERVAL 0.05

@interface CameraRecorder ()
{
}

@property (strong, nonatomic) NSTimer *countDurTimer;
@property (assign, nonatomic) CGFloat currentVideoDur;
@property (assign, nonatomic) NSURL *currentFileURL;
@property (assign ,nonatomic) CGFloat totalVideoDur;

@property (strong, nonatomic) NSMutableArray *videoFileDataArray;

@property (assign, nonatomic) BOOL isFrontCameraSupported;
@property (assign, nonatomic) BOOL isCameraSupported;
@property (assign, nonatomic) BOOL isTorchSupported;
@property (assign, nonatomic) BOOL isTorchOn;
@property (assign, nonatomic) BOOL isUsingFrontFacingCamera;

@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (assign, nonatomic) AVCaptureVideoOrientation orientation;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieFileOutput;

- (void)mergeVideoFiles;

@end

@implementation CameraRecorder

#pragma mark - Life Cycle
- (id)init
{
    self = [super init];
    if (self)
    {
        [self initalize];
    }
    
    return self;
}

- (void)initalize
{
    // Set camera orientation
    [self initCaptureByBackCamera:TRUE];
    
    self.videoFileDataArray = [[NSMutableArray alloc] init];
    self.totalVideoDur = 0.0f;
}

- (void)initCaptureByBackCamera:(BOOL)back
{
    // Session
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // Input
    AVCaptureDevice *frontCamera = nil;
    AVCaptureDevice *backCamera = nil;
    
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras)
    {
        if (camera.position == AVCaptureDevicePositionFront)
        {
            frontCamera = camera;
        }
        else
        {
            backCamera = camera;
        }
    }
    
    if (!backCamera)
    {
        self.isCameraSupported = NO;
        return;
    }
    else
    {
        self.isCameraSupported = YES;
        
        if ([backCamera hasTorch])
        {
            self.isTorchSupported = YES;
        }
        else
        {
            self.isTorchSupported = NO;
        }
    }
    
    if (!frontCamera)
    {
        self.isFrontCameraSupported = NO;
    }
    else
    {
        self.isFrontCameraSupported = YES;
    }
    
    [backCamera lockForConfiguration:nil];
    if ([backCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
    {
        [backCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }

    [backCamera unlockForConfiguration];
    
    // Add default camera direction by Johnny Xu.
    if (back)
    {
        self.isUsingFrontFacingCamera = FALSE;
        self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:nil];
    }
    else
    {
        self.isUsingFrontFacingCamera = TRUE;
        self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:nil];
    }
    
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:nil];
    if ([_captureSession canAddInput:_videoDeviceInput])
    {
        [_captureSession addInput:_videoDeviceInput];
    }
    if ([_captureSession canAddInput:audioDeviceInput])
    {
        [_captureSession addInput:audioDeviceInput];
    }
    
    // Output by video
    self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([_captureSession canAddOutput:_movieFileOutput])
    {
        [_captureSession addOutput:_movieFileOutput];
    }
    
    // Output by Picture
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [stillImageOutput setOutputSettings:outputSettings];
    self.stillImageOutput = stillImageOutput;
    if ([_captureSession canAddOutput:self.stillImageOutput])
    {
        [_captureSession addOutput:self.stillImageOutput];
    }
    
    // Preset
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480; // AVCaptureSessionPresetHigh
    
    // Preview layer
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [_captureSession startRunning];
}

- (void)clearAll
{
    [_captureSession stopRunning];
    [_previewLayer removeFromSuperlayer];
    
    _stillImageOutput = nil;
    _movieFileOutput = nil;

    _captureSession = nil;
    _previewLayer = nil;
}

- (void)startCountDurTimer
{
    self.countDurTimer = [NSTimer scheduledTimerWithTimeInterval:COUNT_DUR_TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
}

- (void)onTimer:(NSTimer *)timer
{
    self.currentVideoDur += COUNT_DUR_TIMER_INTERVAL;
    
    if ([_delegate respondsToSelector:@selector(doingCurrentRecording:duration:recordedVideosTotalDuration:)])
    {
        [_delegate doingCurrentRecording:_currentFileURL duration:_currentVideoDur recordedVideosTotalDuration:_totalVideoDur];
    }
    
    if (_totalVideoDur + _currentVideoDur >= MAX_VIDEO_DUR)
    {
        [self stopCurrentVideoRecording];
    }
}

- (void)stopCountDurTimer
{
    [_countDurTimer invalidate];
    self.countDurTimer = nil;
}

- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;
{
	for ( AVCaptureConnection *connection in connections )
    {
		for ( AVCaptureInputPort *port in [connection inputPorts] )
        {
			if ( [[port mediaType] isEqual:mediaType] )
            {
				return connection;
			}
		}
	}
    
	return nil;
}

- (void)mergeAndExportVideosAtFileURLs:(NSArray *)fileURLArray
{
    NSError *error = nil;
    CGSize renderSize = CGSizeMake(0, 0);
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    CMTime totalDuration = kCMTimeZero;
    
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileURLArray)
    {
        NSLog(@"fileURL: %@", fileURL);
        
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        if (!asset)
        {
            // Retry once
            asset = [AVAsset assetWithURL:fileURL];
            if (!asset)
            {
                 continue;
            }
        }
        [assetArray addObject:asset];
        
        AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        if (!assetTrack)
        {
            // Retry once
            assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            if (!assetTrack)
            {
                NSLog(@"Error reading the transformed video track");
            }
        }
        [assetTrackArray addObject:assetTrack];
        
        NSLog(@"assetTrack.naturalSize Width: %f, Height: %f", assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.width);
        renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.height);
    }
    
    NSLog(@"renderSize width: %f, Height: %f", renderSize.width, renderSize.height);
    if (renderSize.height == 0 || renderSize.width == 0)
    {
        if ([_delegate respondsToSelector:@selector(didRecordingVideosError:)])
        {
            [_delegate didRecordingVideosError:nil];
        }
        
        return;
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++)
    {
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        if ([[asset tracksWithMediaType:AVMediaTypeAudio] count]>0)
        {
            AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:assetAudioTrack atTime:totalDuration error:nil];
        }
        else
        {
            NSLog(@"Reminder: video hasn't audio!");
        }
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        
        // Fix orientation issue
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0));
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];
        
        [layerInstructionArray addObject:layerInstruciton];
    }
    
    // Get save path
    NSURL *mergeFileURL = [NSURL fileURLWithPath:[CaptureToolKit getVideoMergeFilePathString]];
    
    // Export
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW);
    
    NSLog(@"Video: width = %f, height = %f", renderW, renderW);
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.shouldOptimizeForNetworkUse = YES;
    
    // Fix iOS 5.x crash issue by Johnny Xu.
    if (iOS5)
    {
        exporter.outputFileType = AVFileTypeQuickTimeMovie;
    }
    else
    {
        exporter.outputFileType = AVFileTypeMPEG4;
    }
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        // Fix can't export issue under iOS 5.x by Johnny Xu.
        switch ([exporter status])
        {
            case AVAssetExportSessionStatusCompleted:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([_delegate respondsToSelector:@selector(didRecordingVideosSuccess:)])
                    {
                        [_delegate didRecordingVideosSuccess:mergeFileURL];
                    }
                    
                    NSLog(@"Export video success.");
                    
                    // Test
//                    [self writeExportedVideoToAssetsLibrary:mergeFileURL];
                });
                
                break;
            }
            case AVAssetExportSessionStatusFailed:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([_delegate respondsToSelector:@selector(didRecordingVideosError:)])
                    {
                        [_delegate didRecordingVideosError:[exporter error]];
                    }
                    
                    NSLog(@"Export video failed.");
                });
                break;
            }
            case AVAssetExportSessionStatusCancelled:
            {
                NSLog(@"Export canceled");
                break;
            }
            case AVAssetExportSessionStatusWaiting:
            {
                NSLog(@"Export Waiting");
                break;
            }
            case AVAssetExportSessionStatusExporting:
            {
                NSLog(@"Export Exporting");
                break;
            }
            default:
                break;
        }
    }];
}

- (AVCaptureDevice *)getCameraDevice:(BOOL)isFront
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    
    for (AVCaptureDevice *camera in cameras)
    {
        if (camera.position == AVCaptureDevicePositionBack)
        {
            backCamera = camera;
        }
        else
        {
            frontCamera = camera;
        }
    }
    
    if (isFront)
    {
        return frontCamera;
    }
    
    return backCamera;
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResize])
    {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    }
    else
    {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [self.videoDeviceInput ports])
        {
            // 正在使用的videoInput
            if([port mediaType] == AVMediaTypeVideo)
            {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect])
                {
                    if(viewRatio > apertureRatio)
                    {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2)
                        {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    }
                    else
                    {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2)
                        {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                }
                else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill])
                {
                    if(viewRatio > apertureRatio)
                    {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    }
                    else
                    {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    //    NSLog(@"focus point: %f %f", point.x, point.y);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		AVCaptureDevice *device = [_videoDeviceInput device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
        {
			if ([device isFocusPointOfInterestSupported])
            {
                [device setFocusPointOfInterest:point];
            }
            
            if ([device isFocusModeSupported:focusMode])
            {
				[device setFocusMode:focusMode];
			}
            
			if ([device isExposurePointOfInterestSupported])
            {
                [device setExposurePointOfInterest:point];
            }
            
            if ([device isExposureModeSupported:exposureMode])
            {
				[device setExposureMode:exposureMode];
			}
            
			[device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
			[device unlockForConfiguration];
		}
        else
        {
            NSLog(@"对焦错误:%@", error);
        }
	});
}


#pragma mark - Method
- (void)focusInPoint:(CGPoint)touchPoint
{
    CGPoint devicePoint = [self convertToPointOfInterestFromViewCoordinates:touchPoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)openTorch:(BOOL)open
{
    if (!_isTorchSupported || self.isUsingFrontFacingCamera)
    {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureDevice *flashLight = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        BOOL success = [flashLight lockForConfiguration:nil];
        if (success)
        {
            if (!open)
            {
                [flashLight setTorchMode:AVCaptureTorchModeOff];
                self.isTorchOn = FALSE;
            }
            else
            {
                [flashLight setTorchMode:AVCaptureTorchModeOn];
                self.isTorchOn = TRUE;
            }
            [flashLight unlockForConfiguration];
        }
    });
}

- (void)switchCamera
{
    if (!_isFrontCameraSupported || !_isCameraSupported || !_videoDeviceInput)
    {
        return;
    }
    
    if (_isTorchOn)
    {
        [self openTorch:NO];
    }
    
    [_captureSession beginConfiguration];
    [_captureSession removeInput:_videoDeviceInput];
    
    self.isUsingFrontFacingCamera = !_isUsingFrontFacingCamera;
    AVCaptureDevice *device = [self getCameraDevice:_isUsingFrontFacingCamera];
    
    [device lockForConfiguration:nil];
    if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
    {
        [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    [device unlockForConfiguration];
    
    self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    [_captureSession addInput:_videoDeviceInput];
    [_captureSession commitConfiguration];
}

- (BOOL)isFrontCamera
{
    return _isUsingFrontFacingCamera;
}

- (BOOL)isTorchOn
{
    return _isTorchOn;
}

- (BOOL)isTorchSupported
{
    return _isTorchSupported;
}

- (BOOL)isFrontCameraSupported
{
    return _isFrontCameraSupported;
}

- (BOOL)isCameraSupported
{
    return _isCameraSupported;
}

- (void)mergeVideoFiles
{
    NSMutableArray *fileURLArray = [[NSMutableArray alloc] init];
    for (VideoData *data in _videoFileDataArray)
    {
        [fileURLArray addObject:data.fileURL];
    }
    
    [self mergeAndExportVideosAtFileURLs:fileURLArray];
}

// 总时长
- (CGFloat)getTotalVideoDuration
{
    return _totalVideoDur;
}

// 现在录了多少视频
- (NSUInteger)getVideoCount
{
    return [_videoFileDataArray count];
}

- (void)startRecordingToOutputFileURL:(NSURL *)fileURL
{
    if (_totalVideoDur >= MAX_VIDEO_DUR)
    {
        NSLog(@"视频总长达到最大");
        return;
    }
    
    [_movieFileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
}

- (void)stopCurrentVideoRecording
{
    [self stopCountDurTimer];
    [_movieFileOutput stopRecording];
}

// End recording
- (void)endVideoRecording
{
    [self mergeVideoFiles];
}

// 不调用delegate
- (void)deleteAllVideo
{
    for (VideoData *data in _videoFileDataArray)
    {
        NSURL *videoFileURL = data.fileURL;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:filePath])
            {
                NSError *error = nil;
                [fileManager removeItemAtPath:filePath error:&error];
                
                if (error)
                {
                    NSLog(@"deleteAllVideo删除视频文件出错:%@", error);
                }
            }
        });
    }
}

// 会调用delegate
- (void)deleteLastVideo
{
    if ([_videoFileDataArray count] == 0)
    {
        return;
    }
    
    VideoData *data = (VideoData *)[_videoFileDataArray lastObject];
    NSURL *videoFileURL = data.fileURL;
    CGFloat videoDuration = data.duration;
    
    [_videoFileDataArray removeLastObject];
    _totalVideoDur -= videoDuration;
    
    // delete
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:filePath])
        {
            NSError *error = nil;
            [fileManager removeItemAtPath:filePath error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // delegate
                if ([_delegate respondsToSelector:@selector(didRemoveCurrentVideo:totalDuration:error:)])
                {
                    [_delegate didRemoveCurrentVideo:videoFileURL totalDuration:_totalVideoDur error:error];
                }
            });
        }
    });
}

#pragma mark - AVCaptureFileOutputRecordignDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    self.currentFileURL = fileURL;
    self.currentVideoDur = 0.0f;
    [self startCountDurTimer];
    
    if ([_delegate respondsToSelector:@selector(didStartCurrentRecording:)])
    {
        [_delegate didStartCurrentRecording:fileURL];
    }
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    self.totalVideoDur += _currentVideoDur;
    NSLog(@"本段视频长度: %f", _currentVideoDur);
    NSLog(@"现在的视频总长度: %f", _totalVideoDur);
    
    if (!error)
    {
        VideoData *data = [[VideoData alloc] init];
        data.duration = _currentVideoDur;
        data.fileURL = outputFileURL;
        
        [_videoFileDataArray addObject:data];
    }
    
    if ([_delegate respondsToSelector:@selector(didFinishCurrentRecording:duration:totalDuration:error:)])
    {
        [_delegate didFinishCurrentRecording:outputFileURL duration:_currentVideoDur totalDuration:_totalVideoDur error:error];
    }
}

#pragma mark - Take picture
- (UIImage*)capturePicture
{
    AVCaptureConnection *videoConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[self.stillImageOutput connections]];
    if ([videoConnection isVideoOrientationSupported])
    {
        [videoConnection setVideoOrientation:[self orientation]];
    }
	
    if (self.isTorchOn)
    {
        [self openTorch:YES];
        [NSThread sleepForTimeInterval:0.05];
    }
    
    __block UIImage *resultImage = nil;
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:videoConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
                                                         {
                                                             if (imageDataSampleBuffer != NULL)
                                                             {
                                                                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                                 UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                                 
                                                                 CGFloat minLen = MIN(DEVICE_SIZE.width, DEVICE_SIZE.height);
                                                                 CGRect cropRect = CGRectMake(0, 0, minLen, minLen);
                                                                 resultImage = [self getCropImage:[self imageFixOrientation:image] cropRect:cropRect];
                                                                 
                                                                 BOOL success = [self saveImage:resultImage];
                                                                 if (success)
                                                                 {
                                                                     NSString *imageFile = [self getImageOutputFile];
                                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                                         
                                                                         if ([_delegate respondsToSelector:@selector(didTakePictureSuccess:)])
                                                                         {
                                                                             [_delegate didTakePictureSuccess:imageFile];
                                                                         }
                                                                         
                                                                         NSLog(@"CaptureImage save success: %@", imageFile);
                                                                     });
                                                                 }
                                                                 
                                                                 // Test
//                                                                 [self writeExportedPhotoToAssetsLibrary:resultImage];
                                                                 
                                                             }
                                                             else if (error)
                                                             {
                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     if ([_delegate respondsToSelector:@selector(didTakePictureError:)])
                                                                     {
                                                                         [_delegate didTakePictureError:error];
                                                                     }
                                                                     
                                                                     NSLog(@"CaptureImage Failed: %@", error.description);
                                                                 });
                                                             }
                                                             
                                                         }];
    if (self.isTorchOn)
    {
        [self openTorch:NO];
    }
    
    return resultImage;
}

- (NSString*)getImageOutputFile
{
    NSString *filename = @"image.jpg";
    NSString* imageOutputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    return imageOutputFile;
}

- (BOOL)saveImage:(UIImage*)image
{
    NSData *data = UIImageJPEGRepresentation(image, 1);
    NSString *imageOutputFile = [self getImageOutputFile];
    unlink([imageOutputFile UTF8String]);
    return [data writeToFile:imageOutputFile atomically:YES];
}

- (UIImage*)imageFixOrientation:(UIImage*)image
{
    UIImageOrientation imageOrientation = [image imageOrientation];
    if (imageOrientation == UIImageOrientationUp)
        return image;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    UIImageOrientation io = imageOrientation;
    if (io == UIImageOrientationDown || io == UIImageOrientationDownMirrored)
    {
        transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
        transform = CGAffineTransformRotate(transform, M_PI);
    }
    else if (io == UIImageOrientationLeft || io == UIImageOrientationLeftMirrored)
    {
        transform = CGAffineTransformTranslate(transform, image.size.width, 0);
        transform = CGAffineTransformRotate(transform, M_PI_2);
    }
    else if (io == UIImageOrientationRight || io == UIImageOrientationRightMirrored)
    {
        transform = CGAffineTransformTranslate(transform, 0, image.size.height);
        transform = CGAffineTransformRotate(transform, -M_PI_2);
        
    }
    
    if (io == UIImageOrientationUpMirrored || io == UIImageOrientationDownMirrored)
    {
        transform = CGAffineTransformTranslate(transform, image.size.width, 0);
        transform = CGAffineTransformScale(transform, -1, 1);
    }
    else if (io == UIImageOrientationLeftMirrored || io == UIImageOrientationRightMirrored)
    {
        transform = CGAffineTransformTranslate(transform, image.size.height, 0);
        transform = CGAffineTransformScale(transform, -1, 1);
        
    }
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, image.size.width, image.size.height,
                                             CGImageGetBitsPerComponent(image.CGImage), 0,
                                             CGImageGetColorSpace(image.CGImage),
                                             CGImageGetBitmapInfo(image.CGImage));
    CGContextConcatCTM(ctx, transform);
    
    if (io == UIImageOrientationLeft || io == UIImageOrientationLeftMirrored || io == UIImageOrientationRight || io == UIImageOrientationRightMirrored)
    {
        CGContextDrawImage(ctx, CGRectMake(0,0,image.size.height,image.size.width), image.CGImage);
    }
    else
    {
        CGContextDrawImage(ctx, CGRectMake(0,0,image.size.width,image.size.height), image.CGImage);
    }
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

-(UIImage*)getCropImage:(UIImage*)originalImage cropRect:(CGRect)cropRect
{
    // Scale to fit the screen
    CGFloat oriWidth = cropRect.size.width;
    CGFloat oriHeight = originalImage.size.height * (oriWidth / originalImage.size.width);
    CGFloat oriX = cropRect.origin.x + (cropRect.size.width - oriWidth) / 2;
    CGFloat oriY = cropRect.origin.y + (cropRect.size.height - oriHeight) / 2;
    CGRect latestRect = CGRectMake(oriX, oriY, oriWidth, oriHeight);
    
    return [self getSubImageByCropRect:cropRect latestRect:latestRect originalImage:originalImage];
}

-(UIImage*)getSubImageByCropRect:(CGRect)cropRect latestRect:(CGRect)latestRect originalImage:(UIImage*)originalImage
{
    CGRect squareFrame = cropRect;
    CGFloat scaleRatio = latestRect.size.width / originalImage.size.width;
    CGFloat x = (squareFrame.origin.x - latestRect.origin.x) / scaleRatio;
    CGFloat y = (squareFrame.origin.y - latestRect.origin.y) / scaleRatio;
    CGFloat w = squareFrame.size.width / scaleRatio;
    CGFloat h = squareFrame.size.width / scaleRatio;
    if (latestRect.size.width < cropRect.size.width)
    {
        CGFloat newW = originalImage.size.width;
        CGFloat newH = newW * (cropRect.size.height / cropRect.size.width);
        x = 0;
        y = y + (h - newH) / 2;
        w = newH;
        h = newH;
    }
    
    if (latestRect.size.height < cropRect.size.height)
    {
        CGFloat newH = originalImage.size.height;
        CGFloat newW = newH * (cropRect.size.width / cropRect.size.height);
        x = x + (w - newW) / 2;
        y = 0;
        w = newH;
        h = newH;
    }
    
    CGRect imageRect = CGRectMake(x, y, w, h);
    CGImageRef imageRef = originalImage.CGImage;
    CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef, imageRect);
    CGSize size = CGSizeMake(imageRect.size.width, imageRect.size.height);
    
//    NSLog(@"Crop width: %f, height: %f", size.width, size.height);
    
    UIImage* smallImage;
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, imageRect, subImageRef);
//    NSLog(@"context: %@", context);
    if (context)
    {
        smallImage = [UIImage imageWithCGImage:subImageRef];
    }
    else
    {
        smallImage = nil;
    }
    UIGraphicsEndImageContext();
    CGImageRelease(subImageRef);
    
    
    return smallImage;
}

#pragma mark - Private Methods
- (void)writeExportedVideoToAssetsLibrary:(NSURL *)outputURL
{
	NSURL *exportURL = outputURL; // [NSURL fileURLWithPath:outputURL];
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:exportURL])
    {
		[library writeVideoAtPathToSavedPhotosAlbum:exportURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (error)
                 {
                     
                 }
                 else
                 {
                     
                 }

#if !TARGET_IPHONE_SIMULATOR
                 [[NSFileManager defaultManager] removeItemAtURL:exportURL error:nil];
#endif
             });
         }];
	}
    else
    {
		NSLog(@"Video could not be exported to camera roll.");
	}
}

- (void)writeExportedPhotoToAssetsLibrary:(UIImage*)image
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:[image CGImage]
                              orientation:(ALAssetOrientation)[image imageOrientation]
                          completionBlock:^(NSURL *assetURL, NSError *error)
     {
         if (error)
         {
             NSLog(@"Photo could not be exported to camera roll. -- %@", error.description);
         }
         else
         {
             NSLog(@"Photo export is success.");
         }
     }];
}

@end
