//
//  ATMessageCenterDataSource.h
//  ApptentiveConnect
//
//  Created by Andrew Wooster on 11/12/13.
//  Copyright (c) 2013 Apptentive, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "ATAbstractMessage.h"

typedef NS_ENUM(NSInteger, ATMessageCenterMessageType) {
	ATMessageCenterMessageTypeMessage,
	ATMessageCenterMessageTypeReply
};

@protocol ATMessageCenterDataSourceDelegate;

@interface ATMessageCenterDataSource : NSObject
@property (nonatomic, strong, readonly) NSFetchedResultsController *fetchedMessagesController;
@property (nonatomic, weak) NSObject<ATMessageCenterDataSourceDelegate> *delegate;
@property (nonatomic, readonly) NSDateFormatter *dateFormatter;

- (id)initWithDelegate:(NSObject<ATMessageCenterDataSourceDelegate> *)delegate;
- (void)start;
- (void)stop;

- (NSInteger)numberOfMessageGroups;
- (NSInteger)numberOfMessagesInGroup:(NSInteger)groupIndex;
- (ATMessageCenterMessageType)cellTypeAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)textOfMessageAtIndexPath:(NSIndexPath *)indexPath;
- (NSDate *)dateOfMessageGroupAtIndex:(NSInteger)index;
- (BOOL)shouldShowDateForMessageGroupAtIndex:(NSInteger)index;
- (NSString *)senderOfMessageAtIndexPath:(NSIndexPath *)indexPath;
- (NSURL *)imageURLOfSenderAtIndexPath:(NSIndexPath *)indexPath;
- (void)markAsReadMessageAtIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, readonly) BOOL lastMessageIsReply;
@property (nonatomic, readonly) ATPendingMessageState lastSentMessageState;

@end

@protocol ATMessageCenterDataSourceDelegate <NSObject, NSFetchedResultsControllerDelegate>

@end
