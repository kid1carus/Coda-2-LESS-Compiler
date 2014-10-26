//
//  FileView.h
//  LESSCompile
//
//  Created by Michael on 10/30/13.
//
//

#import <Cocoa/Cocoa.h>
@class keyPrefButton;

@interface FileView : NSView
@property (strong) IBOutlet NSTextField *fileName;
@property (strong) IBOutlet NSTextField *lessPath;
@property (strong) IBOutlet NSTextField *cssPath;
@property (strong) IBOutlet NSButton *changeCssPathButton;
@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) IBOutlet NSButton *advancedButton;

@property (assign) NSInteger fileIndex;
@property (strong) IBOutlet NSView *advancedSettingsView;

/* compilation options */
@property (strong) IBOutlet keyPrefButton *shouldMinify;

@property (strong) IBOutlet keyPrefButton *sourceMap;
@property (strong) IBOutlet keyPrefButton *strictMath;
@property (strong) IBOutlet keyPrefButton *noIE;
@property (strong) IBOutlet keyPrefButton *strictImports;
@property (strong) IBOutlet keyPrefButton *insecureImports;
@property (strong) IBOutlet keyPrefButton *relativeUrls;
@property (strong) IBOutlet keyPrefButton *disableJavascript;
@property (strong) IBOutlet keyPrefButton *sourcemapLessInline;
@property (strong) IBOutlet keyPrefButton *soucemapInline;
@property (strong) IBOutlet keyPrefButton *strictUnits;

@property (strong) IBOutlet NSPopUpButton *lineNumbers;

- (IBAction)toggleAdvanced:(id)sender;

- (IBAction)changeCssPath:(id)sender;
- (IBAction)deleteFile:(id)sender;

-(void) setupOptionsWithSelector:(SEL)aSelector andTarget:(id)target;
-(void) setCheckboxesForOptions:(NSDictionary *)options;
-(NSDictionary *) getOptionValues;
@end
