//
//  ApptentiveAttachment.h
//  Apptentive
//
//  Created by Frank Schmitt on 3/22/17.
//  Copyright © 2017 Apptentive, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>

NS_ASSUME_NONNULL_BEGIN

@interface ApptentiveAttachment : NSObject <NSSecureCoding>

@property (readonly, nonatomic) NSString *fileName;
@property (readonly, nonatomic) NSString *contentType;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSInteger size;
@property (readonly, nonatomic) NSURL *remoteURL;

@property (readonly, nonatomic) NSString *fullLocalPath;

- (nullable instancetype)initWithJSON:(NSDictionary *)JSON;
- (nullable instancetype)initWithPath:(NSString *)path contentType:(NSString *)contentType name:(nullable NSString *)name;
- (nullable instancetype)initWithData:(NSData *)data contentType:(NSString *)contentType name:(nullable NSString *)name;

@property (readonly, nonatomic) NSString *extension;
@property (readonly, nonatomic) BOOL canCreateThumbnail;

- (UIImage *)thumbnailOfSize:(CGSize)size;

/** Can be called from background thread. */
- (NSURL *)permanentLocation;

/** Must be called from main thread. */
- (void)completeMoveToStorageFor:(NSURL *)storageLocation;

@end

@interface ApptentiveAttachment (QuickLook) <QLPreviewItem>
@end

NS_ASSUME_NONNULL_END
