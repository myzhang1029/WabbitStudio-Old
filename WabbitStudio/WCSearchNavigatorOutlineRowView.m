//
//  WCSearchNavigatorOutlineRowView.m
//  WabbitStudio
//
//  Created by William Towe on 7/26/11.
//  Copyright 2011 Revolution Software. All rights reserved.
//

#import "WCSearchNavigatorOutlineRowView.h"
#import "RSTreeNode.h"
#import "NSTreeController+RSExtensions.h"

@implementation WCSearchNavigatorOutlineRowView
#pragma mark *** Subclass Overrides ***
- (void)drawBackgroundInRect:(NSRect)dirtyRect {
	RSTreeNode *result = [[self viewAtColumn:0] objectValue];
	
	if (![result isLeafNode]) {
		[super drawBackgroundInRect:dirtyRect];
		if (![result parentNode])
			return;
		
		NSOutlineView *ov = [self outlineView];
		
		if ([ov isItemExpanded:[(NSTreeController *)[ov dataSource] treeNodeForRepresentedObject:result]]) {
			[[NSColor gridColor] setFill];
			NSRectFill(NSMakeRect(NSMinX([self bounds]), NSMaxY([self bounds])-1.0, NSWidth([self bounds]), 1.0));
		}
		return;
	}
	
	[[NSColor colorWithCalibratedWhite:0.95 alpha:1.0] setFill];
	NSRectFill([self bounds]);
	
	if ([[[result parentNode] childNodes] lastObject] == result) {
		[[NSColor gridColor] setFill];
		NSRectFill(NSMakeRect(NSMinX([self bounds]), NSMaxY([self bounds])-1.0, NSWidth([self bounds]), 1.0));
	}
}

@synthesize outlineView=_outlineView;

@end