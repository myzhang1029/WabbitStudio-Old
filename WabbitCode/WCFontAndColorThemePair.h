//
//  WCFontAndColorThemePair.h
//  WabbitEdit
//
//  Created by William Towe on 12/27/11.
//  Copyright (c) 2011 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/NSObject.h>

@class WCFontAndColorTheme;

@interface WCFontAndColorThemePair : NSObject {
	__unsafe_unretained WCFontAndColorTheme *_theme;
	NSString *_name;
	SEL _fontSelector;
	SEL _colorSelector;
	SEL _setFontSelector;
	SEL _setColorSelector;
}
@property (readonly,nonatomic) NSString *name;
@property (readwrite,retain,nonatomic) NSFont *font;
@property (readwrite,retain,nonatomic) NSColor *color;

+ (WCFontAndColorThemePair *)fontAndColorThemePairForTheme:(WCFontAndColorTheme *)theme name:(NSString *)name;
- (id)initWithTheme:(WCFontAndColorTheme *)theme name:(NSString *)name;
@end
