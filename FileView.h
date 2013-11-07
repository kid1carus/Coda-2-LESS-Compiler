//
//  FileView.h
//  LESSCompile
//
//  Created by Michael on 10/30/13.
//
//

#import <Cocoa/Cocoa.h>

@interface FileView : NSView
@property (strong) IBOutlet NSTextField *fileName;
@property (strong) IBOutlet NSTextField *lessPath;
@property (strong) IBOutlet NSTextField *cssPath;
@property (strong) IBOutlet NSButton *changeCssPathButton;
@property (strong) IBOutlet NSButton *shouldMinify;
@property (strong) IBOutlet NSButton *deleteButton;

@property (assign) NSInteger fileIndex;

- (IBAction)changeCssPath:(id)sender;
- (IBAction)deleteFile:(id)sender;
@end
