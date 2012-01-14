//
//  WCFile.h
//  WabbitStudio
//
//  Created by William Towe on 1/13/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import "RSObject.h"

@class RSFileReference;

@interface WCFile : RSObject <RSPlistArchiving> {
	RSFileReference *_fileReference;
}
@property (readonly,nonatomic) RSFileReference *fileReference;
@property (readonly,nonatomic) NSString *fileName;
@property (readonly,nonatomic) NSImage *fileIcon;

+ (id)fileWithFileURL:(NSURL *)fileURL;
- (id)initWithFileURL:(NSURL *)fileURL;
@end