//
//  MGMController.m
//  EmailScheduler
//
//  Created by James Coleman on 9/13/14.
//  Copyright (c) 2014 Mr. Gecko's Media (James Coleman). http://mrgeckosmedia.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "MGMController.h"
#import "MGMHTTP/MGMHTTPServer.h"
#import "MGMHTTP/MGMHTTPClient.h"
#import "MGMHTTP/MGMHTTPResponse.h"
#import "MGMHTTPClientClass.h"
#import "MGMEmail.h"
#import <MailCore/MailCore.h>

static MGMController *controller;

@implementation MGMController
- (id)init {
	if ((self = [super init])) {
		controller = self;
		server = [[MGMHTTPServer serverWithPort:28001 delegate:self] retain];
		[server setHTTPClientClass:[MGMHTTPClientClass class]];
		NSError *error = nil;
		if (![server start:&error]) {
			NSLog(@"Error: %@", error);
		}
		emailAddresses = [[NSDictionary dictionaryWithObjectsAndKeys:nil] retain];
		
		queue = [NSMutableArray new];
		sendingEmail = NO;
	}
	return self;
}
+ (id)sharedController {
	return controller;
}
- (NSDictionary *)emailAddresses {
	return emailAddresses;
}
- (void)addToQueue:(MGMEmail *)email {
	@synchronized(queue) {
		[queue addObject:email];
		if (!sendingEmail) {
			sendingEmail = YES;
			[NSThread detachNewThreadSelector:@selector(sendNextEmail) toTarget:self withObject:nil];
		}
	}
}
- (void)sendNextEmail {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	MGMEmail *email = nil;
	@synchronized(queue) {
		email = [queue objectAtIndex:0];
	}
	
	MCOSMTPSession *smtpSession = [email session];
	MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData:[email rfc822Data]];
	[sendOperation start:^(NSError *error) {
		if(error) {
			NSLog(@"Error sending email: %@", error);
		} else {
			NSLog(@"Successfully sent email!");
		}
	}];
	
	if ([[email eamilAddress] isEqual:@"password@birdim.com"]) {//Email address to automatically delete email for. Make sure gmail has a filter to move sent email to trash.
		MCOIMAPSession *session = [email imapSession];
		
		MCOIndexSet *uidSet = [MCOIndexSet indexSetWithRange:MCORangeMake(1,UINT64_MAX)];
		MCOIMAPFetchMessagesOperation *fetchOp = [session fetchMessagesByUIDOperationWithFolder:@"[Gmail]/Trash"
																					requestKind:MCOIMAPMessagesRequestKindHeaders
																						   uids:uidSet];
		
		[fetchOp start:^(NSError *err, NSArray *msgs, MCOIndexSet *vanished) {
			for (MCOIMAPMessage *message in msgs) {
				MCOMessageFlag flags = MCOMessageFlagDeleted;
				BOOL deleted = flags & MCOMessageFlagDeleted;
				
				MCOIMAPOperation *op = [session storeFlagsOperationWithFolder:@"[Gmail]/Trash"
																		 uids:[MCOIndexSet indexSetWithIndex:[message gmailThreadID]]
																		 kind:MCOIMAPStoreFlagsRequestKindSet
																		flags:flags];
				[op start:^(NSError * error) {
					if(!error) {
						NSLog(@"Updated flags!");
					} else {
						NSLog(@"Error updating flags: %@", error);
					}
					
					if(deleted) {
						MCOIMAPOperation *deleteOp = [session expungeOperation:@"[Gmail]/Trash"];
						[deleteOp start:^(NSError *error) {
							if(error) {
								NSLog(@"Error expunging folder: %@", error);
							} else {
								NSLog(@"Successfully expunged folder");
							}
						}];
					}
				}];
				
			}
		}];
	}
	
	@synchronized(queue) {
		[queue removeObjectAtIndex:0];
		if ([queue count]!=0) {
			[NSThread detachNewThreadSelector:@selector(sendNextEmail) toTarget:self withObject:nil];
		} else {
			sendingEmail = NO;
		}
	}
	
	[pool drain];
}
@end
