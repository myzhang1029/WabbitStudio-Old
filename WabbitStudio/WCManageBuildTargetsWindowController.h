//
//  WCManageBuildTargetsWindowController.h
//  WabbitStudio
//
//  Created by William Towe on 2/11/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import <AppKit/NSWindowController.h>
#import "RSTableViewDelegate.h"

@class WCProjectDocument;

@interface WCManageBuildTargetsWindowController : NSWindowController <RSTableViewDelegate> {
	WCProjectDocument *_projectDocument;
}
@property (readwrite,assign,nonatomic) IBOutlet NSTableView *tableView;
@property (readwrite,assign,nonatomic) IBOutlet NSArrayController *arrayController;

@property (readonly,nonatomic) WCProjectDocument *projectDocument;

+ (id)manageBuildTargetsWindowControllerWithProjectDocument:(WCProjectDocument *)projectDocument;
- (id)initWithProjectDocument:(WCProjectDocument *)projectDocument;

- (void)showManageBuildTargetsWindow;

- (IBAction)ok:(id)sender;
- (IBAction)edit:(id)sender;
- (IBAction)newBuildTarget:(id)sender;
- (IBAction)newBuildTargetFromTemplate:(id)sender;
@end