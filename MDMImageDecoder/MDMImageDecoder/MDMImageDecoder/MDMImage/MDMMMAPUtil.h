//
//  MDMMMAPUtil.h
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/15.
//  Copyright © 2019 mademao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

size_t MDMByteAlign(size_t width, size_t alignment);
size_t MDMByteAlignForCoreAnimation(size_t width);

@interface MDMMMAPUtil : NSObject

+ (NSString *)mmapFilePath;
+ (void *)createMMAPFile:(NSString *)file size:(NSUInteger)size;
+ (void)cleanMMAPFile:(NSString *)file buffer:(void *)buffer size:(NSUInteger)size;
+ (size_t)openImageFileByMMAP:(NSString *)file destBuffer:(void **)destBuffer;


@end

NS_ASSUME_NONNULL_END
