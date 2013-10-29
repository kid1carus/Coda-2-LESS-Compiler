#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"

@class CodaPlugInsController;

@interface LESSPlugin : NSObject <CodaPlugIn>
{
	CodaPlugInsController* controller;
	NSObject <CodaPlugInBundle> * plugInBundle;
    NSTask * task;
    NSPipe * outputPipe;
    NSPipe * errorPipe;
    
    NSString * outputText;
    NSString * errorText;
}

@end
