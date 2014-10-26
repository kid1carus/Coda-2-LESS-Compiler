#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"
#import "BaseCodaPlugin.h"

#import "LessDb.h"
#import "dropView.h"
#import "keyPrefButton.h"

@interface LESSPlugin : BaseCodaPlugin <CodaPlugIn, NSUserNotificationCenterDelegate, NSWindowDelegate, DraggingDestinationDelegate, LessDbDelegate>
{
    
    /* compile tasks and pipes */
    NSTask * task;
    NSPipe * outputPipe;
    NSPipe * errorPipe;
    
    NSString * outputText;
    NSString * errorText;
    
    NSMutableArray * fileViews;
    NSView * fileDocumentView;
    LessDb * Ldb;
    
	BOOL isCompiling;
	int compileCount;
}

#pragma mark - preferences Window

@property (strong) IBOutlet NSView *preferenceWindow;
@property (strong) IBOutlet NSTextField *versionField;
@property (strong) IBOutlet NSTextField *LESSVersionField;

- (IBAction)userChangedPreference:(NSButton *)sender;

#pragma mark - Site Settings Window
@property (strong) IBOutlet NSButton *fileButton;
@property (strong) IBOutlet dropView *fileSettingsWindow;
@property (strong) IBOutlet NSScrollView *fileScrollView;

- (IBAction)filePressed:(NSButton *)sender;

@end
