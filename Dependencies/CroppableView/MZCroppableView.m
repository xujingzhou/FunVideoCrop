
#import "MZCroppableView.h"
#import "UIBezierPath-Points.h"

@interface MZCroppableView()

@property (nonatomic, assign) CGPoint pointClosure;

@end

@implementation MZCroppableView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
    }
    return self;
}

- (id)initWithImageView:(UIImageView *)imageView
{
    self = [super initWithFrame:imageView.frame];
    
    if (self)
    {
        [self initResource];
    }
    return self;
}

- (id)initWithView:(UIView *)view
{
    self = [super initWithFrame:view.frame];
    
    if (self)
    {
        [self initResource];
    }
    return self;
}

- (void)initResource
{
    _pointClosure = CGPointZero;
    
    self.lineWidth = 5.0f;
    [self setBackgroundColor:[UIColor clearColor]];
    [self setClipsToBounds:YES];
    [self setUserInteractionEnabled:YES];
    self.croppingPath = [[UIBezierPath alloc] init];
    [self.croppingPath setLineWidth:self.lineWidth];
    self.lineColor = [UIColor redColor];
}

#pragma mark - My Methods -
+ (CGRect)scaleRespectAspectFromRect1:(CGRect)rect1 toRect2:(CGRect)rect2
{
    CGSize scaledSize = rect2.size;
    float scaleFactor = 1.0;
    
    CGFloat widthFactor  = rect2.size.width / rect1.size.width;
    CGFloat heightFactor = rect2.size.height / rect1.size.width;
    
    if (widthFactor < heightFactor)
        scaleFactor = widthFactor;
    else
        scaleFactor = heightFactor;
    
    scaledSize.height = rect1.size.height * scaleFactor;
    scaledSize.width  = rect1.size.width  * scaleFactor;
    float y = (rect2.size.height - scaledSize.height)/2;
    float x = (rect2.size.width - scaledSize.width)/2;
    
    return CGRectMake(x, y, scaledSize.width, scaledSize.height);
}

+ (CGPoint)convertCGPoint:(CGPoint)point1 fromRect1:(CGSize)rect1 toRect2:(CGSize)rect2
{
    point1.y = rect1.height - point1.y;
    CGPoint result = CGPointMake((point1.x*rect2.width)/rect1.width, (point1.y*rect2.height)/rect1.height);
    return result;
}

+ (CGPoint)convertPoint:(CGPoint)point1 fromRect1:(CGSize)rect1 toRect2:(CGSize)rect2
{
    CGPoint result = CGPointMake((point1.x*rect2.width)/rect1.width, (point1.y*rect2.height)/rect1.height);
    return result;
}

- (NSArray*)getCroppablePathPoints
{
    NSArray *arrayResult = nil;
    NSArray *points = [self.croppingPath points];
    if (points && [points count] > 1)
    {
        arrayResult = [NSArray arrayWithArray:points];
    }
    
    return arrayResult;
}

- (NSArray*)getCroppablePathElements
{
    NSArray *arrayResult = nil;
    NSArray *pathElements = [self.croppingPath bezierElements];
    if (pathElements && [pathElements count] > 1)
    {
        arrayResult = [NSArray arrayWithArray:pathElements];
    }
    
    return arrayResult;
}

- (UIImage *)deleteBackgroundOfImage:(UIImageView *)image
{
    NSArray *points = [self.croppingPath points];
    
    CGRect rect = CGRectZero;
    rect.size = image.image.size;
    
    UIBezierPath *aPath;
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0.0);
    {
        [[UIColor blackColor] setFill];
        UIRectFill(rect);
        [[UIColor whiteColor] setFill];
        
        aPath = [UIBezierPath bezierPath];
        
        // Set the starting point of the shape.
        CGPoint p1 = [MZCroppableView convertCGPoint:[[points objectAtIndex:0] CGPointValue] fromRect1:image.frame.size toRect2:image.image.size];
        [aPath moveToPoint:CGPointMake(p1.x, p1.y)];
        
        for (uint i=1; i<points.count; i++)
        {
            CGPoint p = [MZCroppableView convertCGPoint:[[points objectAtIndex:i] CGPointValue] fromRect1:image.frame.size toRect2:image.image.size];
            [aPath addLineToPoint:CGPointMake(p.x, p.y)];
        }
        
        [aPath closePath];
        [aPath fill];
    }
    
    UIImage *mask = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    {
        CGContextClipToMask(UIGraphicsGetCurrentContext(), rect, mask.CGImage);
        [image.image drawAtPoint:CGPointZero];
    }
    
    UIImage *maskedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGRect croppedRect = aPath.bounds;
    croppedRect.origin.y = rect.size.height - CGRectGetMaxY(aPath.bounds);//This because mask become inverse of the actual image;
    
    croppedRect.origin.x = croppedRect.origin.x*2;
    croppedRect.origin.y = croppedRect.origin.y*2;
    croppedRect.size.width = croppedRect.size.width*2;
    croppedRect.size.height = croppedRect.size.height*2;
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(maskedImage.CGImage, croppedRect);
    maskedImage = [UIImage imageWithCGImage:imageRef];
    
    return maskedImage;
}

#pragma mark - drawRect
- (void)drawRect:(CGRect)rect
{
    // Drawing code
    [self.lineColor setStroke];
    [self.croppingPath strokeWithBlendMode:kCGBlendModeNormal alpha:1.0f];
}

#pragma mark - Touch Methods -
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[touches allObjects] objectAtIndex:0];
    [self.croppingPath moveToPoint:[touch locationInView:self]];
    
    _pointClosure = [touch locationInView:self];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[touches allObjects] objectAtIndex:0];
    [self.croppingPath addLineToPoint:[touch locationInView:self]];
    
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Auto closure
    NSUInteger count = [_croppingPath.points count];
    if (_croppingPath && count > 0)
    {
        CGPoint firstPoint = _pointClosure;
        UITouch *touch = [[touches allObjects] objectAtIndex:0];
        CGPoint lastPoint = [touch locationInView:self];
        if (!CGPointEqualToPoint(firstPoint, lastPoint))
        {
            [self.croppingPath addLineToPoint:lastPoint];
            [self.croppingPath addLineToPoint:firstPoint];
        }
        
        [self setNeedsDisplay];
    }
}

@end
