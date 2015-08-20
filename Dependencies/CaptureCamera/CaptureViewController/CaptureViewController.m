
#import "CaptureViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "ProgressBar.h"
#import "CaptureToolKit.h"
#import "DeleteButton.h"
#import "DDHTimerControl.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <MediaPlayer/MediaPlayer.h>

#define TIMER_INTERVAL 0.05f
#define TAG_ALERTVIEW_CLOSE_CONTROLLER 10086

@interface CaptureViewController ()
{
   
}

@property (nonatomic, assign) BOOL debugMode;
@property (nonatomic, strong) UIView *leftEyeView;
@property (nonatomic, strong) UIView *rightEyeView;
@property (nonatomic, strong) UIView *mouthView;
@property (nonatomic, strong) UIView *faceView;

@property (strong, nonatomic) UIView *maskView;

@property (strong, nonatomic) CameraRecorder *recorder;
@property (strong, nonatomic) ProgressBar *progressBar;
@property (strong, nonatomic) DeleteButton *deleteButton;
@property (strong, nonatomic) UIButton *okButton;

@property (strong, nonatomic) UIButton *closeButton;
@property (strong, nonatomic) UIButton *switchButton;
@property (strong, nonatomic) UIButton *settingButton;
@property (strong, nonatomic) UIButton *recordButton;
@property (strong, nonatomic) UIButton *flashButton;

@property (assign, nonatomic) BOOL initalized;
@property (assign, nonatomic) BOOL isProcessingData;

@property (strong, nonatomic) UIView *preview;
@property (strong, nonatomic) UIImageView *focusRectView;

@property (nonatomic, strong) DDHTimerControl *timerControl;

@end

@implementation CaptureViewController

#pragma mark - CameraRecorderDelegate
- (void)didStartCurrentRecording:(NSURL *)fileURL
{
    NSLog(@"正在录制视频: %@", fileURL);
    
    [self.progressBar addProgressView];
    [_progressBar stopShining];
    
    [_deleteButton setButtonStyle:DeleteButtonStyleNormal];
    
    self.timerControl.hidden = NO;
}

- (void)didFinishCurrentRecording:(NSURL *)outputFileURL duration:(CGFloat)videoDuration totalDuration:(CGFloat)totalDuration error:(NSError *)error
{
    if (error)
    {
        NSLog(@"录制视频错误:%@", error);
        
        NSString *success = GBLocalizedString(@"Failed");
        ProgressBarDismissLoading(success);
    }
    else
    {
        NSLog(@"录制视频完成: %@", outputFileURL);
        
        NSString *success = GBLocalizedString(@"Success");
        ProgressBarDismissLoading(success);
    }
    
    [_progressBar startShining];
    self.isProcessingData = NO;
    
    self.timerControl.hidden = YES;
    if (totalDuration >= MAX_VIDEO_DUR)
    {
        self.timerControl.minutesOrSeconds = 0;
        
        [self pressOKButton];
    }
    else
    {
        self.timerControl.minutesOrSeconds = ((NSInteger) (MAX_VIDEO_DUR - totalDuration + 1));
    }
}

- (void)didRemoveCurrentVideo:(NSURL *)fileURL totalDuration:(CGFloat)totalDuration error:(NSError *)error
{
    if (error)
    {
        NSLog(@"删除视频错误: %@", error);
    }
    else
    {
        NSLog(@"删除了视频: %@", fileURL);
        NSLog(@"现在视频长度: %f", totalDuration);
    }
    
    if ([_recorder getVideoCount] > 0)
    {
        [_deleteButton setStyle:DeleteButtonStyleNormal];
    }
    else
    {
        [_deleteButton setStyle:DeleteButtonStyleDisable];
    }
    
    _okButton.enabled = (totalDuration >= MIN_VIDEO_DUR);
    
    self.timerControl.minutesOrSeconds = ((NSInteger) (MAX_VIDEO_DUR - totalDuration + 1));
}

- (void)doingCurrentRecording:(NSURL *)outputFileURL duration:(CGFloat)videoDuration recordedVideosTotalDuration:(CGFloat)totalDuration
{
    [_progressBar setLastProgressToWidth:videoDuration / MAX_VIDEO_DUR * _progressBar.frame.size.width];
    
    _okButton.enabled = (videoDuration + totalDuration >= MIN_VIDEO_DUR);
    
    self.timerControl.minutesOrSeconds = ((NSInteger) (MAX_VIDEO_DUR - totalDuration - videoDuration + 1));
}

- (void)didRecordingMultiVideosSuccess:(NSArray *)outputFilesURL
{
    NSLog(@"RecordingMultiVideosSuccess: %@", outputFilesURL);

    NSString *success = GBLocalizedString(@"Success");
    ProgressBarDismissLoading(success);
    
    self.isProcessingData = NO;

    // Callback
    if (_callback)
    {
        self.callback(YES, outputFilesURL);
    }
    
    // Close
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didRecordingVideosSuccess:(NSURL *)outputFileURL
{
    NSString *outputFile = [outputFileURL path];
    NSLog(@"didRecordingVideosSuccess: %@", outputFile);
    
    NSString *success = GBLocalizedString(@"Success");
    ProgressBarDismissLoading(success);
    
    self.isProcessingData = NO;
    
    // Callback
    if (_callback)
    {
        self.callback(YES, outputFileURL);
    }
    
    // Close
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didRecordingVideosError:(NSError*)error;
{
    NSLog(@"didRecordingVideosError: %@", error.description);
    
    NSString *failed = GBLocalizedString(@"Failed");
    ProgressBarDismissLoading(failed);
    
    self.isProcessingData = NO;
    
    // Callback
    if (_callback)
    {
        self.callback(NO, @"The recording video is merge failed.");
    }
    
    // Close
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didTakePictureSuccess:(NSString *)outputFile
{
    NSLog(@"didTakePictureSuccess: %@", outputFile);
}

- (void)didTakePictureError:(NSError*)error
{
    NSLog(@"didTakePictureError: %@", error.description);
}

#pragma mark - View Life cycle
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = color(16, 16, 16, 1);
    
    self.maskView = [self getMaskView];
    [self.view addSubview:_maskView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_initalized)
    {
        return;
    }
    
    [self initPreview];
    [self initRecorder];
    [CaptureToolKit createVideoFolderIfNotExist];
    [self initProgressBar];
    [self initRecordButton];
    [self initDeleteButton];
    [self initOKButton];
    [self initTopLayout];
    
    [self initTimeControl];
    [self hideMaskView];
    
    self.initalized = YES;
}

- (void)initTimeControl
{
    CGFloat len = 80;
    _timerControl = [[DDHTimerControl alloc] initWithFrame:CGRectMake((CGRectGetWidth(_progressBar.frame)-len)/2, CGRectGetMinY(self.progressBar.frame) - len, len, len)];
    _timerControl.translatesAutoresizingMaskIntoConstraints = NO;
    _timerControl.color = [UIColor greenColor];
    _timerControl.highlightColor = [UIColor yellowColor];
    _timerControl.minutesOrSeconds = MAX_VIDEO_DUR;
    _timerControl.maxValue = MAX_VIDEO_DUR;
    _timerControl.titleLabel.text = GBLocalizedString(@"Seconds");
    _timerControl.userInteractionEnabled = NO;
    [self.view addSubview:_timerControl];
    _timerControl.hidden = YES;
}

- (void)initPreview
{
    self.preview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_SIZE.width, DEVICE_SIZE.width)];
    _preview.clipsToBounds = YES;
    [self.view insertSubview:_preview belowSubview:_maskView];
}

- (void)initRecorder
{
    self.recorder = [[CameraRecorder alloc] init];
    _recorder.delegate = self;
    _recorder.previewLayer.frame = CGRectMake(0, 0, DEVICE_SIZE.width, DEVICE_SIZE.width);
    [self.preview.layer addSublayer:_recorder.previewLayer];
}

- (void)initProgressBar
{
    self.progressBar = [ProgressBar getInstance];
    [CaptureToolKit setView:_progressBar toOriginY:DEVICE_SIZE.width];
    [self.view insertSubview:_progressBar belowSubview:_maskView];
    [_progressBar startShining];
}

- (void)initDeleteButton
{
    if (_isProcessingData)
    {
        return;
    }
    
    self.deleteButton = [DeleteButton getInstance];
    [_deleteButton setButtonStyle:DeleteButtonStyleDisable];
    [CaptureToolKit setView:_deleteButton toOrigin:CGPointMake(15, self.view.frame.size.height - _deleteButton.frame.size.height - 10)];
    [_deleteButton addTarget:self action:@selector(pressDeleteButton) forControlEvents:UIControlEventTouchUpInside];
    
    CGPoint center = _deleteButton.center;
    center.y = _recordButton.center.y;
    _deleteButton.center = center;
    
    [self.view insertSubview:_deleteButton belowSubview:_maskView];
    
}

- (void)initRecordButton
{
    CGFloat buttonW = 120.0f;
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake((DEVICE_SIZE.width - buttonW) / 2.0, _progressBar.frame.origin.y + _progressBar.frame.size.height + 10, buttonW, buttonW)];
    [_recordButton setImage:[UIImage imageNamed:@"video_longvideo_btn_shot"] forState:UIControlStateNormal];
    [self.view insertSubview:_recordButton belowSubview:_maskView];
    
    // Tap Gesture
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector(longPressGestureRecognized:)];
    gesture.minimumPressDuration = 0.3;
    [_recordButton addGestureRecognizer: gesture];
}

- (void)initOKButton
{
    CGFloat okButtonW = 50;
    self.okButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, okButtonW, okButtonW)];
    _okButton.enabled = NO;
    
    [_okButton setBackgroundImage:[UIImage imageNamed:@"record_icon_hook_normal_bg"] forState:UIControlStateNormal];
    [_okButton setBackgroundImage:[UIImage imageNamed:@"record_icon_hook_highlighted_bg"] forState:UIControlStateHighlighted];
    [_okButton setImage:[UIImage imageNamed:@"record_icon_hook_normal"] forState:UIControlStateNormal];
    
    [CaptureToolKit setView:_okButton toOrigin:CGPointMake(self.view.frame.size.width - okButtonW - 10, self.view.frame.size.height - okButtonW - 10)];
    
    [_okButton addTarget:self action:@selector(pressOKButton) forControlEvents:UIControlEventTouchUpInside];
    
    CGPoint center = _okButton.center;
    center.y = _recordButton.center.y;
    _okButton.center = center;
    
    [self.view insertSubview:_okButton belowSubview:_maskView];
}

- (void)initTopLayout
{
    CGFloat buttonW = 35.0f;
    
    // 关闭
    self.closeButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 5, buttonW, buttonW)];
    [_closeButton setImage:[UIImage imageNamed:@"record_close_normal"] forState:UIControlStateNormal];
    [_closeButton setImage:[UIImage imageNamed:@"record_close_disable"] forState:UIControlStateDisabled];
    [_closeButton setImage:[UIImage imageNamed:@"record_close_highlighted"] forState:UIControlStateSelected];
    [_closeButton setImage:[UIImage imageNamed:@"record_close_highlighted"] forState:UIControlStateHighlighted];
    [_closeButton addTarget:self action:@selector(pressCloseButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:_closeButton belowSubview:_maskView];
    
    // 前后摄像头转换
    self.switchButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - (buttonW + 10) * 2 - 10, 5, buttonW, buttonW)];
    [_switchButton setImage:[UIImage imageNamed:@"record_lensflip_normal"] forState:UIControlStateNormal];
    [_switchButton setImage:[UIImage imageNamed:@"record_lensflip_disable"] forState:UIControlStateDisabled];
    [_switchButton setImage:[UIImage imageNamed:@"record_lensflip_highlighted"] forState:UIControlStateSelected];
    [_switchButton setImage:[UIImage imageNamed:@"record_lensflip_highlighted"] forState:UIControlStateHighlighted];
    [_switchButton addTarget:self action:@selector(pressSwitchButton) forControlEvents:UIControlEventTouchUpInside];
    _switchButton.enabled = [_recorder isFrontCameraSupported];
    [self.view insertSubview:_switchButton belowSubview:_maskView];
    
    self.flashButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - (buttonW + 10), 5, buttonW, buttonW)];
    [_flashButton setImage:[UIImage imageNamed:@"record_flashlight_normal"] forState:UIControlStateNormal];
    [_flashButton setImage:[UIImage imageNamed:@"record_flashlight_disable"] forState:UIControlStateDisabled];
    [_flashButton setImage:[UIImage imageNamed:@"record_flashlight_highlighted"] forState:UIControlStateHighlighted];
    [_flashButton setImage:[UIImage imageNamed:@"record_flashlight_highlighted"] forState:UIControlStateSelected];
    _flashButton.enabled = _recorder.isTorchSupported;
    [_flashButton addTarget:self action:@selector(pressFlashButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:_flashButton belowSubview:_maskView];
    
    _flashButton.enabled = !([_recorder isFrontCameraSupported] && [_recorder isFrontCamera]);
    
    // focus rect view
    self.focusRectView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 90, 90)];
    _focusRectView.image = [UIImage imageNamed:@"touch_focus_not"];
    _focusRectView.alpha = 0;
    [self.preview addSubview:_focusRectView];
}

- (void)pressCloseButton
{
    if ([_recorder getVideoCount] > 0)
    {
        NSString *cancel = GBLocalizedString(@"Cancel");
        NSString *abandon = GBLocalizedString(@"Abandon");
        NSString *reminder = GBLocalizedString(@"Reminder");
        NSString *cancelVideoHint = GBLocalizedString(@"CancelVideoHint");
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:reminder message:cancelVideoHint delegate:self cancelButtonTitle:cancel otherButtonTitles:abandon, nil];
        alertView.tag = TAG_ALERTVIEW_CLOSE_CONTROLLER;
        [alertView show];
    }
    else
    {
        [self dropTheVideo];
    }
}

- (void)pressSwitchButton
{
    _switchButton.selected = !_switchButton.selected;
//    if (_switchButton.selected)
    {
        // 换成前摄像头
        if (_recorder.isFrontCamera)
        {
            [_recorder openTorch:NO];
            _flashButton.selected = NO;
            _flashButton.enabled = YES;
        }
        else
        {
            _flashButton.enabled = NO;
        }
    }
//    else
//    {
//        _flashButton.enabled = [_recorder isFrontCameraSupported] && [_recorder isFrontCamera];
//    }
    
    [_recorder switchCamera];
}

- (void)pressFlashButton
{
    _flashButton.selected = !_flashButton.selected;
    [_recorder openTorch:_flashButton.selected];
}

- (void)pressDeleteButton
{
    if (_deleteButton.style == DeleteButtonStyleNormal)
    {
        // 第一次按下删除按钮
        [_progressBar setLastProgressToStyle:ProgressBarProgressStyleDelete];
        [_deleteButton setButtonStyle:DeleteButtonStyleDelete];
    }
    else if (_deleteButton.style == DeleteButtonStyleDelete)
    {
        // 第二次按下删除按钮
        [self deleteLastVideo];
        [_progressBar deleteLastProgress];
        
        if ([_recorder getVideoCount] > 0)
        {
            [_deleteButton setButtonStyle:DeleteButtonStyleNormal];
        }
        else
        {
            [_deleteButton setButtonStyle:DeleteButtonStyleDisable];
        }
    }
}

- (void)pressOKButton
{
    if (_isProcessingData)
    {
        return;
    }
    
    if (self.timerControl.minutesOrSeconds > 0)
    {
        // Progress bar
        NSString *title = GBLocalizedString(@"Processing");
        ProgressBarShowLoading(title);
    }
    
    [_recorder endVideoRecording];
    self.isProcessingData = YES;
}

- (UIImage*)capturePicture
{
    UIImage *image = [_recorder capturePicture];
    
    UIView *flashView = [[UIView alloc] initWithFrame: _recorder.previewLayer.frame];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [flashView setAlpha:0.f];
    [[[self view] window] addSubview:flashView];
    
    [UIView animateWithDuration:.4f
                     animations:^{
                         [flashView setAlpha:1.f];
                         [flashView setAlpha:0.f];
                     }
                     completion:^(BOOL finished){
                         [flashView removeFromSuperview];
                     }
     ];
    
     return image;
}

// 放弃本次视频，并且关闭页面
- (void)dropTheVideo
{
    [_recorder deleteAllVideo];
    
    if (_callback)
    {
        self.callback(NO, @"Abandon this recording video.");
    }
    
    [self dismissViewControllerAnimated:NO completion:nil];
}

// 删除最后一段视频
- (void)deleteLastVideo
{
    if ([_recorder getVideoCount] > 0)
    {
        [_recorder deleteLastVideo];
    }
}

- (void)hideMaskView
{
    [UIView animateWithDuration:0.5f animations:^{
        CGRect frame = self.maskView.frame;
        frame.origin.y = self.maskView.frame.size.height;
        self.maskView.frame = frame;
    }];
}

- (UIView *)getMaskView
{
    UIView *maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_SIZE.width, DEVICE_SIZE.height + DELTA_Y)];
    maskView.backgroundColor = color(30, 30, 30, 1);
    
    return maskView;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)showFocusRectAtPoint:(CGPoint)point
{
    _focusRectView.alpha = 1.0f;
    _focusRectView.center = point;
    _focusRectView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    [UIView animateWithDuration:0.2f animations:^{
        _focusRectView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    } completion:^(BOOL finished)
    {
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
        animation.values = @[@0.5f, @1.0f, @0.5f, @1.0f, @0.5f, @1.0f];
        animation.duration = 0.5f;
        [_focusRectView.layer addAnimation:animation forKey:@"opacity"];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3f animations:^{
                _focusRectView.alpha = 0;
            }];
        });
    }];
    
//    _focusRectView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
//    _focusRectView.center = point;
//    [UIView animateWithDuration:0.3f animations:^{
//        _focusRectView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
//        _focusRectView.alpha = 1.0f;
//    } completion:^(BOOL finished) {
//        [UIView animateWithDuration:0.1f animations:^{
//            _focusRectView.alpha = 0.0f;
//        }];
//    }];
}


//- (void)startProgressTimer
//{
//    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
//    self.progressCounter = 0;
//}
//
//- (void)stopProgressTimer
//{
//    [_progressTimer invalidate];
//    self.progressTimer = nil;
//}
//
//- (void)onTimer:(NSTimer *)timer
//{
//    self.progressCounter++;
//    [_progressBar setLastProgressToWidth:self.progressCounter * TIMER_INTERVAL / MAX_VIDEO_DUR * DEVICE_SIZE.width];
//}

#pragma mark - Tap Gesture
// Add gesture by Johnny Xu
- (void)longPressGestureRecognized:(UILongPressGestureRecognizer *) gesture
{
    switch (gesture.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            [self startRecording];
            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            [self stopRecording];
            break;
        }
        default:
            break;
    }
}

#pragma mark - Video Recording
- (void)startRecording
{
    if (_isProcessingData)
    {
        return;
    }
    
    if (_deleteButton.style == DeleteButtonStyleDelete)
    {
        // 取消删除
        [_deleteButton setButtonStyle:DeleteButtonStyleNormal];
        [_progressBar setLastProgressToStyle:ProgressBarProgressStyleNormal];
        return;
    }
    
    self.isProcessingData = YES;
    NSString *filePath = [CaptureToolKit getVideoSaveFilePathString];
    [_recorder startRecordingToOutputFileURL:[NSURL fileURLWithPath:filePath]];
}

- (void)stopRecording
{
    if (!_isProcessingData)
    {
        return;
    }
    
    // Progress bar
    NSString *title = GBLocalizedString(@"SavingVideo");
    ProgressBarShowLoading(title);
    
    [_recorder stopCurrentVideoRecording];
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag)
    {
        case TAG_ALERTVIEW_CLOSE_CONTROLLER:
        {
            switch (buttonIndex)
            {
                case 0:
                {
                    break;
                }
                case 1:
                {
                    [self dropTheVideo];
                    break;
                }
                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
}

#pragma mark ---------rotate(only when this controller is presented, the code below effect)-------------
//<iOS6
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0

//iOS6+
- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
	return UIInterfaceOrientationPortrait;
}

#endif


@end













