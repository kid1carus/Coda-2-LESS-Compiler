//
//  preferenceWindowController.h
//  LESSCompile
//
//  Created by Michael on 11/12/14.
//
//

#import <Cocoa/Cocoa.h>
@class LessDb;

@interface preferenceWindowController : NSWindowController
{
    LessDb * Ldb;
}
- (IBAction)viewGithub:(id)sender;
@property (strong) IBOutlet NSView *view;
@property (strong) IBOutlet NSTextField *compilerVersion;
@property (strong) IBOutlet NSTextField *lessVersion;

@end
