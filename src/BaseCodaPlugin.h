#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"


@class CodaPlugInsController;

@interface BaseCodaPlugin : NSObject <CodaPlugIn, NSUserNotificationCenterDelegate>
{
	CodaPlugInsController* controller;
    
	NSObject <CodaPlugInBundle> * plugInBundle;
    NSBundle * bundle;
    NSString * currentSiteUUID;
}
- (id)initWithController:(CodaPlugInsController*)inController;
- (id)initWithController:(CodaPlugInsController*)inController andPlugInBundle:(NSObject <CodaPlugInBundle> *)p;
#pragma mark - open/save file dialogs
-(NSURL *) getFileNameFromUser;
-(NSURL *) getSaveNameFromUser;

#pragma mark - persistant storage methods
-(BOOL) doesPersistantFileExist:(NSString *)path;
-(BOOL) doesPersistantStorageDirectoryExist;
-(NSURL *) urlForPeristantFilePath:(NSString *)path;
-(NSError *) createPersistantStorageDirectory;
-(NSError *) copyFileToPersistantStorage:(NSString *)path;
#pragma mark - url/path helpers
-(NSString *) getResolvedPathForPath:(NSString *)path;
#pragma mark - NSUserNotification methods
-(void) sendUserNotificationWithTitle:(NSString *)title sound:(NSString *)sound andMessage:(NSString * ) message;
@end
