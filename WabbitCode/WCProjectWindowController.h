//
//  WCProjectWindowController.h
//  WabbitStudio
//
//  Created by William Towe on 1/13/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import <AppKit/NSWindowController.h>
#import "RSNavigatorControlDataSource.h"
#import "RSNavigatorControlDelegate.h"
#import "WCProjectDocumentSettingsProvider.h"
#import "WCTabViewControllerDelegate.h"
#import "WCTabViewContext.h"

@class WCProjectNavigatorViewController,WCTabViewController,WCSearchNavigatorViewController,WCIssueNavigatorViewController,WCSymbolNavigatorViewController,WCBreakpointNavigatorViewController;

@interface WCProjectWindowController : NSWindowController <WCTabViewControllerDelegate,WCProjectDocumentSettingsProvider,RSNavigatorControlDataSource,RSNavigatorControlDelegate,WCTabViewContext,NSSplitViewDelegate,NSWindowDelegate> {
	NSMutableArray *_navigatorItemDictionaries;
	WCProjectNavigatorViewController *_projectNavigatorViewController;
	WCSearchNavigatorViewController *_searchNavigatorViewController;
	WCIssueNavigatorViewController *_issueNavigatorViewController;
	WCSymbolNavigatorViewController *_symbolNavigatorViewController;
	WCBreakpointNavigatorViewController *_breakpointNavigatorViewController;
	WCTabViewController *_tabViewController;
}
@property (readwrite,assign,nonatomic) IBOutlet RSNavigatorControl *navigatorControl;
@property (readwrite,assign,nonatomic) IBOutlet NSSplitView *splitView;

@property (readonly,nonatomic) WCProjectNavigatorViewController *projectNavigatorViewController;
@property (readonly,nonatomic) WCTabViewController *tabViewController;
@property (readonly,nonatomic) WCSearchNavigatorViewController *searchNavigatorViewController;
@property (readonly,nonatomic) WCIssueNavigatorViewController *issueNavigatorViewController;
@property (readonly,nonatomic) WCSymbolNavigatorViewController *symbolNavigatorViewController;
@property (readonly,nonatomic) WCBreakpointNavigatorViewController *breakpointNavigatorViewController;

- (IBAction)showProjectNavigator:(id)sender;
- (IBAction)showSymbolNavigator:(id)sender;
- (IBAction)showSearchNavigator:(id)sender;
- (IBAction)showIssueNavigator:(id)sender;
- (IBAction)showBreakpointNavigator:(id)sender;
- (IBAction)showDebugNavigator:(id)sender;
- (IBAction)showBookmarkNavigator:(id)sender;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;

@end