//
//  MGMHTTPClientClass.m
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

#import "MGMHTTPClientClass.h"
#import "MGMController.h"
#import "MGMJSON.h"
#import "MGMEmail.h"
#import <MailCore/MailCore.h>

@implementation MGMHTTPClientClass
- (void)replyToClient {
	MGMController *controller = [MGMController sharedController];
	NSString *user = [self requestWithName:@"user"];
	NSString *fromEmail = [self requestWithName:@"from"];
	NSString *fromName = [self requestWithName:@"from-name"];
	NSString *toEmail = [self requestWithName:@"to"];
	NSString *toName = [self requestWithName:@"to-name"];
	NSString *subject = [self requestWithName:@"subject"];
	NSString *message = [self requestWithName:@"message"];
	NSString *messageHTML = [self requestWithName:@"message-html"];
	NSString *additionalHeadersString = [self requestWithName:@"headers"];
	
	if (fromEmail!=nil && ![fromEmail isEqual:@""] && toEmail!=nil && ![toEmail isEqual:@""] && subject!=nil && ![subject isEqual:@""] && message!=nil && ![message isEqual:@""]) {
		if ([[controller emailAddresses] objectForKey:(user!=nil && ![user isEqual:@""] ? user : fromEmail)]==nil) {
			NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"success", [NSString stringWithFormat:@"No handler for email address %@", fromEmail], @"error", nil];
			[self print:[response JSONValue]];
		} else {
			MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
			MCOAddress *from = [MCOAddress addressWithDisplayName:fromName mailbox:fromEmail];
			MCOAddress *to = [MCOAddress addressWithDisplayName:toName mailbox:toEmail];
			[[builder header] setFrom:from];
			[[builder header] setTo:@[to]];
			[[builder header] setSubject:subject];
			[[builder header] setUserAgent:@"MGMEmail/0.1"];
			if (messageHTML!=nil && ![messageHTML isEqual:@""]) {
				[builder setHTMLBody:messageHTML];
			}
			[builder setTextBody:message];
			
			NSDictionary *additionalHeaders = (NSDictionary *)[additionalHeadersString parseJSON];
			if (additionalHeaders!=nil && [additionalHeaders isKindOfClass:[NSDictionary class]]) {
				NSArray *keys = [additionalHeaders allKeys];
				for (unsigned int i=0; i<[keys count]; i++) {
					[[builder header] setExtraHeaderValue:[additionalHeaders objectForKey:[keys objectAtIndex:i]] forName:[keys objectAtIndex:i]];
				}
			}
			
			NSData *rfc822Data = [builder data];
			MGMEmail *email = [[MGMEmail new] autorelease];
			[email setEmailAddress:(user!=nil && ![user isEqual:@""] ? user : fromEmail)];
			[email setRFC822Data:rfc822Data];
			[controller addToQueue:email];
			
			NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"success", nil];
			[self print:[response JSONValue]];
		}
	} else {
		NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"success", @"Invalid input", @"error", nil];
		[self print:[response JSONValue]];
	}
	
	[super replyToClient];
}
@end
