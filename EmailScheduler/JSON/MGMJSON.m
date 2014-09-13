//
//  MGMJSON.m
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

#import "MGMJSON.h"

@implementation NSString (MGMJSON)
- (id)parseJSON {
	MGMJSON *parser = [[MGMJSON alloc] initWithString:self];
	id object = [parser parse];
	[parser release];
	return object;
}
- (NSString *)JSONValue {
	MGMJSON *writer = [[MGMJSON alloc] init];
	NSString *value = [writer convert:self];
	[writer release];
	return value;
}
@end
@implementation NSData (MGMJSON)
- (id)parseJSON {
	NSString *string = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
	MGMJSON *parser = [[MGMJSON alloc] initWithString:string];
	[string release];
	id object = [parser parse];
	[parser release];
	return object;
}
@end
@implementation NSNumber (MGMJSON)
- (NSString *)JSONValue {
	MGMJSON *writer = [[MGMJSON alloc] init];
	NSString *value = [writer convert:self];
	[writer release];
	return value;
}
@end
@implementation NSNull (MGMJSON)
- (NSString *)JSONValue {
	MGMJSON *writer = [[MGMJSON alloc] init];
	NSString *value = [writer convert:self];
	[writer release];
	return value;
}
@end
@implementation NSDictionary (MGMJSON)
- (NSString *)JSONValue {
	MGMJSON *writer = [[MGMJSON alloc] init];
	NSString *value = [writer convert:self];
	[writer release];
	return value;
}
@end
@implementation NSArray (MGMJSON)
- (NSString *)JSONValue {
	MGMJSON *writer = [[MGMJSON alloc] init];
	NSString *value = [writer convert:self];
	[writer release];
	return value;
}
@end


@implementation MGMJSON
- (id)init {
	if ((self = [super init])) {
		escapeSet = [[NSMutableCharacterSet characterSetWithRange:NSMakeRange(0,32)] retain];
		[escapeSet addCharactersInString:@"\"\\"];
	}
	return self;
}
- (id)initWithString:(NSString *)theString {
    if ((self = [super init])) {
        JSONString = [theString retain];
        length = [JSONString length];
    }
    return self;
}
- (void)dealloc {
	[escapeSet release];
	[JSONString release];
    [super dealloc];
}

- (id)parse {
    position = 0;
    if ([JSONString isEqual:@""])
        return nil;
    return [self parseForObject];
}
- (void)skipWhitespace {
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    while (position<length && [set characterIsMember:[JSONString characterAtIndex:position]]) {
        position++;
    }
}
- (void)skipDigits {
    NSCharacterSet *set = [NSCharacterSet decimalDigitCharacterSet];
    while (position<length && [set characterIsMember:[JSONString characterAtIndex:position]]) {
        position++;
    }
}
- (id)parseForObject {
    [self skipWhitespace];
    switch ([JSONString characterAtIndex:position]) {
        case '{':
            return [self parseForDictionary];
            break;
        case '[':
            return [self parseForArray];
            break;
        case '"':
        case '\'':
            return [self parseForString];
            break;
        case 'T':
        case 't':
        case 'Y':
        case 'y':
            return [self parseForYES];
            break;
        case 'F':
        case 'f':
        case 'N':
        case 'n':
            return [self parseForNONULL];
            break;
        case '-':
        case '0'...'9':
            return [self parseForNumber];
            break;
        case 0x0:
            NSLog(@"JSON: Unexpected end of string.");
            break;
        default:
            NSLog(@"JSON: Unknown character %c", [JSONString characterAtIndex:position]);
            break;
    }
    return nil;
}
- (NSDictionary *)parseForDictionary {
    position++;
    [self skipWhitespace];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    while (position<length) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        if ([JSONString characterAtIndex:position]=='}') {
			[pool drain];
            return dictionary;
        }
        
        NSString *key = nil;
        if ([JSONString characterAtIndex:position]=='"' || [JSONString characterAtIndex:position]=='\'') {
            key = [self parseForString];
        }
        if (key==nil) {
            NSLog(@"JSON: No key found for Dictionary.");
			[pool drain];
            return nil;
        }
        position++;
        
        [self skipWhitespace];
        if ([JSONString characterAtIndex:position]!=':') {
            NSLog(@"JSON: Expected \":\" in Dictionary.");
			[pool drain];
            return nil;
        }
        position++;
        
        id object = [self parseForObject];
        if (object!=nil) {
            [dictionary setObject:object forKey:key];
        } else {
            NSLog(@"JSON: Found no object for Dictionary.");
			[pool drain];
            return nil;
        }
        position++;
        
        [self skipWhitespace];
        if ([JSONString characterAtIndex:position]==',') {
            position++;
            [self skipWhitespace];
            if ([JSONString characterAtIndex:position]=='}') {
                NSLog(@"JSON: Unexpected end of Dictionary.");
				[pool drain];
                return dictionary;
            }
        }
		[pool drain];
    }
    NSLog(@"JSON: Unexpected end of input for Dictionary.");
    return dictionary;
}
- (NSArray *)parseForArray {
    position++;
    [self skipWhitespace];
    NSMutableArray *array = [NSMutableArray array];
    while (position<length) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        if ([JSONString characterAtIndex:position]==']') {
			[pool drain];
            return array;
        }
        
        id object = [self parseForObject];
        if (object!=nil) {
            [array addObject:object];
        } else {
            NSLog(@"JSON: Found no object for Array.");
			[pool drain];
            return nil;
        }
        position++;
        
        [self skipWhitespace];
        if ([JSONString characterAtIndex:position]==',') {
            position++;
            [self skipWhitespace];
            if ([JSONString characterAtIndex:position]==']') {
                NSLog(@"JSON: Unexpected end of Array.");
				[pool drain];
                return array;
            }
        }
		[pool drain];
    }
    NSLog(@"JSON: Unexpected end of input for Array.");
    return array;
}
- (NSString *)parseForString {
	unichar quote = [JSONString characterAtIndex:position];
    position++;
    NSMutableString *string = [NSMutableString string];
	NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%C\\", quote]];
    do {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
		NSString *currentString = [[[JSONString substringFromIndex:position] copy] autorelease];
        NSRange range = [currentString rangeOfCharacterFromSet:set];
		if (range.location==NSNotFound) {
			NSLog(@"JSON: Range not found for String.");
			[pool drain];
			return nil;
		}
		[string appendString:[currentString substringWithRange:NSMakeRange(0, range.location)]];
		position += range.location;
        if ([JSONString characterAtIndex:position]==quote) {
			[pool drain];
            return string;
        } else if ([JSONString characterAtIndex:position]=='\\') {
            position++;
            unichar character = [JSONString characterAtIndex:position];
            switch (character) {
                case '\\':
                case '/':
                case '"':
                case '\'':
                    break;
                    
                case 'U':
                case 'u':
                    position++;
                    character = [self parseForUnicodeChar];
                    break;
                
                case 'b':
                    character = '\b';
                    break;
                case 'f':
                    character = '\f';
                    break;
                case 'n':
                    character = '\n';
                    break;
                case 'r':
                    character = '\r';
                    break;
                case 't':
                    character = '\t';
                    break;
                default:
                    NSLog(@"JSON: Illegal escape \"0x%x\"", character);
					[pool drain];
                    return nil;
                    break;
            }
			if (character==0x0) {
				NSLog(@"JSON: Received NULL when expecting character.");
				[pool drain];
				return nil;
			}
			CFStringAppendCharacters((CFMutableStringRef)string, &character, 1);
            position++;
        }
		[pool drain];
    } while (position<length);
    NSLog(@"JSON: Unexpected end of input for String.");
    return [[string copy] autorelease];
}
- (unichar)parseForUnicodeChar {
    NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789aAbBcCdDeEfF"];
    unsigned long toPosition = position + 4;
    if (toPosition>length) {
        NSLog(@"JSON: Unexpected end of input.");
        return 0x0;
    }
    int len = 0;
    NSMutableString *hexValue = [NSMutableString string];
    [hexValue appendString:@"0x"];
    while (position<toPosition && [set characterIsMember:[JSONString characterAtIndex:position]]) {
        [hexValue appendFormat:@"%c", [JSONString characterAtIndex:position]];
        len++;
        position++;
    }
    if (len!=4) {
        NSLog(@"JSON: Unicode Character invaild.");
        return 0x0;
    }
    position--;
    NSScanner *scanner = [NSScanner scannerWithString: hexValue];
    unsigned int returnValue;
    if ([scanner scanHexInt:&returnValue]) {
        return returnValue;
    }
	NSLog(@"JSON: Failed to scan hex.");
    return 0x0;
}
- (NSNumber *)parseForYES {
    if ([JSONString characterAtIndex:position]=='T' || [JSONString characterAtIndex:position]=='t') {
        if ([[[JSONString substringWithRange:NSMakeRange(position, 4)] lowercaseString] isEqual:@"true"]) {
            position += 3;
            return [NSNumber numberWithBool:YES];
        }
    } else if ([JSONString characterAtIndex:position]=='Y' || [JSONString characterAtIndex:position]=='y') {
        if ([[[JSONString substringWithRange:NSMakeRange(position, 3)] lowercaseString] isEqual:@"yes"]) {
            position += 2;
            return [NSNumber numberWithBool:YES];
        }
    }
    return nil;
}
- (id)parseForNONULL {
    if ([JSONString characterAtIndex:position]=='F' || [JSONString characterAtIndex:position]=='f') {
        if ([[[JSONString substringWithRange:NSMakeRange(position, 5)] lowercaseString] isEqual:@"false"]) {
            position += 4;
            return [NSNumber numberWithBool:NO];
        }
    } else if ([JSONString characterAtIndex:position]=='N' || [JSONString characterAtIndex:position]=='n') {
        if ([[[JSONString substringWithRange:NSMakeRange(position, 2)] lowercaseString] isEqual:@"no"]) {
            position += 1;
            return [NSNumber numberWithBool:NO];
        } else if ([[[JSONString substringWithRange:NSMakeRange(position, 4)] lowercaseString] isEqual:@"null"]) {
            position += 3;
            return [NSNull null];
        } else if ([[[JSONString substringWithRange:NSMakeRange(position, 3)] lowercaseString] isEqual:@"nil"]) {
            position += 2;
            return [NSNull null];
        }
    }
    return nil;
}
- (NSNumber *)parseForNumber {
    unsigned long start = position;
    NSCharacterSet *set = [NSCharacterSet decimalDigitCharacterSet];
    
    if ([JSONString characterAtIndex:position]=='-') {
        position++;
        if (position<length && ![set characterIsMember:[JSONString characterAtIndex:position]]) {
            NSLog(@"JSON: Expected digit after minus.");
            return nil;
        }
    }
    
    if ([JSONString characterAtIndex:position]=='0') {
        position++;
        if (position<length && [set characterIsMember:[JSONString characterAtIndex:position]]) {
            NSLog(@"JSON: Leading zero found.");
            return nil;
        }
    } else {
        [self skipDigits];
    }
    
    if (position<length && [JSONString characterAtIndex:position]=='.') {
        position++;
        if (position<length && ![set characterIsMember:[JSONString characterAtIndex:position]]) {
            NSLog(@"JSON: No digits found after decimal point.");
            return nil;
        }
        [self skipDigits];
    }
    
    if (position<length && ([JSONString characterAtIndex:position]=='E' || [JSONString characterAtIndex:position]=='e')) {
        position++;
        if (position<length && ([JSONString characterAtIndex:position]=='-' || [JSONString characterAtIndex:position]=='+'))
            position++;
        
        if (position<length && ![set characterIsMember:[JSONString characterAtIndex:position]]) {
            NSLog(@"JSON: No digits found after exponent.");
            return nil;
        }
        [self skipDigits];
    }
    
    NSString *numberString = [[[JSONString substringWithRange:NSMakeRange(start, position-start)] copy] autorelease];
	position--;
    if (numberString!=nil) {
        NSNumber *number = [NSDecimalNumber decimalNumberWithString:numberString];
        if (number!=nil)
            return number;
    }
    NSLog(@"JSON: Couldn't create number.");
    return nil;
}

- (NSString *)convert:(id)theObject {
	if ([theObject isKindOfClass:[NSString class]]) {
		return [self writeString:theObject];
	} else if ([NSStringFromClass([theObject class]) isEqual:@"NSCFBoolean"]) {
		return [self writeBool:theObject];
	} else if ([theObject isKindOfClass:[NSNumber class]]) {
		return [self writeNumber:theObject];
	} else if (theObject==nil || [theObject isKindOfClass:[NSNull class]]) {
		return [self writeNull:theObject];
	} else if ([theObject isKindOfClass:[NSDictionary class]]) {
		return [self writeDictionary:theObject];
	} else if ([theObject isKindOfClass:[NSArray class]]) {
		return [self writeArray:theObject];
	}
	NSLog(@"JSON: Invalid calss for JSON %@, returning description.", NSStringFromClass([theObject class]));
	return [self writeString:[theObject description]];
}
- (NSString *)writeString:(NSString *)theString {
	NSRange range = [theString rangeOfCharacterFromSet:escapeSet];
	NSMutableString *string = [NSMutableString string];
	[string appendString:@"\""];
	if (range.location==NSNotFound) {
		[string appendString:theString];
	} else {
		unsigned long len = [theString length];
		for (unsigned long i=0; i<len; i++) {
			unichar character = [theString characterAtIndex:i];
			switch (character) {
				case '"':
					[string appendString:@"\\\""];
					break;
				case '\\':
					[string appendString:@"\\\\"];
					break;
				case '\b':
					[string appendString:@"\\b"];
					break;
				case '\f':
					[string appendString:@"\\f"];
					break;
				case '\n':
					[string appendString:@"\\n"];
					break;
				case '\r':
					[string appendString:@"\\r"];
					break;
				case '\t':
					[string appendString:@"\\t"];
					break;
				default:
					if (character<0x20) {
						[string appendFormat:@"\\u%04x", character];
					} else {
						CFStringAppendCharacters((CFMutableStringRef)string, &character, 1);
					}
					break;
			}
		}
	}
	[string appendString:@"\""];
	return string;
}
- (NSString *)writeNumber:(NSNumber *)theNumber {
	return [theNumber stringValue];
}
- (NSString *)writeBool:(NSNumber *)theNumber {
	return [theNumber boolValue] ? @"true" : @"false";
}
- (NSString *)writeNull:(NSNull *)theNull {
	return @"null";
}
- (NSString *)writeDictionary:(NSDictionary *)theDictionary {
	NSMutableString *string = [NSMutableString string];
	[string appendString:@"{"];
	NSArray *keys = [theDictionary allKeys];
	for (int i=0; i<[keys count]; i++) {
		if (i!=0) {
			[string appendString:@", "];
		}
		NSString *value = [self convert:[theDictionary objectForKey:[keys objectAtIndex:i]]];
		if (value!=nil) {
			[string appendFormat:@"%@: ", [self writeString:[keys objectAtIndex:i]]];
			[string appendString:value];
		}
	}
	[string appendString:@"}"];
	return string;
}
- (NSString *)writeArray:(NSArray *)theArray {
	NSMutableString *string = [NSMutableString string];
	[string appendString:@"["];
	for (int i=0; i<[theArray count]; i++) {
		if (i!=0) {
			[string appendString:@", "];
		}
		NSString *value = [self convert:[theArray objectAtIndex:i]];
		if (value!=nil)
			[string appendString:value];
	}
	[string appendString:@"]"];
	return string;
}
@end