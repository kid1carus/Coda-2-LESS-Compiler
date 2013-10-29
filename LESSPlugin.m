#import "LESSPlugin.h"
#import "CodaPlugInsController.h"
#import "DDLog.h"
#import "DDASLLogger.h"
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface LESSPlugin ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation LESSPlugin

//2.0 and lower
- (id)initWithPlugInController:(CodaPlugInsController*)aController bundle:(NSBundle*)aBundle
{
    return [self initWithController:aController];
}


//2.0.1 and higher
- (id)initWithPlugInController:(CodaPlugInsController*)aController plugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    return [self initWithController:aController andPlugInBundle:p];
}

- (id)initWithController:(CodaPlugInsController*)inController andPlugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
    
    [controller registerActionWithTitle:@"LESS Compiler" target:self selector:nil];
    plugInBundle = p;
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
    
    [controller registerActionWithTitle:@"LESS Compiler" target:self selector:nil];
    
	return self;
}


- (NSString*)name
{
	return @"LESS Compiler";
}

-(void)textViewWillSave:(CodaTextView *)textView
{
    NSString *path = [textView path];
    if ([path length]) {
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        if ([[url pathExtension] isEqualToString:@"less"]) {
            
			NSString *cssFile = [path stringByReplacingOccurrencesOfString:[url lastPathComponent] withString:[[url lastPathComponent] stringByReplacingOccurrencesOfString:@"less" withString:@"css"]];
            
            [self compileFile:textView toFile:cssFile];
        }
    }
}


#pragma mark - LESS methods



-(void) compileFile:(CodaTextView *)textView toFile:(NSString *)cssFile
{
    NSString * lessFile = [textView path];
    
    DDLogVerbose(@"LESS:: Compiling file: %@ to file: %@", lessFile, cssFile);
    task = [[NSTask alloc] init];
    outputPipe = [[NSPipe alloc] init];
    errorPipe = [[NSPipe alloc]  init];
    outputText = [[NSString alloc] init];
    errorText = [[NSString alloc] init];
    
    task.launchPath = @"usr/bin/man"; //[NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
    DDLogVerbose(@"LESS:: launchPath: %@", task.launchPath);
    task.arguments = @[@"-h"];
    
    task.standardOutput = outputPipe;
    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getOutput:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[outputPipe fileHandleForReading]];
    
    task.standardError = errorPipe;
    [[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getError:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[errorPipe fileHandleForReading]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminate:) name:NSTaskDidTerminateNotification object:task];
    
    [task launch];
}


-(void) taskDidTerminate:(NSNotification *) notification
{
        DDLogInfo(@"LESS:: Task terminated.");
        DDLogInfo(@"LESS:: output: %@", outputText);
        DDLogInfo(@"LESS:: errors: %@", errorText);
}

-(void) getOutput:(NSNotification *) notification
{
	DDLogVerbose(@"LESS:: %@",[[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"]);
    NSData *output = [[outputPipe fileHandleForReading] availableData];
    NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
 
    dispatch_async(dispatch_get_main_queue(), ^{
        DDLogVerbose(@"LESS:: getOutput");
        outputText = [outputText stringByAppendingString: outStr];
        DDLogVerbose(@"LESS:: outputText: %@", outputText);
    });
    if([task isRunning])
    {
        [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
}


-(void) getError:(NSNotification *) notification
{
    
    NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
    NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
	DDLogVerbose(@"LESS:: %@", outStr);
    dispatch_async(dispatch_get_main_queue(), ^{
        DDLogVerbose(@"LESS:: getError");
        errorText = [errorText stringByAppendingString: outStr];
    });
    
    if([task isRunning])
    {
    	[[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
}

@end
