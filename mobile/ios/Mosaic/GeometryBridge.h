#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface GeometryBridge : NSObject
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)layouts;
+ (NSArray<NSNumber *> *)frame:(NSString *)layout count:(NSInteger)count width:(double)width height:(double)height gap:(double)gap;
@end
NS_ASSUME_NONNULL_END
