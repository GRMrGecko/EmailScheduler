//
//  MGMHTTPClient.m
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

#import "MGMHTTPClient.h"
#import "MGMHTTPServer.h"
#import "MGMHTTPResponse.h"
#import "MGMHTTPAddons.h"
#import "AsyncSocket.h"

BOOL MGMDisconnectAfterSent = NO;

#if TARGET_OS_IPHONE
int MGMReadChunkSize = (1024 * 128);
#else
int MGMReadChunkSize = (1024 * 512);
#endif

#if TARGET_OS_IPHONE
int MGMPostChunkSize = (1024 * 32);
#else
int MGMPostChunkSize = (1024 * 128);
#endif
int MGMMaxFileSize = (1024 * 1024 * 20);

int MGMReadTimeOut = -1;
int MGMWriteHeaderTimeOut = 30;
int MGMWriteBodyTimeOut = -1;
int MGMWriteErrorTimeOut = 30;

int MGMLimitMaxHeaderLineLength = 8190;
int MGMLimitMaxHeaderLines = 100;
int MGMHTTPBufferLimit = 7000;
int MGMPostMaxLength = 1048576;

enum MGMHTTPTags {
	MGMHTTPRequestHeaderTag = 1,
	MGMHTTPRequestBodyTag,
	MGMHTTPPartialResponseTag,
	MGMHTTPPartialResponseHeaderTag,
	MGMHTTPPartialResponseBodyTag,
	MGMHTTPPartialRangeResponseBodyTag,
	MGMHTTPPartialRangesResponseHeaderTag,
	MGMHTTPBufferResponseBodyTag,
	MGMHTTPBufferResponseBodyFinalTag,
	MGMHTTPResponseTag,
	MGMHTTPFinalResponseTag
};

//Server info
NSString * const MGMHTTPVersion = @"MGMServer/0.1";
NSString * const MGMTmpFileFolder = @"/tmp/mgm/";
NSString * const MGMPropertyFile = @"/Library/Preferences/com.MrGeckosMedia.MGM.plist";


//Dictionary Keys
NSString * const MGMNameKey = @"name";
NSString * const MGMFileNameKey = @"filename";
NSString * const MGMFileSizeKey = @"filesize";
NSString * const MGMFileTypeKey = @"filetype";
NSString * const MGMFilePathKey = @"filepath";
NSString * const MGMCookieKey = @"cookie";
NSString * const MGMExpiresKey = @"expires";
NSString * const MGMDomainKey = @"domain";
NSString * const MGMPathKey = @"path";
NSString * const MGMSecureKey = @"secure";
NSString * const MGMHTTPOnlyKey = @"httpOnly";

//Headers
NSString * const MGMRPath = @"PATH";
NSString * const MGMREncoding = @"__CF_USER_TEXT_ENCODING";
NSString * const MGMGatewayInterface = @"gateway-interface";
NSString * const MGMContentType = @"content-type";
NSString * const MGMContentLength = @"content-length";
NSString * const MGMServerProtocol = @"server-protocol";
NSString * const MGMRequestMethod = @"request-method";
NSString * const MGMRequestURI = @"request-uri";
NSString * const MGMScriptName = @"script-name";
NSString * const MGMRemotePort = @"remote-port";
NSString * const MGMServerAddress = @"server-addr";
NSString * const MGMServerPort = @"server-port";
NSString * const MGMQueryString = @"query-string";
NSString * const MGMCookies = @"cookie";
NSString * const MGMPCRemoteAddress = @"pc-remote-addr";
NSString * const MGMRemoteAddress = @"remote-addr";
NSString * const MGMClientIP = @"client-ip";
NSString * const MGMForwardedFor = @"x-forwarded-for";
NSString * const MGMConnection = @"connection";
NSString * const MGMServerHeader = @"server";
NSString * const MGMAcceptRanges = @"accept-ranges";
NSString * const MGMDate = @"date";

NSString * const MGMClientDisconnectedNotification = @"MGMClientDisconnectedNotification";

#define BAPPEND(ch) \
{ \
	putc(ch, outf); \
	outLen++; \
}

@interface MGMHTTPClient (MGMPrivate)
- (void)sendHTTPResponse;
- (void)cleanConnection:(long)tag;
@end

@implementation MGMHTTPClient
+ (id)clientWithSocket:(AsyncSocket *)theSocket server:(MGMHTTPServer *)theServer {
	return [[[self alloc] initWithSocket:theSocket server:theServer] autorelease];
}
- (id)initWithSocket:(AsyncSocket *)theSocket server:(MGMHTTPServer *)theServer {
	if (self = [super init]) {
		[self setHTTPVersion:(NSString *)kCFHTTPVersion1_1];
		headersPosted = NO;
		isBufferBased = NO;
		
		server = [theServer retain];
		clientRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);
		headers = [NSMutableDictionary new];
		
		clientSocket = [theSocket retain];
		[clientSocket setDelegate:self];
		[clientSocket enablePreBuffering];
		
#if MGMHTTPThreaded
		[NSThread detachNewThreadSelector:@selector(startThread) toTarget:self withObject:nil];
		while (thread==nil) {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, YES);
		}
#endif
	}
	return self;
}
- (void)dealloc {
#if MGMHTTPDebug
	NSLog(@"Release");
#endif
    [clientSocket release];
    [server release];
    [requestHeaders release];
    [headers release];
    [getInputs release];
    [postInputs release];
    [postData release];
    [cookies release];
    [cookiesToPost release];
    [filesUploaded release];
    [fBoundary release];
    [httpVersion release];
    [httpResponse release];
    [responseBuffer release];
    [ranges release];
    [rangesHeaders release];
    [rangesBoundry release];
    CFRelease(clientRequest);
	[super dealloc];
}

- (AsyncSocket *)clientSocket {
	return clientSocket;
}

#if MGMHTTPThreaded
- (void)setRunLoop:(NSRunLoop *)theRunLoop {
	threadRunLoop = [theRunLoop retain];
}
- (NSRunLoop *)runLoop {
	return threadRunLoop;
}
- (void)setThread:(NSThread *)theThread {
	thread = [theThread retain];
}
- (void)startThread {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[self performSelectorOnMainThread:@selector(setRunLoop:) withObject:[NSRunLoop currentRunLoop] waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(setThread:) withObject:[NSThread currentThread] waitUntilDone:YES];
	while (!clientDisconnected) {
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, YES);
		[pool drain];
		pool = [NSAutoreleasePool new];
	}
	[threadRunLoop release];
	threadRunLoop = nil;
	[thread release];
	thread = nil;
	[pool drain];
}
#endif

- (BOOL)parseRanges:(NSString *)theRanges withResponseLength:(MGMInteger)theResponseLength {
	NSRange equalRange = [theRanges rangeOfString:@"="];
	if (equalRange.location==NSNotFound)
		return NO;
	
	NSString *rangeType  = [[theRanges substringToIndex:equalRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *rangeValue = [[theRanges substringFromIndex:equalRange.location+equalRange.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (![[rangeType lowercaseString] isEqualToString:@"bytes"])
		return NO;
	
	NSArray *rangeComponents = [rangeValue componentsSeparatedByString:@","];
	if ([rangeComponents count]==0)
		return NO;
	
	[ranges release];
	ranges = [NSMutableArray new];
	rangeIndex = 0;
	for (int i=0; i<[rangeComponents count]; i++) {
		NSRange dashRange = [[rangeComponents objectAtIndex:i] rangeOfString:@"-"];
		if (dashRange.location == NSNotFound) {
			[ranges addObject:[NSValue valueWithRange:NSMakeRange([[rangeComponents objectAtIndex:i] longValue], 1)]];
		} else {
			MGMInteger r1 = strtol([[[rangeComponents objectAtIndex:i] substringToIndex:dashRange.location] UTF8String], NULL, 0);
			MGMInteger r2 = strtol([[[rangeComponents objectAtIndex:i] substringFromIndex:dashRange.location+dashRange.length] UTF8String], NULL, 0);
			
			if (r2==0)
				r2 = theResponseLength;
			if (r1>r2)
				return NO;
				
			[ranges addObject:[NSValue valueWithRange:NSMakeRange(r1, r2-r1+1)]];
		}
	}
	
	if ([ranges count]==0)
		return NO;
	
	//Check for intercepts
	for (int i=0; i<[ranges count]-1; i++) {
		NSRange range = [[ranges objectAtIndex:i] rangeValue];
		for (int r=i+1; r<[ranges count]; r++) {
			if (NSIntersectionRange(range, [[ranges objectAtIndex:r] rangeValue]).length!=0)
				return NO;
		}
	}
	return YES;
}

- (void)setHTTPVersion:(NSString *)theVersion {
	[httpVersion release];
	httpVersion = [theVersion retain];
}

- (void)setHTTPResponse:(MGMHTTPResponse *)theResponse {
	[httpResponse release];
	httpResponse = [theResponse retain];
}

- (BOOL)supportsMethod:(NSString *)theMethod {
	return [[theMethod lowercaseString] isEqual:@"put"] || [[theMethod lowercaseString] isEqual:@"get"] || [[theMethod lowercaseString] isEqual:@"post"] || [[theMethod lowercaseString] isEqual:@"head"];
}

- (NSString *)getDescriptionForHTTPCode:(int)theCode {
	switch (theCode) {
		case 100:
			return @"Continue";
			break;
		case 101:
			return @"Switching Protocols";
			break;
		case 102:
			return @"Processing";
			break;
		case 200:
			return @"OK";
			break;
		case 201:
			return @"Created";
			break;
		case 202:
			return @"Accepted";
			break;
		case 203:
			return @"Non-Authoritative Information";
			break;
		case 204:
			return @"No Content";
			break;
		case 205:
			return @"Reset Content";
			break;
		case 206:
			return @"Partial Content";
			break;
		case 207:
			return @"Multi-Status";
			break;
		case 208:
			return @"Already Reported";
			break;
		case 226:
			return @"IM Used";
			break;
		case 300:
			return @"Multiple Choices";
			break;
		case 301:
			return @"Moved Permanently";
			break;
		case 302:
			return @"Found";
			break;
		case 303:
			return @"See Other";
			break;
		case 304:
			return @"Not Modified";
			break;
		case 305:
			return @"Use Proxy";
			break;
		case 307:
			return @"Temporary Redirect";
			break;
		case 308:
			return @"Permanent Redirect";
			break;
		case 400:
			return @"Bad Request";
			break;
		case 401:
			return @"Unauthorized";
			break;
		case 402:
			return @"Payment Required";
			break;
		case 403:
			return @"Forbidden";
			break;
		case 404:
			return @"Not Found";
			break;
		case 405:
			return @"Method Not Allowed";
			break;
		case 406:
			return @"Not Acceptable";
			break;
		case 407:
			return @"Proxy Authentication Required";
			break;
		case 408:
			return @"Request Timeout";
			break;
		case 409:
			return @"Conflict";
			break;
		case 410:
			return @"Gone";
			break;
		case 411:
			return @"Length Required";
			break;
		case 412:
			return @"Precondition Failed";
			break;
		case 413:
			return @"Request Entity Too Large";
			break;
		case 414:
			return @"Request-URI Too Long";
			break;
		case 415:
			return @"Unsupported Media Type";
			break;
		case 416:
			return @"Requested Range Not Satisfiable";
			break;
		case 417:
			return @"Expectation Failed";
			break;
		case 418:
			return @"I'm a teapot";
			break;
		case 420:
			return @"Enhance Your Calm";
			break;
		case 422:
			return @"Unprocessable Entity";
			break;
		case 423:
			return @"Locked";
			break;
		case 425:
			return @"Unordered Collection";
			break;
		case 426:
			return @"Upgrade Required";
			break;
		case 428:
			return @"Precondition Required";
			break;
		case 429:
			return @"Too Many Requests";
			break;
		case 431:
			return @"Request Header Fields Too Large";
			break;
		case 444:
			return @"No Response";
			break;
		case 451:
			return @"Unavailable For Legal Reasons";
			break;
		case 499:
			return @"Client Closed Request";
			break;
		case 500:
			return @"Internal Server Error";
			break;
		case 501:
			return @"Not Implemented";
			break;
		case 502:
			return @"Bad Gateway";
			break;
		case 503:
			return @"Service Unavailable";
			break;
		case 504:
			return @"Gateway Timeout";
			break;
		case 505:
			return @"HTTP Version Not Supported";
			break;
		case 506:
			return @"Variant Also Negotiates";
			break;
		case 507:
			return @"Insufficient Storage";
			break;
		case 508:
			return @"Loop Detected";
			break;
		case 509:
			return @"Bandwidth Limit Exceeded";
			break;
		case 510:
			return @"Not Extended";
			break;
		case 511:
			return @"Network Authentication Required";
			break;
		case 598:
			return @"Network read timeout error";
			break;
		case 599:
			return @"Network connect timeout error";
			break;
		default:
			return @"Unknown Code";
			break;
	}
}

- (NSMutableData *)getResponseWithCode:(int)theCode description:(NSString *)theDescription {
	NSString *description;
	if (theDescription!=nil) {
		description = theDescription;
	} else {
		description = [self getDescriptionForHTTPCode:theCode];
	}
	
	NSMutableData *response = [NSMutableData data];
	[response appendData:[[NSString stringWithFormat:@"%@ %d %@\r\n", httpVersion, theCode, description] dataUsingEncoding:NSUTF8StringEncoding]];
	
	if (!headersPosted) {
		if ([headers objectForKey:MGMServerHeader]==nil)
			[self setHeader:MGMHTTPVersion withName:MGMServerHeader];
		if (MGMDisconnectAfterSent && [headers objectForKey:MGMConnection]==nil)
			[self setHeader:@"close" withName:MGMConnection];
		if ([headers objectForKey:MGMAcceptRanges]==nil)
			[self setHeader:@"bytes" withName:MGMAcceptRanges];
		if ([headers objectForKey:MGMDate]==nil)
			[self setHeader:[NSString stringWithDate:[NSDate date]] withName:MGMDate];
		if ([headers objectForKey:MGMContentType]==nil)
			[self setHeader:@"text/html" withName:MGMContentType];
		headersPosted = YES;
	}
	
	NSMutableString *headerString = [NSMutableString string];
	if (cookiesToPost!=nil) {
		for (int i=0; i<[cookiesToPost count]; i++) {
			NSDictionary *cookie = [cookiesToPost objectAtIndex:i];
			
			[headerString appendFormat:@"Set-Cookie: %@=%@", [[cookie objectForKey:MGMNameKey] replace:@" " with:@"+"], [[cookie objectForKey:MGMCookieKey] replace:@" " with:@"+"]];
			if ([cookie objectForKey:MGMExpiresKey])
				[headerString appendFormat:@"; expires=%@", [NSString stringWithDate:[cookie objectForKey:MGMExpiresKey]]];
			if ([cookie objectForKey:MGMDomainKey])
				[headerString appendFormat:@"; domain=%@", [[cookie objectForKey:MGMDomainKey] replace:@" " with:@"+"]];
			if ([cookie objectForKey:MGMPathKey])
				[headerString appendFormat:@"; path=%@", [[cookie objectForKey:MGMPathKey] replace:@" " with:@"+"]];
			if ([[cookie objectForKey:MGMSecureKey] boolValue])
				[headerString appendString:@"; secure"];
			if ([[cookie objectForKey:MGMHTTPOnlyKey] boolValue])
				[headerString appendString:@"; httponly"];
			[headerString appendString:@"\r\n"];
		}
	}
	
	NSArray *keys = [headers allKeys];
	for (int i=0; i<[keys count]; i++) {
		NSArray *nameA = [[keys objectAtIndex:i] componentsSeparatedByString:@"-"];
		NSMutableString *name = [NSMutableString string];
		for (int d=0; d<[nameA count]; d++) {
			if (d==0) {
				[name appendString:[[nameA objectAtIndex:d] capitalizedString]];
			} else {
				[name appendFormat:@"-%@", [[nameA objectAtIndex:d] capitalizedString]];
			}
		}
		[headerString appendFormat:@"%@: %@\r\n", name, [headers objectForKey:[keys objectAtIndex:i]]];
	}
	[response appendData:[headerString dataUsingEncoding:NSUTF8StringEncoding]];
	[response appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	return response;
}

- (void)sendErrorNum:(int)theErrorNum description:(NSString *)theDescription returnHTML:(BOOL)hasHTML {
	NSString *description;
	if (theDescription!=nil) {
		description = theDescription;
	} else {
		description = [self getDescriptionForHTTPCode:theErrorNum];
	}
#if MGMHTTPDebug
	NSLog(@"Error %d - %@", theErrorNum, description);
#endif
	
	NSMutableString *htmlString = [NSMutableString string];
	if (hasHTML) {
		[htmlString appendString:@"<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\"><html>"];
		[htmlString appendFormat:@"<head><title>%d %@</title></head>", theErrorNum, description];
		[htmlString appendFormat:@"<body><h1>%@</h1></body></html>", description];
	}
	[self setHeader:[NSString stringWithInteger:[htmlString length]] withName:@"Content-Length"];
	
	NSMutableData *response = [self getResponseWithCode:theErrorNum description:description];
	[response appendData:[htmlString dataUsingEncoding:NSUTF8StringEncoding]];
	[clientSocket writeData:response withTimeout:MGMWriteErrorTimeOut tag:MGMHTTPResponseTag];
}

- (NSString *)requestHeaderWithName:(NSString *)name {
	return [requestHeaders objectForKey:[name lowercaseString]];
}
- (NSDictionary *)requestHeaders {
	return [NSDictionary dictionaryWithDictionary:requestHeaders];
}
- (MGMInteger)contentLength {
	if ([self requestHeaderWithName:MGMContentLength]==nil)
		return 0;
	return strtol([[self requestHeaderWithName:MGMContentLength] UTF8String], NULL, 0);
}

- (BOOL)setHeader:(NSString *)header withName:(NSString *)name {
	if (!headersPosted) {
		[headers setObject:header forKey:(name==nil ? @"" : [name lowercaseString])];
		return YES;
	} else if (isBufferBased) {
		[self printError:@"Headers has already been posted."];
	}
	return NO;
}
- (BOOL)deleteHeaderWithName:(NSString *)name {
	if (!headersPosted) {
		if ([headers objectForKey:[name lowercaseString]]!=nil) {
			[headers removeObjectForKey:[name lowercaseString]];
			return YES;
		}
	} else if (isBufferBased) {
		[self printError:@"Headers has already been posted."];
	}
	return NO;
}
- (NSString *)headerWithName:(NSString *)name {
	return [headers objectForKey:[name lowercaseString]];
}
- (NSDictionary *)headers {
	return [NSDictionary dictionaryWithDictionary:headers];
}

- (BOOL)setCookie:(NSString *)cookie forName:(NSString *)name expires:(NSDate *)expires domain:(NSString *)domain path:(NSString *)path secure:(BOOL)secure httpOnly:(BOOL)httpOnly {
	if (headersPosted) {
		if (isBufferBased) {
			[self printError:@"Headers has already been posted."];
		}
	} else if (name!=nil && ![name isEqualToString:@""]) {
		if (cookiesToPost==nil) {
			cookiesToPost = [[NSMutableArray new] retain];
		}
		for (int i=0; i<[cookiesToPost count]; i++) {
			if ([[[cookiesToPost objectAtIndex:i] objectForKey:MGMNameKey] isEqualToString:name]) {
				[cookiesToPost removeObjectAtIndex:i];
			}
		}
		NSMutableDictionary *cookieD = [NSMutableDictionary new];
		[cookieD setObject:name forKey:MGMNameKey];
		if (cookie==nil) {
			[cookies setObject:@"" forKey:name];
			[cookieD setObject:@"" forKey:MGMCookieKey];
		} else {
			[cookies setObject:cookie forKey:name];
			[cookieD setObject:cookie forKey:MGMCookieKey];
		}
		if (expires!=nil) {
			[cookieD setObject:expires forKey:MGMExpiresKey];
		}
		if (domain!=nil && ![domain isEqualToString:@""]) {
			[cookieD setObject:domain forKey:MGMDomainKey];
		}
		if (path!=nil && ![path isEqualToString:@""]) {
			[cookieD setObject:path forKey:MGMPathKey];
		}
		[cookieD setObject:[NSNumber numberWithBool:secure] forKey:MGMSecureKey];
		[cookieD setObject:[NSNumber numberWithBool:httpOnly] forKey:MGMHTTPOnlyKey];
		[cookiesToPost addObject:[NSDictionary dictionaryWithDictionary:cookieD]];
		[cookieD release];
		return YES;
	}
	return NO;
}
- (BOOL)deleteCookieWithName:(NSString *)name withDomain:(NSString *)domain  withPath:(NSString *)path secure:(BOOL)secure  httpOnly:(BOOL)httpOnly {
	if (name!=nil && ![name isEqualToString:@""]) {
		if ([cookies objectForKey:name]!=nil) {
			if ([self setCookie:nil forName:name expires:[NSDate date] domain:domain path:path secure:secure httpOnly:httpOnly]) {
				[cookies removeObjectForKey:name];
				return YES;
			}
		}
	}
	return NO;
}
- (NSString *)cookieWithName:(NSString *)name {
	return [cookies objectForKey:name];
}
- (NSDictionary *)cookies {
	return [NSDictionary dictionaryWithDictionary:cookies];
}

- (NSString *)getInputWithName:(NSString *)name {
	return [getInputs objectForKey:name];
}
- (NSDictionary *)getInputs {
	return getInputs;
}
- (NSString *)postInputWithName:(NSString *)name {
	return [postInputs objectForKey:name];
}
- (NSDictionary *)postInputs {
	return postInputs;
}

- (NSString *)requestWithName:(NSString *)name {
	NSString *request = nil;
	if ([getInputs objectForKey:name]!=nil)
		request = [getInputs objectForKey:name];
	if ([postInputs objectForKey:name]!=nil)
		request = [postInputs objectForKey:name];
	if ([cookies objectForKey:name]!=nil)
		request = [cookies objectForKey:name];
	return request;
}
- (NSDictionary *)requests {
	NSMutableDictionary *requests = [NSMutableDictionary new];
	NSArray *keys;
	keys = [getInputs allKeys];
	for (int i=0; i<[keys count]; i++) {
		[requests setObject:[getInputs objectForKey:[keys objectAtIndex:i]] forKey:[keys objectAtIndex:i]];
	}
	keys = [postInputs allKeys];
	for (int i=0; i<[keys count]; i++) {
		[requests setObject:[postInputs objectForKey:[keys objectAtIndex:i]] forKey:[keys objectAtIndex:i]];
	}
	keys = [cookies allKeys];
	for (int i=0; i<[keys count]; i++) {
		[requests setObject:[cookies objectForKey:[keys objectAtIndex:i]] forKey:[keys objectAtIndex:i]];
	}
	NSDictionary *returnRequests = [NSDictionary dictionaryWithDictionary:requests];
	[requests release];
	return returnRequests;
}
- (NSDictionary *)fileWithName:(NSString *)Name {
	return [filesUploaded objectForKey:Name];
}
- (NSDictionary *)filesUploaded {
	return [NSDictionary dictionaryWithDictionary:filesUploaded];
}

- (NSString *)userIP {
	NSString *ip = nil;
	if ([self requestHeaderWithName:MGMRemoteAddress])
		ip = [self requestHeaderWithName:MGMRemoteAddress];
	if ([self requestHeaderWithName:MGMPCRemoteAddress])
		ip = [self requestHeaderWithName:MGMPCRemoteAddress];
	if ([self requestHeaderWithName:MGMClientIP])
		ip = [self requestHeaderWithName:MGMClientIP];
	if ([self requestHeaderWithName:MGMForwardedFor])
		ip = [self requestHeaderWithName:MGMForwardedFor];
	return ip;
}

- (NSArray *)sslCertificates {
	return nil;
}

- (void)replyToClient {
	if (isBufferBased) {
		if (isBufferSending) {
			isBufferSending = NO;
			NSData *data = [NSData dataWithData:responseBuffer];
			[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPBufferResponseBodyFinalTag];
			[responseBuffer release];
			responseBuffer = nil;
		} else {
			isBufferBased = NO;
			NSData *data = [NSData dataWithData:responseBuffer];
			httpResponse = [[MGMHTTPResponse responseWithData:data] retain];
			[responseBuffer release];
			responseBuffer = nil;
			[self sendHTTPResponse];
		}
	} else {
		[self sendHTTPResponse];
	}
}

- (void)sendHTTPResponse {
	if (httpResponse==nil) {
		if ([[server delegate] respondsToSelector:@selector(httpResponseForClient:)]) {
			httpResponse = [[[server delegate] httpResponseForClient:self] retain];
		} else {
			[self sendErrorNum:500 description:nil returnHTML:YES];
			return;
		}
	}
	
	MGMInteger contentLength = httpResponse ? [httpResponse contentLength] : 0;
	if (contentLength==0) {
		[self sendErrorNum:204 description:nil returnHTML:YES];
		[httpResponse release];
		httpResponse = nil;
		return;
	}
	
	NSString *rangeHeader = [self requestHeaderWithName:@"range"];
	BOOL isRangeRequest = NO;
	
	if (rangeHeader!=nil && [self parseRanges:rangeHeader withResponseLength:contentLength]) {
		isRangeRequest = YES;
	}
	
	NSMutableData *response;
	if (!isRangeRequest) {
		[self setHeader:[NSString stringWithInteger:contentLength] withName:@"Content-Length"];
		response = [self getResponseWithCode:200 description:nil];
	} else {
		if ([ranges count]==1) {
			NSRange range = [[ranges objectAtIndex:0] rangeValue];
			
			[self setHeader:[NSString stringWithInteger:range.length] withName:@"Content-Length"];
			NSString *contentRangeStr = [NSString stringWithFormat:@"bytes %@-%@/%@", [NSString stringWithInteger:range.location], [NSString stringWithInteger:NSMaxRange(range)-1], [NSString stringWithInteger:contentLength]];
			[self setHeader:contentRangeStr withName:@"Content-Range"];
		} else {
			rangesHeaders = [NSMutableArray new];
			srandomdev();
			rangesBoundry = [[NSString stringWithFormat:@"MGM%ld", random()%20000] retain];
			
			MGMInteger actualContentLength = 0;
			
			for (int i=0; i < [ranges count]; i++) {
				NSRange range = [[ranges objectAtIndex:i] rangeValue];
				
				NSData *header = [[NSString stringWithFormat:@"\r\n--%@\r\nContent-Range: bytes %@-%@/%@\r\n\r\n", rangesBoundry,
								   [NSString stringWithInteger:range.location], [NSString stringWithInteger:NSMaxRange(range)-1],
								   [NSString stringWithInteger:contentLength]] dataUsingEncoding:NSUTF8StringEncoding];
				[rangesHeaders addObject:header];
				
				actualContentLength += [header length];
				actualContentLength += range.length;
			}
			actualContentLength += 8+[rangesBoundry length];
			
			[self setHeader:[NSString stringWithInteger:actualContentLength] withName:@"Content-Length"];
			[self setHeader:[NSString stringWithFormat:@"multipart/byteranges; boundary=%@", rangesBoundry] withName:@"Content-Type"];
		}
		response = [self getResponseWithCode:206 description:nil];
	}
	
	if ([[[self requestHeaderWithName:MGMRequestMethod] lowercaseString] isEqual:@"head"]) {
		[clientSocket writeData:response withTimeout:MGMWriteHeaderTimeOut tag:MGMHTTPResponseTag];
	} else {
		[clientSocket writeData:response withTimeout:MGMWriteHeaderTimeOut tag:MGMHTTPPartialResponseTag];
		
		if (!isRangeRequest) {
			NSData *data = [httpResponse readDataOfLength:MGMReadChunkSize];
			[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialResponseBodyTag];
		} else {
			if ([ranges count]==1) {
				NSRange range = [[ranges objectAtIndex:0] rangeValue];
				[httpResponse setOffset:range.location];
				
				MGMInteger bytesToRead = range.length<MGMReadChunkSize ? range.length : MGMReadChunkSize;
				[clientSocket writeData:[httpResponse readDataOfLength:bytesToRead] withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialRangeResponseBodyTag];
			} else {
				rangeIndex = 0;
				NSData *rangeHeader = [rangesHeaders objectAtIndex:rangeIndex];
				[clientSocket writeData:rangeHeader withTimeout:MGMWriteHeaderTimeOut tag:MGMHTTPPartialResponseHeaderTag];
				
				NSRange range = [[ranges objectAtIndex:rangeIndex] rangeValue];
				[httpResponse setOffset:range.location];
				
				MGMInteger bytesToRead = range.length<MGMReadChunkSize ? range.length : MGMReadChunkSize;
				NSData *data = [httpResponse readDataOfLength:bytesToRead];
				[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialRangesResponseHeaderTag];
			}
		}
	}
}

- (void)postHeaders {
	[self setHeader:@"Identity" withName:@"Transfer-Encoding"];
	NSMutableData *response = [self getResponseWithCode:200 description:nil];
	[clientSocket writeData:response withTimeout:MGMWriteHeaderTimeOut tag:MGMHTTPPartialResponseHeaderTag];
}
- (void)printData:(NSData *)data {
	isBufferBased = YES;
	if (responseBuffer==nil) {
		responseBuffer = [NSMutableData new];
	}
	[responseBuffer appendData:data];
	if ([responseBuffer length]>=MGMHTTPBufferLimit) {
		if (!isBufferSending) {
			isBufferSending = YES;
			[self postHeaders];
		}
		if (![[[self requestHeaderWithName:MGMRequestMethod] lowercaseString] isEqual:@"head"]) {
			NSRange range = NSMakeRange(0, MGMHTTPBufferLimit);
			NSData *data = [responseBuffer subdataWithRange:range];
			[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPBufferResponseBodyTag];
			while (range.length+range.location!=[responseBuffer length]) {
				range.location += MGMHTTPBufferLimit;
				range.length = ([responseBuffer length]-range.location<MGMHTTPBufferLimit ? [responseBuffer length]-range.location : MGMHTTPBufferLimit);
				NSData *data = [responseBuffer subdataWithRange:range];
				[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPBufferResponseBodyTag];
			}
		}
		[responseBuffer release];
		responseBuffer = [NSMutableData new];
	}
}
- (void)print:(NSString *)format, ... {
	va_list ap;
	va_start(ap, format);
	if (format==nil)
		return;
	NSString *info = [[NSString alloc] initWithFormat:format arguments:ap];
	va_end(ap);
	[self printData:[info dataUsingEncoding:NSUTF8StringEncoding]];
	[info release];
}
- (void)printError:(NSString *)format, ... {
	va_list ap;
	va_start(ap, format);
	if (format==nil)
		return;
	NSString *info = [[NSString alloc] initWithFormat:format arguments:ap];
	va_end(ap);
	[self print:@"<br /><font color=\"#FF0000\" size=\"4pt\">Error: %@</font><br />", info];
	[info release];
}
- (void)flush {
	if (!isBufferSending) {
		isBufferSending = YES;
		[self postHeaders];
	}
	if (![[[self requestHeaderWithName:MGMRequestMethod] lowercaseString] isEqual:@"head"]) {
		NSData *data = [NSData dataWithData:responseBuffer];
		[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPBufferResponseBodyTag];
	}
	[responseBuffer release];
	responseBuffer = [NSMutableData new];
}

- (BOOL)onSocketWillConnect:(AsyncSocket *)sock {
	NSArray *certificates = [self sslCertificates];
	if (certificates!=nil && [certificates count]>0) {
		NSMutableDictionary *settings = [NSMutableDictionary dictionary];
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLIsServer];
		[settings setObject:certificates forKey:(NSString *)kCFStreamSSLCertificates];
		[settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL forKey:(NSString *)kCFStreamSSLLevel];
		
		CFReadStreamSetProperty([clientSocket getCFReadStream], kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
		CFWriteStreamSetProperty([clientSocket getCFWriteStream], kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
	}
	return YES;
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
#if MGMHTTPDebug
	NSLog(@"Connected to %@:%hu", host, port);
#endif
	[clientSocket readDataToData:[AsyncSocket CRLFData] withTimeout:MGMReadTimeOut maxLength:MGMLimitMaxHeaderLineLength tag:MGMHTTPRequestHeaderTag];
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag {
	if (tag==MGMHTTPRequestHeaderTag) {
		isKeepAlive = NO;
		BOOL result = CFHTTPMessageAppendBytes(clientRequest, [data bytes], [data length]);
		if (!result) {
			[self sendErrorNum:400 description:nil returnHTML:YES];
		} else if (!CFHTTPMessageIsHeaderComplete(clientRequest)) {
			numHeaders++;
			if (numHeaders>MGMLimitMaxHeaderLines) {
				[self disconnect];
			} else {
				[clientSocket readDataToData:[AsyncSocket CRLFData] withTimeout:MGMReadTimeOut maxLength:MGMLimitMaxHeaderLineLength tag:MGMHTTPRequestHeaderTag];
			}
		} else {
			NSString *version = [(NSString *)CFHTTPMessageCopyVersion(clientRequest) autorelease];
			if (version==nil || (![version isEqualToString:(NSString *)kCFHTTPVersion1_1] && ![version isEqualToString:(NSString *)kCFHTTPVersion1_0])) {
				[self sendErrorNum:505 description:nil returnHTML:YES];
				return;
			}
			NSString *method = [(NSString *)CFHTTPMessageCopyRequestMethod(clientRequest) autorelease];
			NSURL *uri = [(NSURL *)CFHTTPMessageCopyRequestURL(clientRequest) autorelease];
			
			NSDictionary *requestHeadersDictionary = [(NSDictionary *)CFHTTPMessageCopyAllHeaderFields(clientRequest) autorelease];
			NSArray *requestKeys = [requestHeadersDictionary allKeys];
			NSMutableDictionary *requestDictionary = [NSMutableDictionary dictionary];
			for (int i=0; i<[requestKeys count]; i++) {
				[requestDictionary setObject:[requestHeadersDictionary objectForKey:[requestKeys objectAtIndex:i]] forKey:[[requestKeys objectAtIndex:i] lowercaseString]];
			}
			[requestDictionary setObject:version forKey:MGMServerProtocol];
			[requestDictionary setObject:method forKey:MGMRequestMethod];
			[requestDictionary setObject:[[uri standardizedURL] path] forKey:MGMScriptName];
			
			NSString *path = [[[uri standardizedURL] path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			CFStringRef escapedPath = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)[[uri standardizedURL] path], NULL, CFSTR("!*'();:^@&=+$,?%#[]|"), kCFStringEncodingUTF8);
			
			if (escapedPath!=NULL)
				path = [(NSString *)escapedPath autorelease];
			[requestDictionary setObject:[NSString stringWithFormat:@"http://%@%@", [requestDictionary objectForKey:@"host"], path] forKey:MGMRequestURI];
			
			[requestDictionary setObject:[clientSocket connectedHost] forKey:MGMRemoteAddress];
			[requestDictionary setObject:[[NSNumber numberWithInt:[clientSocket connectedPort]] stringValue] forKey:MGMRemotePort];
			[requestDictionary setObject:[clientSocket localHost] forKey:MGMServerAddress];
			[requestDictionary setObject:[[NSNumber numberWithInt:[clientSocket localPort]] stringValue] forKey:MGMServerPort];
			if ([uri query]!=nil) {
				[requestDictionary setObject:[uri query] forKey:MGMQueryString];
			}
			requestHeaders = [[NSDictionary dictionaryWithDictionary:requestDictionary] retain];
#if MGMHTTPDebug
			NSLog(@"%@", requestHeaders);
#endif
			
			NSArray *cookiesA = [[self requestHeaderWithName:MGMCookies] componentsSeparatedByString:@";"];
			cookies = [NSMutableDictionary new];
			for (int i=0; i<[cookiesA count]; i++) {
				NSArray *cookie = [[cookiesA objectAtIndex:i] componentsSeparatedByString:@"="];
				[cookies setObject:([cookie count]==1 ? @"" : [[[cookie objectAtIndex:1] trim] urlDecode]) forKey:[[[cookie objectAtIndex:0] trim] urlDecode]];
			}
			
			if ([[self requestHeaderWithName:MGMQueryString] length]!=0) {
				NSArray *formInputsA = [[self requestHeaderWithName:MGMQueryString] componentsSeparatedByString:@"&"];
				NSMutableDictionary *inputs = [NSMutableDictionary new];
				for (int i=0; i<[formInputsA count]; i++) {
					NSArray *input = [[formInputsA objectAtIndex:i] componentsSeparatedByString:@"="];
					[inputs setObject:([input count]==1 ? @"" : [[input objectAtIndex:1] urlDecode]) forKey:[[input objectAtIndex:0] urlDecode]];
				}
				getInputs = [[NSDictionary dictionaryWithDictionary:inputs] retain];
				[inputs release];
			}
			
			if (![self supportsMethod:method]) {
				[self sendErrorNum:405 description:nil returnHTML:YES];
				return;
			}
			
			MGMInteger requestContentLength = [self contentLength];
			BOOL expectsUpload = [[[self requestHeaderWithName:MGMRequestMethod] lowercaseString] isEqualToString:@"post"] || [[[self requestHeaderWithName:MGMRequestMethod] lowercaseString] isEqualToString:@"put"];
			if (expectsUpload) {
				if(requestContentLength==0) {
					[self sendErrorNum:400 description:nil returnHTML:YES];
					return;
				}
			} else if (requestContentLength!=0) {
				[self sendErrorNum:400 description:nil returnHTML:YES];
				return;
			}
			requestContentLengthReceived = 0;
			
			if (expectsUpload) {
				if ([[[self requestHeaderWithName:MGMRequestMethod] lowercaseString] isEqualToString:@"post"]) {
					NSString *contentType = nil;
					if ([self requestHeaderWithName:MGMContentType]!=nil) {
						NSArray *contentA = [[self requestHeaderWithName:MGMContentType] componentsSeparatedByString:@";"];
						for (int i=0; i<[contentA count]; i++) {
							NSArray *content = [[contentA objectAtIndex:i] componentsSeparatedByString:@"="];
							if ([content count]==1) {
								contentType = [[[[content objectAtIndex:0] trim] lowercaseString] urlDecode];
							} else {
								if ([[[[[content objectAtIndex:0] trim] lowercaseString] urlDecode] isEqualToString:@"boundary"]) {
									[fBoundary release];
									fBoundary = [[@"--" stringByAppendingString:[[[content objectAtIndex:1] trim] urlDecode]] retain];
								}
							}
							
						}
					}
					isMultipart = [contentType isEqualToString:@"multipart/form-data"];
					if (isMultipart) {
						MGMInteger bytesToRead = requestContentLength<MGMPostChunkSize ? requestContentLength : MGMPostChunkSize;
						[clientSocket readDataToLength:bytesToRead withTimeout:MGMReadTimeOut tag:MGMHTTPRequestBodyTag];
					} else {
						if (requestContentLength>MGMPostMaxLength) {
							[self sendErrorNum:400 description:nil returnHTML:YES];
							return;
						} else {
							[clientSocket readDataToLength:requestContentLength withTimeout:MGMReadTimeOut tag:MGMHTTPRequestBodyTag];
						}
					}
				}
			} else {
				[self replyToClient];
			}
		}
	} else {
		if (isMultipart) {
			requestContentLengthReceived += [data length];
			
			MGMInteger requestContentLength = [self contentLength];
			if (requestContentLengthReceived<requestContentLength) {
				MGMInteger bytesLeft = requestContentLength - requestContentLengthReceived;
				MGMInteger bytesToRead = bytesLeft<MGMPostChunkSize ? bytesLeft : MGMPostChunkSize;
				[clientSocket readDataToLength:bytesToRead withTimeout:MGMReadTimeOut tag:MGMHTTPRequestBodyTag];
			} else {
				//NSLog(@"%@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
				[self replyToClient];
			}
		} else {
			postData = [data retain];
			NSString *formString = [[[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding] autorelease];
			
			NSRange equalRange = [formString rangeOfString:@"="];
			if (equalRange.location!=NSNotFound) {
				NSArray *formInputsA = [formString componentsSeparatedByString:@"&"];
				NSMutableDictionary *inputs = [NSMutableDictionary dictionary];
				for (int i=0; i<[formInputsA count]; i++) {
					NSArray *input = [[formInputsA objectAtIndex:i] componentsSeparatedByString:@"="];
					[inputs setObject:([input count]==1 ? @"" : [[input objectAtIndex:1] urlDecode]) forKey:[[input objectAtIndex:0] urlDecode]];
				}
				postInputs = [[NSDictionary dictionaryWithDictionary:inputs] retain];
			}
			[self replyToClient];
		}
	}
}
- (void)cleanConnection:(long)tag {
	if (clientDisconnected) {
		[[NSNotificationCenter defaultCenter] postNotificationName:MGMClientDisconnectedNotification object:self];
		return;
	}
	isKeepAlive = NO;
	if ([[server delegate] respondsToSelector:@selector(finnishedSendingResponse:)]) {
		[[server delegate] finnishedSendingResponse:self];
	}
	NSString *connection = [self requestHeaderWithName:MGMConnection];
	if (tag==MGMHTTPFinalResponseTag || tag==MGMHTTPBufferResponseBodyFinalTag) {
		[self disconnect];
	} else if ([[connection lowercaseString] isEqualToString:@"close"]) {
		[self disconnect];
	} else {
		isKeepAlive = YES;
		//Get ready for next request
		headersPosted = NO;
		isBufferBased = NO;
		if (requestHeaders!=nil) {
			[requestHeaders release];
			requestHeaders = nil;
			numHeaders = 0;
		}
		[headers release];
		headers = nil;
		headers = [NSMutableDictionary new];
		[cookies release];
		cookies = nil;
		[getInputs release];
		getInputs = nil;
		[postInputs release];
		postInputs = nil;
		[postData release];
		postData = nil;
		[cookiesToPost release];
		cookiesToPost = nil;
		[filesUploaded release];
		filesUploaded = nil;
		[httpResponse release];
		httpResponse = nil;
		[ranges release];
		ranges = nil;
		[rangesHeaders release];
		rangesHeaders = nil;
		[rangesBoundry release];
		rangesBoundry = nil;
		[fBoundary release];
		fBoundary = nil;
		requestContentLengthReceived = 0;
		if (clientRequest!=NULL)
			CFRelease(clientRequest);
		clientRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);
		
		[clientSocket readDataToData:[AsyncSocket CRLFData] withTimeout:MGMReadTimeOut maxLength:MGMLimitMaxHeaderLineLength tag:MGMHTTPRequestHeaderTag];
	}
}
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
	if (tag==MGMHTTPPartialResponseBodyTag) {
		NSData *data = [httpResponse readDataOfLength:MGMReadChunkSize];
		
		if ([data length]>0) {
			[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialResponseBodyTag];
		} else {
			[self cleanConnection:tag];
		}
	} else if (tag==MGMHTTPPartialRangeResponseBodyTag) {
		NSRange range = [[ranges objectAtIndex:0] rangeValue];
		MGMInteger offset = [httpResponse offset];
		MGMInteger bytesRead = offset-range.location;
		MGMInteger bytesLeft = range.length-bytesRead;
		
		if (bytesLeft>0) {
			MGMInteger bytesToRead = bytesLeft<MGMReadChunkSize ? bytesLeft : MGMReadChunkSize;
			NSData *data = [httpResponse readDataOfLength:bytesToRead];
			[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialRangeResponseBodyTag];
		} else {
			[self cleanConnection:tag];
		}
	} else if (tag==MGMHTTPPartialRangesResponseHeaderTag) {
		NSRange range = [[ranges objectAtIndex:rangeIndex] rangeValue];
		MGMInteger offset = [httpResponse offset];
		MGMInteger bytesRead = offset - range.location;
		MGMInteger bytesLeft = range.length - bytesRead;
		
		if (bytesLeft>0) {
			MGMInteger bytesToRead = bytesLeft<MGMReadChunkSize ? bytesLeft : MGMReadChunkSize;
			NSData *data = [httpResponse readDataOfLength:bytesToRead];
			[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialRangesResponseHeaderTag];
		} else {
			rangeIndex = rangeIndex+1;
			if (rangeIndex<[ranges count]) {
				NSData *rangeHeader = [rangesHeaders objectAtIndex:rangeIndex];
				[clientSocket writeData:rangeHeader withTimeout:MGMWriteHeaderTimeOut tag:MGMHTTPPartialResponseHeaderTag];
				
				NSRange range = [[ranges objectAtIndex:rangeIndex] rangeValue];
				[httpResponse setOffset:range.location];
				
				MGMInteger bytesToRead = range.length<MGMReadChunkSize ? range.length : MGMReadChunkSize;
				NSData *data = [httpResponse readDataOfLength:bytesToRead];
				[clientSocket writeData:data withTimeout:MGMWriteBodyTimeOut tag:MGMHTTPPartialRangesResponseHeaderTag];
			} else {
				NSData *data = [[NSString stringWithFormat:@"\r\n--%@--\r\n", rangesBoundry] dataUsingEncoding:NSUTF8StringEncoding];
				[clientSocket writeData:data withTimeout:MGMWriteHeaderTimeOut tag:MGMHTTPResponseTag];
			}
		}
	} else if (tag==MGMHTTPResponseTag || tag==MGMHTTPFinalResponseTag || tag==MGMHTTPBufferResponseBodyFinalTag) {
		[self cleanConnection:tag];
	}
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
#if MGMHTTPDebug
	NSLog(@"onSocket:%@ willDisconnectWithError:%@", sock, err);
#endif
}
- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
	clientDisconnected = YES;
	if (disconnecting || isKeepAlive)
		[[NSNotificationCenter defaultCenter] postNotificationName:MGMClientDisconnectedNotification object:self];
}

- (void)disconnect {
	disconnecting =YES;
	[clientSocket disconnect];
}
@end