//
//  MGMJSON.h
//  MGMUsers
//
//  Created by Mr. Gecko on 7/31/10.
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

@interface NSString (MGMJSON)
- (id)parseJSON;
- (NSString *)JSONValue;
@end
@interface NSData (MGMJSON)
- (id)parseJSON;
@end
@interface NSNumber (MGMJSON)
- (NSString *)JSONValue;
@end
@interface NSNull (MGMJSON)
- (NSString *)JSONValue;
@end
@interface NSDictionary (MGMJSON)
- (NSString *)JSONValue;
@end
@interface NSArray (MGMJSON)
- (NSString *)JSONValue;
@end

@interface MGMJSON : NSObject {
@private
	NSMutableCharacterSet *escapeSet;
    NSString *JSONString;
    unsigned long position;
    unsigned long length;
}
- (id)initWithString:(NSString *)theString;
- (id)parse;
- (void)skipWhitespace;
- (void)skipDigits;
- (id)parseForObject;
- (NSDictionary *)parseForDictionary;
- (NSArray *)parseForArray;
- (NSString *)parseForString;
- (unichar)parseForUnicodeChar;
- (NSNumber *)parseForYES;
- (id)parseForNONULL;
- (NSNumber *)parseForNumber;

- (NSString *)convert:(id)theObject;
- (NSString *)writeString:(NSString *)theString;
- (NSString *)writeNumber:(NSNumber *)theNumber;
- (NSString *)writeBool:(NSNumber *)theNumber;
- (NSString *)writeNull:(NSNull *)theNull;
- (NSString *)writeDictionary:(NSDictionary *)theDictionary;
- (NSString *)writeArray:(NSArray *)theArray;
@end