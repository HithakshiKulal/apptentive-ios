//
//  ApptentiveMessageCenterViewModel.m
//  Apptentive
//
//  Created by Andrew Wooster on 11/12/13.
//  Copyright (c) 2013 Apptentive, Inc. All rights reserved.
//

#import "ApptentiveMessageCenterViewModel.h"
#import "ApptentiveAttachment.h"
#import "ApptentiveMessageSender.h"

#import "ApptentiveBackend.h"
#import "Apptentive.h"
#import "Apptentive_Private.h"
#import "ApptentiveAttachmentCell.h"
#import "ApptentiveUtilities.h"
#import "ApptentiveInteraction.h"
#import "ApptentivePerson.h"
#import "ApptentiveReachability.h"

NSString *const ATMessageCenterServerErrorDomain = @"com.apptentive.MessageCenterServerError";
NSString *const ATMessageCenterErrorMessagesKey = @"com.apptentive.MessageCenterErrorMessages";
NSString *const ATInteractionMessageCenterEventLabelRead = @"read";

NSString *const ATMessageCenterDidSkipProfileKey = @"ATMessageCenterDidSkipProfileKey";
NSString *const ATMessageCenterDraftMessageKey = @"ATMessageCenterDraftMessageKey";


@interface ApptentiveMessageCenterViewModel ()

@property (readonly, nonatomic) ApptentiveMessage *lastUserMessage;
@property (readonly, nonatomic) NSURLSession *attachmentDownloadSession;
@property (readonly, nonatomic) NSMutableDictionary<NSValue *, NSIndexPath *> *taskIndexPaths;
@property (strong, nonatomic) ApptentiveMessage *contextMessage;

@end


@implementation ApptentiveMessageCenterViewModel

- (instancetype)initWithInteraction:(ApptentiveInteraction *)interaction messageManager:(ApptentiveMessageManager *)messageManager {
	if ((self = [super init])) {
		_interaction = interaction;
		_messageManager = messageManager;
		messageManager.delegate = self;

		_dateFormatter = [[NSDateFormatter alloc] init];
		_dateFormatter.dateStyle = NSDateFormatterLongStyle;
		_dateFormatter.timeStyle = NSDateFormatterNoStyle;

		_attachmentDownloadSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
		_taskIndexPaths = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)dealloc {
	// TODO: get resume data from cancelled downloads and use it
	[self.attachmentDownloadSession invalidateAndCancel];

	self.messageManager.delegate = nil;
}

- (void)start {
	[[Apptentive sharedConnection].backend messageCenterEnteredForeground];

	if (self.contextMessageBody) {
		self.contextMessage = [[ApptentiveMessage alloc] initWithBody:self.contextMessageBody attachments:@[] senderIdentifier:self.messageManager.localUserIdentifier automated:YES customData:nil];
		[self.contextMessage updateWithLocalIdentifier:@"context-message"];

		[self.messageManager appendMessage:self.contextMessage];
	}
}

- (void)stop {
	if (self.contextMessage) {
		[self.messageManager removeMessage:self.contextMessage];
	}

	[[Apptentive sharedConnection].backend messageCenterLeftForeground];
}

#pragma mark - Message center view controller support

- (id<ApptentiveStyle>)styleSheet {
	return Apptentive.shared.style;
}

- (NSString *)title {
	return self.interaction.configuration[@"title"];
}

- (NSString *)branding {
	return self.interaction.configuration[@"branding"];
}

#pragma mark - Composer

- (NSString *)composerTitle {
	return self.interaction.configuration[@"composer"][@"title"];
}

- (NSString *)composerPlaceholderText {
	return self.interaction.configuration[@"composer"][@"hint_text"];
}

- (NSString *)composerSendButtonTitle {
	return self.interaction.configuration[@"composer"][@"send_button"];
}

- (NSString *)composerCloseConfirmBody {
	return self.interaction.configuration[@"composer"][@"close_confirm_body"];
}

- (NSString *)composerCloseDiscardButtonTitle {
	return self.interaction.configuration[@"composer"][@"close_discard_button"];
}

- (NSString *)composerCloseCancelButtonTitle {
	return self.interaction.configuration[@"composer"][@"close_cancel_button"];
}

#pragma mark - Greeting

- (NSString *)greetingTitle {
	return self.interaction.configuration[@"greeting"][@"title"];
}

- (NSString *)greetingBody {
	return self.interaction.configuration[@"greeting"][@"body"];
}

- (NSURL *)greetingImageURL {
	NSString *URLString = self.interaction.configuration[@"greeting"][@"image_url"];

	return (URLString.length > 0) ? [NSURL URLWithString:URLString] : nil;
}

#pragma mark - Status

- (NSString *)statusBody {
	return self.interaction.configuration[@"status"][@"body"];
}

#pragma mark - Context / Automated Message

- (NSString *)contextMessageBody {
	return self.interaction.configuration[@"automated_message"][@"body"];
}

#pragma mark - Error Messages

- (NSString *)HTTPErrorBody {
	return self.interaction.configuration[@"error_messages"][@"http_error_body"];
}

- (NSString *)networkErrorBody {
	return self.interaction.configuration[@"error_messages"][@"network_error_body"];
}

#pragma mark - Profile

- (BOOL)profileRequested {
	return [self.interaction.configuration[@"profile"][@"request"] boolValue];
}

- (BOOL)profileRequired {
	return [self.interaction.configuration[@"profile"][@"require"] boolValue];
}

- (NSString *)personName {
	return Apptentive.shared.backend.conversationManager.activeConversation.person.name;
}

- (NSString *)personEmailAddress {
	return Apptentive.shared.backend.conversationManager.activeConversation.person.emailAddress;
}

#pragma mark - Profile (Initial)

- (NSString *)profileInitialTitle {
	return self.interaction.configuration[@"profile"][@"initial"][@"title"];
}

- (NSString *)profileInitialNamePlaceholder {
	return self.interaction.configuration[@"profile"][@"initial"][@"name_hint"];
}

- (NSString *)profileInitialEmailPlaceholder {
	return self.interaction.configuration[@"profile"][@"initial"][@"email_hint"];
}

- (NSString *)profileInitialSkipButtonTitle {
	return self.interaction.configuration[@"profile"][@"initial"][@"skip_button"];
}

- (NSString *)profileInitialSaveButtonTitle {
	return self.interaction.configuration[@"profile"][@"initial"][@"save_button"];
}

- (NSString *)profileInitialEmailExplanation {
	return self.interaction.configuration[@"profile"][@"initial"][@"email_explanation"];
}

#pragma mark - Profile (Edit)

- (NSString *)profileEditTitle {
	return self.interaction.configuration[@"profile"][@"edit"][@"title"];
}

- (NSString *)profileEditNamePlaceholder {
	return self.interaction.configuration[@"profile"][@"edit"][@"name_hint"];
}

- (NSString *)profileEditEmailPlaceholder {
	return self.interaction.configuration[@"profile"][@"edit"][@"email_hint"];
}

- (NSString *)profileEditSkipButtonTitle {
	return self.interaction.configuration[@"profile"][@"edit"][@"skip_button"];
}

- (NSString *)profileEditSaveButtonTitle {
	return self.interaction.configuration[@"profile"][@"edit"][@"save_button"];
}

- (BOOL)hasNonContextMessages {
	if (self.numberOfMessageGroups == 0 || [self numberOfMessagesInGroup:0] == 0) {
		return NO;
	} else if (self.numberOfMessageGroups == 1) {
		return (![self messageAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].automated);
	} else {
		return YES;
	}
}

- (NSInteger)numberOfMessageGroups {
	return [self.messageManager numberOfMessages];
}

- (NSInteger)numberOfMessagesInGroup:(NSInteger)groupIndex {
	return 1;
}

- (ATMessageCenterMessageType)cellTypeAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveMessage *message = [self messageAtIndexPath:indexPath];

	if (message.automated) {
		return ATMessageCenterMessageTypeContextMessage;
	} else if (![self messageSentByLocalUser:message]) {
		if (message.attachments.count) {
			return ATMessageCenterMessageTypeCompoundReply;
		} else {
			return ATMessageCenterMessageTypeReply;
		}
	} else {
		if (message.attachments.count) {
			return ATMessageCenterMessageTypeCompoundMessage;
		} else {
			return ATMessageCenterMessageTypeMessage;
		}
	}
}

- (NSString *)textOfMessageAtIndexPath:(NSIndexPath *)indexPath {
	return [self messageAtIndexPath:indexPath].body;
}

- (NSString *)titleForHeaderInSection:(NSInteger)index {
	return [self.dateFormatter stringFromDate:[self dateOfMessageGroupAtIndex:index]];
}

- (NSDate *)dateOfMessageGroupAtIndex:(NSInteger)index {
	if ([self numberOfMessagesInGroup:index] > 0) {
		ApptentiveMessage *message = [self messageAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:index]];

		return message.sentDate;
	} else {
		return nil;
	}
}

- (ATMessageCenterMessageStatus)statusOfMessageAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveMessage *message = [self messageAtIndexPath:indexPath];

	switch (message.state) {
		case ApptentiveMessageStateFailedToSend:
			return ATMessageCenterMessageStatusFailed;
		case ApptentiveMessageStateWaiting:
		case ApptentiveMessageStateSending:
			return ATMessageCenterMessageStatusSending;
		case ApptentiveMessageStateSent:
			if (message == self.lastUserMessage)
				return ATMessageCenterMessageStatusSent;
		default:
			return ATMessageCenterMessageStatusHidden;
	}
}

- (BOOL)shouldShowDateForMessageGroupAtIndex:(NSInteger)index {
	if (index == 0) {
		return YES;
	} else {
		NSDate *previousDate = [self dateOfMessageGroupAtIndex:index - 1];
		NSDate *currentDate = [self dateOfMessageGroupAtIndex:index];

		return ![[self.dateFormatter stringFromDate:previousDate] isEqualToString:[self.dateFormatter stringFromDate:currentDate]];
	}
}

- (NSString *)senderOfMessageAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveMessage *message = [self messageAtIndexPath:indexPath];
	return message.sender.name;
}

- (NSURL *)imageURLOfSenderAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveMessage *message = [self messageAtIndexPath:indexPath];
	if (message.sender.profilePhotoURL) {
		return message.sender.profilePhotoURL;
	} else {
		return nil;
	}
}

- (BOOL)messageSentByLocalUser:(ApptentiveMessage *)message {
	return [message.sender.identifier isEqualToString:self.messageManager.localUserIdentifier];
}

- (void)markAsReadMessageAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveMessage *message = [self messageAtIndexPath:indexPath];

	if (message.identifier && ![self messageSentByLocalUser:message]) {
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

		if (message.identifier) {
			[userInfo setObject:message.identifier forKey:@"message_id"];
		}

		[userInfo setObject:@"CompoundMessage" forKey:@"message_type"];

		[self.interaction engage:ATInteractionMessageCenterEventLabelRead fromViewController:nil userInfo:userInfo];
	}

	if (message.state == ApptentiveMessageStateUnread) {
		message.state = ApptentiveMessageStateRead;
	}
}

- (BOOL)lastMessageIsReply {
	ApptentiveMessage *lastMessage = self.messageManager.messages.lastObject;

	return ![self messageSentByLocalUser:lastMessage];
}

- (ApptentiveMessageState)lastUserMessageState {
	return self.lastUserMessage.state;
}

#pragma mark Attachments

- (NSInteger)numberOfAttachmentsForMessageAtIndex:(NSInteger)index {
	return [self messageAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:index]].attachments.count;
}

- (BOOL)shouldUsePlaceholderForAttachmentAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveAttachment *attachment = [self fileAttachmentAtIndexPath:indexPath];

	return attachment.fileName == nil || !attachment.canCreateThumbnail;
}

- (BOOL)canPreviewAttachmentAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveAttachment *attachment = [self fileAttachmentAtIndexPath:indexPath];

	return attachment.fileName != nil;
}

- (UIImage *)imageForAttachmentAtIndexPath:(NSIndexPath *)indexPath size:(CGSize)size {
	ApptentiveAttachment *attachment = [self fileAttachmentAtIndexPath:indexPath];

	if (attachment.fileName) {
		UIImage *thumbnail = [attachment thumbnailOfSize:size];
		if (thumbnail) {
			return thumbnail;
		}
	}

	// return generic image attachment icon
	return [[ApptentiveUtilities imageNamed:@"at_document"] resizableImageWithCapInsets:UIEdgeInsetsMake(9.0, 2.0, 2.0, 9.0)];
}

- (NSString *)extensionForAttachmentAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveAttachment *attachment = [self fileAttachmentAtIndexPath:indexPath];

	return attachment.extension;
}

- (void)downloadAttachmentAtIndexPath:(NSIndexPath *)indexPath {
	if ([self.taskIndexPaths.allValues containsObject:indexPath]) {
		return;
	}

	ApptentiveAttachment *attachment = [self fileAttachmentAtIndexPath:indexPath];
	if (attachment.fileName != nil || !attachment.remoteURL) {
		ApptentiveLogError(@"Attempting to download attachment with missing or invalid remote URL");
		return;
	}

	NSURLRequest *request = [NSURLRequest requestWithURL:attachment.remoteURL];
	NSURLSessionDownloadTask *task = [self.attachmentDownloadSession downloadTaskWithRequest:request];

	[self.delegate messageCenterViewModel:self attachmentDownloadAtIndexPath:indexPath didProgress:0];

	[self setIndexPath:indexPath forTask:task];
	[task resume];
}

- (id<QLPreviewControllerDataSource>)previewDataSourceAtIndex:(NSInteger)index {
	return [self messageAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:index]];
}

#pragma mark - URL session delegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
	NSIndexPath *attachmentIndexPath = [self indexPathForTask:downloadTask];
	[self removeTask:downloadTask];

	NSURL *finalLocation = [self fileAttachmentAtIndexPath:attachmentIndexPath].permanentLocation;

	// -beginMoveToStorageFrom: must be called on this (background) thread.
	NSError *error;
	if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:finalLocation error:&error]) {
		ApptentiveLogError(@"Unable to move attachment to final location: %@", error);
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		// -completeMoveToStorageFor: must be called on main thread.
		[[self fileAttachmentAtIndexPath:attachmentIndexPath] completeMoveToStorageFor:finalLocation];
		[self.delegate messageCenterViewModel:self didLoadAttachmentThumbnailAtIndexPath:attachmentIndexPath];
	});
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
	NSIndexPath *attachmentIndexPath = [self indexPathForTask:downloadTask];

	dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate messageCenterViewModel:self attachmentDownloadAtIndexPath:attachmentIndexPath didProgress:(double) totalBytesWritten / (double) totalBytesExpectedToWrite];
	});
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
	if (error == nil) return;

	NSIndexPath *attachmentIndexPath = [self indexPathForTask:task];
	[self removeTask:task];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate messageCenterViewModel:self didFailToLoadAttachmentThumbnailAtIndexPath:attachmentIndexPath error:error];
	});
}

#pragma mark - Message Manager delegate

- (void)messageManagerWillBeginUpdates:(ApptentiveMessageManager *)manager {
	[self.delegate viewModelWillChangeContent:self];
}

- (void)messageManagerDidEndUpdates:(ApptentiveMessageManager *)manager {
	[self.delegate viewModelDidChangeContent:self];
}

- (void)messageManager:(ApptentiveMessageManager *)manager didInsertMessage:(ApptentiveMessage *)message atIndex:(NSInteger)index {
	[self.delegate messageCenterViewModel:self didInsertMessageAtIndex:index];
}

- (void)messageManager:(ApptentiveMessageManager *)manager didUpdateMessage:(ApptentiveMessage *)message atIndex:(NSInteger)index {
	[self.delegate messageCenterViewModel:self didUpdateMessageAtIndex:index];
}

- (void)messageManager:(ApptentiveMessageManager *)manager didDeleteMessage:(ApptentiveMessage *)message atIndex:(NSInteger)index {
	[self.delegate messageCenterViewModel:self didDeleteMessageAtIndex:index];
}

- (void)messageManager:(ApptentiveMessageManager *)manager messageSendProgressDidUpdate:(float)progress {
	[self.delegate messageCenterViewModel:self messageProgressDidChange:progress];
}

#pragma mark - Misc

- (void)sendMessage:(NSString *)messageText withAttachments:(NSArray *)attachments {
	if (self.contextMessage) {
		[self.messageManager enqueueMessageForSending:self.contextMessage];
		self.contextMessage = nil;
	}

	ApptentiveMessage *message = [[ApptentiveMessage alloc] initWithBody:messageText attachments:attachments senderIdentifier:self.messageManager.localUserIdentifier automated:NO customData:Apptentive.shared.backend.currentCustomData];

	[self.messageManager sendMessage:message];

	Apptentive.shared.backend.currentCustomData = nil;
}

- (void)setPersonName:(NSString *)name emailAddress:(NSString *)emailAddress {
	Apptentive.shared.backend.conversationManager.activeConversation.person.name = name;
	Apptentive.shared.backend.conversationManager.activeConversation.person.emailAddress = emailAddress;
}

- (BOOL)networkIsReachable {
	return [[ApptentiveReachability sharedReachability] currentNetworkStatus] != ApptentiveNetworkNotReachable;
}

- (BOOL)didSkipProfile {
	return [[Apptentive.shared.backend.conversationManager.activeConversation.userInfo objectForKey:ATMessageCenterDidSkipProfileKey] boolValue];
}

- (void)setDidSkipProfile:(BOOL)didSkipProfile {
	[Apptentive.shared.backend.conversationManager.activeConversation setUserInfo:@(didSkipProfile) forKey:ATMessageCenterDidSkipProfileKey];
}

- (NSString *)draftMessage {
	return Apptentive.shared.backend.conversationManager.activeConversation.userInfo[ATMessageCenterDraftMessageKey];
}

- (void)setDraftMessage:(NSString *)draftMessage {
	if (draftMessage) {
		[Apptentive.shared.backend.conversationManager.activeConversation setUserInfo:draftMessage forKey:ATMessageCenterDraftMessageKey];
	} else {
		[Apptentive.shared.backend.conversationManager.activeConversation removeUserInfoForKey:ATMessageCenterDraftMessageKey];
	}
}

#pragma mark - Private

- (NSIndexPath *)indexPathForTask:(NSURLSessionTask *)task {
	return [self.taskIndexPaths objectForKey:[NSValue valueWithNonretainedObject:task]];
}

- (void)setIndexPath:(NSIndexPath *)indexPath forTask:(NSURLSessionTask *)task {
	[self.taskIndexPaths setObject:indexPath forKey:[NSValue valueWithNonretainedObject:task]];
}

- (void)removeTask:(NSURLSessionTask *)task {
	[self.taskIndexPaths removeObjectForKey:[NSValue valueWithNonretainedObject:task]];
}

// indexPath.section refers to the message index (table view section), indexPath.row refers to the attachment index.
- (ApptentiveAttachment *)fileAttachmentAtIndexPath:(NSIndexPath *)indexPath {
	ApptentiveMessage *message = [self messageAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:indexPath.section]];
	return [message.attachments objectAtIndex:indexPath.row];
}

- (ApptentiveMessage *)messageAtIndexPath:(NSIndexPath *)indexPath {
	return [self.messageManager.messages objectAtIndex:indexPath.section];
}

- (ApptentiveMessage *)lastUserMessage {
	for (ApptentiveMessage *message in self.messageManager.messages.reverseObjectEnumerator) {
		if ([self messageSentByLocalUser:message]) {
			return message;
		}
	}

	return nil;
}

@end
