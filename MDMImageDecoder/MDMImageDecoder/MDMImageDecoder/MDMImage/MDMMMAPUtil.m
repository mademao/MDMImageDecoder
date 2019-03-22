//
//  MDMMMAPUtil.m
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/15.
//  Copyright © 2019 mademao. All rights reserved.
//

#import "MDMMMAPUtil.h"
#import <sys/mman.h>

size_t MDMByteAlign(size_t width, size_t alignment) {
    return ((width + (alignment - 1)) / alignment) * alignment;
}

size_t MDMByteAlignForCoreAnimation(size_t width) {
    return MDMByteAlign(width, 64);
}

@implementation MDMMMAPUtil

+ (NSString *)mmapFilePath
{
    NSString *cachePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.mademao.gifimage"];
#if TARGET_IPHONE_SIMULATOR
    cachePath = @"/tmp/mademao/com.mademao.gifimage";
#endif
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    });
    
    BOOL isDirectory = YES;
    BOOL success = [[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDirectory];
    
    if (success == NO ||
        isDirectory == NO) {
        success = [[NSFileManager defaultManager] createDirectoryAtPath:cachePath
                                            withIntermediateDirectories:YES
                                                             attributes:nil
                                                                  error:nil];
        if (success == NO) {
            cachePath = nil;
        }
    }
    
    return cachePath;
}

+ (void *)createMMAPFile:(NSString *)file size:(NSUInteger)size
{
    NSString *path = [[self mmapFilePath] stringByAppendingPathComponent:file];
    
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
    }
    
    char *buffer = NULL;
    int fd = open(path.UTF8String, O_CREAT|O_RDWR, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
    if (fd != -1) {
        int ret = ftruncate(fd, size);
        if (ret != -1) {
            buffer = mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, fd, 0);
            if (buffer == MAP_FAILED) {
                buffer = NULL;
            }
        }
        close(fd);
    }
    return buffer;
}

+ (void)cleanMMAPFile:(NSString *)file buffer:(void *)buffer size:(NSUInteger)size
{
    if (buffer) {
        munmap(buffer, size);
        buffer = NULL;
    }
    
    if (file && file.length) {
        NSString *path = [[self mmapFilePath] stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

+ (size_t)openImageFileByMMAP:(NSString *)file destBuffer:(void **)destBuffer
{
    void *buffer = NULL;
    size_t size = -1;
    int fd = open([file fileSystemRepresentation], O_RDONLY, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
    if (fd != -1) {
        size = (size_t)lseek(fd, 0, SEEK_END);
        buffer = mmap(NULL, size, PROT_READ, MAP_FILE|MAP_SHARED, fd, 0);
        if (buffer == MAP_FAILED) {
            buffer = NULL;
        }
        close(fd);
    }
    
    *destBuffer = buffer;
    
    return size;
}

@end
