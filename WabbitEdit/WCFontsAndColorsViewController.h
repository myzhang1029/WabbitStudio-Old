//
//  WCFontsAndColorsViewController.h
//  WabbitEdit
//
//  Created by William Towe on 12/27/11.
//  Copyright (c) 2011 Revolution Software. All rights reserved.
//

#import <AppKit/NSViewController.h>
#import "RSPreferencesModule.h"
#import "RSUserDefaultsProvider.h"
#import "RSTableViewDelegate.h"

extern NSString *const WCFontsAndColorsCurrentThemeIdentifierKey;
extern NSString *const WCFontsAndColorsUserThemeIdentifiersKey;

@interface WCFontsAndColorsViewController : NSViewController <RSPreferencesModule,RSUserDefaultsProvider,RSTableViewDelegate,NSWindowDelegate,NSMenuDelegate> {
	id <NSWindowDelegate> _oldWindowDelegate;
	id _fontPanelWillCloseObservingToken;
}
@property (readwrite,assign,nonatomic) IBOutlet NSView *initialFirstResponder;
@property (readwrite,assign,nonatomic) IBOutlet NSArrayController *themesArrayController;
@property (readwrite,assign,nonatomic) IBOutlet NSArrayController *pairsArrayController;
@property (readwrite,assign,nonatomic) IBOutlet RSTableView *themesTableView;
@property (readwrite,assign,nonatomic) IBOutlet NSTableView *pairsTableView;

- (IBAction)chooseFont:(id)sender;
- (IBAction)deleteTheme:(id)sender;
- (IBAction)duplicateTheme:(id)sender;
@end
