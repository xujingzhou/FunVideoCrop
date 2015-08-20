
#import <UIKit/UIKit.h>

typedef enum
{
    DeleteButtonStyleDelete,
    DeleteButtonStyleNormal,
    DeleteButtonStyleDisable,
}DeleteButtonStyle;

@interface DeleteButton : UIButton

@property (assign, nonatomic) DeleteButtonStyle style;

+ (DeleteButton *)getInstance;
- (void)setButtonStyle:(DeleteButtonStyle)style;


@end
