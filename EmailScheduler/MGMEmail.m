//
//  MGMEmail.m
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

#import "MGMEmail.h"
#import "MGMController.h"
#import <MailCore/MailCore.h>

@implementation MGMEmail
- (void)setEmailAddress:(NSString *)email {
	[emailAddress autorelease];
	emailAddress = [email retain];
}
- (NSString *)eamilAddress {
	return emailAddress;
}
- (MCOSMTPSession *)session {
	MGMController *controller = [MGMController sharedController];
	MCOSMTPSession *smtpSession = [[[MCOSMTPSession alloc] init] autorelease];
	smtpSession.hostname = @"smtp.gmail.com";
	smtpSession.port = 465;
	smtpSession.username = emailAddress;
	smtpSession.password = [[controller emailAddresses] objectForKey:emailAddress];
	smtpSession.authType = MCOAuthTypeSASLPlain;
	smtpSession.connectionType = MCOConnectionTypeTLS;
	return smtpSession;
}
- (MCOIMAPSession *)imapSession {
	MGMController *controller = [MGMController sharedController];
	MCOIMAPSession *session = [[[MCOIMAPSession alloc] init] autorelease];
	session.hostname = @"imap.gmail.com";
	session.port = 993;
	session.username = emailAddress;
	session.password = [[controller emailAddresses] objectForKey:emailAddress];
	session.connectionType = MCOConnectionTypeTLS;
	return session;
}

- (void)setRFC822Data:(NSData *)data {
	[rfc822Data autorelease];
	rfc822Data = [data retain];
}
- (NSData *)rfc822Data {
	return rfc822Data;
}
@end
