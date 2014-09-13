//
//  MGMHTTPAddons.m
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

#import "MGMHTTPAddons.h"


@implementation NSString (MGMHTTPAddons)
- (NSString *)trim {
	return  [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)trimQuotes {
	return  [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'`"]];
}

- (NSString *)replace:(NSString *)targetString with:(NSString *)replaceString {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableString *temp = [[NSMutableString alloc] init];
	NSRange replaceRange = NSMakeRange(0, [self length]);
	NSRange rangeInOriginalString = replaceRange;
	int replaced = 0;
	
	while (1) {
		NSRange rangeToCopy;
		NSRange foundRange = [self rangeOfString:targetString options:0 range:rangeInOriginalString];
		if (foundRange.length==0) break;
		rangeToCopy = NSMakeRange(rangeInOriginalString.location, foundRange.location - rangeInOriginalString.location);	
		[temp appendString:[self substringWithRange:rangeToCopy]];
		[temp appendString:replaceString];
		rangeInOriginalString.length -= (NSMaxRange(foundRange)-rangeInOriginalString.location);
		rangeInOriginalString.location = NSMaxRange(foundRange);
		replaced++;
		if ((replaced%100)==0) {
			[pool drain];
			pool = [NSAutoreleasePool new];
		}
	}
	if (rangeInOriginalString.length>0) [temp appendString:[self substringWithRange:rangeInOriginalString]];
	[pool release];
	
	return [temp autorelease];
}

- (NSString *)urlEncode {
	NSString *result = [self stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	CFStringRef escapedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR("!*'();:^@&=+$,/?%#[]|"), kCFStringEncodingUTF8);
	
	if (escapedString!=NULL)
		result = [(NSString *)escapedString autorelease];
	return result;
}

- (NSString *)urlDecode {
	return [[self replace:@"+" with:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *)stringWithInteger:(MGMInteger)theInteger {
	return [NSString stringWithFormat:@"%ld", theInteger];
}
+ (NSString *)stringWithDate:(NSDate *)theDate {
	NSDateFormatter *formatter = [[NSDateFormatter new] autorelease];
	[formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
	return [formatter stringFromDate:theDate];
}
@end
