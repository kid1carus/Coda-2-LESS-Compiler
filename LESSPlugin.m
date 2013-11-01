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
    [NSBundle loadNibNamed:@"siteSettingsWindow" owner: self];
}

-(void) openPreferencesMenu
{
    [NSBundle loadNibNamed:@"preferencesWindow" owner: self];
    [self.LESSVersionField setStringValue:@"1.4.2"];
    [self.versionField setStringValue:@"0.1"];
    
    if(prefs == nil)
    {
        return;
    }
    
    DDLogVerbose(@"LESS:: setting up preference window");
    for(NSButton * b in [self.preferenceWindow subviews])
    {
        if([b isKindOfClass:[NSButton class]] && [b valueForKey:@"prefKey"] != nil)
        {
            NSString * prefKey = [b valueForKey:@"prefKey"];
            NSNumber * val = [prefs objectForKey:prefKey];
            DDLogVerbose(@"LESS:: Preference: %@ : %@", prefKey, val);
            if(val != nil)
            {
                [b setState:[val integerValue]];
            }
        }
    }
}

-(NSURL *) getFileNameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    
    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];
    
    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];
    
    // Display the dialog. If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [openDlg URLs];
        
        // Loop through all the files and process them.
        for(NSURL * url in files)
        {
            chosenFile = url;
        }
    }
    return chosenFile;
}

#pragma mark - database methods

-(void) setupDb
{
    dbQueue = [FMDatabaseQueue databaseQueueWithPath:[[plugInBundle resourcePath] stringByAppendingString:@"/db.sqlite"]];
    
    [dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet * prefSet = [db executeQuery:@"SELECT * FROM preferences"];
        if([prefSet next])
        {
            prefs = [[NSJSONSerialization JSONObjectWithData:[[prefSet stringForColumn:@"json"] dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] mutableCopy];
            DDLogVerbose(@"LESS:: prefs: %@", prefs);
        }
        else
        {
            DDLogVerbose(@"LESS:: no preferences found!");
            prefs = [NSMutableDictionary dictionaryWithObjectsAndKeys: nil];
        }
    }];
}

-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val
{
    [dbQueue inDatabase:^(FMDatabase *db) {
        [prefs setObject:val forKey:pref];
		NSData * jData = [NSJSONSerialization dataWithJSONObject:prefs options:kNilOptions error:nil];
        [db executeUpdate:@"UPDATE preferences SET json = :json WHERE id == 1" withParameterDictionary:@{@"json" : jData}];
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

-(NSString *) getResourceIdFromURL:(NSURL *)url
{
    NSString * r;
	NSError * error;
    [url getResourceValue:&r forKey:NSURLFileResourceIdentifierKey error:&error];
    if(error)
    {
        DDLogError(@"LESS:: Error getting file resource id: %@", error);
        return nil;
    }
    return r;
}

-(NSString *) getResolvedPathForPath:(NSString *)path
{
    NSURL * url = [NSURL fileURLWithPath:path];
    url = [NSURL URLWithString:[url absoluteString]];	//absoluteString returns path in file:// format
	NSString * newPath = [[url URLByResolvingSymlinksInPath] path];	//URLByResolvingSymlinksInPath expects file:// format for link, then resolves all symlinks
    DDLogVerbose(@"LESS:: Converted from: %@ \n to: %@", path, newPath);
    return newPath;
}


-(void) registerFile:(NSURL *)url
{
    if(url == nil)
    {
        DDLogVerbose(@"LESS:: User canceled file selection");
        return;
    }
    
	DDLogVerbose(@"LESS:: file system representation: %s", [url fileSystemRepresentation]);
    
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    NSString *cssFile = [fileName stringByReplacingOccurrencesOfString:[url lastPathComponent] withString:[[url lastPathComponent] stringByReplacingOccurrencesOfString:@"less" withString:@"css"]];
    DDLogVerbose(@"LESS:: registering file: %@ with css file: %@", fileName, cssFile);
    [dbQueue inDatabase:^(FMDatabase *db) {
        if(![db executeUpdate:@"DELETE FROM less_files WHERE path = :path" withParameterDictionary:@{@"path" : fileName}])
        {
            DDLogError(@"LESS:: Whoa, big problem trying to delete sql rows");
        }
        
        NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", cssFile, @"css_path", fileName, @"path", [NSNumber numberWithInteger:-1], @"parent_id", nil];

        if(![db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id) VALUES (:minify, :css_path, :path, :parent_id)"
    			withParameterDictionary:args ])
        {
			DDLogError(@"LESS:: SQL ERROR: %@", [db lastError]);
            return;
        }
        DDLogVerbose(@"LESS:: Inserted registered file");
        [self performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:fileName waitUntilDone:FALSE];
    }];
}

-(void) performDependencyCheckOnFile:(NSString *)path
{
    DDLogVerbose(@"LESS:: Performing dependency check on %@", path);

    [dbQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet * parent = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:path, @"path", nil]];
        if(![parent next])
        {
            DDLogError(@"LESS:: Parent file not found in db!");
            return;
        }
        
        DDLogVerbose(@"LESS:: Continuing with dependency check");
        int parentId = [parent intForColumn:@"id"];
        [parent close];
        
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
            
            [dbQueue inDatabase:^(FMDatabase *db) {
                if(![db executeUpdate:@"DELETE FROM less_files WHERE parent_id = :parent_id" withParameterDictionary:@{@"parent_id": [NSNumber numberWithInteger:parentId]}])
                {
                    DDLogError(@"LESS:: Whoa, big problem deleting old files");
                }
            }];
            for(NSTextCheckingResult * ntcr in dependencies)
            {
                NSString * fileName =   [self getResolvedPathForPath:[outStr substringWithRange:[ntcr rangeAtIndex:1]]];
                
                DDLogVerbose(@"LESS:: dependency: \"%@\"", fileName);
                [dbQueue inDatabase:^(FMDatabase *db) {
                    NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", @"", @"css_path", fileName, @"path", [NSNumber numberWithInteger:parentId], @"parent_id", nil];
                    
                    if([db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id) VALUES (:minify, :css_path, :path, :parent_id)" withParameterDictionary:args])
                    {
                        DDLogVerbose(@"LESS:: dependency update succeeded: %@", fileName);
                    }
                    else
                    {
                        DDLogError(@"LESS:: dependency update failed: %@", fileName);
                    }
                }];
            }
            
        }];
        
        [indexTask launch];
        
    }];
}


#pragma mark - LESS methods

-(void) handleLessFile:(CodaTextView *)textView
{

    NSString *path = [self getResolvedPathForPath:[textView path]];
    DDLogVerbose(@"LESS:: Handling file: %@", path);
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * s = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:@{@"path": path}];
        if([s next])
        {
            FMResultSet * parentFile = s;
            int parent_id = [parentFile intForColumn:@"parent_id"];
            DDLogVerbose(@"LESS:: initial parent_id: %d", parent_id);
            while(parent_id > -1)
            {
                parentFile = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE id = %d", parent_id]];
                if([parentFile next])
                {
                    parent_id = [parentFile intForColumn:@"parent_id"];
                }
                DDLogVerbose(@"LESS:: next parent_id: %d", parent_id);
            }
            
			NSString * parentPath = [parentFile stringForColumn:@"path"];
            NSString *cssPath = [parentFile stringForColumn:@"css_path"];
            DDLogVerbose(@"LESS:: parent Path: %@", parentPath);
            DDLogVerbose(@"LESS:: css Path: %@", cssPath);
            [self performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:parentPath waitUntilDone:false];
            [self compileFile:parentPath toFile:cssPath];
        }
        else
        {
            DDLogError(@"LESS:: No DB entry found for file: %@", path);
        }
    }];
    

}

-(void) compileFile:(NSString *)lessFile toFile:(NSString *)cssFile
{
    
    DDLogVerbose(@"LESS:: Compiling file: %@ to file: %@", lessFile, cssFile);
    task = [[NSTask alloc] init];
    outputPipe = [[NSPipe alloc] init];
    errorPipe = [[NSPipe alloc]  init];
    outputText = [[NSString alloc] init];
    errorText = [[NSString alloc] init];
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
    
    task.launchPath = [NSString stringWithFormat:@"%@/node", [plugInBundle resourcePath]];
    task.arguments = @[lessc, @"--no-color", lessFile, cssFile];
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
    DDLogVerbose(@"LESS:: Task terminated with status: %d", task.terminationStatus);
    if(task.terminationStatus == 0)
    {
        if([[prefs objectForKey:@"displayOnSuccess"] intValue] == 1)
        {
            NSString * sound = nil;
            if([[prefs objectForKey:@"playOnSuccess"] intValue] == 1)
            {
                sound = NSUserNotificationDefaultSoundName;
            }
            
        	[self sendUserNotificationWithTitle:@"LESS:: Compiled Successfully!" sound:sound  andMessage:@"File compiled successfully!"];
        }
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
    if([outStr isEqualToString:@""])
    {
        return;
    }
    DDLogError(@"LESS:: Encountered some error: %@", outStr);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * error = [self getErrorMessage:outStr];
        if(![error isEqualToString:@""])
        {
            if([[prefs objectForKey:@"displayOnError"] integerValue] == 1)
            {
                NSString * sound = nil;
                if([[prefs objectForKey:@"playOnError"] integerValue] == 1)
                {
                    sound = @"Basso";
                }
                
                [self sendUserNotificationWithTitle:@"LESS:: Parse Error" sound:sound andMessage:error];
            }
            
            if([[prefs objectForKey:@"openFileOnError"] integerValue] == 1)
            {
                NSError * err;
                [controller openFileAtPath:[self getFileNameFromError:outStr] error:&err];
                if(err)
                {
                	DDLogVerbose(@"LESS:: error opening file: %@", err);
                }
            }
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

-(NSString *) getFileNameFromError:(NSString *)fullError
{
    NSError * error = nil;
    NSString * output = [NSString stringWithFormat:@""];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ParseError:(.*?) in (.*?less) (.*):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        output = [fullError substringWithRange:[ntcr rangeAtIndex:2]];
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


#pragma mark - Site Settings
- (IBAction)filePressed:(NSButton *)sender
{
    [self registerFile:[self getFileNameFromUser]];
}

#pragma mark - preferences

- (IBAction)userChangedPreference:(NSButton *)sender
{
    if([sender valueForKey:@"prefKey"] == nil)
    {
        return;
    }
    NSString * pref = [sender valueForKey:@"prefKey"];
    NSNumber * newState = [NSNumber numberWithInteger:[sender state]];
    DDLogVerbose(@"LESS:: setting preference %@ : %@", pref, newState);
    [self updatePreferenceNamed:pref withValue:newState];
}
@end
