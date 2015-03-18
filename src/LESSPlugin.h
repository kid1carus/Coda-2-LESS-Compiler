#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"
#import "BaseCodaPlugin.h"

#import "LessDb.h"
#import "dropView.h"
#import "keyPrefButton.h"
#import "siteSettingsWindowController.h"
#import "preferenceWindowController.h"

#import "TaskMan.h"

@interface LESSPlugin : BaseCodaPlugin <CodaPlugIn, NSUserNotificationCenterDelegate, NSWindowDelegate, LessDbDelegate>
{
    
    TaskMan * task;
    NSString * outputText;
    NSString * errorText;
    
    siteSettingsWindowController * siteSettingsController;
    preferenceWindowController * preferenceController;
    LessDb * Ldb;
    
	BOOL isCompiling;
	int compileCount;
}

#pragma mark - preferences Window

//@property (strong) IBOutlet NSView *preferenceWindow;
//@property (strong) IBOutlet NSTextField *versionField;
//@property (strong) IBOutlet NSTextField *LESSVersionField;

//- (IBAction)userChangedPreference:(NSButton *)sender;
//- (IBAction)viewGithub:(id)sender;

@end
