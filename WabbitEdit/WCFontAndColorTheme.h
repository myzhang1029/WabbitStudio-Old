//
//  WCFontAndColorTheme.h
//  WabbitEdit
//
//  Created by William Towe on 12/26/11.
//  Copyright (c) 2011 Revolution Software. All rights reserved.
//

#import <Foundation/NSObject.h>
#import "RSPlistArchiving.h"

extern NSString *const WCFontAndColorThemeNameKey;
extern NSString *const WCFontAndColorThemeIdentifierKey;

extern NSString *const WCFontAndColorThemeSelectionColorKey;
extern NSString *const WCFontAndColorThemeBackgroundColorKey;
extern NSString *const WCFontAndColorThemeCursorColorKey;
extern NSString *const WCFontAndColorThemeCurrentLineColorKey;

extern NSString *const WCFontAndColorThemePlainTextFontKey;
extern NSString *const WCFontAndColorThemePlainTextColorKey;
extern NSString *const WCFontAndColorThemeCommentFontKey;
extern NSString *const WCFontAndColorThemeCommentColorKey;
extern NSString *const WCFontAndColorThemeRegisterFontKey;
extern NSString *const WCFontAndColorThemeRegisterColorKey;
extern NSString *const WCFontAndColorThemeMneumonicFontKey;
extern NSString *const WCFontAndColorThemeMneumonicColorKey;
extern NSString *const WCFontAndColorThemeDirectiveFontKey;
extern NSString *const WCFontAndColorThemeDirectiveColorKey;
extern NSString *const WCFontAndColorThemePreProcessorFontKey;
extern NSString *const WCFontAndColorThemePreProcessorColorKey;
extern NSString *const WCFontAndColorThemeConditionalFontKey;
extern NSString *const WCFontAndColorThemeConditionalColorKey;
extern NSString *const WCFontAndColorThemeNumberFontKey;
extern NSString *const WCFontAndColorThemeNumberColorKey;
extern NSString *const WCFontAndColorThemeHexadecimalFontKey;
extern NSString *const WCFontAndColorThemeHexadecimalColorKey;
extern NSString *const WCFontAndColorThemeBinaryFontKey;
extern NSString *const WCFontAndColorThemeBinaryColorKey;
extern NSString *const WCFontAndColorThemeStringFontKey;
extern NSString *const WCFontAndColorThemeStringColorKey;

extern NSString *const WCFontAndColorThemeLabelFontKey;
extern NSString *const WCFontAndColorThemeLabelColorKey;
extern NSString *const WCFontAndColorThemeEquateFontKey;
extern NSString *const WCFontAndColorThemeEquateColorKey;
extern NSString *const WCFontAndColorThemeDefineFontKey;
extern NSString *const WCFontAndColorThemeDefineColorKey;
extern NSString *const WCFontAndColorThemeMacroFontKey;
extern NSString *const WCFontAndColorThemeMacroColorKey;

@interface WCFontAndColorTheme : NSObject <RSPlistArchiving,NSCopying,NSMutableCopying> {
	NSString *_name;
	NSString *_identifier;
	NSMutableArray *_pairs;
	
	NSColor *_selectionColor;
	NSColor *_backgroundColor;
	NSColor *_cursorColor;
	NSColor *_currentLineColor;
	
	NSFont *_plainTextFont;
	NSColor *_plainTextColor;
	NSFont *_commentFont;
	NSColor *_commentColor;
	NSFont *_registerFont;
	NSColor *_registerColor;
	NSFont *_mneumonicFont;
	NSColor *_mneumonicColor;
	NSFont *_directiveFont;
	NSColor *_directiveColor;
	NSFont *_preProcessorFont;
	NSColor *_preProcessorColor;
	NSFont *_conditionalFont;
	NSColor *_conditionalColor;
	NSFont *_numberFont;
	NSColor *_numberColor;
	NSFont *_hexadecimalFont;
	NSColor *_hexadecimalColor;
	NSFont *_binaryFont;
	NSColor *_binaryColor;
	NSFont *_stringFont;
	NSColor *_stringColor;
	
	NSFont *_labelFont;
	NSColor *_labelColor;
	NSFont *_equateFont;
	NSColor *_equateColor;
	NSFont *_defineFont;
	NSColor *_defineColor;
	NSFont *_macroFont;
	NSColor *_macroColor;
}
@property (readwrite,copy,nonatomic) NSString *name;
@property (readwrite,copy,nonatomic) NSString *identifier;
@property (readonly,nonatomic) NSArray *pairs;

@property (readwrite,retain,nonatomic) NSColor *selectionColor;
@property (readwrite,retain,nonatomic) NSColor *backgroundColor;
@property (readwrite,retain,nonatomic) NSColor *cursorColor;
@property (readwrite,retain,nonatomic) NSColor *currentLineColor;

@property (readwrite,retain,nonatomic) NSFont *plainTextFont;
@property (readwrite,retain,nonatomic) NSColor *plainTextColor;
@property (readwrite,retain,nonatomic) NSFont *commentFont;
@property (readwrite,retain,nonatomic) NSColor *commentColor;
@property (readwrite,retain,nonatomic) NSFont *registerFont;
@property (readwrite,retain,nonatomic) NSColor *registerColor;
@property (readwrite,retain,nonatomic) NSFont *mneumonicFont;
@property (readwrite,retain,nonatomic) NSColor *mneumonicColor;
@property (readwrite,retain,nonatomic) NSFont *directiveFont;
@property (readwrite,retain,nonatomic) NSColor *directiveColor;
@property (readwrite,retain,nonatomic) NSFont *preProcessorFont;
@property (readwrite,retain,nonatomic) NSColor *preProcessorColor;
@property (readwrite,retain,nonatomic) NSFont *conditionalFont;
@property (readwrite,retain,nonatomic) NSColor *conditionalColor;
@property (readwrite,retain,nonatomic) NSFont *numberFont;
@property (readwrite,retain,nonatomic) NSColor *numberColor;
@property (readwrite,retain,nonatomic) NSFont *hexadecimalFont;
@property (readwrite,retain,nonatomic) NSColor *hexadecimalColor;
@property (readwrite,retain,nonatomic) NSFont *binaryFont;
@property (readwrite,retain,nonatomic) NSColor *binaryColor;
@property (readwrite,retain,nonatomic) NSFont *stringFont;
@property (readwrite,retain,nonatomic) NSColor *stringColor;

@property (readwrite,retain,nonatomic) NSFont *labelFont;
@property (readwrite,retain,nonatomic) NSColor *labelColor;
@property (readwrite,retain,nonatomic) NSFont *equateFont;
@property (readwrite,retain,nonatomic) NSColor *equateColor;
@property (readwrite,retain,nonatomic) NSFont *defineFont;
@property (readwrite,retain,nonatomic) NSColor *defineColor;
@property (readwrite,retain,nonatomic) NSFont *macroFont;
@property (readwrite,retain,nonatomic) NSColor *macroColor;

@end
