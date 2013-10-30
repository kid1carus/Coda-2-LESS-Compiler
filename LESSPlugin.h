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
    NSBundle * oldBundle;
    
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
    FMResultSet * prefs;
    FMResultSet * currentSiteFiles;
}


#pragma mark - preferences Window
@property (strong) IBOutlet NSButton *displayNotificationOnError;
@property (strong) IBOutlet NSButton *displayNotificationOnSuccess;
@property (strong) IBOutlet NSButton *openFileOnError;

@property (strong) IBOutlet NSButton *playSoundsOnSuccess;
@property (strong) IBOutlet NSButton *playSoundsOnError;

@property (strong) IBOutlet NSTextField *versionField;
@property (strong) IBOutlet NSTextField *LESSVersionField;


#pragma mark - Site Settings Window


@end
