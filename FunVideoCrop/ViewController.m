//
//  ViewController.m
//  FunVideoCrop
//
//  Created by Johnny Xu(徐景周) on 6/25/15.
//  Copyright (c) 2015 Future Studio. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import <StoreKit/StoreKit.h>

#import "ViewController.h"
#import "PBJVideoPlayerController.h"
#import "CaptureViewController.h"
#import "JGActionSheet.h"
#import "DBPrivateHelperController.h"
#import "KGModal.h"
#import "CMPopTipView.h"
#import "UIAlertView+Blocks.h"
#import "ExportEffects.h"
#import "AudioViewController.h"
#import "MZCroppableView.h"
#import "DKHorizontalColorPicker.h"
#import "NSString+Height.h"

#define MaxVideoLength MAX_VIDEO_DUR

#define DemoVideoName @"Demo.mp4"

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate, PBJVideoPlayerControllerDelegate, SKStoreProductViewControllerDelegate, DKHorizontalColorPickerDelegate>
{
    CMPopTipView *_popTipView;
}

@property (nonatomic, strong) PBJVideoPlayerController *demoVideoPlayerController;
@property (nonatomic, strong) UIView *demoVideoContentView;
@property (nonatomic, strong) UIImageView *demoPlayButton;

@property (nonatomic, strong) UIScrollView *captureContentView;
@property (nonatomic, strong) UIButton *videoView;

@property (nonatomic, strong) UIScrollView *videoContentView;
@property (nonatomic, strong) PBJVideoPlayerController *videoPlayerController;
@property (nonatomic, strong) UIImageView *playButton;
@property (nonatomic, strong) UIButton *closeVideoPlayerButton;

@property (nonatomic, copy) NSURL *videoPickURL;
@property (nonatomic, copy) NSString *audioPickFile;

@property (nonatomic, strong) UIView *parentView;
@property (nonatomic, strong) UIButton *demoButton;

@property (nonatomic, strong) MZCroppableView *croppableView;

@property (nonatomic, strong) DKHorizontalColorPicker *horizonPicker;
@property (nonatomic, strong) UILabel *bgColorLabel;

@end

@implementation ViewController

#pragma mark - Authorization Helper
- (void)popupAlertView
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:GBLocalizedString(@"Private_Setting_Audio_Tips") delegate:nil cancelButtonTitle:GBLocalizedString(@"IKnow") otherButtonTitles:nil, nil];
    [alertView show];
}

- (void)popupAuthorizationHelper:(id)type
{
    DBPrivateHelperController *privateHelper = [DBPrivateHelperController helperForType:[type longValue]];
    privateHelper.snapshot = [self snapshot];
    privateHelper.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:privateHelper animated:YES completion:nil];
}

- (UIImage *)snapshot
{
    id <UIApplicationDelegate> appDelegate = [[UIApplication sharedApplication] delegate];
    UIGraphicsBeginImageContextWithOptions(appDelegate.window.bounds.size, NO, appDelegate.window.screen.scale);
    [appDelegate.window drawViewHierarchyInRect:appDelegate.window.bounds afterScreenUpdates:NO];
    UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return snapshotImage;
}

#pragma mark - File Helper
- (AVURLAsset *)getURLAsset:(NSString *)filePath
{
    NSURL *videoURL = getFileURL(filePath);
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    
    return asset;
}

#pragma mark - Delete Temp Files
- (void)deleteTempDirectory
{
    NSString *dir = NSTemporaryDirectory();
    deleteFilesAt(dir, @"mov");
}

#pragma mark - Custom ActionSheet
- (void)showCustomActionSheetByView:(UIView *)anchor
{
    UIView *locationAnchor = anchor;
    
    NSString *videoTitle = [NSString stringWithFormat:@"%@", GBLocalizedString(@"SelectVideo")];
    JGActionSheetSection *sectionVideo = [JGActionSheetSection sectionWithTitle:videoTitle
                                                                        message:nil
                                                                   buttonTitles:@[
                                                                                  GBLocalizedString(@"Camera"),
                                                                                  GBLocalizedString(@"PhotoAlbum")
                                                                                  ]
                                                                    buttonStyle:JGActionSheetButtonStyleDefault];
    [sectionVideo setButtonStyle:JGActionSheetButtonStyleBlue forButtonAtIndex:0];
    [sectionVideo setButtonStyle:JGActionSheetButtonStyleBlue forButtonAtIndex:1];
    
    NSArray *sections = (iPad ? @[sectionVideo] : @[sectionVideo, [JGActionSheetSection sectionWithTitle:nil message:nil buttonTitles:@[GBLocalizedString(@"Cancel")] buttonStyle:JGActionSheetButtonStyleCancel]]);
    JGActionSheet *sheet = [[JGActionSheet alloc] initWithSections:sections];
    
    [sheet setButtonPressedBlock:^(JGActionSheet *sheet, NSIndexPath *indexPath)
     {
         NSLog(@"indexPath: %ld; section: %ld", (long)indexPath.row, (long)indexPath.section);
         
         if (indexPath.section == 0)
         {
             if (indexPath.row == 0)
             {
                 // Check permission for Video & Audio
                 [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted)
                  {
                      if (!granted)
                      {
                          [self performSelectorOnMainThread:@selector(popupAlertView) withObject:nil waitUntilDone:YES];
                          return;
                      }
                      else
                      {
                          [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted)
                           {
                               if (!granted)
                               {
                                   [self performSelectorOnMainThread:@selector(popupAuthorizationHelper:) withObject:[NSNumber numberWithLong:DBPrivacyTypeCamera] waitUntilDone:YES];
                                   return;
                               }
                               else
                               {
                                   // Has permisstion
                                   [self performSelectorOnMainThread:@selector(pickBackgroundVideoFromCamera) withObject:nil waitUntilDone:NO];
                               }
                           }];
                      }
                  }];
             }
             else if (indexPath.row == 1)
             {
                 // Check permisstion for photo album
                 ALAuthorizationStatus authStatus = [ALAssetsLibrary authorizationStatus];
                 if (authStatus == ALAuthorizationStatusRestricted || authStatus == ALAuthorizationStatusDenied)
                 {
                     [self performSelectorOnMainThread:@selector(popupAuthorizationHelper:) withObject:[NSNumber numberWithLong:DBPrivacyTypePhoto] waitUntilDone:YES];
                     return;
                 }
                 else
                 {
                     // Has permisstion to execute
                     [self performSelector:@selector(pickBackgroundVideoFromPhotosAlbum) withObject:nil afterDelay:0.1];
                 }
             }
         }
         
         [sheet dismissAnimated:YES];
     }];
    
    if (iPad)
    {
        [sheet setOutsidePressBlock:^(JGActionSheet *sheet)
         {
             [sheet dismissAnimated:YES];
         }];
        
        CGPoint point = (CGPoint){ CGRectGetMidX(locationAnchor.bounds), CGRectGetMaxY(locationAnchor.bounds) };
        point = [self.navigationController.view convertPoint:point fromView:locationAnchor];
        
        [sheet showFromPoint:point inView:self.navigationController.view arrowDirection:JGActionSheetArrowDirectionTop animated:YES];
    }
    else
    {
        [sheet setOutsidePressBlock:^(JGActionSheet *sheet)
         {
             [sheet dismissAnimated:YES];
         }];
        
        [sheet showInView:self.navigationController.view animated:YES];
    }
}

- (void)showCustomActionSheetByNav:(UIBarButtonItem *)barButtonItem withEvent:(UIEvent *)event
{
    UIView *anchor = [event.allTouches.anyObject view];
    [self showCustomActionSheetByView:anchor];
}

#pragma mark - PBJVideoPlayerControllerDelegate
- (void)videoPlayerReady:(PBJVideoPlayerController *)videoPlayer
{
    //NSLog(@"Max duration of the video: %f", videoPlayer.maxDuration);
}

- (void)videoPlayerPlaybackStateDidChange:(PBJVideoPlayerController *)videoPlayer
{
}

- (void)videoPlayerPlaybackWillStartFromBeginning:(PBJVideoPlayerController *)videoPlayer
{
    if (videoPlayer == _videoPlayerController)
    {
        _playButton.alpha = 1.0f;
        _playButton.hidden = NO;
        
        [UIView animateWithDuration:0.1f animations:^{
            _playButton.alpha = 0.0f;
        } completion:^(BOOL finished)
         {
             _playButton.hidden = YES;
         }];
    }
    else if (videoPlayer == _demoVideoPlayerController)
    {
        _demoPlayButton.alpha = 1.0f;
        _demoPlayButton.hidden = NO;
        
        [UIView animateWithDuration:0.1f animations:^{
            _demoPlayButton.alpha = 0.0f;
        } completion:^(BOOL finished)
         {
             _demoPlayButton.hidden = YES;
         }];
    }
}

- (void)videoPlayerPlaybackDidEnd:(PBJVideoPlayerController *)videoPlayer
{
    if (videoPlayer == _videoPlayerController)
    {
        _playButton.hidden = NO;
        
        [UIView animateWithDuration:0.1f animations:^{
            _playButton.alpha = 1.0f;
        } completion:^(BOOL finished)
         {
             
         }];
    }
    else if (videoPlayer == _demoVideoPlayerController)
    {
        _demoPlayButton.hidden = NO;
        
        [UIView animateWithDuration:0.1f animations:^{
            _demoPlayButton.alpha = 1.0f;
        } completion:^(BOOL finished)
         {
             
         }];
    }
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // 1.
    [self dismissViewControllerAnimated:NO completion:nil];
    
    NSLog(@"info = %@",info);
    
    // 2.
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if([mediaType isEqualToString:@"public.movie"])
    {
        NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
        [self setPickedVideo:url];
    }
    else
    {
        NSLog(@"Error media type");
        return;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:NO completion:nil];
}

- (void)setPickedVideo:(NSURL *)url
{
    [self setPickedVideo:url checkVideoLength:YES];
}

- (void)setPickedVideo:(NSURL *)url checkVideoLength:(BOOL)checkVideoLength
{
    if (!url || (url && ![url isFileURL]))
    {
        NSLog(@"Input video url is invalid.");
        return;
    }
    
    if (checkVideoLength)
    {
        if (getVideoDuration(url) > MaxVideoLength)
        {
            NSString *ok = GBLocalizedString(@"OK");
            NSString *error = GBLocalizedString(@"Error");
            NSString *fileLenHint = GBLocalizedString(@"FileLenHint");
            NSString *seconds = GBLocalizedString(@"Seconds");
            NSString *hint = [fileLenHint stringByAppendingFormat:@" %.0f ", MaxVideoLength];
            hint = [hint stringByAppendingString:seconds];
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:error
                                                            message:hint
                                                           delegate:nil
                                                  cancelButtonTitle:ok
                                                  otherButtonTitles: nil];
            [alert show];
            
            return;
        }
    }
    
    _videoPickURL = url;
    NSLog(@"Pick background video is success: %@", _videoPickURL);
    
    [self reCalcVideoSize:[url relativePath]];
    
    // Setting
    [self defaultVideoSetting:url];
    
    // Hint to draw clipping area
    if ([self getAppRunCount] < 6 && [self getNextStepRunCondition])
    {
        if (_popTipView)
        {
            NSString *hint = GBLocalizedString(@"UsageDrawClippingArea");
            _popTipView.message = hint;
            [_popTipView autoDismissAnimated:YES atTimeInterval:3.0];
            [_popTipView presentPointingAtView:_playButton inView:_parentView animated:YES];
        }
    }
    
    // Hint to next step
//    if ([self getAppRunCount] < 6 && [self getNextStepRunCondition])
//    {
//        if (_popTipView)
//        {
//            NSString *hint = GBLocalizedString(@"UsageNextHint");
//            _popTipView.message = hint;
//            [_popTipView autoDismissAnimated:YES atTimeInterval:5.0];
//            [_popTipView presentPointingAtBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES];
//        }
//    }
}

#pragma mark - pickBackgroundVideoFromPhotosAlbum
- (void)pickBackgroundVideoFromPhotosAlbum
{
    [self pickVideoFromPhotoAlbum];
}

- (void)pickVideoFromPhotoAlbum
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        // Only movie
        NSArray* availableMedia = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
        picker.mediaTypes = [NSArray arrayWithObject:availableMedia[1]];
    }
    
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - pickBackgroundVideoFromCamera
- (void)pickBackgroundVideoFromCamera
{
    [self pickVideoFromCamera];
}

- (void)pickVideoFromCamera
{
    CaptureViewController *captureVC = [[CaptureViewController alloc] init];
    [captureVC setCallback:^(BOOL success, id result)
     {
         if (success)
         {
             NSURL *fileURL = result;
             [self setPickedVideo:fileURL checkVideoLength:NO];
         }
         else
         {
             NSLog(@"Video Picker Failed: %@", result);
         }
     }];
    
    [self presentViewController:captureVC animated:YES completion:^{
        NSLog(@"PickVideo present");
    }];
}

#pragma mark - pickMusicFromCustom
- (void)pickMusicFromCustom
{
    if (![self getNextStepRunCondition])
    {
        NSString *message = nil;
        message = GBLocalizedString(@"VideoIsEmptyHint");
        showAlertMessage(message, nil);
        return;
    }
    
    AudioViewController *audioController = [[AudioViewController alloc] init];
    [audioController setSeletedRowBlock: ^(BOOL success, id result) {
        
        if (success && [result isKindOfClass:[NSNumber class]])
        {
            NSInteger index = [result integerValue];
            NSLog(@"pickAudio result: %ld", (long)index);
            
            if (index != NSNotFound)
            {
                NSArray *allAudios = [NSArray arrayWithObjects:
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"Apple"), @"song", @"Apple.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"TheMoodOfLove"), @"song", @"Love Paradise.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"LeadMeOn"), @"song", @"Lead Me On.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"Butterfly"), @"song", @"Butterfly.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"ALittleKiss"), @"song", @"A Little Kiss.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"ByeByeSunday"), @"song", @"Bye Bye Sunday.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"ComeWithMe"), @"song", @"Come With Me.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"DolphinTango"), @"song", @"Dolphin Tango.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"IDo"), @"song", @"I Do.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"LetMeKnow"), @"song", @"Let Me Know.mp3", @"url", nil],
                                      [NSDictionary dictionaryWithObjectsAndKeys:GBLocalizedString(@"SwingDance"), @"song", @"Swing Dance.mp3", @"url", nil],
                                      
                                      nil];
                NSDictionary *item = [allAudios objectAtIndex:index];
                NSString *file = [item objectForKey:@"url"];
                _audioPickFile = file;
            }
            else
            {
                _audioPickFile = nil;
            }
            
            // Convert
            [self handleConvert];
        }
    }];
    
    [self.navigationController pushViewController:audioController animated:NO];
}

#pragma mark - getNextStepCondition
- (BOOL)getNextStepRunCondition
{
    BOOL result = TRUE;
    if (!_videoPickURL)
    {
        result = FALSE;
    }
    
    return result;
}

#pragma mark - Default Setting
- (void)defaultVideoSetting:(NSURL *)url
{
    [self showVideoPlayView:YES];
    
    [self playDemoVideo:[url absoluteString] withinVideoPlayerController:_videoPlayerController];
}

#pragma mark - playDemoVideo
- (void)playDemoVideo:(NSString*)inputVideoPath withinVideoPlayerController:(PBJVideoPlayerController*)videoPlayerController
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        videoPlayerController.videoPath = inputVideoPath;
        [videoPlayerController playFromBeginning];
    });
}

#pragma mark - StopAllVideo
- (void)stopAllVideo
{
    if (_videoPlayerController.playbackState == PBJVideoPlayerPlaybackStatePlaying)
    {
        [_videoPlayerController stop];
    }
}

#pragma mark - Show/Hide
- (void)showVideoPlayView:(BOOL)show
{
    if (show)
    {
        _videoContentView.hidden = NO;
        _closeVideoPlayerButton.hidden = NO;
        
        _videoView.hidden = YES;
    }
    else
    {
        [self stopAllVideo];
        
        _videoView.hidden = NO;
        
        _videoContentView.hidden = YES;
        _closeVideoPlayerButton.hidden = YES;
    }
}

#pragma mark - reCalc on the basis of video size & view size
- (void)adjustColorPicker:(BOOL)referVideoContentView
{
    CGFloat gap = 10;
    CGRect referRect = _videoContentView.frame;
    if (!referVideoContentView)
    {
        referRect = _captureContentView.frame;
    }
    _bgColorLabel.frame = CGRectMake(CGRectGetMinX(_bgColorLabel.frame), CGRectGetMinY(referRect) - gap - CGRectGetHeight(_bgColorLabel.frame), CGRectGetWidth(_bgColorLabel.frame), CGRectGetHeight(_bgColorLabel.frame));
    _horizonPicker.frame = CGRectMake(CGRectGetMaxX(_bgColorLabel.frame) + gap, CGRectGetMinY(_bgColorLabel.frame), CGRectGetWidth(_horizonPicker.frame), CGRectGetHeight(_horizonPicker.frame));
}

- (void)reCalcVideoSize:(NSString *)videoPath
{
    CGFloat statusBarHeight = iOS7AddStatusHeight;
    CGSize sizeVideo = [self reCalcVideoViewSize:videoPath];
    _videoContentView.frame =  CGRectMake(CGRectGetMidX(self.view.frame) - sizeVideo.width/2, CGRectGetMidY(self.view.frame) - sizeVideo.height/2 + statusBarHeight, sizeVideo.width, sizeVideo.height);
    _videoPlayerController.view.frame = _videoContentView.bounds;
    _playButton.center = _videoPlayerController.view.center;
    _closeVideoPlayerButton.center = _videoContentView.frame.origin;
    
    [self createCroppableView:_parentView];
    _croppableView.frame = _videoContentView.frame;
    
    [self adjustColorPicker:YES];
}

- (CGSize)reCalcVideoViewSize:(NSString *)videoPath
{
    CGSize resultSize = CGSizeZero;
    if (isStringEmpty(videoPath))
    {
        return resultSize;
    }
    
    UIImage *videoFrame = getImageFromVideoFrame(getFileURL(videoPath), kCMTimeZero);
    if (!videoFrame || videoFrame.size.height < 1 || videoFrame.size.width < 1)
    {
        return resultSize;
    }
    
    NSLog(@"reCalcVideoViewSize: %@, width: %f, height: %f", videoPath, videoFrame.size.width, videoFrame.size.height);
    
    CGFloat statusBarHeight = 0; //iOS7AddStatusHeight;
    CGFloat navHeight = 0; //CGRectGetHeight(self.navigationController.navigationBar.bounds);
    CGFloat gap = 15;
    CGFloat height = CGRectGetHeight(self.view.frame) - navHeight - statusBarHeight - 2*gap;
    CGFloat width = CGRectGetWidth(self.view.frame) - 2*gap;
    if (height < width)
    {
        width = height;
    }
    else if (height > width)
    {
        height = width;
    }
    CGFloat videoHeight = videoFrame.size.height, videoWidth = videoFrame.size.width;
    CGFloat scaleRatio = videoHeight/videoWidth;
    CGFloat resultHeight = 0, resultWidth = 0;
    if (videoHeight <= height && videoWidth <= width)
    {
        resultHeight = videoHeight;
        resultWidth = videoWidth;
    }
    else if (videoHeight <= height && videoWidth > width)
    {
        resultWidth = width;
        resultHeight = height*scaleRatio;
    }
    else if (videoHeight > height && videoWidth <= width)
    {
        resultHeight = height;
        resultWidth = width/scaleRatio;
    }
    else
    {
        if (videoHeight < videoWidth)
        {
            resultWidth = width;
            resultHeight = height*scaleRatio;
        }
        else if (videoHeight == videoWidth)
        {
            resultWidth = width;
            resultHeight = height;
        }
        else
        {
            resultHeight = height;
            resultWidth = width/scaleRatio;
        }
    }
    
    resultSize = CGSizeMake(resultWidth, resultHeight);
    return resultSize;
}

#pragma mark - getOutputFilePath
- (NSString*)getOutputFilePath
{
    NSString* mp4OutputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"outputMovie.mov"];
    return mp4OutputFile;
}

#pragma mark - Progress callback
- (void)retrievingProgress:(id)progress title:(NSString *)text
{
    if (progress && [progress isKindOfClass:[NSNumber class]])
    {
        NSString *title = text ?text :GBLocalizedString(@"SavingVideo");
        NSString *currentPrecentage = [NSString stringWithFormat:@"%d%%", (int)([progress floatValue] * 100)];
        ProgressBarUpdateLoading(title, currentPrecentage);
    }
}

#pragma mark AppStore Open
- (void)showAppInAppStore:(NSString *)appId
{
    Class isAllow = NSClassFromString(@"SKStoreProductViewController");
    if (isAllow)
    {
        // > iOS6.0
        SKStoreProductViewController *sKStoreProductViewController = [[SKStoreProductViewController alloc] init];
        sKStoreProductViewController.delegate = self;
        [self presentViewController:sKStoreProductViewController
                           animated:YES
                         completion:nil];
        [sKStoreProductViewController loadProductWithParameters:@{SKStoreProductParameterITunesItemIdentifier: appId}completionBlock:^(BOOL result, NSError *error)
         {
             if (error)
             {
                 NSLog(@"%@",error);
             }
             
         }];
    }
    else
    {
        // < iOS6.0
        NSString *appUrl = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/us/app/id%@?mt=8", appId];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appUrl]];
        
        //        UIWebView *callWebview = [[UIWebView alloc] init];
        //        NSURL *appURL =[NSURL URLWithString:appStore];
        //        [callWebview loadRequest:[NSURLRequest requestWithURL:appURL]];
        //        [self.view addSubview:callWebview];
    }
}

- (void)createRecommendAppButtons:(UIView *)containerView
{
    // Recommend App
    UIButton *beautyTime = [[UIButton alloc] init];
    [beautyTime setTitle:GBLocalizedString(@"BeautyTime")
                forState:UIControlStateNormal];
    
    UIButton *photoBeautify = [[UIButton alloc] init];
    [photoBeautify setTitle:GBLocalizedString(@"PhotoBeautify")
                   forState:UIControlStateNormal];
    
    [photoBeautify setTag:1];
    [beautyTime setTag:2];
    
    CGFloat gap = 0, height = 30, width = 80;
    CGFloat fontSize = 16;
    NSString *fontName = @"迷你简启体"; // GBLocalizedString(@"FontName");
    photoBeautify.frame =  CGRectMake(gap, gap, width, height);
    [photoBeautify.titleLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
    [photoBeautify.titleLabel setTextAlignment:NSTextAlignmentLeft];
    [photoBeautify setTitleColor:kLightBlue forState:UIControlStateNormal];
    [photoBeautify addTarget:self action:@selector(recommendAppButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    beautyTime.frame =  CGRectMake(CGRectGetWidth(containerView.frame) - width - gap, gap, width, height);
    [beautyTime.titleLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
    [beautyTime.titleLabel setTextAlignment:NSTextAlignmentRight];
    [beautyTime setTitleColor:kLightBlue forState:UIControlStateNormal];
    [beautyTime addTarget:self action:@selector(recommendAppButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [containerView addSubview:photoBeautify];
    [containerView addSubview:beautyTime];
}

- (void)recommendAppButtonAction:(id)sender
{
    UIButton *button = (UIButton *)sender;
    switch (button.tag)
    {
        case 1:
        {
            // Picture in Picture
            [self showAppInAppStore:@"1006401631"];
            break;
        }
        case 2:
        {
            // BeautyTime
            [self showAppInAppStore:@"1002437952"];
            break;
        }
        default:
            break;
    }
    
    [button setSelected:YES];
}

#pragma mark - SKStoreProductViewControllerDelegate
// Dismiss contorller
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - DKHorizontalColorPickerDelegate
- (void)colorPicked:(UIColor *)color
{
    NSLog(@"colorPicked");
    
    [self setOutputBGColor:color];
}

#pragma mark - NSUserDefaults
#pragma mark - AppRunCount
- (void)addAppRunCount
{
    NSUInteger appRunCount = [self getAppRunCount];
    NSInteger limitCount = 6;
    if (appRunCount < limitCount)
    {
        ++appRunCount;
        NSString *appRunCountKey = @"AppRunCount";
        NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
        [userDefaultes setInteger:appRunCount forKey:appRunCountKey];
        [userDefaultes synchronize];
    }
}

- (NSUInteger)getAppRunCount
{
    NSUInteger appRunCount = 0;
    NSString *appRunCountKey = @"AppRunCount";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    if ([userDefaultes integerForKey:appRunCountKey])
    {
        appRunCount = [userDefaultes integerForKey:appRunCountKey];
    }
    
    NSLog(@"getAppRunCount: %lu", (unsigned long)appRunCount);
    return appRunCount;
}

#pragma mark - PathPoints
- (void)setPathPoints:(NSArray *)pathPoints
{
    NSString *flag = @"ArrayPathPoints";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    if (!pathPoints || [pathPoints count] < 1)
    {
        [userDefaultes removeObjectForKey:flag];
    
        NSLog(@"pathPoints is empty.");
        return;
    }
    
    NSData *dataPathPoints = [NSKeyedArchiver archivedDataWithRootObject:pathPoints];
    [userDefaultes setObject:dataPathPoints forKey:flag];
    [userDefaultes synchronize];
}

#pragma mark - OutputBGColor
- (void)setOutputBGColor:(UIColor*)color
{
    NSString *flag = @"OutputBGColor";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSData *bgColor = [NSKeyedArchiver archivedDataWithRootObject:color];
    [userDefaultes setObject:bgColor forKey:flag];
    [userDefaultes synchronize];
}

#pragma mark - View LifeCycle
- (void)createRecommendAppView
{
    CGFloat statusBarHeight = 0; //iOS7AddStatusHeight;
    CGFloat navHeight = 0; //CGRectGetHeight(self.navigationController.navigationBar.bounds);
    CGFloat height = 30;
    UIView *recommendAppView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame) - height - navHeight - statusBarHeight, CGRectGetWidth(self.view.frame), height)];
    [recommendAppView setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:recommendAppView];
    
    [self createRecommendAppButtons:recommendAppView];
    
    // Demo button
    CGFloat width = 60;
    _demoButton = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.view.frame)/2 - width/2, CGRectGetHeight(self.view.frame) - width, width, width)];
    UIImage *image = [UIImage imageNamed:@"demo"];
    [_demoButton setImage:image forState:UIControlStateNormal];
    [_demoButton addTarget:self action:@selector(handleDemoButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_demoButton];
}

- (void)createVideoView
{
    _parentView = [[UIView alloc] initWithFrame:self.view.bounds];
    _parentView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_parentView];
    
    [self createContentView:_parentView];
    [self createVideoPlayView:_parentView];
}

- (void)createContentView:(UIView *)parentView
{
    CGFloat statusBarHeight = 0; //iOS7AddStatusHeight;
    CGFloat navHeight = CGRectGetHeight(self.navigationController.navigationBar.bounds);
    CGFloat gap = 15, len = MIN((CGRectGetHeight(self.view.frame) - navHeight - statusBarHeight - 2*gap), (CGRectGetWidth(self.view.frame) - navHeight - statusBarHeight - 2*gap));
    _captureContentView =  [[UIScrollView alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.view.frame) - len/2, CGRectGetMidY(self.view.frame) - len/2, len, len)];
    [_captureContentView setBackgroundColor:[UIColor clearColor]];
    [parentView addSubview:_captureContentView];
    
    _videoView = [[UIButton alloc] initWithFrame:_captureContentView.frame];
    [_videoView setBackgroundColor:[UIColor clearColor]];
    
    _videoView.layer.cornerRadius = 5;
    _videoView.layer.masksToBounds = YES;
    _videoView.layer.borderWidth = 1.0;
    _videoView.layer.borderColor = [UIColor whiteColor].CGColor;
    
    UIImage *addFileImage = [UIImage imageNamed:@"Video_Add"];
    [_videoView setImage:addFileImage forState:UIControlStateNormal];
    [_videoView addTarget:self action:@selector(showCustomActionSheetByView:) forControlEvents:UIControlEventTouchUpInside];
    [parentView addSubview:_videoView];
}

- (void)createVideoPlayView:(UIView *)parentView
{
    _videoContentView =  [[UIScrollView alloc] initWithFrame:_captureContentView.frame];
    [_videoContentView setBackgroundColor:[UIColor clearColor]];
    [parentView addSubview:_videoContentView];
    
    // Video player
    _videoPlayerController = [[PBJVideoPlayerController alloc] init];
    _videoPlayerController.delegate = self;
    _videoPlayerController.view.frame = _videoView.bounds;
    _videoPlayerController.view.clipsToBounds = YES;
    
    [self addChildViewController:_videoPlayerController];
    [_videoContentView addSubview:_videoPlayerController.view];
    
    _playButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play_button"]];
    _playButton.center = _videoPlayerController.view.center;
    [_videoPlayerController.view addSubview:_playButton];
    
    // Close video player
    UIImage *imageClose = [UIImage imageNamed:@"close"];
    CGFloat width = 60;
    _closeVideoPlayerButton = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMinX(_videoContentView.frame) - width/2, CGRectGetMinY(_videoContentView.frame) - width/2, width, width)];
    _closeVideoPlayerButton.center = _captureContentView.frame.origin;
    [_closeVideoPlayerButton setImage:imageClose forState:(UIControlStateNormal)];
    [_closeVideoPlayerButton addTarget:self action:@selector(handleCloseVideo:) forControlEvents:UIControlEventTouchUpInside];
    [parentView addSubview:_closeVideoPlayerButton];
    
    _closeVideoPlayerButton.hidden = YES;
}

- (void)clearCroppableView
{
    if (_croppableView)
    {
        [_croppableView removeFromSuperview];
        _croppableView = nil;
    }
}

- (void)createCroppableView:(UIView *)parentView
{
    if (_croppableView)
    {
        [self clearCroppableView];
    }
    
    _croppableView = [[MZCroppableView alloc] initWithView:_videoContentView];
    [parentView addSubview:_croppableView];
}

- (void)createColorPicker
{
    CGFloat heightColor = 40, widthColor = 160, gap = 10;
    CGFloat fontHeight = 15;
    NSString *text = GBLocalizedString(@"BackgroundColor");
    CGFloat labelWidth = [text maxWidthForText:text height:fontHeight font:[UIFont systemFontOfSize:fontHeight]];
   
    _bgColorLabel = [[UILabel alloc]initWithFrame:CGRectMake(CGRectGetMidX(_videoContentView.frame) - (widthColor + gap + labelWidth)/2, CGRectGetMinY(_videoContentView.frame) - gap - heightColor, labelWidth, heightColor)];
    _bgColorLabel.font = [UIFont systemFontOfSize:fontHeight];
    _bgColorLabel.text = text;
    [self.view addSubview:_bgColorLabel];
    
    _horizonPicker = [[DKHorizontalColorPicker alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_bgColorLabel.frame) + gap, CGRectGetMinY(_bgColorLabel.frame), widthColor, heightColor)];
    _horizonPicker.delegate = self;
    _horizonPicker.selectedColor = [UIColor blackColor];
    [self.view addSubview:_horizonPicker];
}

- (void)createNavigationBar
{
    NSString *fontName = GBLocalizedString(@"FontName");
    CGFloat fontSize = 20;
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [UIColor colorWithRed:0 green:0.7 blue:0.8 alpha:1];
    [self.navigationController.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                     kBrightBlue, NSForegroundColorAttributeName,
                                                                     shadow,
                                                                     NSShadowAttributeName,
                                                                     [UIFont fontWithName:fontName size:fontSize], NSFontAttributeName,
                                                                     nil]];
    
    self.title = GBLocalizedString(@"FunVideoCrop");
}

- (void)createNavigationItem
{
    NSString *fontName = GBLocalizedString(@"FontName");
    CGFloat fontSize = 18;
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:GBLocalizedString(@"Crop") style:UIBarButtonItemStylePlain target:self action:@selector(pickMusicFromCustom)];
    [rightItem setTitleTextAttributes:@{NSForegroundColorAttributeName:kBrightBlue, NSFontAttributeName:[UIFont fontWithName:fontName size:fontSize]} forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithTitle:GBLocalizedString(@"Undo") style:UIBarButtonItemStylePlain target:self action:@selector(handleResetButton:)];
    [leftItem setTitleTextAttributes:@{NSForegroundColorAttributeName:kBrightBlue, NSFontAttributeName:[UIFont fontWithName:fontName size:fontSize]} forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = leftItem;
}

- (void)createPopTipView
{
    NSArray *colorSchemes = [NSArray arrayWithObjects:
                             [NSArray arrayWithObjects:[NSNull null], [NSNull null], nil],
                             [NSArray arrayWithObjects:[UIColor colorWithRed:134.0/255.0 green:74.0/255.0 blue:110.0/255.0 alpha:1.0], [NSNull null], nil],
                             [NSArray arrayWithObjects:[UIColor darkGrayColor], [NSNull null], nil],
                             [NSArray arrayWithObjects:[UIColor lightGrayColor], [UIColor darkTextColor], nil],
                             nil];
    NSArray *colorScheme = [colorSchemes objectAtIndex:foo4random()*[colorSchemes count]];
    UIColor *backgroundColor = [colorScheme objectAtIndex:0];
    UIColor *textColor = [colorScheme objectAtIndex:1];
    
    NSString *hint = GBLocalizedString(@"UsageHint");
    _popTipView = [[CMPopTipView alloc] initWithMessage:hint];
    if (backgroundColor && ![backgroundColor isEqual:[NSNull null]])
    {
        _popTipView.backgroundColor = backgroundColor;
    }
    if (textColor && ![textColor isEqual:[NSNull null]])
    {
        _popTipView.textColor = textColor;
    }
    
    _popTipView.animation = arc4random() % 2;
    _popTipView.has3DStyle = NO;
    _popTipView.dismissTapAnywhere = YES;
    [_popTipView autoDismissAnimated:YES atTimeInterval:5.0];
    
    [_popTipView presentPointingAtView:_playButton inView:_parentView animated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"sharebg3"]];
    _videoPickURL = nil;
    
    [self createNavigationItem];
    
    [self createVideoView];
    [self createRecommendAppView];
    [self createColorPicker];
    
    // Hint
    NSInteger appRunCount = [self getAppRunCount], maxRunCount = 6;
    if (appRunCount < maxRunCount)
    {
        [self createPopTipView];
    }
    
    [self addAppRunCount];
    
    [self showVideoPlayView:NO];
    
    // Delete temp files
    [self deleteTempDirectory];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self createNavigationBar];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Handle Event
- (void)handleDemoButton
{
    NSString *demoVideoPath = getFilePath(DemoVideoName);
    [self showDemoVideo:demoVideoPath];
}

- (void)handleResetButton:(UIBarButtonItem *)sender
{
    if (!_videoPickURL)
    {
        NSString *message = nil;
        message = GBLocalizedString(@"VideoIsEmptyHint");
        showAlertMessage(message, nil);
        return;
    }
    
    [self createCroppableView:_parentView];
}

- (void)handleConvert
{
    if (_croppableView)
    {
        // Croppable path
        NSArray *pointsPath = [_croppableView getCroppablePathPoints];
        
        NSMutableArray *fixedPathPoints = nil;
        if (pointsPath && [pointsPath count] > 0)
        {
            CGPoint flagClosure = CGPointZero;
            fixedPathPoints = [[NSMutableArray alloc] initWithCapacity:1];
            CGSize videoSize = [getImageFromVideoFrame(_videoPickURL, CMTimeMake(0, 1)) size];
            for (NSUInteger i = 0; i < [pointsPath count]; ++i)
            {
                CGPoint point = [[pointsPath objectAtIndex:i] CGPointValue];
                if (!CGPointEqualToPoint(flagClosure, point))
                {
                    // 存在闭合曲线，跳过此处
                    point = [MZCroppableView convertCGPoint:[[pointsPath objectAtIndex:i] CGPointValue] fromRect1:_croppableView.frame.size toRect2:videoSize];
                }
                [fixedPathPoints addObject:[NSValue valueWithCGPoint:point]];
            }
        }
        
        [self setPathPoints:fixedPathPoints];
    }
    
    ProgressBarShowLoading(GBLocalizedString(@"Processing"));
    
    [[ExportEffects sharedInstance] setExportProgressBlock: ^(NSNumber *percentage) {
        
        // Export progress
        [self retrievingProgress:percentage title:GBLocalizedString(@"SavingVideo")];
    }];
    
    [[ExportEffects sharedInstance] setFinishVideoBlock: ^(BOOL success, id result) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (success)
            {
                ProgressBarDismissLoading(GBLocalizedString(@"Success"));
            }
            else
            {
                ProgressBarDismissLoading(GBLocalizedString(@"Failed"));
            }
            
            // Alert
            NSString *ok = GBLocalizedString(@"OK");
            [UIAlertView showWithTitle:nil
                               message:result
                     cancelButtonTitle:ok
                     otherButtonTitles:nil
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                  
                                  if (buttonIndex == [alertView cancelButtonIndex])
                                  {
                                      NSLog(@"Alert Cancelled");
                                      
                                      [NSThread sleepForTimeInterval:0.5];
                                      
                                      // Demo result video
                                      if (!isStringEmpty([ExportEffects sharedInstance].filenameBlock()))
                                      {
                                          NSString *outputPath = [ExportEffects sharedInstance].filenameBlock();
                                          [self showDemoVideo:outputPath];
                                      }
                                  }
                              }];
            
            [self showVideoPlayView:TRUE];
        });
    }];
    
    [[ExportEffects sharedInstance] addEffectToVideo:[_videoPickURL relativePath] withAudioFilePath:getFilePath(_audioPickFile)];
}

- (void)handleCloseVideo:(UIView *)anchor
{
    [self showVideoPlayView:NO];
    
    [self clearCroppableView];
    [_videoPlayerController clearView];
    _videoPickURL = nil;
    
    [self adjustColorPicker:NO];
}

#pragma mark - showDemoVideo
- (void)showDemoVideo:(NSString *)videoPath
{
    CGFloat statusBarHeight = iOS7AddStatusHeight;
    CGFloat navHeight = CGRectGetHeight(self.navigationController.navigationBar.bounds);
    CGSize size = [self reCalcVideoViewSize:videoPath];
    _demoVideoContentView =  [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.view.frame) - size.width/2, CGRectGetMidY(self.view.frame) - size.height/2 - navHeight - statusBarHeight, size.width, size.height)];
    [self.view addSubview:_demoVideoContentView];
    
    // Video player of destination
    _demoVideoPlayerController = [[PBJVideoPlayerController alloc] init];
    _demoVideoPlayerController.view.frame = _demoVideoContentView.bounds;
    _demoVideoPlayerController.view.clipsToBounds = YES;
    _demoVideoPlayerController.videoView.videoFillMode = AVLayerVideoGravityResizeAspect;
    _demoVideoPlayerController.delegate = self;
    //    _demoVideoPlayerController.playbackLoops = YES;
    [_demoVideoContentView addSubview:_demoVideoPlayerController.view];
    
    _demoPlayButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play_button"]];
    _demoPlayButton.center = _demoVideoPlayerController.view.center;
    [_demoVideoPlayerController.view addSubview:_demoPlayButton];
    
    // Popup modal view
    [[KGModal sharedInstance] setCloseButtonType:KGModalCloseButtonTypeLeft];
    [[KGModal sharedInstance] showWithContentView:_demoVideoContentView andAnimated:YES];
    
    [self playDemoVideo:videoPath withinVideoPlayerController:_demoVideoPlayerController];
}

@end
