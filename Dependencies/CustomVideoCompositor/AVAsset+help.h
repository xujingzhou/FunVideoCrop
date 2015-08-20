
#import <AVFoundation/AVFoundation.h>

@interface AVAsset (help)

+ (instancetype)assetWithResourceName:(NSString *)name;
+ (instancetype)assetWithFileURL:(NSURL *)url;
- (AVAssetTrack *)firstVideoTrack;

- (void)whenProperties:(NSArray *)propertyNames areReadyDo:(void (^)(void))block;

@end
