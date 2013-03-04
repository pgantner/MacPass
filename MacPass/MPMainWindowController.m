//
//  MPMainWindowController.m
//  MacPass
//
//  Created by Michael Starke on 24.07.12.
//  Copyright (c) 2012 HicknHack Software GmbH. All rights reserved.
//

#import "MPMainWindowController.h"
#import "MPDatabaseController.h"
#import "MPDatabaseDocument.h"
#import "MPPasswordInputController.h"
#import "MPEntryViewController.h"
#import "MPToolbarDelegate.h"
#import "MPOutlineViewController.h"
#import "MPMainWindowSplitViewDelegate.h"
#import "MPAppDelegate.h"
#import "MPEntryEditController.h"

@interface MPMainWindowController ()


@property (assign) IBOutlet NSView *outlineView;
@property (assign) IBOutlet NSSplitView *splitView;
@property (assign) IBOutlet NSView *contentView;

@property (retain) IBOutlet NSView *welcomeView;
@property (assign) IBOutlet NSTextField *welcomeText;
@property (retain) NSToolbar *toolbar;

@property (retain) MPPasswordInputController *passwordInputController;
@property (retain) MPEntryViewController *entryViewController;
@property (retain) MPEntryEditController *entryEditController;
@property (retain) MPOutlineViewController *outlineViewController;

@property (retain) MPToolbarDelegate *toolbarDelegate;
@property (retain) MPMainWindowSplitViewDelegate *splitViewDelegate;

- (void)_collapseOutlineView;
- (void)_expandOutlineView;
- (void)_setContentViewController:(MPViewController *)viewController;
- (void)_updateWindowTitle;

@end

@implementation MPMainWindowController

-(id)init {
  self = [super initWithWindowNibName:@"MainWindow" owner:self];
  if( self ) {
    _toolbarDelegate = [[MPToolbarDelegate alloc] init];    
    _outlineViewController = [[MPOutlineViewController alloc] init];
    _splitViewDelegate = [[MPMainWindowSplitViewDelegate alloc] init];
    
    [[NSBundle mainBundle] loadNibNamed:@"WelcomeView" owner:self topLevelObjects:NULL];
    [self.welcomeView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didOpenDocument:)
                                                 name:MPDatabaseControllerDidLoadDatabaseNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.welcomeView = nil;
  self.welcomeText = nil;
  self.toolbar = nil;
  
  self.passwordInputController = nil;
  self.entryViewController = nil;
  self.entryEditController = nil;
  self.outlineViewController = nil;
  
  self.toolbarDelegate = nil;
  self.splitViewDelegate = nil;
  [super dealloc];
}

#pragma mark View Handling

- (void)windowDidLoad
{
  [super windowDidLoad];
  [self _updateWindowTitle];
    
  [[self.welcomeText cell] setBackgroundStyle:NSBackgroundStyleRaised];
  
  const CGFloat minimumWindowWidth = MPMainWindowSplitViewDelegateMinimumContentWidth + MPMainWindowSplitViewDelegateMinimumOutlineWidth + [self.splitView dividerThickness];
  [self.window setMinSize:NSMakeSize( minimumWindowWidth, 400)];
  
  _toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainWindowToolbar"];
  [self.toolbar setAllowsUserCustomization:YES];
  [self.toolbar setDelegate:self.toolbarDelegate];
  [self.window setToolbar:self.toolbar];
  
  [self.splitView setDelegate:self.splitViewDelegate];
  
  NSRect frame = [self.outlineView frame];
  [self.outlineViewController.view setFrame:frame];
  [self.outlineViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [self.splitView replaceSubview:self.outlineView with:[self.outlineViewController view]];
  [self.outlineViewController updateResponderChain];
  [self.splitView adjustSubviews];
  
  [self _setContentViewController:nil];
  [self _collapseOutlineView];
}

- (void)_setContentViewController:(MPViewController *)viewController {
  NSView *newContentView = self.welcomeView;
  if(viewController && viewController.view) {
    newContentView = viewController.view;
  }
  /*
   Set correct size and resizing for view
   */
  [newContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  NSSize frameSize = [self.contentView frame].size;
  [newContentView setFrame:NSMakeRect(0,0, frameSize.width, frameSize.height)];
  
  /*
   Add or replace subview
   */
  NSArray *subViews = [self.contentView subviews];
  BOOL hasSubViews = ([subViews count] > 0);
  if(hasSubViews) {
    NSView *subView = subViews[0];
    assert(subView);
    [self.contentView replaceSubview:subView with:newContentView];
  }
  else {
    [self.contentView addSubview:newContentView];
  }
  [viewController updateResponderChain];
  [self.contentView setNeedsDisplay:YES];
  [self.splitView adjustSubviews];
  /*
   Set focus AFTER having added the view
   */
  [self.window makeFirstResponder:[viewController reconmendedFirstResponder]];
}

- (void)_collapseOutlineView {
  NSView *outlineView = [self.splitView subviews][0];
  if(![outlineView isHidden]) {
    [self.splitView setPosition:0 ofDividerAtIndex:0];
  }
}

- (void)_expandOutlineView {
  NSView *outlineView = [self.splitView subviews][0];
  if([outlineView isHidden]) {
    [self.splitView setPosition:MPMainWindowSplitViewDelegateMinimumOutlineWidth ofDividerAtIndex:0];
  }
}

- (void)_updateWindowTitle {
  if([MPDatabaseController defaultController].database) {
    NSString *appName = [(MPAppDelegate *)[NSApp delegate] applicationName];
    NSString *openFile = [[MPDatabaseController defaultController].database.file lastPathComponent];
    [self.window setTitle:[NSString stringWithFormat:@"%@ - %@", appName, openFile]];
  }
  else {
    [self.window setTitle:[(MPAppDelegate *)[NSApp delegate] applicationName]];
  }
}

#pragma mark Actions

- (void)performFindPanelAction:(id)sender {
  [self.window makeFirstResponder:[self.toolbarDelegate.searchItem view]];
}

- (void)showMainWindow:(id)sender {
  [self showWindow:self.window];
}

- (void)openDocument:(id)sender {
 
  if(!self.passwordInputController) {
    self.passwordInputController = [[[MPPasswordInputController alloc] init] autorelease];
  }
  
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseDirectories:NO];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setAllowsMultipleSelection:NO];
  [openPanel setAllowedFileTypes:@[ @"kdbx", @"kdb"]];
  [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
    if(result == NSFileHandlingPanelOKButton) {
      NSURL *file = [[openPanel URLs] lastObject];
      self.passwordInputController.fileURL = file;
      [self _collapseOutlineView];
      [self _setContentViewController:self.passwordInputController];
    }
  }];
}

- (void)updateFilter:(id)sender {
  NSSearchField *searchField = sender;
  self.entryViewController.filter = [searchField stringValue];
  [((NSOutlineView *)self.outlineViewController.view) deselectAll:self];
}

- (void)clearFilter:(id)sender {
  NSSearchField *searchField = sender;
  if(![sender isKindOfClass:[NSSearchField class]]) {
    searchField = [self locateToolbarSearchField];
  }
  [searchField setStringValue:@""];
  [self.entryViewController clearFilter];
}

- (void)clearOutlineSelection:(id)sender {
  [self.outlineViewController clearSelection];
}

- (void)showEditForm:(id)sender {
  if( ![MPDatabaseController hasOpenDatabase] ) {
    return; // No database open - nothing to do;
  }
  
  if(!self.entryEditController) {
    self.entryEditController = [[[MPEntryEditController alloc] init] autorelease];
  }
  //find active selection
  self.entryEditController.selectedItem = nil;
  [self _setContentViewController:self.entryEditController];
}


#pragma mark Helper

- (NSSearchField *)locateToolbarSearchField {
  for(NSToolbarItem *toolbarItem in [[self.window toolbar] items]) {
    NSView *view = [toolbarItem view];
    if([view isKindOfClass:[NSSearchField class]]) {
      return (NSSearchField *)view;
    }
  }
  return nil;
}

#pragma mark Notifications

- (void)didOpenDocument:(NSNotification *)notification {
  [self _updateWindowTitle];
  [self showEntries];
}

- (void)showEntries {
  [self _expandOutlineView];
  if(!self.entryViewController) {
    _entryViewController = [[MPEntryViewController alloc] init];
  }
  [self _setContentViewController:self.entryViewController];
}

- (IBAction)changedFileType:(id)sender {
}
@end
