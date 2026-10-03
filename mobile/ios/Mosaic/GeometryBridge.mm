#import "GeometryBridge.h"
#include "../../core/Geometry.hpp"
@implementation GeometryBridge
+ (NSArray *)layouts {
    NSMutableArray *out = [NSMutableArray new];
    for (const auto& item : mosaic::layouts())
        [out addObject:@{@"id": @(item.id), @"category": @(item.category), @"vi": @(item.vi), @"en": @(item.en)}];
    return out;
}
+ (NSArray *)frame:(NSString *)layout count:(NSInteger)count width:(double)width height:(double)height gap:(double)gap {
    NSMutableArray *out = [NSMutableArray new];
    try { for (auto value : mosaic::packedFrame(layout.UTF8String, (int)count, width, height, gap)) [out addObject:@(value)]; }
    catch (const std::exception&) { return @[]; }
    return out;
}
@end
