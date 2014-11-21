//
//  siteSettingsWindowController.h
//  LESSCompile
//
//  Created by Michael on 10/29/14.
//
//

#import <Cocoa/Cocoa.h>
#import "dropView.h"
#import "FileView.h"
#import "flippedView.h"

@class LessDb;

@interface siteSettingsWindowController : NSWindowController <NSWindowDelegate, DraggingDestinationDelegate>
{
    LessDb * Ldb;
    NSMutableArray * fileViews;
    NSView * fileDocumentView;
    NSView * fileDocumentSubview;
}
@property (strong) IBOutlet NSButton *addFileButton;
@property (strong) IBOutlet NSScrollView *fileScrollView;
@property (strong) IBOutlet dropView *fileDropView;
- (IBAction)filePressed:(NSButton *)sender;
@end
