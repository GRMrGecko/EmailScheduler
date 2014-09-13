//
//  MGMHTTPClient.h
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
#import "MGMHTTPDefines.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AsyncSocket, MGMHTTPServer, MGMHTTPResponse;

extern NSString * const MGMClientDisconnectedNotification;

extern NSString * const MGMRPath;
extern NSString * const MGMREncoding;
extern NSString * const MGMGatewayInterface;
extern NSString * const MGMContentType;
extern NSString * const MGMContentLength;
extern NSString * const MGMServerProtocol;
extern NSString * const MGMRequestMethod;
extern NSString * const MGMRequestURI;
extern NSString * const MGMScriptName;
extern NSString * const MGMRemotePort;
extern NSString * const MGMServerAddress;
extern NSString * const MGMServerPort;
extern NSString * const MGMQueryString;
extern NSString * const MGMCookies;
extern NSString * const MGMPCRemoteAddress;
extern NSString * const MGMRemoteAddress;
extern NSString * const MGMClientIP;
extern NSString * const MGMForwardedFor;
extern NSString * const MGMConnection;
extern NSString * const MGMServerHeader;
extern NSString * const MGMAcceptRanges;
extern NSString * const MGMDate;

@interface MGMHTTPClient : NSObject {
	AsyncSocket *clientSocket;
	MGMHTTPServer *server;
#if MGMHTTPThreaded
	NSRunLoop *threadRunLoop;
	NSThread *thread;
#endif
	
	CFHTTPMessageRef clientRequest;
	NSDictionary *requestHeaders;
	int numHeaders;
	NSMutableDictionary *headers;
	NSDictionary *getInputs;
	NSDictionary *postInputs;
	NSData *postData;
	NSMutableDictionary *cookies;
	NSMutableArray *cookiesToPost;
	NSDictionary *filesUploaded;
	BOOL headersPosted;
	
	//File Upload
	NSString *fBoundary;
	char fPutback[1024];
	int fReadPosition;
	int fWritePosition;
	int fOffset;
	BOOL isMultipart;
	
	NSString *httpVersion;
	
	MGMHTTPResponse *httpResponse;
	BOOL isBufferBased;
	NSMutableData *responseBuffer;
	BOOL isBufferSending;
	
	NSMutableArray *ranges;
	NSMutableArray *rangesHeaders;
	NSString *rangesBoundry;
	int rangeIndex;
	
	MGMInteger requestContentLengthReceived;
	
	BOOL isKeepAlive;
	BOOL clientDisconnected;
	BOOL disconnecting;
}
- (AsyncSocket *)clientSocket;
#if MGMHTTPThreaded
- (NSRunLoop *)runLoop;
#endif

+ (id)clientWithSocket:(AsyncSocket *)theSocket server:(MGMHTTPServer *)theServer;
- (id)initWithSocket:(AsyncSocket *)theSocket server:(MGMHTTPServer *)theServer;

- (void)setHTTPVersion:(NSString *)theVersion;

- (void)setHTTPResponse:(MGMHTTPResponse *)theResponse;

- (void)sendErrorNum:(int)theErrorNum description:(NSString *)theDescription returnHTML:(BOOL)hasHTML;

- (NSString *)requestHeaderWithName:(NSString *)name;
- (NSDictionary *)requestHeaders;
- (MGMInteger)contentLength;

- (BOOL)setHeader:(NSString *)header withName:(NSString *)name;
- (BOOL)deleteHeaderWithName:(NSString *)name;
- (NSString *)headerWithName:(NSString *)name;
- (NSDictionary *)headers;

- (BOOL)setCookie:(NSString *)cookie forName:(NSString *)name expires:(NSDate *)expires domain:(NSString *)domain path:(NSString *)path secure:(BOOL)secure httpOnly:(BOOL)httpOnly;
- (BOOL)deleteCookieWithName:(NSString *)name withDomain:(NSString *)domain  withPath:(NSString *)path secure:(BOOL)secure  httpOnly:(BOOL)httpOnly;
- (NSString *)cookieWithName:(NSString *)name;
- (NSDictionary *)cookies;

- (NSString *)getInputWithName:(NSString *)name;
- (NSDictionary *)getInputs;
- (NSString *)postInputWithName:(NSString *)name;
- (NSDictionary *)postInputs;

- (NSString *)requestWithName:(NSString *)name;
- (NSDictionary *)requests;

- (NSDictionary *)fileWithName:(NSString *)Name;
- (NSDictionary *)filesUploaded;

- (NSString *)userIP;

- (NSArray *)sslCertificates;
- (void)replyToClient;

- (void)printData:(NSData *)data;
- (void)print:(NSString *)format, ...;
- (void)printError:(NSString *)format, ...;
- (void)flush;

- (void)disconnect;
@end