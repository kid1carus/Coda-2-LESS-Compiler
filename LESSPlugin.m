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
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
    
    task.launchPath = [NSString stringWithFormat:@"%@/node", [plugInBundle resourcePath]];
    DDLogVerbose(@"LESS:: launchPath: %@", task.launchPath);
    task.arguments = @[lessc, @"--no-color", lessFile];
    task.standardOutput = outputPipe;
    DDLogVerbose(@"LESS:: %@", task.environment);
    
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
        DDLogVerbose(@"LESS:: Task terminated with status: %d", task.terminationStatus);
}

-(void) getOutput:(NSNotification *) notification
{

    NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
    NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
	DDLogVerbose(@"LESS:: getOutput: %@",outStr);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        outputText = [outputText stringByAppendingString: outStr];
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
    DDLogError(@"LESS:: Encountered some error: %@", outStr);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * error = [self getErrorMessage:outStr];
        [self sendUserNotificationWithTitle:@"LESS:: Parse Error" sound: @"Basso" andMessage:error];
    });
    
    if([task isRunning])
    {
    	[[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
}

-(NSString *) getErrorMessage:(NSString *)fullError
{
    NSError * error = nil;
    NSString * output = [NSString stringWithFormat:@""];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ParseError:(.*?) in (.*?less) (.*):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        NSString * errorName = [fullError substringWithRange:[ntcr rangeAtIndex:1]];
        NSString * fileName = [[fullError substringWithRange:[ntcr rangeAtIndex:2]] lastPathComponent];
        NSString * lineNumber = [fullError substringWithRange:[ntcr rangeAtIndex:3]];
		output = [output stringByAppendingString:[NSString stringWithFormat:@"%@ in %@ %@", errorName, fileName, lineNumber]];
    }
    return output;
}

#pragma mark - NSUserNotification

-(void) sendUserNotificationWithTitle:(NSString *)title sound:(NSString *)sound andMessage:(NSString * ) message
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    notification.soundName = sound;

	if([[NSUserNotificationCenter defaultUserNotificationCenter] delegate] == nil)
    {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

@end
