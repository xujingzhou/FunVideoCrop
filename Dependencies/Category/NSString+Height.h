
#import <Foundation/Foundation.h>

@interface NSString (Height)

// Add by Johnny Xu, 2015/2/28
- (CGFloat)maxWidthForText:(NSString *)text height:(CGFloat)textHeight font:(UIFont*)font;
- (CGSize)maxHeightForText:(NSString *)text width:(CGFloat)textWidth font:(UIFont*)font;
- (CGSize)sizeForText:(NSString *)text font:(UIFont*)font;

@end
