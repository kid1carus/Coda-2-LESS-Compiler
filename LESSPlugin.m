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
    plugInBundle = p;
    [self registerActions];
    [self setupDb];
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
    
    [self registerActions];
	return self;
}

-(void) registerActions
{
    [controller registerActionWithTitle:@"Site Settings" underSubmenuWithTitle:@"top menu" target:self selector:@selector(openSitesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    [controller registerActionWithTitle:@"Preferences" underSubmenuWithTitle:@"top menu" target:self selector:@selector(openPreferencesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return true;
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
            
            [self handleLessFile:textView];
            
        }
    }
}

#pragma mark - Menu methods

-(void) openSitesMenu
{
    
}

-(void) openPreferencesMenu
{
    [NSBundle loadNibNamed:@"preferencesWindow" owner: self];
    [self.LESSVersionField setStringValue:@"1.4.2"];
    [self.versionField setStringValue:@"0.1"];
}
#pragma mark - database methods

-(void) setupDb
{
    dbQueue = [FMDatabaseQueue databaseQueueWithPath:[[plugInBundle resourcePath] stringByAppendingString:@"/db.sqlite"]];
    
    [dbQueue inDatabase:^(FMDatabase *db) {
		prefs = [db executeQuery:@"SELECT * FROM preferences"];
    }];
}


-(FMResultSet *) getRegisteredFilesForSite:(NSString *) siteName
{
    DDLogVerbose(@"LESS:: getting registered files for site: %@", siteName);
    __block FMResultSet * ret;
    [dbQueue inDatabase:^(FMDatabase *db) {
       ret = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE site_id == '%@'", siteName]];
    }];
    
    return ret;
}




#pragma mark - LESS methods

-(void) handleLessFile:(CodaTextView *)textView
{
    NSString *path = [textView path];
    [self performDependencyCheckOnFile:path];
//    
//    
//    [dbQueue inDatabase:^(FMDatabase *db) {
//        FMResultSet * s = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE path = '%@'", path]];
//        while([s next])
//        {
//            FMResultSet * parentFile = s;
//            int parent_id = [parentFile intForColumn:@"parent_id"];
//            DDLogVerbose(@"LESS:: initial parent_id: %d", parent_id);
//            while(parent_id > -1)
//            {
//                parentFile = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE id = %d", parent_id]];
//                if([parentFile next])
//                {
//                    parent_id = [parentFile intForColumn:@"parent_id"];
//                }
//                DDLogVerbose(@"LESS:: next parent_id: %d", parent_id);
//            }
//            
//			NSString * parentPath = [parentFile stringForColumn:@"path"];
//            NSString *cssPath = [parentFile stringForColumn:@"css_path"];
//            DDLogVerbose(@"LESS:: parent Path: %@", parentPath);
//            DDLogVerbose(@"LESS:: css Path: %@", cssPath);
//            [self performDependencyCheckOnFile:parentPath];
//            [self compileFile:textView toFile:cssPath];
//        }
//    }];
    

}

-(void) performDependencyCheckOnFile:(NSString *)path
{
    indexTask = [[NSTask alloc] init];
    indexPipe = [[NSPipe alloc]  init];
    
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
    
    indexTask.launchPath = [NSString stringWithFormat:@"%@/node", [plugInBundle resourcePath]];
    indexTask.arguments = @[lessc, @"--depends", path, @"DEPENDS"];
    
    indexTask.standardOutput = indexPipe;
    
    [[indexPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification object:[indexPipe fileHandleForReading] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        
        NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
        NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        DDLogVerbose(@"LESS:: Output from --depends: %@", outStr);
        NSError * error;
        outStr = [outStr stringByReplacingOccurrencesOfString:@"DEPENDS: " withString:@""];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(/.*?\.less)" options:nil error:&error];
        NSArray * dependencies = [regex matchesInString:outStr options:nil range:NSMakeRange(0, [outStr length])];
        for(NSTextCheckingResult * ntcr in dependencies)
        {
            NSString * fileName = [outStr substringWithRange:[ntcr rangeAtIndex:1]];
            DDLogVerbose(@"LESS:: dependency: \"%@\"", fileName);
        }

    }];

	[indexTask launch];
}

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
    task.arguments = @[lessc, @"--no-color", lessFile, cssFile];
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
    if(task.terminationStatus == 0)
    {
        [self sendUserNotificationWithTitle:@"LESS:: Compiled Successfully!" sound: NSUserNotificationDefaultSoundName andMessage:@"File compiled successfully!"];
    }
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
        if(![error isEqualToString:@""])
        {
        	[self sendUserNotificationWithTitle:@"LESS:: Parse Error" sound: @"Basso" andMessage:error];
        }
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
