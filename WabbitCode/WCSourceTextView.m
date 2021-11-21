//
//  WCSourceTextView.m
//  WabbitEdit
//
//  Created by William Towe on 12/23/11.
//  Copyright (c) 2011 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "WCSourceTextView.h"
#import "WCSourceToken.h"
#import "WCSourceScanner.h"
#import "NSArray+WCExtensions.h"
#import "RSDefines.h"
#import "WCCompletionWindowController.h"
#import "WCFontAndColorThemeManager.h"
#import "WCFontAndColorTheme.h"
#import "NSAttributedString+WCExtensions.h"
#import "NSObject+WCExtensions.h"
#import "WCEditorViewController.h"
#import "WCSourceToken.h"
#import "RSToolTipManager.h"
#import "WCMacroSymbol.h"
#import "RSFindBarViewController.h"
#import "RSBezelWidgetManager.h"
#import "WCSourceHighlighter.h"
#import "WCKeyboardViewController.h"
#import "WCJumpInWindowController.h"
#import "WCJumpToLineWindowController.h"
#import "NSString+WCExtensions.h"
#import "NSString+RSExtensions.h"
#import "WCSourceTextStorage.h"
#import "RSBookmark.h"
#import "NSEvent+RSExtensions.h"
#import "WCArgumentPlaceholderCell.h"
#import "NSTextView+WCExtensions.h"
#import "WCProjectDocument.h"
#import "WCFile.h"
#import "WCSourceTypesetter.h"
#import "WCFold.h"
#import "NSAlert-OAExtensions.h"
#import "NSBezierPath+StrokeExtensions.h"
#import "WCFoldAttachmentCell.h"
#import "WCSearchNavigatorViewController.h"
#import "WCProjectWindowController.h"
#import "RSNavigatorControl.h"
#import "WCBuildIssue.h"
#import "WCBuildController.h"
#import "NSParagraphStyle+RSExtensions.h"
#import "WCBreakpointManager.h"
#import "WCFileBreakpoint.h"
#import "AIColorAdditions.h"
#import "WCSourceFileDocument.h"
#import "NSURL+RSExtensions.h"

@interface WCSourceTextView ()
@property (readwrite,copy,nonatomic) NSIndexSet *autoHighlightArgumentsRanges;

- (void)_commonInit;
- (void)_drawCurrentLineHighlightInRect:(NSRect)rect;
- (void)_drawPageGuideInRect:(NSRect)rect;
- (void)_highlightMatchingBrace;
- (void)_highlightMatchingTempLabel;
- (void)_insertMatchingBraceWithString:(id)string;
- (void)_handleAutoCompletionWithString:(id)string;
- (BOOL)_handleAutoIndentAfterLabel;
- (void)_highlightEnclosedMacroArguments;
- (BOOL)_handleUnfoldForEvent:(NSEvent *)theEvent;
- (void)_drawVisibleBookmarksInRect:(NSRect)bookmarkRect;
- (void)_drawVisibleBuildIssuesInRect:(NSRect)buildIssueRect;
- (void)_drawFocusFollowsCodeRectsInRect:(NSRect)focusFollowsCodeRect;
- (BOOL)_unfoldChildFoldsForFold:(WCFold *)fold;
@end

@implementation WCSourceTextView
#pragma mark *** Subclass Overrides ***
- (void)dealloc {
#ifdef DEBUG
	NSLog(@"%@ called in %@",NSStringFromSelector(_cmd),[self className]);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_completionTimer invalidate];
	_completionTimer = nil;
	[_autoHighlightArgumentsTimer invalidate];
	_autoHighlightArgumentsTimer = nil;
	[_autoHighlightArgumentsRanges release];
	[self cleanUpUserDefaultsObserving];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container {
	if (!(self = [super initWithFrame:frameRect textContainer:container]))
		return nil;
	
	[self _commonInit];
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;
	
	[self _commonInit];
	
	return self;
}

- (void)mouseDown:(NSEvent *)theEvent {
	if ([theEvent type] == NSLeftMouseDown &&
		[theEvent clickCount] == 2 &&
		[theEvent isOnlyCommandKeyPressed]) {
		
		NSRange symbolRange = [[self string] symbolRangeForRange:NSMakeRange([self characterIndexForInsertionAtPoint:[self convertPointFromBase:[theEvent locationInWindow]]], 0)];
		if (symbolRange.location == NSNotFound) {
            [[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Not Found", nil) centeredInView:self.enclosingScrollView];
            
			NSBeep();
			return;
		}
		
		[self setSelectedRange:symbolRange];
        
		[self jumpToDefinition:nil];
        
        return;
	}
	else if ([self _handleUnfoldForEvent:theEvent])
		return;
	
	[super mouseDown:theEvent];
}

+ (NSMenu *)defaultMenu; {
	static NSMenu *retval;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		retval = [[NSMenu alloc] initWithTitle:@""];
		
		[retval addItemWithTitle:NSLocalizedString(@"Cut", @"Cut") action:@selector(cut:) keyEquivalent:@""];
		[retval addItemWithTitle:NSLocalizedString(@"Copy", @"Copy") action:@selector(copy:) keyEquivalent:@""];
		[retval addItemWithTitle:NSLocalizedString(@"Paste", @"Paste") action:@selector(paste:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Find Selected Text in Project\u2026", @"Find Selected Text in Project with ellipsis") action:@selector(findSelectedTextInProject:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Jump to Caller", @"Jump to Caller") action:@selector(jumpToCaller:) keyEquivalent:@""];
		[retval addItemWithTitle:NSLocalizedString(@"Jump to Definition", @"Jump to Definition") action:@selector(jumpToDefinition:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Shift Left", @"Shift Left") action:@selector(shiftLeft:) keyEquivalent:@""];
		[retval addItemWithTitle:NSLocalizedString(@"Shift Right", @"Shift Right") action:@selector(shiftRight:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Comment/Uncomment Selection", @"Comment/Uncomment Selection") action:@selector(commentUncommentSelection:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:@"" action:@selector(toggleBookmarkAtCurrentLine:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Add Breakpoint at Current Line", @"Add Breakpoint at Current Line") action:@selector(toggleBreakpointAtCurrentLine:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Reveal in Project Navigator", @"Reveal in Project Navigator") action:@selector(revealInProjectNavigator:) keyEquivalent:@""];
		[retval addItemWithTitle:NSLocalizedString(@"Show in Finder", @"Show in Finder") action:@selector(showInFinder:) keyEquivalent:@""];
		[retval addItem:[NSMenuItem separatorItem]];
		[retval addItemWithTitle:NSLocalizedString(@"Open in Separate Editor", @"Open in Separate Editor") action:@selector(openInSeparateEditor:) keyEquivalent:@""];
		
	});
	return retval;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
	NSMenu *retval = [super menuForEvent:event];
	if (retval)
		retval = [[self class] defaultMenu];
	return retval;
}

- (void)viewDidMoveToWindow {
	[super viewDidMoveToWindow];
	
	[[RSToolTipManager sharedManager] removeView:self];
	
	[[NSNotificationCenter defaultCenter] removeObserver:_windowDidBecomeKeyObservingToken];
	[[NSNotificationCenter defaultCenter] removeObserver:_windowDidResignKeyObservingToken];
	
	if ([self window]) {
		[[RSToolTipManager sharedManager] addView:self];
		
		_windowDidBecomeKeyObservingToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidBecomeKeyNotification object:[self window] queue:nil usingBlock:^(NSNotification *note) {
			[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
			
			[self _highlightEnclosedMacroArguments];
		}];
		_windowDidResignKeyObservingToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignKeyNotification object:[self window] queue:nil usingBlock:^(NSNotification *note) {
			[self setAutoHighlightArgumentsRanges:nil];
			[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
		}];
	}
}

- (void)drawViewBackgroundInRect:(NSRect)rect {
	[super drawViewBackgroundInRect:rect];
	
	[self _drawPageGuideInRect:rect];
	
	[self _drawFocusFollowsCodeRectsInRect:rect];
	
	[self _drawCurrentLineHighlightInRect:rect];
	
	[self _drawVisibleBuildIssuesInRect:rect];
	
	if ([[self autoHighlightArgumentsRanges] count]) {
		[[self autoHighlightArgumentsRanges] enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
			NSUInteger rectCount;
			NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:range withinSelectedCharacterRange:NSNotFoundRange inTextContainer:[self textContainer] rectCount:&rectCount];
			
			if (!rectCount)
				return;
			
			NSRect argumentRect = rects[0];
			
			if (!NSIntersectsRect(argumentRect, rect) || ![self needsToDrawRect:argumentRect])
				return;
			
			NSBezierPath *path = [NSBezierPath bezierPathWithRect:argumentRect];
			
			CGFloat dash[2];
			
			dash[0] = 3.0;
			dash[1] = 1.0;
			
			[path setLineDash:dash count:2 phase:0.0];
			[[NSColor darkGrayColor] setStroke];
			[path strokeInside];
		}];
	}
}

- (NSRange)rangeForUserCompletion {
	static NSRegularExpression *regex;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		regex = [[NSRegularExpression alloc] initWithPattern:@"[A-Za-z0-9_!?.#]+" options:0 error:NULL];
	});
	
	NSRange selectedRange = [self selectedRange];
	__block NSRange completionRange = NSNotFoundRange;
	NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
	
	[regex enumerateMatchesInString:[self string] options:0 range:lineRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
		if (NSLocationInOrEqualToRange(selectedRange.location, [result range])) {
			completionRange = [result range];
			*stop = YES;
		}
	}];
	
	return completionRange;
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedCharRange granularity:(NSSelectionGranularity)granularity {
	if (granularity != NSSelectByWord)
		return proposedCharRange;
	
	// look for a symbol inside the proposed range
	NSRange symbolRange = [[self string] symbolRangeForRange:proposedCharRange];
	if (symbolRange.location == NSNotFound)
		return proposedCharRange;
	return symbolRange;
}

- (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
	if (!stillSelectingFlag && ([ranges count] == 1)) {
        NSRange range = [[ranges objectAtIndex:0] rangeValue];
        NSTextStorage *textStorage = [self textStorage];
        NSUInteger length = [textStorage length];
		
        if ((range.location < length) && ([[ranges objectAtIndex:0] rangeValue].length == 0)) { // make sure it's not inside lineFoldingAttributeName
            NSNumber *value = [textStorage attribute:WCLineFoldingAttributeName atIndex:range.location effectiveRange:NULL];
			
            if (value && [value boolValue]) {
                NSRange effectiveRange;
                (void)[textStorage attribute:WCLineFoldingAttributeName atIndex:range.location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, length)];
				
                if (range.location != effectiveRange.location) { // it's not at the beginning. should be adjusted
                    range.location = ((affinity == NSSelectionAffinityUpstream) ? effectiveRange.location : NSMaxRange(effectiveRange));
                    [super setSelectedRange:range];
                    return;
                }
            }
        }   
    }
	
	[super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];
	
	if (stillSelectingFlag) {
		[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
		[[[self enclosingScrollView] verticalRulerView] setNeedsDisplay:YES];
	}
}

- (NSString *)preferredPasteboardTypeFromArray:(NSArray *)availableTypes restrictedToTypesFromArray:(NSArray *)allowedTypes {
	if ([availableTypes containsObject:WCPasteboardTypeArgumentPlaceholderCell])
		return WCPasteboardTypeArgumentPlaceholderCell;
	return [super preferredPasteboardTypeFromArray:availableTypes restrictedToTypesFromArray:allowedTypes];
}

- (NSArray *)acceptableDragTypes; {
	NSMutableArray *types = [[[super acceptableDragTypes] mutableCopy] autorelease];
	
	[types insertObject:WCPasteboardTypeArgumentPlaceholderCell atIndex:0];
	
	return types;
}
- (NSArray *)readablePasteboardTypes {
	NSMutableArray *types = [[[super readablePasteboardTypes] mutableCopy] autorelease];
	
	[types insertObject:WCPasteboardTypeArgumentPlaceholderCell atIndex:0];
	
	return types;
}

- (NSArray *)writablePasteboardTypes {
	NSMutableArray *types = [[[super writablePasteboardTypes] mutableCopy] autorelease];
	
	[types insertObject:WCPasteboardTypeArgumentPlaceholderCell atIndex:0];
	
	return types;
}
 
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard type:(NSString *)type {
	if ([type isEqualToString:WCPasteboardTypeArgumentPlaceholderCell]) {
		WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
		NSArray *plistArray = [pboard propertyListForType:WCPasteboardTypeArgumentPlaceholderCell];
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[currentTheme plainTextFont],NSFontAttributeName,[currentTheme plainTextColor],NSForegroundColorAttributeName,[WCSourceTextStorage defaultParagraphStyle],NSParagraphStyleAttributeName, nil];
		NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:@"" attributes:attributes] autorelease];
		
		for (id plist in plistArray) {
			if ([plist isKindOfClass:[NSString class]])
				[string appendAttributedString:[[[NSAttributedString alloc] initWithString:plist attributes:attributes] autorelease]];
			else {
				NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithFileWrapper:nil] autorelease];
				WCArgumentPlaceholderCell *cell = [[[WCArgumentPlaceholderCell alloc] initWithPlistRepresentation:plist] autorelease];
				
				[attachment setAttachmentCell:cell];
				
				[string appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
			}
		}
		
		if ([self shouldChangeTextInRange:[self rangeForUserTextChange] replacementString:[string string]]) {
			[[self textStorage] replaceCharactersInRange:[self rangeForUserTextChange] withAttributedString:string];
			[self didChangeText];
			
			return YES;
		}
		return NO;
	}
	return [super readSelectionFromPasteboard:pboard type:type];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types {
	if ([types containsObject:WCPasteboardTypeArgumentPlaceholderCell]) {
		NSMutableArray *plistArray = [NSMutableArray arrayWithCapacity:0];
		NSMutableString *string = [NSMutableString stringWithCapacity:0];
		
		[[self textStorage] enumerateAttributesInRange:[self selectedRange] options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
			NSString *substring;
			id plist;
			
			if ([[[attrs objectForKey:NSAttachmentAttributeName] attachmentCell] isKindOfClass:[WCArgumentPlaceholderCell class]]) {
				plist = [(WCArgumentPlaceholderCell *)[[attrs objectForKey:NSAttachmentAttributeName] attachmentCell] plistRepresentation];
				substring = [plist objectForKey:@"stringValue"];
			}
			else {
				substring = [[self string] substringWithRange:range];
				plist = substring;
			}
			
			[plistArray addObject:plist];
			[string appendString:substring];
		}];
		
		NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
		
		[item setPropertyList:plistArray forType:WCPasteboardTypeArgumentPlaceholderCell];
		[item setString:string forType:NSPasteboardTypeString];
		
		[pboard clearContents];
		
		return [pboard writeObjects:[NSArray arrayWithObjects:item, nil]];
	}
	return [super writeSelectionToPasteboard:pboard types:types];
}

#pragma mark IBActions
- (IBAction)complete:(id)sender {
	[[WCCompletionWindowController sharedWindowController] showCompletionWindowControllerForSourceTextView:self];
}

- (IBAction)insertTab:(id)sender {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardUseTabToNavigateArgumentPlaceholdersKey]) {
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:WCEditorIndentUsingKey] unsignedIntegerValue] == WCEditorIndentUsingTabs)
			[super insertTab:nil];
		else {
			NSUInteger tabWidth = [[[NSUserDefaults standardUserDefaults] objectForKey:WCEditorTabWidthKey] unsignedIntegerValue];
			NSMutableString *spacesString = [NSMutableString stringWithCapacity:tabWidth];
			NSUInteger charIndex;
			
			for (charIndex=0; charIndex<tabWidth; charIndex++)
				[spacesString appendString:@" "];
			
			[super insertText:spacesString];
		}
		return;
	}
	
	NSRange placeholderRange = [[self textStorage] nextArgumentPlaceholderRangeForRange:[self selectedRange] inRange:[[self string] lineRangeForRange:[self selectedRange]] wrapAround:YES];
	if (placeholderRange.location == NSNotFound) {
		[super insertTab:sender];
		return;
	}
	
	[self setSelectedRange:placeholderRange];
}

- (IBAction)insertBacktab:(id)sender {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardUseTabToNavigateArgumentPlaceholdersKey]) {
		[super insertBacktab:nil];
		return;
	}
	
	NSRange placeholderRange = [[self textStorage] previousArgumentPlaceholderRangeForRange:[self selectedRange] inRange:[[self string] lineRangeForRange:[self selectedRange]] wrapAround:YES];
	if (placeholderRange.location == NSNotFound) {
		[super insertBacktab:sender];
		return;
	}
	
	[self setSelectedRange:placeholderRange];
}

- (IBAction)insertNewline:(id)sender {
	WCEditorDefaultLineEndings lineEnding = [[[NSUserDefaults standardUserDefaults] objectForKey:WCEditorDefaultLineEndingsKey] unsignedIntValue];
	switch (lineEnding) {
		case WCEditorDefaultLineEndingsUnix:
			[super insertNewline:nil];
			break;
		case WCEditorDefaultLineEndingsMacOS:
			[super insertText:[NSString macOSLineEndingString]];
			break;
		case WCEditorDefaultLineEndingsWindows:
			[super insertText:[NSString windowsLineEndingString]];
			break;
		default:
			break;
	}	
	
	if ([self _handleAutoIndentAfterLabel])
		return;
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:WCEditorAutomaticallyIndentAfterNewlinesKey]) {
		NSString *previousLineWhitespaceString;
		NSScanner *previousLineScanner = [[[NSScanner alloc] initWithString:[[self string] substringWithRange:[[self string] lineRangeForRange:NSMakeRange([self selectedRange].location - 1, 0)]]] autorelease];
		[previousLineScanner setCharactersToBeSkipped:nil];
		
		if ([previousLineScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&previousLineWhitespaceString])
			[self insertText:previousLineWhitespaceString];
	}
}

- (void)insertText:(id)insertString {
	[self setAutoHighlightArgumentsRanges:nil];
	
	[super insertText:insertString];
	
	[self _insertMatchingBraceWithString:insertString];
	
	[self _handleAutoCompletionWithString:insertString];
}

- (void)deleteBackward:(id)sender {
	if ([self selectedRange].length) {
		[super deleteBackward:nil];
		return;
	}
	
	NSRange foldRange = [(WCSourceTextStorage *)[self textStorage] foldRangeForRange:NSMakeRange([self selectedRange].location-1, 0)];
	
	if (foldRange.location == NSNotFound) {
		[super deleteBackward:nil];
		return;
	}
	
	if ([self shouldChangeTextInRange:foldRange replacementString:@""]) {
		[self replaceCharactersInRange:foldRange withString:@""];
		[self didChangeText];
	}
}
- (void)deleteForward:(id)sender {
	if ([self selectedRange].length) {
		[super deleteForward:nil];
		return;
	}
	
	NSRange foldRange = [(WCSourceTextStorage *)[self textStorage] foldRangeForRange:[self selectedRange]];
	
	if (foldRange.location == NSNotFound) {
		[super deleteForward:nil];
		return;
	}
	
	if ([self shouldChangeTextInRange:foldRange replacementString:@""]) {
		[self replaceCharactersInRange:foldRange withString:@""];
		[self didChangeText];
	}
}
#pragma mark NSObject+WCExtensions
- (NSSet *)userDefaultsKeyPathsToObserve {
	return [NSSet setWithObjects:WCEditorShowCurrentLineHighlightKey,WCEditorWrapLinesToEditorWidthKey,WCEditorPageGuideColumnNumberKey,WCEditorShowPageGuideAtColumnKey,WCEditorFocusFollowsSelectionKey, nil];
}
#pragma mark NSKeyValueObserving
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:[kUserDefaultsKeyPathPrefix stringByAppendingString:WCEditorShowCurrentLineHighlightKey]] ||
		[keyPath isEqualToString:[kUserDefaultsKeyPathPrefix stringByAppendingString:WCEditorPageGuideColumnNumberKey]] ||
		[keyPath isEqualToString:[kUserDefaultsKeyPathPrefix stringByAppendingString:WCEditorShowPageGuideAtColumnKey]] ||
		[keyPath isEqualToString:[kUserDefaultsKeyPathPrefix stringByAppendingString:WCEditorFocusFollowsSelectionKey]]) {
		
		[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
	}
	else if ([keyPath isEqualToString:[kUserDefaultsKeyPathPrefix stringByAppendingFormat:WCEditorWrapLinesToEditorWidthKey]])
		[self setWrapLines:[[NSUserDefaults standardUserDefaults] boolForKey:WCEditorWrapLinesToEditorWidthKey]];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
#pragma mark NSMenuValidation
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if ([menuItem action] == @selector(jumpInFile:)) {
		WCSourceScanner *sourceScanner = [[self delegate] sourceScannerForSourceTextView:self];
		
		[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Jump in \"%@\"", @"jump in file menu item title format string"),[[sourceScanner delegate] fileDisplayNameForSourceScanner:sourceScanner]]];
	}
	else if ([menuItem action] == @selector(toggleBookmarkAtCurrentLine:)) {
		if ([[self sourceTextStorage] bookmarkAtLineNumber:[[self string] lineNumberForRange:[self selectedRange]]])
			[menuItem setTitle:NSLocalizedString(@"Remove Bookmark at Current Line", @"Remove Bookmark at Current Line")];
		else
			[menuItem setTitle:NSLocalizedString(@"Add Bookmark at Current Line", @"Add Bookmark at Current Line")];
	}
	else if ([menuItem action] == @selector(openInSeparateEditor:)) {
		if (![[self delegate] projectDocumentForSourceTextView:self])
			return NO;
	}
	else if ([menuItem action] == @selector(findSelectedTextInProject:)) {		
		if (![self selectedRange].length)
			return NO;
	}
	else if ([menuItem action] == @selector(toggleBreakpointAtCurrentLine:)) {
		WCProjectDocument *projectDocument = [[self delegate] projectDocumentForSourceTextView:self];
		
		if (!projectDocument)
			return NO;
		
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		
		WCFileBreakpoint *fileBreakpoint = [[[self delegate] fileBreakpointsForSourceTextView:self] fileBreakpointForRange:NSMakeRange(lineRange.location, 0)];
		
		if (fileBreakpoint)
			[menuItem setTitle:NSLocalizedString(@"Remove Breakpoint at Current Line", @"Remove Breakpoint at Current Line")];
		else
			[menuItem setTitle:NSLocalizedString(@"Add Breakpoint at Current Line", @"Add Breakpoint at Current Line")];
	}
	return [super validateMenuItem:menuItem];
}

#pragma mark NSUserInterfaceValidations
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem {
	return [super validateUserInterfaceItem:anItem];
}
#pragma mark RSToolTipView
- (NSArray *)toolTipManager:(RSToolTipManager *)toolTipManager toolTipProvidersForToolTipAtPoint:(NSPoint)toolTipPoint {
	NSUInteger charIndex = [self characterIndexForInsertionAtPoint:toolTipPoint];
	if (charIndex >= [[self string] length])
		return nil;
	
	NSRange foldRange = [[self sourceTextStorage] foldRangeForRange:NSMakeRange(charIndex, 0)];
	if (foldRange.location != NSNotFound) {
		WCFold *fold = [[[[self delegate] sourceScannerForSourceTextView:self] folds] deepestFoldForRange:NSMakeRange(foldRange.location, 0)];
		if (fold)
			return [NSArray arrayWithObjects:fold, nil];
		return nil;
	}
	else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[[self string] characterAtIndex:charIndex]])
		return nil;
	
	NSRange toolTipRange = [[self string] symbolRangeForRange:NSMakeRange(charIndex, 0)];
	if (toolTipRange.location == NSNotFound)
		return nil;
	
	WCSourceToken *token = [[[self delegate] sourceTokensForSourceTextView:self] sourceTokenForRange:toolTipRange];
	if (NSLocationInRange(toolTipRange.location, [token range]) &&
		([token type] == WCSourceTokenTypeComment || [token type] == WCSourceTokenTypeString))
		return nil;
	
	NSArray *symbols = [[self delegate] sourceTextView:self sourceSymbolsForSymbolName:[[self string] substringWithRange:toolTipRange]];
	if (![symbols count])
		return nil;
	return symbols;
}
#pragma mark WCJumpInDataSource
- (NSArray *)jumpInItems {
	return [[self delegate] sourceSymbolsForSourceTextView:self];
}
- (NSTextView *)jumpInTextView {
	return self;
}
- (NSString *)jumpInFileName {
	WCSourceScanner *sourceScanner = [[self delegate] sourceScannerForSourceTextView:self];
	
	return [[sourceScanner delegate] fileDisplayNameForSourceScanner:sourceScanner];
}

#pragma mark *** Public Methods ***
#pragma mark IBActions
- (IBAction)jumpToNextPlaceholder:(id)sender; {
	NSRange placeholderRange = [[self textStorage] nextArgumentPlaceholderRangeForRange:[self selectedRange] inRange:NSMakeRange(0, [[self string] length]) wrapAround:YES];
	if (placeholderRange.location == NSNotFound) {
		NSBeep();
		return;
	}
	
	[self setSelectedRange:placeholderRange];
}
- (IBAction)jumpToPreviousPlaceholder:(id)sender; {
	NSRange placeholderRange = [[self textStorage] previousArgumentPlaceholderRangeForRange:[self selectedRange] inRange:NSMakeRange(0, [[self string] length]) wrapAround:YES];
	if (placeholderRange.location == NSNotFound) {
		NSBeep();
		return;
	}
	
	[self setSelectedRange:placeholderRange];
}
- (IBAction)findSelectedTextInProject:(id)sender; {
	WCProjectDocument *projectDocument = [[self delegate] projectDocumentForSourceTextView:self];
	WCSearchNavigatorViewController *viewController = [[projectDocument projectWindowController] searchNavigatorViewController];
	NSString *searchString = [[self string] substringWithRange:[self selectedRange]];
	
	[[[projectDocument projectWindowController] navigatorControl] setSelectedItemIdentifier:@"search"];
	[viewController setSearchString:searchString];
	[viewController search:nil];
}
- (IBAction)jumpToLine:(id)sender; {
	[[WCJumpToLineWindowController sharedWindowController] showJumpToLineWindowForTextView:self];
}
- (IBAction)jumpToSelection:(id)sender; {
	[self scrollRangeToVisible:[self selectedRange]];
}
- (IBAction)jumpToCaller:(id)sender; {
	NSRange symbolRange = [[self string] symbolRangeForRange:[self selectedRange]];
	if (symbolRange.location == NSNotFound) {
		NSBeep();
		
		[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Not Found", @"Symbol Not Found") centeredInView:[self enclosingScrollView]];
		
		return;
	}
	
	NSArray *symbols = [[self delegate] sourceTextView:self sourceSymbolsForSymbolName:[[self string] substringWithRange:symbolRange]];
	if (![symbols count]) {
		NSBeep();
		
		[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Not Found", @"Symbol Not Found") centeredInView:[self enclosingScrollView]];
		return;
	}
	
	WCSourceSymbol *symbol = [symbols objectAtIndex:0];
	NSString *symbolName = [[symbol name] lowercaseString];
	
	if ([[self delegate] projectDocumentForSourceTextView:self]) {
		WCProjectDocument *projectDocument = [[self delegate] projectDocumentForSourceTextView:self];
		NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
		[menu setFont:[NSFont menuFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		[menu setShowsStateColumn:NO];
		NSString *callPattern = [NSString stringWithFormat:@"\\b(?:call|jp|jr)\\s+%@\\b",symbolName];
		NSRegularExpression *callRegex = [NSRegularExpression regularExpressionWithPattern:callPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		NSString *callWithConditionalPattern = [NSString stringWithFormat:@"\\b(?:call|jp|jr)\\s+(?:nz|nv|nc|po|pe|c|p|m|n|z|v),\\s*%@\\b",symbolName];
		NSRegularExpression *callWithConditionalRegex = [NSRegularExpression regularExpressionWithPattern:callWithConditionalPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		
		for (WCSourceFileDocument *sfDocument in [projectDocument sourceFileDocuments]) {
			WCSourceScanner *sourceScanner = [sfDocument sourceScanner];
			
			// if the symbol name doesn't show up in the set of called labels, skip the document
			if (![[sourceScanner calledLabels] containsObject:symbolName])
				continue;
			
			NSMutableArray *textCheckingResults = [NSMutableArray arrayWithCapacity:0];
			WCSourceTextStorage *textStorage = [sfDocument textStorage];
			NSString *string = [textStorage string];
			
			// collect the matches from each regex in our array
			[textCheckingResults addObjectsFromArray:[callRegex matchesInString:string options:0 range:NSMakeRange(0, [string length])]];
			[textCheckingResults addObjectsFromArray:[callWithConditionalRegex matchesInString:string options:0 range:NSMakeRange(0, [string length])]];
			
			if ([textCheckingResults count]) {
				// if we got any results insert our header menu item before we start inserting the match items
				NSString *fileDisplayName = [[sourceScanner delegate] fileDisplayNameForSourceScanner:sourceScanner];
                NSMenuItem *fileMenuItem = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ \u2192 (%@)", @"jump to caller file menu item title format string"),fileDisplayName,[[[sfDocument fileURL] path] stringByAbbreviatingWithTildeInPath]] action:NULL keyEquivalent:@""];
				
				[fileMenuItem setImage:[[sfDocument fileURL] fileIcon]];
				[[fileMenuItem image] setSize:NSSmallSize];
				
				for (NSTextCheckingResult *result in textCheckingResults) {
					NSString *resultSymbolName = [[string substringWithRange:[result range]] stringByReplacingTabsWithSpaces];
					WCSourceSymbol *resultSymbol = [WCSourceSymbol sourceSymbolOfType:[symbol type] range:[result range] name:resultSymbolName];
					
					[resultSymbol setSourceScanner:sourceScanner];
					
					NSUInteger lineNumber = [textStorage lineNumberForRange:[result range]];
					NSMenuItem *item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ \u2192 (%@:%lu)", @"jump to caller menu item title format string"),[resultSymbol name],fileDisplayName,lineNumber+1] action:@selector(_jumpToCallersMenuClicked:) keyEquivalent:@""];
					
					[item setImage:[resultSymbol icon]];
					[[item image] setSize:NSSmallSize];
					[item setTarget:self];
					[item setRepresentedObject:resultSymbol];
					[item setIndentationLevel:1];
				}
			}
		}
		
		if (![menu numberOfItems]) {
			NSBeep();
			
			[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Caller(s) Not Found", @"Symbol Caller(s) Not Found") centeredInView:[self enclosingScrollView]];
			return;
		}
		else if ([menu numberOfItems] == 2) {
			WCSourceSymbol *symbolToJumpTo = [[[menu itemArray] lastObject] representedObject];
			
			[[self delegate] handleJumpToDefinitionForSourceTextView:self sourceSymbol:symbolToJumpTo];
		}
		else {
			NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:symbolRange.location];
			NSRect lineRect = [[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
			NSPoint selectedPoint = [[self layoutManager] locationForGlyphAtIndex:glyphIndex];
			
			lineRect.origin.y += lineRect.size.height;
			lineRect.origin.x += selectedPoint.x;
			
			NSCursor *currentCursor = [[self enclosingScrollView] documentCursor];
			
			if (![menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:lineRect.origin inView:self])
				[currentCursor set];
		}
	}
	else {
		WCSourceScanner *sourceScanner = [[self delegate] sourceScannerForSourceTextView:self];
		
		if (![[sourceScanner calledLabels] containsObject:symbolName]) {
			NSBeep();
			
			[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Caller(s) Not Found", @"Symbol Caller(s) Not Found") centeredInView:[self enclosingScrollView]];
			return;
		}
		
		NSMutableArray *textCheckingResults = [NSMutableArray arrayWithCapacity:0];
		NSString *callPattern = [NSString stringWithFormat:@"\\b(?:call|jp|jr)\\s+%@\\b",symbolName];
		NSRegularExpression *callRegex = [NSRegularExpression regularExpressionWithPattern:callPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		
		[textCheckingResults addObjectsFromArray:[callRegex matchesInString:[self string] options:0 range:NSMakeRange(0, [[self string] length])]];
		
		NSString *callWithConditionalPattern = [NSString stringWithFormat:@"\\b(?:call|jp|jr)\\s+(?:nz|nv|nc|po|pe|c|p|m|n|z|v),\\s*%@\\b",symbolName];
		NSRegularExpression *callWithConditionalRegex = [NSRegularExpression regularExpressionWithPattern:callWithConditionalPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		
		[textCheckingResults addObjectsFromArray:[callWithConditionalRegex matchesInString:[self string] options:0 range:NSMakeRange(0, [[self string] length])]];
		
		if (![textCheckingResults count]) {
			NSBeep();
			
			[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Caller(s) Not Found", @"Symbol Caller(s) Not Found") centeredInView:[self enclosingScrollView]];
			return;
		}
		else if ([textCheckingResults count] == 1) {
			NSTextCheckingResult *result = [textCheckingResults lastObject];
			NSString *resultName = [[[self string] substringWithRange:[result range]] stringByReplacingTabsWithSpaces];
			WCSourceSymbol *resultSymbol = [WCSourceSymbol sourceSymbolOfType:[symbol type] range:[result range] name:resultName];
			
			[resultSymbol setSourceScanner:sourceScanner];
			
			[[self delegate] handleJumpToDefinitionForSourceTextView:self sourceSymbol:resultSymbol];
		}
		else {
			NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
			[menu setFont:[NSFont menuFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
			[menu setShowsStateColumn:NO];
			
			for (NSTextCheckingResult *result in textCheckingResults) {
				WCSourceSymbol *resultSymbol = [WCSourceSymbol sourceSymbolOfType:[symbol type] range:[result range] name:[[self string] substringWithRange:[result range]]];
				
				[resultSymbol setSourceScanner:sourceScanner];
				
				NSString *fileDisplayName = [[sourceScanner delegate] fileDisplayNameForSourceScanner:sourceScanner];
				NSUInteger lineNumber = [[self textStorage] lineNumberForRange:[result range]];
				NSMenuItem *item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ \u2192 (%@:%lu)", @"jump to callers menu item title format string"),[resultSymbol name],fileDisplayName,lineNumber+1] action:@selector(_jumpToCallersMenuClicked:) keyEquivalent:@""];
				
				[item setImage:[resultSymbol icon]];
				[[item image] setSize:NSSmallSize];
				[item setTarget:self];
				[item setRepresentedObject:resultSymbol];
			}
			
			NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:symbolRange.location];
			NSRect lineRect = [[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
			NSPoint selectedPoint = [[self layoutManager] locationForGlyphAtIndex:glyphIndex];
			
			lineRect.origin.y += lineRect.size.height;
			lineRect.origin.x += selectedPoint.x;
			
			NSCursor *currentCursor = [[self enclosingScrollView] documentCursor];
			
			if (![menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:lineRect.origin inView:self])
				[currentCursor set];
		}
	}
}
- (IBAction)jumpToDefinition:(id)sender; {
	if ([[self delegate] projectDocumentForSourceTextView:self]) {
		NSDictionary *filePathsToFiles = [[[self delegate] projectDocumentForSourceTextView:self] filePathsToFiles];
		__block WCFile *includedFile = nil;
		
		[[WCSourceScanner includesRegularExpression] enumerateMatchesInString:[self string] options:0 range:[[self string] lineRangeForRange:[self selectedRange]] usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSString *fileName = [[self string] substringWithRange:[result rangeAtIndex:1]];
            
			[filePathsToFiles enumerateKeysAndObjectsUsingBlock:^(NSString *filePath, WCFile *file, BOOL *stop) {
				if ([filePath hasSuffix:fileName]) {
					includedFile = file;
					*stop = YES;
				}
			}];
		}];
		
		if (includedFile) {
			[[self delegate] handleJumpToDefinitionForSourceTextView:self file:includedFile];
			return;
		}
	}
	
	NSRange symbolRange = [[self string] symbolRangeForRange:[self selectedRange]];
	if (symbolRange.location == NSNotFound) {
		NSBeep();
		
		[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Not Found", @"Symbol Not Found") centeredInView:[self enclosingScrollView]];
		
		return;
	}
	
	NSArray *symbols = [[self delegate] sourceTextView:self sourceSymbolsForSymbolName:[[self string] substringWithRange:symbolRange]];
	if (![symbols count]) {
		NSBeep();
		
		[[RSBezelWidgetManager sharedWindowController] showString:NSLocalizedString(@"Symbol Not Found", @"Symbol Not Found") centeredInView:[self enclosingScrollView]];
		return;
	}
	else if ([symbols count] == 1) {
		WCSourceSymbol *symbol = [symbols lastObject];
		
		[[self delegate] handleJumpToDefinitionForSourceTextView:self sourceSymbol:symbol];
	}
	else {
		NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
		[menu setFont:[NSFont menuFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		[menu setShowsStateColumn:NO];
		
		for (WCSourceSymbol *symbol in symbols) {
			NSString *fileDisplayName = [[[symbol sourceScanner] delegate] fileDisplayNameForSourceScanner:[symbol sourceScanner]];
			NSMenuItem *item = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ \u2192 (%@:%lu)", @"jump to definition contextual menu format string"),[symbol name],fileDisplayName,[symbol lineNumber]+1] action:@selector(_symbolMenuClicked:) keyEquivalent:@""];
			
			[item setImage:[symbol icon]];
			[[item image] setSize:NSSmallSize];
			[item setTarget:self];
			[item setRepresentedObject:symbol];
		}
		
		NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:symbolRange.location];
		NSRect lineRect = [[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
		NSPoint selectedPoint = [[self layoutManager] locationForGlyphAtIndex:glyphIndex];
		
		lineRect.origin.y += lineRect.size.height;
		lineRect.origin.x += selectedPoint.x;
		
		NSCursor *currentCursor = [[self enclosingScrollView] documentCursor];
		
		if (![menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:lineRect.origin inView:self])
			[currentCursor set];
	}
}
- (IBAction)jumpInFile:(id)sender; {
	[[WCJumpInWindowController sharedWindowController] showJumpInWindowWithDataSource:self];
}
- (IBAction)shiftLeft:(id)sender; {
	if ([self selectedRange].length) {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		
		[[lineString string] enumerateSubstringsInRange:NSMakeRange(0, [lineString length]) options:NSStringEnumerationByLines|NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
			NSRange wordRange = [substring rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]];
			
			if (wordRange.location == NSNotFound)
				return;
			else if ([substring rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:0 range:NSMakeRange(0, [substring length]-wordRange.location)].location == NSNotFound)
				return;
			
			[lineString deleteCharactersInRange:NSMakeRange(substringRange.location, 1)];
		}];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			[self setSelectedRange:oldRange];
		}
	}
	else {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSRange wordRange = [[lineString string] rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]];
		
		if (wordRange.location == NSNotFound) {
			NSBeep();
			return;
		}
		else if ([[lineString string] rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:0 range:NSMakeRange(0, [lineString length]-wordRange.location)].location == NSNotFound) {
			NSBeep();
			return;
		}
		
		[lineString deleteCharactersInRange:NSMakeRange(0, 1)];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			oldRange.location--;
			[self setSelectedRange:oldRange];
		}
	}
}
- (IBAction)shiftRight:(id)sender; {
	if ([self selectedRange].length) {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[[[WCFontAndColorThemeManager sharedManager] currentTheme] plainTextFont],NSFontAttributeName, nil];
		
		[[lineString string] enumerateSubstringsInRange:NSMakeRange(0, [lineString length]) options:NSStringEnumerationByLines|NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
			NSRange wordRange = [substring rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]];
			
			if (wordRange.location == NSNotFound)
				return;
			else if ([substring rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:0 range:NSMakeRange(0, [substring length]-wordRange.location)].location == NSNotFound)
				return;
			
			[lineString insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\t" attributes:attributes] autorelease] atIndex:substringRange.location];
		}];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			[self setSelectedRange:oldRange];
		}
	}
	else {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSRange wordRange = [[lineString string] rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]];
		
		if (wordRange.location == NSNotFound) {
			NSBeep();
			return;
		}
		else if ([[lineString string] rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:0 range:NSMakeRange(0, [lineString length]-wordRange.location)].location == NSNotFound) {
			NSBeep();
			return;
		}
		
		[lineString insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\t" attributes:[NSDictionary dictionaryWithObjectsAndKeys:[[[WCFontAndColorThemeManager sharedManager] currentTheme] plainTextFont],NSFontAttributeName, nil]] autorelease] atIndex:0];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			oldRange.location++;
			[self setSelectedRange:oldRange];
		}
	}
}

- (IBAction)commentUncommentSelection:(id)sender; {
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^;+" options:NSRegularExpressionAnchorsMatchLines error:NULL];
	if ([regex rangeOfFirstMatchInString:[self string] options:0 range:[[self string] lineRangeForRange:[self selectedRange]]].location == NSNotFound)
		[self commentSelection:nil];
	else
		[self uncommentSelection:nil];
}
- (IBAction)commentSelection:(id)sender; {
	if ([self selectedRange].length) {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSString *commentString = NSLocalizedString(@";;", @"comment string");
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[[[WCFontAndColorThemeManager sharedManager] currentTheme] plainTextFont],NSFontAttributeName, nil];
		__block NSUInteger numberOfComments = 0;
		
		[[lineString string] enumerateSubstringsInRange:NSMakeRange(0, [lineString length]) options:NSStringEnumerationByLines|NSStringEnumerationSubstringNotRequired|NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
			[lineString insertAttributedString:[[[NSAttributedString alloc] initWithString:commentString attributes:attributes] autorelease] atIndex:substringRange.location];
			numberOfComments++;
		}];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			oldRange.location += [commentString length];
			oldRange.length += (--numberOfComments)*[commentString length];
			[self setSelectedRange:oldRange];
		}
	}
	else {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSString *commentString = NSLocalizedString(@";;", @"comment string");
		
		[lineString insertAttributedString:[[[NSAttributedString alloc] initWithString:commentString attributes:[NSDictionary dictionaryWithObjectsAndKeys:[[[WCFontAndColorThemeManager sharedManager] currentTheme] plainTextFont],NSFontAttributeName, nil]] autorelease] atIndex:0];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			oldRange.location += [commentString length];
			[self setSelectedRange:oldRange];
		}
	}
}
- (IBAction)uncommentSelection:(id)sender; {
	if ([self selectedRange].length) {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSString *commentString = NSLocalizedString(@";;", @"comment string");
		__block NSUInteger numberOfComments = 0;
		
		[[lineString string] enumerateSubstringsInRange:NSMakeRange(0, [lineString length]) options:NSStringEnumerationByLines|NSStringEnumerationReverse usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
			NSRange commentRange = [[lineString string] rangeOfString:commentString options:0 range:substringRange];
			if (commentRange.location == NSNotFound || commentRange.location != substringRange.location)
				return;
			
			[lineString deleteCharactersInRange:NSMakeRange(substringRange.location, [commentString length])];
			numberOfComments++;
		}];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			oldRange.location -= [commentString length];
			oldRange.length -= (--numberOfComments)*[commentString length];
			[self setSelectedRange:oldRange];
		}
	}
	else {
		NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
		NSMutableAttributedString *lineString = [[[[self textStorage] attributedSubstringFromRange:lineRange] mutableCopy] autorelease];
		NSString *commentString = NSLocalizedString(@";;", @"comment string");
		NSRange commentRange = [[lineString string] rangeOfString:commentString];
		
		if (commentRange.location == NSNotFound || commentRange.location != 0) {
			NSBeep();
			return;
		}
		
		[lineString deleteCharactersInRange:NSMakeRange(0, [commentString length])];
		
		NSRange oldRange = [self selectedRange];
		
		if ([self shouldChangeTextInRange:lineRange replacementString:[lineString string]]) {
			[[self textStorage] replaceCharactersInRange:lineRange withAttributedString:lineString];
			[self didChangeText];
			
			oldRange.location -= [commentString length];
			[self setSelectedRange:oldRange];
		}
	}
}

- (IBAction)toggleBookmarkAtCurrentLine:(id)sender; {
	if ([[self sourceTextStorage] bookmarkAtLineNumber:[[self string] lineNumberForRange:[self selectedRange]]])
		[self removeBookmarkAtCurrentLine:nil];
	else
		[self addBookmarkAtCurrentLine:nil];
}
- (IBAction)addBookmarkAtCurrentLine:(id)sender; {
	RSBookmark *bookmark = [RSBookmark bookmarkWithRange:[self selectedRange] visibleRange:NSEmptyRange textStorage:[self textStorage]];
	
	[[self sourceTextStorage] addBookmark:bookmark];
}
- (IBAction)removeBookmarkAtCurrentLine:(id)sender; {
	RSBookmark *bookmark = [[self sourceTextStorage] bookmarkAtLineNumber:[[self string] lineNumberForRange:[self selectedRange]]];
	
	[[self sourceTextStorage] removeBookmark:bookmark];
}
- (IBAction)removeAllBookmarks:(id)sender; {
	WCSourceScanner *scanner = [[self delegate] sourceScannerForSourceTextView:self];
	NSAlert *removeAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove All Bookmarks?", @"Remove All Bookmarks?") defaultButton:NSLocalizedString(@"Remove All Bookmarks", @"Remove All Bookmarks") alternateButton:LOCALIZED_STRING_CANCEL otherButton:nil informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all bookmarks in \"%@\"? This operation cannot be undone.", @"remove all bookmarks alert informative text format string"),[[scanner delegate] fileDisplayNameForSourceScanner:scanner]];
	
	[removeAlert OA_beginSheetModalForWindow:[self window] completionHandler:^(NSAlert *alert, NSInteger returnCode) {
		[[alert window] orderOut:nil];
		if (returnCode == NSAlertAlternateReturn)
			return;
		
		[(WCSourceTextStorage *)[self textStorage] removeAllBookmarks];
	}];
}

- (IBAction)jumpToNextBookmark:(id)sender; {
	NSArray *bookmarks = [(WCSourceTextStorage *)[self textStorage] bookmarksForRange:NSMakeRange(0, [[self string] length])];
	for (RSBookmark *bookmark in bookmarks) {
		if ([bookmark range].location > [self selectedRange].location) {
			[self setSelectedRange:[bookmark range]];
			[self scrollRangeToVisible:[bookmark range]];
			return;
		}
	}
	
	if ([bookmarks count] && !NSEqualRanges([[bookmarks firstObject] range], [self selectedRange])) {
		[self setSelectedRange:[[bookmarks firstObject] range]];
		[self scrollRangeToVisible:[[bookmarks firstObject] range]];
		
		[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicator"] centeredInView:[self enclosingScrollView]];
	}
	else
		NSBeep();
}
- (IBAction)jumpToPreviousBookmark:(id)sender; {
	NSArray *bookmarks = [(WCSourceTextStorage *)[self textStorage] bookmarksForRange:NSMakeRange(0, [[self string] length])];
	for (RSBookmark *bookmark in [bookmarks reverseObjectEnumerator]) {
		if ([bookmark range].location < [self selectedRange].location) {
			[self setSelectedRange:[bookmark range]];
			[self scrollRangeToVisible:[bookmark range]];
			return;
		}
	}
	
	if ([bookmarks count] && !NSEqualRanges([[bookmarks lastObject] range], [self selectedRange])) {
		[self setSelectedRange:[[bookmarks lastObject] range]];
		[self scrollRangeToVisible:[[bookmarks lastObject] range]];
		
		[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicatorReverse"] centeredInView:[self enclosingScrollView]];
	}
	else
		NSBeep();
}

- (IBAction)jumpToNextIssue:(id)sender; {
	NSArray *buildIssues = [[self delegate] buildIssuesForSourceTextView:self];
	
	for (WCBuildIssue *buildIssue in buildIssues) {
		if ([buildIssue range].location > [self selectedRange].location) {
			[self setSelectedRange:[buildIssue range]];
			[self scrollRangeToVisible:[buildIssue range]];
			return;
		}
	}
	
	if ([buildIssues count] && !NSEqualRanges([[buildIssues firstObject] range], [self selectedRange])) {
		[self setSelectedRange:[[buildIssues firstObject] range]];
		[self scrollRangeToVisible:[[buildIssues firstObject] range]];
		
		[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicator"] centeredInView:[self enclosingScrollView]];
	}
	else
		NSBeep();
}
- (IBAction)jumpToPreviousIssue:(id)sender; {
	NSArray *buildIssues = [[self delegate] buildIssuesForSourceTextView:self];
	
	for (WCBuildIssue *buildIssue in [buildIssues reverseObjectEnumerator]) {
		if ([buildIssue range].location < [self selectedRange].location) {
			[self setSelectedRange:[buildIssue range]];
			[self scrollRangeToVisible:[buildIssue range]];
			return;
		}
	}
	
	if ([buildIssues count] && !NSEqualRanges([[buildIssues lastObject] range], [self selectedRange])) {
		[self setSelectedRange:[[buildIssues lastObject] range]];
		[self scrollRangeToVisible:[[buildIssues lastObject] range]];
		
		[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicatorReverse"] centeredInView:[self enclosingScrollView]];
	}
	else
		NSBeep();
}

- (IBAction)toggleBreakpointAtCurrentLine:(id)sender; {
	NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
	WCFileBreakpoint *fileBreakpoint = [[[self delegate] fileBreakpointsForSourceTextView:self] fileBreakpointForRange:NSMakeRange(lineRange.location, 0)];
	
	if (fileBreakpoint)
		[[[[self delegate] projectDocumentForSourceTextView:self] breakpointManager] removeFileBreakpoint:fileBreakpoint];
	else {
		fileBreakpoint = [WCFileBreakpoint fileBreakpointWithRange:NSMakeRange(lineRange.location, 0) file:[[self delegate] fileForSourceTextView:self] projectDocument:[[self delegate] projectDocumentForSourceTextView:self]];
		
		[[[[self delegate] projectDocumentForSourceTextView:self] breakpointManager] addFileBreakpoint:fileBreakpoint];
	}
}

- (IBAction)fold:(id)sender; {
	WCFold *fold = [[[[self delegate] sourceScannerForSourceTextView:self] folds] deepestFoldForRange:[self selectedRange]];
	
	if (fold) {
		[(WCSourceTextStorage *)[self textStorage] foldRange:[fold contentRange]];
		
		[self setSelectedRange:NSMakeRange(NSMaxRange([fold contentRange]), 0)];
	}
}
- (IBAction)foldAll:(id)sender; {
	NSArray *folds = [[[self delegate] sourceScannerForSourceTextView:self] folds];
	
	for (WCFold *fold in folds)
		[[self sourceTextStorage] foldRange:[fold contentRange]];
}
- (IBAction)unfold:(id)sender; {
	NSRange effectiveRange;
	if (![(WCSourceTextStorage *)[self textStorage] unfoldRange:[self selectedRange] effectiveRange:&effectiveRange] &&
		![(WCSourceTextStorage *)[self textStorage] unfoldRange:NSMakeRange([self selectedRange].location-1, 0) effectiveRange:&effectiveRange]) {
		NSBeep();
		return;
	}
	
	[self setSelectedRange:NSMakeRange(NSMaxRange(effectiveRange), 0)];
}
- (IBAction)unfoldAll:(id)sender; {
	NSArray *folds = [[[self delegate] sourceScannerForSourceTextView:self] folds];
	
	for (WCFold *fold in folds) {
		if ([[self sourceTextStorage] unfoldRange:[fold contentRange] effectiveRange:NULL])
			continue;
		else
			[self _unfoldChildFoldsForFold:fold];
	}
}
- (IBAction)foldCommentBlocks:(id)sender; {
	NSArray *folds = [[[self delegate] sourceScannerForSourceTextView:self] folds];
	
	for (WCFold *fold in folds) {
		if ([fold type] == WCFoldTypeComment)
			[(WCSourceTextStorage *)[self textStorage] foldRange:[fold contentRange]];
	}
}
- (IBAction)unfoldCommentBlocks:(id)sender; {
	NSArray *folds = [[[self delegate] sourceScannerForSourceTextView:self] folds];
	
	for (WCFold *fold in folds) {
		if ([fold type] == WCFoldTypeComment)
			[(WCSourceTextStorage *)[self textStorage] unfoldRange:[fold contentRange] effectiveRange:NULL];
	}
}

- (IBAction)editAllMacroArgumentsInScope:(id)sender; {
	
}

- (IBAction)openInSeparateEditor:(id)sender; {
	WCProjectDocument *projectDocument = [[self delegate] projectDocumentForSourceTextView:self];
	
	if (!projectDocument) {
		NSBeep();
		return;
	}
	
	[projectDocument openSeparateEditorForSourceFileDocument:[[self delegate] sourceFileDocumentForSourceTextView:self]];
}
#pragma mark Properties
@synthesize delegate=_delegate;
- (void)setDelegate:(id<WCSourceTextViewDelegate>)delegate {
	[super setDelegate:delegate];
	
	_delegate = delegate;
	
	if (_delegate) {
		WCProjectDocument *projectDocument = [_delegate projectDocumentForSourceTextView:self];
		
		if (projectDocument) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_buildControllerDidFinishBuilding:) name:WCBuildControllerDidFinishBuildingNotification object:[projectDocument buildController]];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_buildControllerDidChangeBuildIssueVisible:) name:WCBuildControllerDidChangeBuildIssueVisibleNotification object:[projectDocument buildController]];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_buildControllerDidChangeAllBuildIssuesVisible:) name:WCBuildControllerDidChangeAllBuildIssuesVisibleNotification object:[projectDocument buildController]];
		}
	}
}
@dynamic wrapLines;
- (BOOL)wrapLines {
	return (![[self enclosingScrollView] hasHorizontalScroller]);
}
- (void)setWrapLines:(BOOL)wrapLines {
	if ([self wrapLines] == wrapLines)
		return;
	
	if (wrapLines) {
		NSRange selectedRange = [self selectedRange];
		NSAttributedString *string = [[[self textStorage] copy] autorelease];
		[[self enclosingScrollView] setHasHorizontalScroller:NO];
		[[self textStorage] deleteCharactersInRange:NSMakeRange(0, [[self textStorage] length])];
		[[self textContainer] setWidthTracksTextView:YES];
		[[self textContainer] setContainerSize:NSMakeSize([[self enclosingScrollView] contentSize].width, CGFLOAT_MAX)];
		[[self textStorage] replaceCharactersInRange:NSMakeRange(0, 0) withAttributedString:string];
		[self setHorizontallyResizable:NO];
		[self setSelectedRange:selectedRange];
		[self scrollRangeToVisible:selectedRange];
	}
	else {
		[[self textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
		[[self textContainer] setWidthTracksTextView:NO];
		[self setHorizontallyResizable:YES];
		[[self enclosingScrollView] setHasHorizontalScroller:YES];
	}
}
@dynamic sourceTextStorage;
- (WCSourceTextStorage *)sourceTextStorage {
	return (WCSourceTextStorage *)[self textStorage];
}
@dynamic autoHighlightArgumentsRanges;
- (NSIndexSet *)autoHighlightArgumentsRanges {
	return _autoHighlightArgumentsRanges;
}
- (void)setAutoHighlightArgumentsRanges:(NSIndexSet *)autoHighlightArgumentsRanges {
	BOOL needsUpdate = (_autoHighlightArgumentsRanges != autoHighlightArgumentsRanges);
	
	[_autoHighlightArgumentsRanges release];
	_autoHighlightArgumentsRanges = [autoHighlightArgumentsRanges copy];
	
	if (needsUpdate)
		[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
}
#pragma mark *** Private Methods ***
- (void)_commonInit; {
	[self setAllowsImageEditing:NO];
	[self setAllowsUndo:YES];
	[self setAllowsDocumentBackgroundColorChange:NO];
	[self setAutomaticDashSubstitutionEnabled:NO];
	[self setAutomaticDataDetectionEnabled:NO];
	[self setAutomaticLinkDetectionEnabled:YES];
	[self setAutomaticQuoteSubstitutionEnabled:NO];
	[self setAutomaticSpellingCorrectionEnabled:NO];
	[self setAutomaticTextReplacementEnabled:NO];
	[self setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable|NSViewMinXMargin|NSViewMinYMargin];
	[self setContinuousSpellCheckingEnabled:NO];
	[self setDisplaysLinkToolTips:YES];
	[self setDrawsBackground:YES];
	[self setSelectable:YES];
	[self setEditable:YES];
	[self setFieldEditor:NO];
	[self setFocusRingType:NSFocusRingTypeNone];
	[self setGrammarCheckingEnabled:NO];
	[self setHorizontallyResizable:NO];
	[self setImportsGraphics:NO];
	[self setIncrementalSearchingEnabled:NO];
	[self setRichText:YES];
	[self setSmartInsertDeleteEnabled:NO];
	[self setVerticallyResizable:YES];
	[self setMinSize:[[self textContainer] containerSize]];
	[[self textContainer] setWidthTracksTextView:YES];
	[self setMaxSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
	[self setUsesFindBar:NO];
	[self setUsesFindPanel:NO];
	[self setUsesFontPanel:NO];
	[self setUsesInspectorBar:NO];
	[self setUsesRuler:NO];
	
	[self setupUserDefaultsObserving];
	
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[currentTheme selectionColor],NSBackgroundColorAttributeName, nil]];
	[self setBackgroundColor:[currentTheme backgroundColor]];
	[self setInsertionPointColor:[currentTheme cursorColor]];
	
	NSParagraphStyle *paragraphStyle = [WCSourceTextStorage defaultParagraphStyle];
	
	[self setTypingAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[currentTheme plainTextFont],NSFontAttributeName,[currentTheme plainTextColor],NSForegroundColorAttributeName,paragraphStyle,NSParagraphStyleAttributeName, nil]];
	[self setDefaultParagraphStyle:paragraphStyle];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_textViewDidChangeSelection:) name:NSTextViewDidChangeSelectionNotification object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_currentThemeDidChange:) name:WCFontAndColorThemeManagerCurrentThemeDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_selectionColorDidChange:) name:WCFontAndColorThemeManagerSelectionColorDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_backgroundColorDidChange:) name:WCFontAndColorThemeManagerBackgroundColorDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_currentLineColorDidChange:) name:WCFontAndColorThemeManagerCurrentLineColorDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_cursorColorDidChange:) name:WCFontAndColorThemeManagerCursorColorDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_textStorageDidFold:) name:WCSourceTextStorageDidFoldNotification object:[self sourceTextStorage]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_textStorageDidUnfold:) name:WCSourceTextStorageDidUnfoldNotification object:[self sourceTextStorage]];
}

- (void)_drawCurrentLineHighlightInRect:(NSRect)rect; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorShowCurrentLineHighlightKey])
		return;
	
	NSUInteger numRects;
	NSRectArray rects;
	if ([self selectedRange].length)
		rects = [[self layoutManager] rectArrayForCharacterRange:[[self string] lineRangeForRange:[self selectedRange]] withinSelectedCharacterRange:NSNotFoundRange inTextContainer:[self textContainer] rectCount:&numRects];
	else
		rects = [[self layoutManager] rectArrayForCharacterRange:[self selectedRange] withinSelectedCharacterRange:NSNotFoundRange inTextContainer:[self textContainer] rectCount:&numRects];
	
	if (!numRects)
		return;
	
	NSRect lineRect;
	
	if (numRects == 1)
		lineRect = rects[0];
	else {
		lineRect = NSZeroRect;
		NSUInteger rectIndex;
		for (rectIndex=0; rectIndex<numRects; rectIndex++)
			lineRect = NSUnionRect(lineRect, rects[rectIndex]);
	}
	
	lineRect.origin.x = NSMinX([self bounds]);
	lineRect.size.width = NSWidth([self bounds]);
	
	if (!NSIntersectsRect(lineRect, rect) || ![self needsToDrawRect:lineRect])
		return;
	
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	[[[currentTheme currentLineColor] colorWithAlphaComponent:0.5] setFill];
	NSRectFillUsingOperation(lineRect, NSCompositingOperationSourceOver);
	[[currentTheme currentLineColor] setFill];
	NSRectFill(NSMakeRect(NSMinX(lineRect), NSMinY(lineRect), NSWidth(lineRect), 1.0));
	NSRectFill(NSMakeRect(NSMinX(lineRect), NSMaxY(lineRect)-1, NSWidth(lineRect), 1.0));
}

- (void)_drawPageGuideInRect:(NSRect)rect; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorShowPageGuideAtColumnKey])
		return;
	
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[currentTheme plainTextFont],NSFontAttributeName, nil];
	CGFloat width = [@" " sizeWithAttributes:attributes].width;
	NSUInteger columnNumber = [[[NSUserDefaults standardUserDefaults] objectForKey:WCEditorPageGuideColumnNumberKey] unsignedIntegerValue];
	CGFloat xPosition = floor(width*columnNumber);
	NSRect guideRect = NSMakeRect(xPosition, NSMinY([self bounds]), 1.0, NSHeight([self bounds]));
	
	if (!NSIntersectsRect(guideRect, rect) || ![self needsToDrawRect:guideRect])
		return;
	
	guideRect.size.width = NSWidth([self bounds]) - xPosition;
	
	[[[NSColor lightGrayColor] colorWithAlphaComponent:0.35] setFill];
	NSRectFillUsingOperation(guideRect, NSCompositingOperationSourceOver);
	
	guideRect.size.width = 1.0;
	
	[[NSColor lightGrayColor] setFill];
	NSRectFill(guideRect);
}

- (void)_highlightMatchingBrace; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorShowMatchingBraceHighlightKey])
		return;
	// need at least two characters in our string to be able to match
	else if ([[self string] length] <= 1)
		return;
	// return early if we have any text selected
	else if ([self selectedRange].length)
		return;
	
	static NSCharacterSet *closingCharacterSet;
	static NSCharacterSet *openingCharacterSet;
	if (!closingCharacterSet) {
		closingCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@")]}"] retain];
		openingCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"([{"] retain];
	}
	// return early if the character at the caret position is not one our closing brace characters
	if (![closingCharacterSet characterIsMember:[[self string] characterAtIndex:[self selectedRange].location-1]])
		return;
	
	unichar closingBraceCharacter = [[self string] characterAtIndex:[self selectedRange].location-1];
	NSUInteger numberOfClosingBraces = 0, numberOfOpeningBraces = 0;
	NSInteger characterIndex;
	NSRange visibleRange = [self visibleRange];
	
	// scan backwards starting at the selected character index
	for (characterIndex = [self selectedRange].location-1; characterIndex > visibleRange.location; characterIndex--) {
		unichar charAtIndex = [[self string] characterAtIndex:characterIndex];
		
		// increment the number of opening braces
		if ([openingCharacterSet characterIsMember:charAtIndex]) {
			numberOfOpeningBraces++;
			
			// if the number of opening and closing braces are equal and the opening and closing characters match
			// show the find indicator on the opening brace
			if (numberOfOpeningBraces == numberOfClosingBraces &&
				((closingBraceCharacter == ')' && charAtIndex == '(') ||
				 (closingBraceCharacter == ']' && charAtIndex == '[') ||
				 (closingBraceCharacter == '}' && charAtIndex == '{'))) {
					[self showFindIndicatorForRange:NSMakeRange(characterIndex, 1)];
					return;
				}
			// otherwise the braces don't match, beep at the user because we are angry
			else if (numberOfOpeningBraces > numberOfClosingBraces) {
				NSBeep();
				return;
			}
		}
		// increment the number of closing braces
		else if ([closingCharacterSet characterIsMember:charAtIndex])
			numberOfClosingBraces++;
	}
	
	NSBeep();
}

- (void)_highlightMatchingTempLabel; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorShowMatchingTemporaryLabelHighlightKey])
		return;
	// need at least two characters in order to match
	else if ([[self string] length] <= 2)
		return;
	// selection cannot have a length
	else if ([self selectedRange].length)
		return;
	
	NSRange selectedRange = [self selectedRange];
	if ([[self string] characterAtIndex:selectedRange.location-1] != '_')
		return;
	// dont highlight the temp labels themselves
	else if ([[self string] lineRangeForRange:selectedRange].location == selectedRange.location-1)
		return;
	
	// number of references (going forwards or backwards) we are looking for
	__block NSInteger numberOfReferences = 0;
	
	NSUInteger stringLength = [[self string] length];
	NSInteger charIndex;
	
	// count of the number of references so we know how many temp labels to skip over
	for (charIndex = selectedRange.location-2; charIndex > 0; charIndex--) {
		unichar charAtIndex = [[self string] characterAtIndex:charIndex];
		
		// '+' means search forward in the file
		if (charAtIndex == '+')
			numberOfReferences++;
		// '-' means seach backwards in the file
		else if (charAtIndex == '-')
			numberOfReferences--;
		// otherwise we are done counting references
		else
			break;
	}
	
	// if we didn't count any references, it's an underscore by itself
	if (!numberOfReferences) {
		static NSCharacterSet *delimiterCharSet;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			NSMutableCharacterSet *charSet = [[[NSCharacterSet whitespaceCharacterSet] mutableCopy] autorelease];
			[charSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
			delimiterCharSet = [charSet copy];
		});
		
		// we need to make sure it isn't part of another word before continuing the search
		if (![delimiterCharSet characterIsMember:[[self string] characterAtIndex:selectedRange.location-2]])
			return;
		
		// otherwise count it as a single forward reference
		numberOfReferences++;
	}
	
	// always enumerate by lines, adding the reverse flag when we have a negative number of references
	__block BOOL foundMatchingTempLabel = NO;
	NSStringEnumerationOptions enumOptions = NSStringEnumerationByLines;
	if (numberOfReferences < 0)
		enumOptions |= NSStringEnumerationReverse;
	// we want to search either from our selected index forward to the end of the file
	// or backwards from our selected index to the beginning of the file
	NSRange enumRange = (numberOfReferences > 0)?NSMakeRange(selectedRange.location, stringLength-selectedRange.location):NSMakeRange(0, selectedRange.location);
	
	[[self string] enumerateSubstringsInRange:enumRange options:enumOptions usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
		// the first character has to be an underscore
		if (substringRange.length && [substring characterAtIndex:0] == '_') {
			// make sure the underscore isn't part of another symbol (i.e. a label)
			NSRange symbolRange = [[self string] symbolRangeForRange:NSMakeRange(substringRange.location, 0)];
			if (symbolRange.length != 1)
				return;
			
			// make sure the underscore isn't part of a block comment
			WCSourceToken *token = [[[[self delegate] sourceScannerForSourceTextView:self] tokens] sourceTokenForRange:substringRange];
			if (NSLocationInRange(substringRange.location, [token range]) &&
				[token type] == WCSourceTokenTypeComment)
				return;
			
			// decrement the number of references, checking for 0
			if (numberOfReferences > 0 && (!(--numberOfReferences))) {
				foundMatchingTempLabel = YES;
				*stop = YES;
				
				[self showFindIndicatorForRange:NSMakeRange(substringRange.location, 1)];
			}
			// increment the number of references, checking for 0
			else if (numberOfReferences < 0 && (!(++numberOfReferences))) {
				foundMatchingTempLabel = YES;
				*stop = YES;
				
				[self showFindIndicatorForRange:NSMakeRange(substringRange.location, 1)];
			}
		}
	}];
	
	// if we didn't find a matching temp label, beep at the user because we are angry
	if (!foundMatchingTempLabel)
		NSBeep();
}

- (void)_insertMatchingBraceWithString:(id)string; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorAutomaticallyInsertMatchingBraceKey])
		return;
	// "string" can only be an opening brace character if it's 1 character long
	else if ([string length] != 1)
		return;
	
	static NSCharacterSet *openBraceCharacters;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		openBraceCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"{(["] retain];
	});
	
	// if the only character isn't part of the brace characters we recognize, return early
	if (![openBraceCharacters characterIsMember:[string characterAtIndex:0]])
		return;
	
	// insert the appropriate matching brace character
	switch ([string characterAtIndex:0]) {
		case '(':
			[super insertText:@")"];
			break;
		case '[':
			[super insertText:@"]"];
			break;
		case '{':
			[super insertText:@"}"];
			break;
		default:
			break;
	}
	
	// adjust the selected range since we inserted an additional character
	[self setSelectedRange:NSMakeRange([self selectedRange].location-1, 0)];
}

- (void)_handleAutoCompletionWithString:(id)string; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorSuggestCompletionsWhileTypingKey])
		return;
	// only trigger auto completion when the user types a single character
	// disregard single character inserts if they are part of an undo or redo
	else if ([string length] != 1 ||
			 [[self undoManager] isUndoing] ||
			 [[self undoManager] isRedoing]) {
		[_completionTimer invalidate];
		_completionTimer = nil;
		return;
	}
	
	// only trigger on certain characters, for now this is letters, numbers and a few additional symbol characters
	static NSCharacterSet *legalChars;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *charSet = [[[NSCharacterSet letterCharacterSet] mutableCopy] autorelease];
		[charSet formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
		[charSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"_!?.#"]];
		legalChars = [charSet copy];
	});
	
	// if our single character isn't part of our legal character set, return early
	if (![legalChars characterIsMember:[string characterAtIndex:0]]) {
		[_completionTimer invalidate];
		_completionTimer = nil;
		return;
	}
	
	NSRange completionRange = [self rangeForUserCompletion];
	NSRange lineRange = [[self string] lineRangeForRange:completionRange];
	
	// special case, don't complete when typing at the beginning of a line, the user is usually typing a new label in this case, no need to put the completion up and annoy them
	// the exception being if the first character typed was a '#' or '.' which are preprocessor and directive keywords respectively
	if (completionRange.location == lineRange.location) {
		unichar lineChar = [[self string] characterAtIndex:lineRange.location];
		if (lineChar != '.' && lineChar != '#') {
			[_completionTimer invalidate];
			_completionTimer = nil;
			return;
		}
	}
	// also don't complete when we are inside a comment
	id attributeValue = [[self textStorage] attribute:WCSourceTokenTypeAttributeName atIndex:completionRange.location effectiveRange:NULL];
	if ([attributeValue unsignedIntValue] == WCSourceTokenTypeComment ||
		[attributeValue unsignedIntValue] == WCSourceTokenTypeMultilineComment) {
		
		[_completionTimer invalidate];
		_completionTimer = nil;
		return;
	}
	
	NSTimeInterval completionDelay = [[NSUserDefaults standardUserDefaults] floatForKey:WCEditorSuggestCompletionsWhileTypingDelayKey];
	
	// if the timer already exists, restart it
	if (_completionTimer)
		[_completionTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:completionDelay]];
	// otherwise create the timer
	else {
		_completionTimer = [NSTimer scheduledTimerWithTimeInterval:completionDelay target:self selector:@selector(_completionTimerCallback:) userInfo:nil repeats:NO];
	}
}

- (BOOL)_handleAutoIndentAfterLabel {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorAutomaticallyIndentAfterLabelsKey])
		return NO;
	
	NSRange lineRange = [[self string] lineRangeForRange:NSMakeRange([self selectedRange].location-1, 0)];
	// is there an equate definition on our current line?
	NSRange equateRange = [[WCSourceScanner equateRegularExpression] rangeOfFirstMatchInString:[self string] options:0 range:lineRange];
	if (equateRange.location != NSNotFound)
		return NO;
	
	// is there a label definition on our current line?
	NSRange labelRange = [[WCSourceScanner labelRegularExpression] rangeOfFirstMatchInString:[self string] options:0 range:lineRange];
	if (labelRange.location == NSNotFound)
		return NO;
	
	[self insertTab:nil];
	
	return YES;
}

- (void)_highlightEnclosedMacroArguments; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorShowHighlightEnclosedMacroArgumentsKey] ||
		[self selectedRange].length) {
		
		[self setAutoHighlightArgumentsRanges:nil];
		return;
	}
	
	NSArray *macros = [[self delegate] macrosForSourceTextView:self];
	WCMacroSymbol *macro = (WCMacroSymbol *)[macros sourceSymbolForRange:[self selectedRange]];
	
	if (!macro || !NSLocationInRange([self selectedRange].location, [macro valueRange])) {
		[self setAutoHighlightArgumentsRanges:nil];
		return;
	}
	else if (![[macro arguments] count]) {
		[self setAutoHighlightArgumentsRanges:nil];
		return;
	}
	
	NSRange symbolRange = [[self string] symbolRangeForRange:[self selectedRange]];
	if (symbolRange.location == NSNotFound) {
		[self setAutoHighlightArgumentsRanges:nil];
		return;
	}
	
	NSString *symbolString = [[self string] substringWithRange:symbolRange];
	if (![[macro argumentsSet] containsObject:[symbolString lowercaseString]]) {
		[self setAutoHighlightArgumentsRanges:nil];
		return;
	}
	
	NSMutableIndexSet *autoHighlightRanges = [NSMutableIndexSet indexSet];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@\\b",symbolString] options:NSRegularExpressionCaseInsensitive error:NULL];
	[regex enumerateMatchesInString:[self string] options:0 range:[macro valueRange] usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
		[autoHighlightRanges addIndexesInRange:[result range]];
	}];
	
	[self setAutoHighlightArgumentsRanges:autoHighlightRanges];
}
- (BOOL)_handleUnfoldForEvent:(NSEvent *)theEvent {
	[(WCSourceTextStorage *)[self textStorage] setLineFoldingEnabled:YES];
	
	if ([theEvent type] == NSLeftMouseDown &&
		[theEvent clickCount] == 2) {
		
		NSUInteger glyphIndex = [[self layoutManager] glyphIndexForPoint:[self convertPointFromBase:[theEvent locationInWindow]] inTextContainer:[self textContainer]];
		
		if (glyphIndex >= [[self layoutManager] numberOfGlyphs]) {
			[(WCSourceTextStorage *)[self textStorage] setLineFoldingEnabled:NO];
			return NO;
		}
		
		NSUInteger charIndex = [[self layoutManager] characterIndexForGlyphAtIndex:glyphIndex];
		NSRange effectiveRange;
		id attributeValue = [[self textStorage] attribute:WCLineFoldingAttributeName atIndex:charIndex longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, [[self textStorage] length])];
		
		if (![attributeValue boolValue]) {
			[(WCSourceTextStorage *)[self textStorage] setLineFoldingEnabled:NO];
			return NO;
		}
		
		NSTextAttachment *attachment = [[self textStorage] attribute:NSAttachmentAttributeName atIndex:effectiveRange.location effectiveRange:NULL];
		
		if (!attachment) {
			[(WCSourceTextStorage *)[self textStorage] setLineFoldingEnabled:NO];
			return NO;
		}
		
		[(WCSourceTextStorage *)[self textStorage] setLineFoldingEnabled:NO];
		
		glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:effectiveRange.location];
		
		id <NSTextAttachmentCell> cell = [attachment attachmentCell];
		NSPoint delta = [[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL].origin;
		NSRect cellFrame;
		
		cellFrame.origin = [self textContainerOrigin];
		cellFrame.size = [[self layoutManager] attachmentSizeForGlyphAtIndex:glyphIndex];
		cellFrame.origin.x += delta.x;
		cellFrame.origin.y += delta.y;
		cellFrame.origin.x += [[self layoutManager] locationForGlyphAtIndex:glyphIndex].x;
		
		if ([cell wantsToTrackMouseForEvent:theEvent inRect:cellFrame ofView:self atCharacterIndex:effectiveRange.location] &&
			[cell trackMouse:theEvent inRect:cellFrame ofView:self atCharacterIndex:effectiveRange.location untilMouseUp:YES])
			return NO;
		
		return YES;
	}
	
	[(WCSourceTextStorage *)[self textStorage] setLineFoldingEnabled:NO];
	return NO;
}
- (void)_drawVisibleBookmarksInRect:(NSRect)bookmarkRect; {
	// TODO: draw the bookmarks at all?
}

static const NSSize kIconSize = {.width = 9.0, .height = 9.0};
static const CGFloat kTriangleHeight = 4.0;

- (void)_drawVisibleBuildIssuesInRect:(NSRect)buildIssueRect {
	static NSTextStorage *buildIssuesTextStorage;
	static NSLayoutManager *buildIssuesLayoutManager;
	static NSTextContainer *buildIssuesTextContainer;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		buildIssuesTextStorage = [[NSTextStorage alloc] initWithString:@"somestring"];
		buildIssuesLayoutManager = [[[NSLayoutManager alloc] init] autorelease];
		buildIssuesTextContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)] autorelease];
		
		[buildIssuesTextStorage addLayoutManager:buildIssuesLayoutManager];
		[buildIssuesLayoutManager addTextContainer:buildIssuesTextContainer];
	});
	
	NSArray *buildIssues = [[self delegate] buildIssuesForSourceTextView:self];
	NSMutableIndexSet *errorIndexes = [NSMutableIndexSet indexSet];
	NSMutableIndexSet *warningIndexes = [NSMutableIndexSet indexSet];
	
	[buildIssuesTextStorage addAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]],NSFontAttributeName,[[self typingAttributes] objectForKey:NSForegroundColorAttributeName],NSForegroundColorAttributeName, nil] range:NSMakeRange(0, [buildIssuesTextStorage length])];
	
	for (WCBuildIssue *buildIssue in [buildIssues buildIssuesForRange:[self visibleRange]]) {
		if (![buildIssue isVisible])
			continue;
		
		switch ([buildIssue type]) {
			case WCBuildIssueTypeError:
				if ([errorIndexes containsIndex:[buildIssue range].location])
					continue;
				else {
					NSUInteger rectCount;
					NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:[[self string] lineRangeForRange:[buildIssue range]] withinSelectedCharacterRange:NSNotFoundRange inTextContainer:[self textContainer] rectCount:&rectCount];
					
					if (!rectCount)
						continue;
					
					NSRect lineRect;
					if (rectCount == 1)
						lineRect = rects[0];
					else {
						lineRect = NSZeroRect;
						NSUInteger rectIndex;
						for (rectIndex=0; rectIndex<rectCount; rectIndex++)
							lineRect = NSUnionRect(lineRect, rects[rectIndex]);
					}
					
					lineRect = NSMakeRect(NSMinX([self bounds]), NSMinY(lineRect), NSWidth([self bounds]), NSHeight(lineRect));
					
					if (!NSIntersectsRect(lineRect, [self bounds]) || ![self needsToDrawRect:lineRect])
						continue;
					
					[[WCBuildIssue errorSelectedFillGradient] drawInRect:lineRect angle:90.0];
					[[WCBuildIssue errorFillColor] setFill];
					NSRectFill(NSMakeRect(NSMinX(lineRect), NSMinY(lineRect), NSWidth(lineRect), 1.0));
					NSRectFill(NSMakeRect(NSMinX(lineRect), NSMaxY(lineRect)-1.0, NSWidth(lineRect), 1.0));
					
					[buildIssuesTextStorage replaceCharactersInRange:NSMakeRange(0, [buildIssuesTextStorage length]) withString:[buildIssue message]];
					[buildIssuesLayoutManager ensureLayoutForCharacterRange:NSMakeRange(0, [buildIssuesTextStorage length])];
					
					NSSize stringSize = [buildIssuesLayoutManager usedRectForTextContainer:buildIssuesTextContainer].size;
					NSRect stringRect = NSCenteredRectWithSize(stringSize, lineRect);
					
					stringRect.origin.x = NSMaxX(lineRect)-stringSize.width;
					
					NSBezierPath *path = [NSBezierPath bezierPath];
					
					[path moveToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMinY(lineRect))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width-kTriangleHeight, NSMinY(lineRect)+ceil(NSHeight(lineRect)/2.0))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMaxY(lineRect))];
					
					[[WCBuildIssue errorFillColor] setStroke];
					[path stroke];
					
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect), NSMaxY(lineRect))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect), NSMinY(lineRect))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMinY(lineRect))];
					[path closePath];
					
					[[WCBuildIssue errorFillGradient] drawInBezierPath:path angle:90.0];
					
					[[NSGraphicsContext currentContext] saveGraphicsState];
					
					NSRectClip(stringRect);
					
					[buildIssuesLayoutManager drawGlyphsForGlyphRange:[buildIssuesLayoutManager glyphRangeForCharacterRange:NSMakeRange(0, [buildIssuesTextStorage length]) actualCharacterRange:NULL] atPoint:stringRect.origin];
					
					[[NSGraphicsContext currentContext] restoreGraphicsState];
					
					NSImage *image = [NSImage imageNamed:@"Error"];
					
					[image drawInRect:NSMakeRect(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMinY(lineRect)+floor((NSHeight(lineRect)-kIconSize.height)/2.0), kIconSize.width, kIconSize.height) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
					
					[errorIndexes addIndex:[buildIssue range].location];
				}
				break;
			case WCBuildIssueTypeWarning:
				if ([errorIndexes containsIndex:[buildIssue range].location] ||
					[warningIndexes containsIndex:[buildIssue range].location])
					continue;
				else {
					NSUInteger rectCount;
					NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:[[self string] lineRangeForRange:[buildIssue range]] withinSelectedCharacterRange:NSNotFoundRange inTextContainer:[self textContainer] rectCount:&rectCount];
					
					if (!rectCount)
						continue;
					
					NSRect lineRect;
					if (rectCount == 1)
						lineRect = rects[0];
					else {
						lineRect = NSZeroRect;
						NSUInteger rectIndex;
						for (rectIndex=0; rectIndex<rectCount; rectIndex++)
							lineRect = NSUnionRect(lineRect, rects[rectIndex]);
					}
					
					lineRect = NSMakeRect(NSMinX([self bounds]), NSMinY(lineRect), NSWidth([self bounds]), NSHeight(lineRect));
					
					if (!NSIntersectsRect(lineRect, [self bounds]) || ![self needsToDrawRect:lineRect])
						continue;
					
					[[WCBuildIssue warningSelectedFillGradient] drawInRect:lineRect angle:90.0];
					[[WCBuildIssue warningFillColor] setFill];
					NSRectFill(NSMakeRect(NSMinX(lineRect), NSMinY(lineRect), NSWidth(lineRect), 1.0));
					NSRectFill(NSMakeRect(NSMinX(lineRect), NSMaxY(lineRect)-1, NSWidth(lineRect), 1.0));
					
					[buildIssuesTextStorage replaceCharactersInRange:NSMakeRange(0, [buildIssuesTextStorage length]) withString:[buildIssue message]];
					[buildIssuesLayoutManager ensureLayoutForCharacterRange:NSMakeRange(0, [buildIssuesTextStorage length])];
					
					NSSize stringSize = [buildIssuesLayoutManager usedRectForTextContainer:buildIssuesTextContainer].size;
					NSRect stringRect = NSCenteredRectWithSize(stringSize, lineRect);
					
					stringRect.origin.x = NSMaxX(lineRect)-stringSize.width;
					
					NSBezierPath *path = [NSBezierPath bezierPath];
					
					[path moveToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMinY(lineRect))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width-kTriangleHeight, NSMinY(lineRect)+ceil(NSHeight(lineRect)/2.0))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMaxY(lineRect))];
					
					[[WCBuildIssue warningFillColor] setStroke];
					[path stroke];
					
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect), NSMaxY(lineRect))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect), NSMinY(lineRect))];
					[path lineToPoint:NSMakePoint(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMinY(lineRect))];
					[path closePath];
					
					[[WCBuildIssue warningFillGradient] drawInBezierPath:path angle:90.0];
					
					[[NSGraphicsContext currentContext] saveGraphicsState];
					
					NSRectClip(stringRect);
					
					[buildIssuesLayoutManager drawGlyphsForGlyphRange:[buildIssuesLayoutManager glyphRangeForCharacterRange:NSMakeRange(0, [buildIssuesTextStorage length]) actualCharacterRange:NULL] atPoint:stringRect.origin];
					
					[[NSGraphicsContext currentContext] restoreGraphicsState];
					
					NSImage *image = [NSImage imageNamed:@"Warning"];
					
					[image drawInRect:NSMakeRect(NSMaxX(lineRect)-stringSize.width-kIconSize.width, NSMinY(lineRect)+floor((NSHeight(lineRect)-kIconSize.height)/2.0), kIconSize.width, kIconSize.height) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
					
					[warningIndexes addIndex:[buildIssue range].location];
				}
				break;
			default:
				break;
		}
	}
}

- (void)_drawFocusFollowsCodeRectsInRect:(NSRect)focusFollowsCodeRect; {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:WCEditorFocusFollowsSelectionKey])
		return;
	
	NSRange selectedRange = [self selectedRange];
	WCFold *fold = [[[[self delegate] sourceScannerForSourceTextView:self] folds] deepestFoldForRange:selectedRange];
	
	if (!fold)
		return;
	
	static const CGFloat stepAmount = 0.05;
	NSColor *baseColor = [self backgroundColor];
	NSMutableArray *rectsAndColorsDictionaries = [NSMutableArray arrayWithCapacity:0];
	BOOL baseColorIsDark = [baseColor colorIsDark];
	
	do {
		NSUInteger rectCount;
		NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:[fold contentRange] withinSelectedCharacterRange:NSNotFoundRange inTextContainer:[self textContainer] rectCount:&rectCount];
		
		if (!rectCount)
			break;
		
		NSMutableArray *contentRangeRects = [NSMutableArray arrayWithCapacity:rectCount];
		NSUInteger rectIndex;
		
		for (rectIndex=0; rectIndex<rectCount; rectIndex++)
			[contentRangeRects addObject:[NSValue valueWithRect:rects[rectIndex]]];
		
		[rectsAndColorsDictionaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:contentRangeRects,@"rect",baseColor,@"color",fold,@"fold", nil]];
		
		CGFloat darkenOrLightenAmount = stepAmount*((CGFloat)[fold level]+1);
		if (baseColorIsDark)
			baseColor = [baseColor darkenBy:-darkenOrLightenAmount];
		else
			baseColor = [baseColor darkenBy:darkenOrLightenAmount];
		
		fold = [fold parentNode];
		
	} while (fold);
	
	[baseColor setFill];
	NSRectFill(focusFollowsCodeRect);
	
	[rectsAndColorsDictionaries enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *dict, NSUInteger dictIndex, BOOL *stop) {
		[[dict objectForKey:@"color"] setFill];
		
		for (NSValue *rectValue in [dict objectForKey:@"rect"])
			NSRectFill([rectValue rectValue]);
	}];
}

- (BOOL)_unfoldChildFoldsForFold:(WCFold *)fold; {
	for (WCFold *childFold in [fold childNodes]) {
		if ([[self sourceTextStorage] unfoldRange:[childFold contentRange] effectiveRange:NULL])
			return YES;
		else if ([self _unfoldChildFoldsForFold:childFold])
			return YES;
	}
	return NO;
}
#pragma mark IBActions
- (IBAction)_symbolMenuClicked:(NSMenuItem *)sender {
	[[self delegate] handleJumpToDefinitionForSourceTextView:self sourceSymbol:[sender representedObject]];
}
- (IBAction)_jumpToCallersMenuClicked:(id)sender {
	[[self delegate] handleJumpToDefinitionForSourceTextView:self sourceSymbol:[sender representedObject]];
}
#pragma mark Notifications
- (void)_textViewDidChangeSelection:(NSNotification *)note {
	NSRange oldSelectedRange = [[[note userInfo] objectForKey:@"NSOldSelectedCharacterRange"] rangeValue];
	// we only want to match braces and temp labels if there was no previous selection, the new selected index is greater than the previous one, and the difference between them is 1 (meaning the user only moved the caret a single position)
	if (!oldSelectedRange.length &&
		oldSelectedRange.location < [self selectedRange].location &&
		[self selectedRange].location - oldSelectedRange.location == 1) {
		
		[self _highlightMatchingBrace];
		[self _highlightMatchingTempLabel];
	}
	
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
	
	NSTimeInterval autoHighlightArgumentsDelay = [[NSUserDefaults standardUserDefaults] floatForKey:WCEditorShowHighlightEnclosedMacroArgumentsDelayKey];
	if (_autoHighlightArgumentsTimer)
		[_autoHighlightArgumentsTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:autoHighlightArgumentsDelay]];
	else
		_autoHighlightArgumentsTimer = [NSTimer scheduledTimerWithTimeInterval:autoHighlightArgumentsDelay target:self selector:@selector(_autoHighlightArgumentsTimerCallback:) userInfo:nil repeats:NO];
}
- (void)_currentThemeDidChange:(NSNotification *)note {
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	[self setTypingAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[currentTheme plainTextFont],NSFontAttributeName,[currentTheme plainTextColor],NSForegroundColorAttributeName, nil]];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[currentTheme selectionColor],NSBackgroundColorAttributeName, nil]];
	[self setBackgroundColor:[currentTheme backgroundColor]];
	[self setInsertionPointColor:[currentTheme cursorColor]];
}
- (void)_selectionColorDidChange:(NSNotification *)note {
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[currentTheme selectionColor],NSBackgroundColorAttributeName, nil]];
}
- (void)_backgroundColorDidChange:(NSNotification *)note {
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	[self setBackgroundColor:[currentTheme backgroundColor]];
}
- (void)_currentLineColorDidChange:(NSNotification *)note {
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
}
- (void)_cursorColorDidChange:(NSNotification *)note {
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	[self setInsertionPointColor:[currentTheme cursorColor]];
}
- (void)_textStorageDidFold:(NSNotification *)note {
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
}
- (void)_textStorageDidUnfold:(NSNotification *)note {
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:NO];
}
- (void)_buildControllerDidFinishBuilding:(NSNotification *)note {
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
}
- (void)_buildControllerDidChangeBuildIssueVisible:(NSNotification *)note {
	WCBuildIssue *buildIssue = [[note userInfo] objectForKey:WCBuildControllerDidChangeBuildIssueVisibleChangedBuildIssueUserInfoKey];
	
	if (NSLocationInOrEqualToRange([buildIssue range].location, [self visibleRange]))
		[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
}
- (void)_buildControllerDidChangeAllBuildIssuesVisible:(NSNotification *)note {
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:YES];
}
#pragma mark Callbacks
- (void)_completionTimerCallback:(NSTimer *)timer {
	[_completionTimer invalidate];
	_completionTimer = nil;
	
	[self complete:nil];
}

- (void)_autoHighlightArgumentsTimerCallback:(NSTimer *)timer {
	[_autoHighlightArgumentsTimer invalidate];
	_autoHighlightArgumentsTimer = nil;
	
	[self _highlightEnclosedMacroArguments];
}
@end
