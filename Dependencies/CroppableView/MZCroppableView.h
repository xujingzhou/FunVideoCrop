
#import <UIKit/UIKit.h>

@interface MZCroppableView : UIView
{
    
}

@property(nonatomic, strong) UIBezierPath *croppingPath;
@property(nonatomic, strong) UIColor *lineColor;
@property(nonatomic, assign) float lineWidth;

- (id)initWithView:(UIView *)view;
- (id)initWithImageView:(UIImageView *)imageView;

+ (CGPoint)convertCGPoint:(CGPoint)point1 fromRect1:(CGSize)rect1 toRect2:(CGSize)rect2;
+ (CGPoint)convertPoint:(CGPoint)point1 fromRect1:(CGSize)rect1 toRect2:(CGSize)rect2;
+ (CGRect)scaleRespectAspectFromRect1:(CGRect)rect1 toRect2:(CGRect)rect2;

- (UIImage *)deleteBackgroundOfImage:(UIImageView *)image;

- (NSArray*)getCroppablePathPoints;
- (NSArray*)getCroppablePathElements;

@end
