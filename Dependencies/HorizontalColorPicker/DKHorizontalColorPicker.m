
#import "DKHorizontalColorPicker.h"

@interface DKHorizontalColorPicker ()

@property (nonatomic) CGFloat currentSelectionX;

@end

@implementation DKHorizontalColorPicker

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.currentSelectionX = 0.0;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

// for when coming out of a nib
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    if (self)
    {
        self.currentSelectionX = 0.0;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    // Drawing code
    [super drawRect:rect];
    
    CGFloat tempXPlace = self.currentSelectionX;
    if (tempXPlace < 0.0)
    {
        tempXPlace = 0.0;
    }
    else if (tempXPlace >= self.frame.size.width)
    {
        tempXPlace = self.frame.size.width - 1.0;
    }
    
    // Draw central bar over it
    CGFloat cbxbegin = self.frame.size.height * 0.2;
    CGFloat cbHeight = self.frame.size.height * 0.6;
    for (int x = 0; x < self.frame.size.width; ++x)
    {
        [[UIColor colorWithHue:(x/self.frame.size.width) saturation:1.0 brightness:1.0 alpha:1.0] set];
        CGRect temp = CGRectMake(x, cbxbegin, 1.0, cbHeight);
        UIRectFill(temp);
    }
    
    // Draw wings
    [[UIColor blackColor] set];
    CGRect temp = CGRectMake(tempXPlace, 0.0, 2.0, self.frame.size.height);
    UIRectFill(temp);
}

/*!
 Changes the selected color, updates the UI, and notifies the delegate.
 */
- (void)setSelectedColor:(UIColor *)selectedColor
{
    if (selectedColor != _selectedColor)
    {
        CGFloat hue = 0.0, temp = 0.0;
        if ([selectedColor getHue:&hue saturation:&temp brightness:&temp alpha:&temp])
        {
            self.currentSelectionX = floorf(hue * self.frame.size.width);
            [self setNeedsDisplay];
        }
        
        _selectedColor = selectedColor;
        if([self.delegate respondsToSelector:@selector(colorPicked:)])
        {
            [self.delegate colorPicked:_selectedColor];
        }
    }
}

#pragma mark - Touch Events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Update color
    self.currentSelectionX = [((UITouch *)[touches anyObject]) locationInView:self].x;
    _selectedColor = [UIColor colorWithHue:(self.currentSelectionX / self.frame.size.width) saturation:1.0 brightness:1.0 alpha:1.0];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Update color
    self.currentSelectionX = [((UITouch *)[touches anyObject]) locationInView:self].x;
    _selectedColor = [UIColor colorWithHue:(self.currentSelectionX / self.frame.size.width) saturation:1.0 brightness:1.0 alpha:1.0];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Update color
    self.currentSelectionX = [((UITouch *)[touches anyObject]) locationInView:self].x;
    _selectedColor = [UIColor colorWithHue:(self.currentSelectionX / self.frame.size.width) saturation:1.0 brightness:1.0 alpha:1.0];
    
    // Notify delegate
    if([self.delegate respondsToSelector:@selector(colorPicked:)])
    {
        [self.delegate colorPicked:self.selectedColor];
    }
    
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

@end
