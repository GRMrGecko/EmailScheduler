//
//  MGMHTTPServer.h
//  MGMHTTP
//
//  Created by Mr. Gecko on 8/14/13.
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

#import <Foundation/Foundation.h>

#define MGMHTTPDebug 0
#define MGMHTTPThreaded 0

@class AsyncSocket, MGMHTTPClient, MGMHTTPResponse;

@protocol MGMHTTPServerDelegate
- (Class)httpClientClass;
- (MGMHTTPResponse *)httpResponseForClient:(MGMHTTPClient *)theClient;
- (void)finnishedSendingResponse:(MGMHTTPClient *)theClient;
@end

@interface MGMHTTPServer : NSObject
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= 1060)
	<NSNetServiceDelegate>
#endif
{
	AsyncSocket *httpSocket;
	
	NSObject<MGMHTTPServerDelegate> *delegate;
	Class clientClass;
	NSMutableArray *clientConnections;
	int port;
	
	NSNetService *bonjour;
	NSString *bonjourDomain;
	NSString *bonjourType;
	NSString *bonjourName;
	BOOL bonjourEnabled;
}
+ (id)serverWithPort:(int)thePort delegate:(id)theDelegate;
- (id)initServerWithPort:(int)thePort delegate:(id)theDelegate;

- (AsyncSocket *)httpSocket;
- (NSArray *)clientConnections;

- (id)delegate;
- (void)setDelegate:(id)theDelegate;

- (int)port;
- (void)setPort:(int)thePort;

- (NSString *)bonjourDomain;
- (void)setBonjourDomain:(NSString *)theDomain;

- (NSString *)bonjourType;
- (void)setBonjourType:(NSString *)theType;

- (NSString *)bonjourName;
- (NSString *)bonjourPublishedName;
- (void)setBonjourName:(NSString *)theName;

- (BOOL)isBonjourEnabled;
- (void)setBonjourEnabled:(BOOL)isEnabled;

- (Class)httpClientClass;
- (void)setHTTPClientClass:(Class)theClientClass;

- (BOOL)start:(NSError **)error;
- (void)stop;
@end