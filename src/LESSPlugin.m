#import "LESSPlugin.h"
#import "CodaPlugInsController.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "FileView.h"

static int ddLogLevel = LOG_LEVEL_ERROR;
static NSString * COMPVERSION = @"0.5.0";
static NSString * LESSVERSION = @"1.7.0";
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
    if ( (self = [super initWithController:inController andPlugInBundle:p]) != nil )
	{
        [self registerActions];
        Ldb = [[LessDb alloc] initWithDelegate:self];
        [Ldb setupDb];
    }
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		self.controller = inController;
        [self registerActions];
    }
	return self;
}

-(void) registerActions
{
    [self.controller registerActionWithTitle:@"Site Settings" underSubmenuWithTitle:nil target:self selector:@selector(openSitesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    
    [self.controller registerActionWithTitle:@"Preferences" underSubmenuWithTitle:nil target:self selector:@selector(openPreferencesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    //preference menu can always be opened.
    if([[menuItem title] isEqualToString:@"Preferences"])
    {
        return true;
    }
    
    return [self isSiteOpen];
}

- (NSString*)name
{
	return @"LESS Compiler";
}

-(void)textViewWillSave:(CodaTextView *)textView
{
    NSString *path = [textView path];
    if([path length] > 0)
    {
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        if([[url pathExtension] isEqualToString:@"less"])
        {
            [self performSelectorOnMainThread:@selector(handleLessFile:) withObject:textView waitUntilDone:true];
        }
    }
}

#pragma mark - Menu methods

-(void) openSitesMenu
{
    if(self.fileSettingsWindow != nil)
    {
        return;
    }
    [self updateCurrentSiteUUID];
    siteSettingsController = [[siteSettingsWindowController alloc] init];
    [siteSettingsController showWindow:self];
    
	//make sure currentSiteUUID is up to date.
   	
    
//    [NSBundle loadNibNamed:@"siteSettingsWindow" owner: self];
//    [[self.fileSettingsWindow window] setDelegate:self];

//    [self.fileSettingsWindow setDelegate:self];
//    fileDocumentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
//    
//    [self.fileScrollView setDocumentView:fileDocumentView];
//    [Ldb updateParentFilesListWithCompletion:^{
//        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
//    }];
}

-(void) openPreferencesMenu
{
    if(self.preferenceWindow != nil)
    {
        return;
    }
    BOOL result = [NSBundle loadNibNamed:@"preferencesWindow" owner: self ];
    DDLogError(@"LESS:: loaded preferencesWindow? %d", result);
    if(self.preferenceWindow == nil)
    {
        DDLogError(@"LESS:: preferenceWindow is still nil?");
    }
    
    [[self.preferenceWindow window] setDelegate:self];
    [self.LESSVersionField setStringValue:LESSVERSION];
    [self.versionField setStringValue:COMPVERSION];
    
    if(Ldb.prefs == nil)
    {
        DDLogVerbose(@"LESS:: prefs is nil");
        return;
    }
    
    DDLogVerbose(@"LESS:: setting up preference window");
    for(NSButton * b in [self.preferenceWindow subviews])
    {
        if([b isKindOfClass:[NSButton class]] && [b valueForKey:@"prefKey"] != nil)
        {
            NSString * prefKey = [b valueForKey:@"prefKey"];
            NSNumber * val = [Ldb.prefs objectForKey:prefKey];
            DDLogVerbose(@"LESS:: Preference: %@ : %@", prefKey, val);
            if(val != nil)
            {
                [b setState:[val integerValue]];
            }
        }
    }
}

-(void) rebuildFileList
{
    DDLogVerbose(@"LESS:: rebuildFileList");

    [fileDocumentView setSubviews:[NSArray array]];

    fileViews = [NSMutableArray array];
    NSRect fRect;
    
    [fileDocumentView setFrame:NSMakeRect(0, 0, 583, MAX( (111 * (Ldb.currentParentFilesCount + 1)), self.fileScrollView.frame.size.height - 10))];

    // if there are no files to display, then display a footer.
    
    if(Ldb.currentParentFilesCount == 0)
    {
        NSView * footerView;
        NSArray *nibObjects = [self loadNibNamed:@"FileFooter"];
        
        for(NSView * o in nibObjects)
        {
            if([o isKindOfClass:[NSView class]])
            {
                footerView = o;
                break;
            }
        }
        
        fRect = footerView.frame;
        fRect.origin.y = 0;
        footerView.frame = fRect;
        
        [fileDocumentView addSubview:footerView];
        return;
    }
    
    //otherwise, display the list of files.
    
    for(int i = Ldb.currentParentFilesCount - 1; i >= 0; i--)
    {
        NSDictionary * currentFile = [Ldb.currentParentFiles objectAtIndex:i];
        
        NSArray *nibObjects = [self loadNibNamed:@"FileView"];
        
        FileView * f;
        for(FileView * o in nibObjects)
        {
            if([o isKindOfClass:[FileView class]])
            {
                f = o;
                break;
            }
        }
        
        if(f == nil)
        {
            DDLogError(@"LESS:: Error loading nib FileView");
        }
        
       
        fRect = f.frame;
        
        [f setupOptionsWithSelector:@selector(userUpdatedLessFilePreference:) andTarget:self];
        NSDictionary * options = [NSJSONSerialization JSONObjectWithData:[currentFile objectForKey:@"options"] options:0 error:nil];
        [f setCheckboxesForOptions:options];
        
        NSURL * url = [NSURL fileURLWithPath:[currentFile objectForKey:@"path"] isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:[currentFile objectForKey:@"path"]];
        [f.cssPath setStringValue:[currentFile objectForKey:@"css_path"]];
        
        [f.deleteButton setAction:@selector(deleteParentFile:)];
        [f.deleteButton setTarget:self];
        [f.changeCssPathButton setAction:@selector(changeCssFile:)];
        [f.changeCssPathButton setTarget:self];
        
		f.fileIndex = i;
        
        float frameY = Ldb.currentParentFilesCount > 3 ? i * fRect.size.height : (fileDocumentView.frame.size.height - ((Ldb.currentParentFilesCount - i) * fRect.size.height));
        [f setFrame:NSMakeRect(0, frameY, fRect.size.width, fRect.size.height)];
        [fileViews addObject:f];
    	[fileDocumentView addSubview:f];
    }
}

#pragma mark - NSWindowDelegate methods


-(void)windowWillClose:(NSNotification *)notification
{
    if([[notification object] isEqualTo:[self.fileSettingsWindow window]])
    {
        self.fileSettingsWindow = nil;
        self.fileScrollView = nil;
        fileDocumentView = nil;
    }
    
    if([[notification object] isEqualTo:[self.preferenceWindow window]])
    {
        self.preferenceWindow = nil;
    }
}


#pragma mark - LESS methods

-(void) handleLessFile:(CodaTextView *)textView
{
    if(isCompiling || Ldb.isDepenencying || (task!= nil && [task isRunning]))
    {
        DDLogVerbose(@"LESS:: Compilation already happening!");
        return;
    }
    
    NSString *path = [self getResolvedPathForPath:[textView path]];
    DDLogVerbose(@"LESS:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    DDLogVerbose(@"LESS:: Handling file: %@", path);
    
    [Ldb.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * s = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:@{@"path": path}];
        if([s next])
        {
            FMResultSet * parentFile = s;
            int parent_id = [parentFile intForColumn:@"parent_id"];
            DDLogVerbose(@"LESS:: initial parent_id: %d", parent_id);
            //Find the parent Less file (parent_id = -1)
            //This could probably be done with one query, but I'm kind of bad with SQL recursion :welp:
            while(parent_id > -1)
            {
                [parentFile close];
                parentFile = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE id = %d", parent_id]];
                if([parentFile next])
                {
                    parent_id = [parentFile intForColumn:@"parent_id"];
                }
            }
            
			NSString * parentPath = [parentFile stringForColumn:@"path"];
            NSString *cssPath = [parentFile stringForColumn:@"css_path"];

            DDLogVerbose(@"LESS:: parent Path: %@", parentPath);
            DDLogVerbose(@"LESS:: css Path: %@", cssPath);
            
            //start the dependency check back on the main thread
            [Ldb performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:parentPath waitUntilDone:false];
            
            
            //Set compilation options
            NSMutableArray * options  = [NSMutableArray array];
            NSDictionary * parentFileOptions = [NSJSONSerialization JSONObjectWithData:[parentFile dataForColumn:@"options"] options:0 error:nil];
            
            for(NSString * optionName in parentFileOptions.allKeys)
            {
                if([[parentFileOptions objectForKey:optionName] intValue] == 1)
                {
                    [options addObject:optionName];
                }
            }
            
            [parentFile close];
            [self compileFile:parentPath toFile:cssPath withOptions:options];
        }
        else
        {
            DDLogError(@"LESS:: No DB entry found for file: %@", path);
        }
        [s close];
    }];
}

-(void) compileFile:(NSString *)lessFile toFile:(NSString *)cssFile withOptions:(NSArray *)options
{
    if(isCompiling || Ldb.isDepenencying || (task!= nil && [task isRunning]))
    {
        DDLogVerbose(@"LESS:: Compilation task is already running.");
        return;
    }
    isCompiling = true;
    compileCount++;
    DDLogVerbose(@"LESS:: Compiling file: %@ to file: %@", lessFile, cssFile);
    DDLogVerbose(@"LESS:: Compile count: %d", compileCount);
    task = [[NSTask alloc] init];
    outputPipe = [[NSPipe alloc] init];
    errorPipe = [[NSPipe alloc]  init];
    outputText = [[NSString alloc] init];
    errorText = [[NSString alloc] init];
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [self.pluginBundle resourcePath]];
    NSMutableArray * arguments = [NSMutableArray array];
    [arguments addObject:lessc];
    [arguments addObject:@"--no-color"];
    if(options)
    {
        for(NSString * arg in options)
        {
            [arguments addObject:arg];
        }
    }
    
    [arguments addObject:lessFile];
    [arguments addObject:cssFile];
    DDLogVerbose(@"LESS:: Node arguments: %@", arguments);
    task.launchPath = [NSString stringWithFormat:@"%@/node", [self.pluginBundle resourcePath]];
    task.arguments = arguments;
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
    DDLogVerbose(@"LESS:: Received taskDidTerminate.");
    
    if(task.isRunning)
    {
        DDLogVerbose(@"LESS:: Psyche, task is still running.");
        return;
    }
    DDLogVerbose(@"LESS:: Task terminated with status: %d", task.terminationStatus);
    DDLogVerbose(@"LESS:: =====================================================");
}

-(void) getOutput:(NSNotification *) notification
{

    NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
    NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
//	DDLogVerbose(@"LESS:: getOutput: %@",outStr);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        outputText = [outputText stringByAppendingString: outStr];
    });
    
    if([task isRunning])
    {
        [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
    else
    {
        DDLogVerbose(@"LESS:: Task terminated with status: %d", task.terminationStatus);
        DDLogVerbose(@"LESS:: =====================================================");
        isCompiling = false;
        if(task.terminationStatus == 0)
        {
        	[self displaySuccess];
        }
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
    DDLogError(@"LESS:: Encountered some error on compilation task: %@", outStr);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary * error = [self getErrorMessage:outStr];
        if(error != nil)
        {
            if([[Ldb.prefs objectForKey:@"displayOnError"] integerValue] == 1)
            {
                NSString * sound = nil;
                if([[Ldb.prefs objectForKey:@"playOnError"] integerValue] == 1)
                {
                    sound = @"Basso";
                }
                
                [self sendUserNotificationWithTitle:@"LESS:: Parse Error" andMessage:[error objectForKey:@"errorMessage"]];
            }
            
            if([[Ldb.prefs objectForKey:@"openFileOnError"] integerValue] == 1)
            {
                NSError * err;
                CodaTextView * errorTextView = [self.controller openFileAtPath:[error objectForKey:@"filePath"] error:&err];
                if(err)
                {
                	DDLogVerbose(@"LESS:: error opening file: %@", err);
                    return;
                }
                
                [errorTextView goToLine:[[error objectForKey:@"lineNumber"] integerValue] column:[[error objectForKey:@"columnNumber"] integerValue] ];
            }
        }
    });
    
    if([task isRunning])
    {
    	[[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
}

/* parse the error message and pull the useful bits from it. */

-(NSDictionary *) getErrorMessage:(NSString *)fullError
{
    NSError * error = nil;
    NSDictionary * output = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.*?)Error:(.*?) in (.*?less) on line (.*?), column (.*?):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        NSString * errorType = 	  [fullError substringWithRange:[ntcr rangeAtIndex:1]];
        NSString * errorName = 	  [fullError substringWithRange:[ntcr rangeAtIndex:2]];
        NSString * filePath = 	  [fullError substringWithRange:[ntcr rangeAtIndex:3]];
        NSString * fileName = 	  [[fullError substringWithRange:[ntcr rangeAtIndex:3]] lastPathComponent];
        NSNumber * lineNumber =   [NSNumber numberWithInteger: [[fullError substringWithRange:[ntcr rangeAtIndex:4]] integerValue]];
        NSNumber * columnNumber = [NSNumber numberWithInteger: [[fullError substringWithRange:[ntcr rangeAtIndex:5]] integerValue]];
        
        NSString * errorMessage = [NSString stringWithFormat:@"%@ in %@, on line %@ column %@", errorName, fileName, lineNumber, columnNumber];
        
        output = @{@"errorMessage": errorMessage,
                   @"errorType": errorType,
                   @"filePath": filePath,
                   @"fileName": fileName,
                   @"lineNumber":lineNumber,
                   @"columnNumber":columnNumber};
        
    }
    DDLogVerbose(@"LESS:: Error: %@", output);
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



-(void) displaySuccess
{
    if([[Ldb.prefs objectForKey:@"displayOnSuccess"] intValue] == 1)
    {
        NSString * sound = nil;
        if([[Ldb.prefs objectForKey:@"playOnSuccess"] intValue] == 1)
        {
            sound = NSUserNotificationDefaultSoundName;
        }
        
        [self sendUserNotificationWithTitle:@"LESS:: Compiled Successfully!" andMessage:@"file compiled successfully!"];
    }
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
    [Ldb updatePreferenceNamed:pref withValue:newState];
    
    if([pref isEqualToString:@"verboseLog"])
    {
        if([sender state] == NSOffState)
        {
            ddLogLevel = LOG_LEVEL_ERROR;
            DDLogError(@"LESS:: Verbose logging disabled.");
        }
        else if([sender state] == NSOnState)
        {
            ddLogLevel = LOG_LEVEL_VERBOSE;
            DDLogVerbose(@"LESS:: Verbose logging enabled.");
        }
    }
}
@end
