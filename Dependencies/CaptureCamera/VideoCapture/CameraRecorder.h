
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import "CommonDefine.h"

@class CameraRecorder;
@protocol CameraRecorderDelegate <NSObject>

@optional
- (void)didStartCurrentRecording:(NSURL *)fileURL;

- (void)didFinishCurrentRecording:(NSURL *)outputFileURL duration:(CGFloat)videoDuration totalDuration:(CGFloat)totalDuration error:(NSError *)error;

- (void)doingCurrentRecording:(NSURL *)outputFileURL duration:(CGFloat)videoDuration recordedVideosTotalDuration:(CGFloat)totalDuration;

- (void)didRemoveCurrentVideo:(NSURL *)fileURL totalDuration:(CGFloat)totalDuration error:(NSError *)error;

@required
- (void)didRecordingMultiVideosSuccess:(NSArray *)outputFilesURL;
- (void)didRecordingVideosSuccess:(NSURL *)outputFileURL;
- (void)didRecordingVideosError:(NSError*)error;

- (void)didTakePictureSuccess:(NSString *)outputFile;
- (void)didTakePictureError:(NSError*)error;

@end


@interface CameraRecorder : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (weak, nonatomic) id <CameraRecorderDelegate> delegate;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

- (CGFloat)getTotalVideoDuration;
- (NSUInteger)getVideoCount;

- (void)deleteLastVideo;
- (void)deleteAllVideo;

- (void)startRecordingToOutputFileURL:(NSURL *)fileURL;
- (void)stopCurrentVideoRecording;
- (void)endVideoRecording;
- (UIImage*)capturePicture;

- (BOOL)isTorchOn;
- (BOOL)isFrontCamera;

- (BOOL)isCameraSupported;
- (BOOL)isFrontCameraSupported;
- (BOOL)isTorchSupported;

- (void)switchCamera;
- (void)openTorch:(BOOL)open;

//- (void)focusInPoint:(CGPoint)touchPoint;

@end
