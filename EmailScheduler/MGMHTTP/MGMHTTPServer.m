//
//  MGMHTTPServer.m
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

#import "MGMHTTPServer.h"
#import "MGMHTTPClient.h"
#import "AsyncSocket.h"

@implementation MGMHTTPServer
+ (id)serverWithPort:(int)thePort delegate:(id)theDelegate {
	return [[[self alloc] initServerWithPort:thePort delegate:theDelegate] autorelease];
}
- (id)initServerWithPort:(int)thePort delegate:(id)theDelegate {
	if (self = [super init]) {
		httpSocket = [[AsyncSocket alloc] initWithDelegate:self];
		port = thePort;
		delegate = [theDelegate retain];
		clientClass = [MGMHTTPClient class];
		
		[self setBonjourDomain:@"local."];
		[self setBonjourType:@"_http._tcp."];
		[self setBonjourName:@""];
		[self setBonjourEnabled:NO];
		clientConnections = [NSMutableArray new];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientDisconected:) name:MGMClientDisconnectedNotification object:nil];
	}
	return self;
}
- (void)dealloc {
	[httpSocket disconnect];
    [httpSocket release];
    [clientConnections release];
    [bonjour release];
    [bonjourDomain release];
    [bonjourType release];
    [bonjourName release];
	[super dealloc];
}

- (AsyncSocket *)httpSocket {
	return httpSocket;
}
- (NSArray *)clientConnections {
	return clientConnections;
}

- (id)delegate {
	return delegate;
}
- (void)setDelegate:(id)theDelegate {
	delegate = theDelegate;
}

- (int)port {
	return port;
}
- (void)setPort:(int)thePort {
	port = thePort;
}

- (NSString *)bonjourDomain {
    return bonjourDomain;
}
- (void)setBonjourDomain:(NSString *)theDomain {
	[bonjourDomain release];
	bonjourDomain = [theDomain retain];
}

- (NSString *)bonjourType {
    return bonjourType;
}
- (void)setBonjourType:(NSString *)theType {
	[bonjourType release];
	bonjourType = [theType retain];
}

- (NSString *)bonjourName {
    return bonjourName;
}
- (NSString *)bonjourPublishedName {
	return [bonjour name];
}
- (void)setBonjourName:(NSString *)theName {
	[bonjourName release];
	bonjourName = [theName retain];
}

- (BOOL)isBonjourEnabled {
	return bonjourEnabled;
}
- (void)setBonjourEnabled:(BOOL)isEnabled {
	bonjourEnabled = isEnabled;
	if (bonjourEnabled) {
		if (bonjour==nil && [httpSocket isConnected]) {
			bonjour = [[NSNetService alloc] initWithDomain:bonjourDomain type:bonjourType name:bonjourName port:port];
			[bonjour setDelegate:self];
			[bonjour publish];
		}
	} else {
		if (bonjour!=nil) {
			[bonjour stop];
			[bonjour release];
			bonjour = nil;
		}
	}
}

- (Class)httpClientClass {
	return clientClass;
}
- (void)setHTTPClientClass:(Class)theClientClass {
	clientClass = theClientClass;
}

- (BOOL)start:(NSError **)error {
	BOOL success = [httpSocket acceptOnPort:port error:error];
	if (success) {
		port = [httpSocket localPort];
#if MGMHTTPDebug
		NSLog(@"Started server on port %d", port);
#endif
		if (bonjourEnabled) {
			bonjour = [[NSNetService alloc] initWithDomain:bonjourDomain type:bonjourType name:bonjourName port:port];
			[bonjour setDelegate:self];
			[bonjour publish];
		}
	} else {
		NSLog(@"Failed to start Server: %@", *error);
	}
	return success;
}
- (void)stop {
	if(bonjour!=nil) {
		[bonjour stop];
		[bonjour release];
		bonjour = nil;
	}
	[httpSocket disconnect];
	[clientConnections removeAllObjects];
}

- (void)netServiceDidPublish:(NSNetService *)sender {
#if MGMHTTPDebug
	NSLog(@"Bonjour Published domain:%@ type:%@ name:%@", [sender domain], [sender type], [sender name]);
#endif
}
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
	NSLog(@"Failed to Publish Bonjour domain:%@ type:%@ name:%@ error:%@", [sender domain], [sender type], [sender name], errorDict);
}

- (int)clientConnectionCount {
	int count;
	@synchronized(clientConnections) {
		count = (int)[clientConnections count];
	}
	return count;
}
#if MGMHTTPThreaded
- (NSRunLoop *)onSocket:(AsyncSocket *)sock wantsRunLoopForNewSocket:(AsyncSocket *)newSocket {
	@synchronized(clientConnections) {
		for (unsigned int i=0; i<[clientConnections count]; i++) {
			if ([[[clientConnections objectAtIndex:i] clientSocket] isEqual:newSocket])
				return [[clientConnections objectAtIndex:i] runLoop];
		}
	}
	return [NSRunLoop currentRunLoop];
}
#endif
- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket {
	if (clientClass==[MGMHTTPClient class]) {
		if ([delegate respondsToSelector:@selector(httpClientClass)]) {
			clientClass = [delegate httpClientClass];
		}
	}
	MGMHTTPClient *theClient = [clientClass clientWithSocket:newSocket server:self];
	@synchronized(clientConnections) {
		[clientConnections addObject:theClient];
	}
}
- (void)clientDisconected:(NSNotification *)theNotification {
	@synchronized(clientConnections) {
		[clientConnections removeObject:[theNotification object]];
	}
}
@end