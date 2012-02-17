//
//  WCSymbolNavigatorViewController.m
//  WabbitStudio
//
//  Created by William Towe on 2/16/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import "WCSymbolNavigatorViewController.h"
#import "WCProjectDocument.h"
#import "WCSourceSymbol.h"
#import "WCProject.h"
#import "WCSourceTextViewController.h"
#import "WCProjectWindowController.h"
#import "RSOutlineView.h"
#import "NSTreeController+RSExtensions.h"
#import "WCSymbolFileContainer.h"
#import "WCSymbolContainer.h"
#import "WCSourceFileSeparateWindowController.h"
#import "WCTabViewController.h"
#import "WCProjectContainer.h"
#import "WCSourceScanner.h"

@interface WCSymbolNavigatorViewController ()
- (void)_updateSymbols;
@end

@implementation WCSymbolNavigatorViewController
#pragma mark *** Subclass Overrides ***
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_projectDocument = nil;
	[super dealloc];
}

- (NSString *)nibName {
	return @"WCSymbolNavigatorView";
}

- (void)loadView {
	[super loadView];
	
	[[[self searchField] cell] setPlaceholderString:NSLocalizedString(@"Filter Symbols", @"Filter Symbols")];
	[[[[self searchField] cell] searchButtonCell] setImage:[NSImage imageNamed:@"Filter"]];
	[[[[self searchField] cell] searchButtonCell] setAlternateImage:nil];
	
	[[self outlineView] setTarget:self];
	[[self outlineView] setDoubleAction:@selector(_outlineViewDoubleClick:)];
	[[self outlineView] setAction:@selector(_outlineViewSingleClick:)];
	
	[self _updateSymbols];
}
#pragma mark NSOutlineViewDelegate
static NSString *const kProjectCellIdentifier = @"ProjectCell";
static NSString *const kMainCellIdentifier = @"MainCell";

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	id object = [[item representedObject] representedObject];
	
	if ([object isKindOfClass:[WCFile class]])
		return [outlineView makeViewWithIdentifier:kProjectCellIdentifier owner:self];
	return [outlineView makeViewWithIdentifier:kMainCellIdentifier owner:self];
}

static const CGFloat kProjectCellHeight = 30.0;
static const CGFloat kMainCellHeight = 20.0;
- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
	id object = [[item representedObject] representedObject];
	
	if ([object isKindOfClass:[WCFile class]])
		return kProjectCellHeight;
	return kMainCellHeight;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
	if ([rowView respondsToSelector:@selector(setOutlineView:)])
		[(id)rowView setOutlineView:outlineView];
}
- (void)outlineView:(NSOutlineView *)outlineView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
	if ([rowView respondsToSelector:@selector(setOutlineView:)])
		[(id)rowView setOutlineView:nil];
}
#pragma mark RSOutlineViewDelegate
- (void)handleReturnPressedForOutlineView:(RSOutlineView *)outlineView {
	[[self outlineView] sendAction:[[self outlineView] action] to:[[self outlineView] target]];
}

#pragma mark WCNavigatorModule
- (NSArray *)selectedObjects {
	NSMutableArray *retval = [NSMutableArray arrayWithCapacity:0];
	NSInteger clickedRow = [[self outlineView] clickedRow];
	if (clickedRow == -1 || [[[self outlineView] selectedRowIndexes] containsIndex:clickedRow])
		[retval addObjectsFromArray:[[self treeController] selectedRepresentedObjects]];
	else
		[retval addObject:[[[self outlineView] itemAtRow:clickedRow] representedObject]];
	
	return [[retval copy] autorelease];
}
- (void)setSelectedObjects:(NSArray *)objects {
	[[self treeController] setSelectedRepresentedObjects:objects];
}

- (NSArray *)selectedModelObjects {
	return [[self selectedObjects] valueForKey:@"representedObject"];
}
- (void)setSelectedModelObjects:(NSArray *)modelObjects {
	[[self treeController] setSelectedModelObjects:modelObjects];
}

- (NSArray *)selectedObjectsAndClickedObject:(id *)clickedObject; {
	NSInteger clickedRow = [[self outlineView] clickedRow];
	
	if (clickedRow != -1 && clickedObject)
		*clickedObject = [[[self outlineView] itemAtRow:clickedRow] representedObject];
	
	return [self selectedObjects];
}

- (NSArray *)selectedModelObjectsAndClickedObject:(id *)clickedObject; {
	NSInteger clickedRow = [[self outlineView] clickedRow];
	
	if (clickedRow != -1 && clickedObject)
		*clickedObject = [[[[self outlineView] itemAtRow:clickedRow] representedObject] representedObject];
	
	return [self selectedModelObjects];
}
#pragma mark *** Public Methods ***
- (id)initWithProjectDocument:(WCProjectDocument *)projectDocument; {
	if (!(self = [super initWithNibName:[self nibName] bundle:nil]))
		return nil;
	
	_projectDocument = projectDocument;
	_symbolFileContainer = [[WCSymbolFileContainer alloc] initWithFile:[[projectDocument projectContainer] representedObject]];
	
	return self;
}
#pragma mark Properties
@synthesize outlineView=_outlineView;
@synthesize treeController=_treeController;
@synthesize searchField=_searchField;

@synthesize projectDocument=_projectDocument;
@synthesize symbolFileContainer=_symbolFileContainer;

#pragma mark *** Private Methods ***
- (void)_updateSymbols; {
	[[self symbolFileContainer] willChangeValueForKey:@"statusString"];
	
	NSMapTable *filesToSourceFileDocuments = [[self projectDocument] filesToSourceFileDocuments];
	
	for (WCFile *file in [filesToSourceFileDocuments keyEnumerator]) {
		WCSymbolFileContainer *fileContainer = [WCSymbolFileContainer symbolFileContainerWithFile:file];
		NSArray *symbols = [[[filesToSourceFileDocuments objectForKey:file] sourceScanner] symbolsSortedByName];
		
		for (WCSourceSymbol *symbol in symbols) {
			WCSymbolContainer *symbolContainer = [WCSymbolContainer symbolContainerWithSourceSymbol:symbol];
			
			[[fileContainer mutableChildNodes] addObject:symbolContainer];
		}
		
		[[[self symbolFileContainer] mutableChildNodes] addObject:fileContainer];
	}
	
	[[self symbolFileContainer] didChangeValueForKey:@"statusString"];
	
	[[self outlineView] expandItem:nil expandChildren:YES];
}
#pragma mark IBActions
- (IBAction)_outlineViewDoubleClick:(id)sender; {
	for (id container in [self selectedObjects]) {
		id result = [container representedObject];
		
		if (![result isKindOfClass:[WCSourceSymbol class]])
			continue;
		
		WCFile *file = [[container parentNode] representedObject];
		WCSourceFileSeparateWindowController *windowController = [[self projectDocument] openSeparateEditorForFile:file];
		WCSourceTextViewController *stvController = [[[[[windowController tabViewController] sourceFileDocumentsToSourceTextViewControllers] objectEnumerator] allObjects] lastObject];
		
		[[stvController textView] setSelectedRange:[result range]];
		[[stvController textView] centerSelectionInVisibleArea:nil];
	}
}
- (IBAction)_outlineViewSingleClick:(id)sender; {
	for (id container in [self selectedObjects]) {
		id result = [container representedObject];
		
		if (![result isKindOfClass:[WCSourceSymbol class]])
			continue;
		
		WCFile *file = [[container parentNode] representedObject];
		WCSourceTextViewController *stvController = [[self projectDocument] openTabForFile:file tabViewContext:nil];
		
		[[stvController textView] setSelectedRange:[result range]];
		[[stvController textView] centerSelectionInVisibleArea:nil];
	}
}

#pragma mark Notifications

@end
