#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseQueue.h"

@class CodaPlugInsController;

@interface LESSPlugin : NSObject <CodaPlugIn, NSUserNotificationCenterDelegate>
{
	CodaPlugInsController* controller;
    
	NSObject <CodaPlugInBundle> * plugInBundle;
    NSBundle * bundle;
    
    /* compile tasks and pipes */
    NSTask * task;
    NSPipe * outputPipe;
    NSPipe * errorPipe;
    
    /* indexing tasks and pipes */
    NSTask * indexTask;
    NSPipe * indexPipe;
    
    NSString * outputText;
    NSString * errorText;
    
    FMDatabaseQueue * dbQueue;
	NSMutableDictionary * prefs;
    NSMutableArray * currentParentFiles;
    int currentParentFilesCount;
    NSMutableArray * fileViews;
    NSView * fileDocumentView;
}

#pragma mark - preferences Window
@property (strong) IBOutlet NSView *preferenceWindow;
@property (strong) IBOutlet NSTextField *versionField;
@property (strong) IBOutlet NSTextField *LESSVersionField;

- (IBAction)userChangedPreference:(NSButton *)sender;

#pragma mark - Site Settings Window
@property (strong) IBOutlet NSButton *fileButton;
@property (strong) IBOutlet NSView *fileSettingsWindow;
@property (strong) IBOutlet NSScrollView *fileScrollView;

- (IBAction)filePressed:(NSButton *)sender;

@end
