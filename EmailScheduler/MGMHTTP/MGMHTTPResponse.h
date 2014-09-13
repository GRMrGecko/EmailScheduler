//
//  MGMHTTPResponse.h
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

@interface MGMHTTPResponse : NSObject {
	MGMInteger offset;
	NSData *data;
}
+ (id)responseWithData:(NSData *)theData;
- (id)initWithData:(NSData *)theData;
+ (id)responseWithString:(NSString *)theString;
- (id)initWithString:(NSString *)theString;

- (MGMInteger)contentLength;

- (MGMInteger)offset;
- (void)setOffset:(MGMInteger)theOffset;

- (NSData *)readDataOfLength:(MGMInteger)theLength;
@end

@interface MGMHTTPFileResponse : MGMHTTPResponse {
	NSString *filePath;
	NSFileHandle *fileHandle;
}
+ (id)responseWithFilePath:(NSString *)thePath;
- (id)initWithFilePath:(NSString *)thePath;
@end

@interface MGMHTTPMIME : NSObject {
	
}
+ (NSString *)mimeForExtension:(NSString *)theExtension;
@end