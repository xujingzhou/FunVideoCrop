
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CaptureDefine.h"
#import "CameraRecorder.h"

@interface CaptureViewController : UIViewController <CameraRecorderDelegate, UIAlertViewDelegate>
{
    
}

// Add callback by Johnny Xu
@property (copy, nonatomic) GenericCallback callback;

@end
