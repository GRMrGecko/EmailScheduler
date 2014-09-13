//
//  MGMHTTPResponse.m
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

#import "MGMHTTPResponse.h"

@implementation MGMHTTPResponse
+ (id)responseWithData:(NSData *)theData {
	return [[[self alloc] initWithData:theData] autorelease];
}
- (id)initWithData:(NSData *)theData {
	if (self = [super init]) {
		data = [theData retain];
	}
	return self;
}
+ (id)responseWithString:(NSString *)theString {
	return [[[self alloc] initWithString:theString] autorelease];
}
- (id)initWithString:(NSString *)theString {
	if (self = [super init]) {
		data = [[theString dataUsingEncoding:NSUTF8StringEncoding] retain];
	}
	return self;
}
- (void)dealloc {
    [data release];
	[super dealloc];
}

- (MGMInteger)contentLength {
	return [data length];
}

- (MGMInteger)offset {
	return offset;
}
- (void)setOffset:(MGMInteger)theOffset {
	offset = theOffset;
}

- (NSData *)readDataOfLength:(MGMInteger)theLength {
	MGMInteger remaining = [data length]-offset;
	MGMInteger length = theLength<remaining ? theLength : remaining;
	
	NSData *returnData = [data subdataWithRange:NSMakeRange(offset, length)];
	offset = offset+length;
	return returnData;
}
@end

@implementation MGMHTTPFileResponse
+ (id)responseWithFilePath:(NSString *)thePath {
	return [[[self alloc] initWithFilePath:thePath] autorelease];
}
- (id)initWithFilePath:(NSString *)thePath {
	if (self = [super init]) {
		filePath = [thePath retain];
		fileHandle = [[NSFileHandle fileHandleForReadingAtPath:filePath] retain];
	}
	return self;
}
- (void)dealloc {
    [fileHandle release];
    [filePath release];
	[super dealloc];
}

- (MGMInteger)contentLength {
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDictionary *fileAttributes = nil;
	if ([manager respondsToSelector:@selector(fileAttributesAtPath:traverseLink:)]) {
		fileAttributes = [manager fileAttributesAtPath:filePath traverseLink:YES];
	} else {
		fileAttributes = [manager attributesOfItemAtPath:filePath error:nil];
	}
	return [[fileAttributes objectForKey:NSFileSize] longValue];
}

- (MGMInteger)offset {
	return (MGMInteger)[fileHandle offsetInFile];
}
- (void)setOffset:(MGMInteger)theOffset {
	[fileHandle seekToFileOffset:theOffset];
}

- (NSData *)readDataOfLength:(MGMInteger)theLength {
	return [fileHandle readDataOfLength:theLength];
}
@end

static NSArray *MGMHTTPMIMEMap = nil;

@implementation MGMHTTPMIME
+ (NSString *)mimeForExtension:(NSString *)theExtension {
	if (MGMHTTPMIMEMap==nil) {
		MGMHTTPMIMEMap = [[NSArray arrayWithContentsOfFile:[[[NSBundle bundleForClass:self] resourcePath] stringByAppendingPathComponent:@"mimeTypes.plist"]] retain];
	}
	for (unsigned int mimeIndex=0; mimeIndex<[MGMHTTPMIMEMap count]; mimeIndex++) {
		NSDictionary *mime = [MGMHTTPMIMEMap objectAtIndex:mimeIndex];
		NSArray *extensions = [mime objectForKey:@"extensions"];
		for (unsigned int extensionIndex=0; extensionIndex<[extensions count]; extensionIndex++) {
			if ([[extensions objectAtIndex:extensionIndex] isEqualToString:theExtension])
				return [mime objectForKey:@"type"];
		}
	}
	return @"text/plain";
}
@end