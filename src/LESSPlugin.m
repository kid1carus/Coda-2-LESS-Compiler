#import "LESSPlugin.h"
#import "CodaPlugInsController.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "FileView.h"

static int ddLogLevel = LOG_LEVEL_ERROR;
static NSString * COMPVERSION = @"0.5.0";
static NSString * LESSVERSION = @"1.7.0";
static float COMPATIBLEDB = 0.5f;
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
        [self setupDb];
    }
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		controller = inController;
        [self registerActions];
    }
	return self;
}

-(void) registerActions
{
    [controller registerActionWithTitle:@"Site Settings" underSubmenuWithTitle:nil target:self selector:@selector(openSitesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    
    [controller registerActionWithTitle:@"Preferences" underSubmenuWithTitle:nil target:self selector:@selector(openPreferencesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    
    isCompiling = false;
    isDepenencying = false;
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
    DDLogError(@"growl delegate: %@", [GrowlApplicationBridge growlDelegate]);
	//make sure currentSiteUUID is up to date.
   	[self updateCurrentSiteUUID];
    
    [NSBundle loadNibNamed:@"siteSettingsWindow" owner: self];
    [[self.fileSettingsWindow window] setDelegate:self];
    
    [self.fileSettingsWindow setDelegate:self];
    fileDocumentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    
    [self.fileScrollView setDocumentView:fileDocumentView];
    [self updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}

-(void) openPreferencesMenu
{
    if(self.preferenceWindow != nil)
    {
        return;
    }
    [NSBundle loadNibNamed:@"preferencesWindow" owner: self];
    [[self.preferenceWindow window] setDelegate:self];
    [self.LESSVersionField setStringValue:LESSVERSION];
    [self.versionField setStringValue:COMPVERSION];
    
    if(prefs == nil)
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
            NSNumber * val = [prefs objectForKey:prefKey];
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
    
    [fileDocumentView setFrame:NSMakeRect(0, 0, 583, MAX( (111 * (currentParentFilesCount + 1)), self.fileScrollView.frame.size.height - 10))];

    // if there are no files to display, then display a footer.
    
    if(currentParentFilesCount == 0)
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
    
    for(int i = currentParentFilesCount - 1; i >= 0; i--)
    {
        NSDictionary * currentFile = [currentParentFiles objectAtIndex:i];
        
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
        fRect = f.frame;
        
        
        NSURL * url = [NSURL fileURLWithPath:[currentFile objectForKey:@"path"] isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:[currentFile objectForKey:@"path"]];
        [f.cssPath setStringValue:[currentFile objectForKey:@"css_path"]];
        [f.shouldMinify setState:[[currentFile objectForKey:@"minify"] intValue]];
        
        [f.deleteButton setAction:@selector(deleteParentFile:)];
        [f.deleteButton setTarget:self];
        [f.changeCssPathButton setAction:@selector(changeCssFile:)];
        [f.changeCssPathButton setTarget:self];
        [f.shouldMinify setAction:@selector(changeMinify:)];
        [f.shouldMinify setTarget:self];
        
		f.fileIndex = i;
        
        float frameY = currentParentFilesCount > 3 ? i * fRect.size.height : (fileDocumentView.frame.size.height - ((currentParentFilesCount - i) * fRect.size.height));
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


#pragma mark - database methods

-(void) setupDb
{
	//Create Db file if it doesn't exist
    NSError * error;
    NSURL * dbFile;
    if (![self doesPersistantFileExist:@"db.sqlite"]) {
        DDLogVerbose(@"LESS:: db file does not exist. Attempting to create.");
       if(![self copyDbFile])
       {
           return;
       }
    }
    dbFile = [self urlForPeristantFilePath:@"db.sqlite"];
    DDLogVerbose(@"LESS:: dbFile: %@", dbFile);
    
    dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * versionSet  = [db executeQuery:@"SELECT version from preferences"];
        if([versionSet next])
        {
            float dbVersion = [versionSet doubleForColumn:@"version"];
            [versionSet close];
            //The current database version is lower than the latest, so we'll need to kill it :x
            if(dbVersion < COMPATIBLEDB)
            {
                [self performSelectorOnMainThread:@selector(replaceDatabase) withObject:nil waitUntilDone:false];
            }
            else
            {
                [self performSelectorOnMainThread:@selector(getDbPreferences) withObject:nil waitUntilDone:false];
            }
        }
        [versionSet close];
    }];
    
    [self updateParentFilesListWithCompletion:nil];
}

-(void) replaceDatabase
{
    DDLogError(@"LESS:: Current database incompatible with latest compiler release. So we're going to have to nuke it. Sorry :/");
    NSError * error;
    NSURL * dbFile;
    
    if(![self copyDbFile])
    {
        return;
    }
    
    dbFile = [self urlForPeristantFilePath:@"db.sqlite"];
    DDLogVerbose(@"LESS:: dbFile: %@", dbFile);
    
    [dbQueue close];
    dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    [self getDbPreferences];
}

-(void) getDbPreferences
{
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
        
        if([prefs objectForKey:@"verboseLog"] != nil && [[prefs objectForKey:@"verboseLog"] intValue] == 1)
        {
            ddLogLevel = LOG_LEVEL_VERBOSE;
        }
		[prefSet close];
    }];
    
    [self updateParentFilesListWithCompletion:nil];
}

-(BOOL) copyDbFile
{
	NSError * error;
    if(![self doesPersistantStorageDirectoryExist])
    {
        error = [self createPersistantStorageDirectory];
        if(error)
        {
            DDLogError(@"LESS:: Error creating Persistant Storage Directory: %@", error);
            return false;
        }
    }
    DDLogVerbose(@"LESS:: path for resource: %@",[plugInBundle pathForResource:@"db" ofType:@"sqlite"]);
    error = [self copyFileToPersistantStorage:[plugInBundle pathForResource:@"db" ofType:@"sqlite"]];
    if(error)
    {
        DDLogError(@"LESS:: Error creating database file: %@", error);
        return false;
    }
    DDLogVerbose(@"LESS:: Successfully created db.sqlite file");
    return true;
}

-(void) updateParentFilesListWithCompletion:(void(^)(void))handler;
{
    if(currentSiteUUID == nil)
    {
        return;
    }
    
    [dbQueue inDatabase:^(FMDatabase *db) {
        DDLogVerbose(@"LESS:: updateParentFilesWithCompletion");
        FMResultSet * d = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE parent_id == -1 AND site_uuid == '%@'", currentSiteUUID] ];
        if(currentParentFiles == nil)
        {
            currentParentFiles = [NSMutableArray array];
        }
        else
        {
            [currentParentFiles removeAllObjects];
        }
		while([d next])
        {
            [currentParentFiles addObject:[d resultDictionary]];
        }
        
        FMResultSet *s = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM less_files WHERE parent_id == -1 AND site_uuid == '%@'", currentSiteUUID] ];
        if ([s next])
        {
            currentParentFilesCount = [s intForColumnIndex:0];
        }
        
        if(handler != nil)
        {
            handler();
        }
        [s close];
        [d close];
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

-(void) registerFile:(NSURL *)url
{
    if(url == nil)
    {
        return;
    }
    
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    if(![[fileName pathExtension] isEqualToString:@"less"])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Hey that file isn't a Less file"];
        [alert setInformativeText:[NSString stringWithFormat:@"The file '%@' doesn't appear to be a Less file.", [fileName lastPathComponent]]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[[controller focusedTextView] window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        return;
    }
    NSString *cssFile = [fileName stringByReplacingOccurrencesOfString:[url lastPathComponent] withString:[[url lastPathComponent] stringByReplacingOccurrencesOfString:@"less" withString:@"css"]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        DDLogVerbose(@"LESS:: registerFile");
        
        // check if the file has already been registered
        FMResultSet * file = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:@{@"path": fileName}];
        if([file next])
        {
            // is it a dependency of a parent file?
            if([file intForColumn:@"parent_id"] > -1)
            {
                NSString * filePath = [[file stringForColumn:@"path"] lastPathComponent];
                FMResultSet * parent = [db executeQuery:@"SELECT * FROM less_files WHERE id = :id" withParameterDictionary:@{@"id" : [NSNumber numberWithInt:[file intForColumn:@"parent_id"]] }];
                
                //make sure that the parent file actually exists. If it does, then throw an alert.
                if([parent next])
                {
                    NSString * parentPath = [[parent stringForColumn:@"path"] lastPathComponent];
                    
                   DDLogError(@"LESS:: Trying to register dependency of file '%@'.", [parent stringForColumn:@"path"]);
                    
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:@"OK"];
                    [alert setMessageText:@"File already registered"];
                    [alert setInformativeText:[NSString stringWithFormat:@"The file '%@' is already a dependency of '%@'", filePath, parentPath]];
                    [alert setAlertStyle:NSWarningAlertStyle];
                    
                    [alert beginSheetModalForWindow:[[controller focusedTextView] window] modalDelegate:self didEndSelector:nil contextInfo:nil];
                    [parent close];
					[file close];
                    return;
                }
                [parent close];
            }
            //otherwise, we could maybe throw another alert here. But instead, let's just re-register the file.
        }
        [file close];
        
        NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", cssFile, @"css_path", fileName, @"path", [NSNumber numberWithInteger:-1], @"parent_id", currentSiteUUID, @"site_uuid", nil];

        if(![db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id, site_uuid) VALUES (:minify, :css_path, :path, :parent_id, :site_uuid)"
    			withParameterDictionary:args ])
        {
			DDLogError(@"LESS:: SQL ERROR: %@", [db lastError]);
            return;
        }
        DDLogVerbose(@"LESS:: Inserted registered file");
        [self performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:fileName waitUntilDone:FALSE];
    }];
}

-(void) unregisterFile:(NSURL *)url
{
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
    	FMResultSet * parentFile = [db executeQuery:@"SELECT * FROM less_files WHERE path == :path" withParameterDictionary:@{@"path":fileName}];
        if(![parentFile next])
        {
            DDLogError(@"LESS:: unregisterFile: file %@ not found in db", fileName);
            return;
        }
        
        int parentFileId = [parentFile intForColumn:@"id"];
        [db executeUpdate:@"DELETE FROM less_files WHERE parent_id == :parent_id" withParameterDictionary:@{@"parent_id" : [NSNumber numberWithInt:parentFileId]}];
        
        [db executeUpdate:@"DELETE FROM less_files WHERE id == :id" withParameterDictionary:@{@"id" : [NSNumber numberWithInt:parentFileId]}];
        DDLogVerbose(@"LESS:: unregisterFile: unregistered file %@", fileName);
        [parentFile close];
    }];
}

-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url
{
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    NSString * cssFileName = [self getResolvedPathForPath:[cssUrl path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * parentFile = [db executeQuery:@"SELECT * FROM less_files WHERE path == :path" withParameterDictionary:@{@"path":fileName}];
        if(![parentFile next])
        {
            DDLogError(@"LESS:: setCssPath: file %@ not found in db", fileName);
            return;
        }
		if([db executeUpdate:@"UPDATE less_files SET css_path == :css_path WHERE id == :id" withParameterDictionary:@{@"css_path":cssFileName, @"id": [NSNumber numberWithInt:[parentFile intForColumn:@"id"]]}])
        {
        	DDLogVerbose(@"LESS:: setCssPath: successfully set css path for file %@", fileName);
        }
        else
        {
            DDLogError(@"LESS:: setCssPath: error, %@",[db lastError]);
        }
        [parentFile close];
    }];
}

-(void) setLessFilePreference:(NSString *)pref toValue:(id)val forPath:(NSURL *) url
{
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        if([db executeUpdate:[NSString stringWithFormat:@"UPDATE less_files SET %@ == :val WHERE path == :path", pref] withParameterDictionary:@{@"val": val, @"path" : fileName}])
        {
            DDLogVerbose(@"LESS:: setLessFilePreferences: successfully updated preference for %@", fileName);
        }
        else
        {
            DDLogError(@"LESS:: setLessFilePreferences: error: %@", [db lastError]);
        }
    }];
}

-(void) performDependencyCheckOnFile:(NSString *)path
{
    if(isDepenencying)
    {
        DDLogVerbose(@"LESS:: Already checking Dependencies!");
        return;
    }
    DDLogVerbose(@"LESS:: Performing dependency check on %@", path);
	isDepenencying = true;
    [dbQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet * parent = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:path, @"path", nil]];
        if(![parent next])
        {
            DDLogError(@"LESS:: Parent file not found in db!");
            [parent close];
            return;
        }
        
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
            NSError * error;
            outStr = [outStr stringByReplacingOccurrencesOfString:@"DEPENDS: " withString:@""];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(/.*?\\.less)" options:nil error:&error];
            NSArray * dependencies = [regex matchesInString:outStr options:nil range:NSMakeRange(0, [outStr length])];
            
            [dbQueue inDatabase:^(FMDatabase *db) {
                for(NSTextCheckingResult * ntcr in dependencies)
                {
                    NSString * fileName =   [self getResolvedPathForPath:[outStr substringWithRange:[ntcr rangeAtIndex:1]]];
                    
                    NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", @"", @"css_path", fileName, @"path", [NSNumber numberWithInteger:parentId], @"parent_id", currentSiteUUID, @"site_uuid", nil];
                    
                    if([db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id, site_uuid) VALUES (:minify, :css_path, :path, :parent_id, :site_uuid)" withParameterDictionary:args])
                    {
                        DDLogVerbose(@"LESS:: dependency update succeeded: %@", fileName);
                    }
                    else
                    {
                        DDLogError(@"LESS:: dependency update failed: %@", fileName);
                    }
                }
                isDepenencying = false;
            }];
        }];
        
        [indexTask launch];
        
    }];
}

#pragma mark - LESS methods

-(void) handleLessFile:(CodaTextView *)textView
{
    if(isCompiling || isDepenencying || (task != nil && [task isRunning]))
    {
        DDLogVerbose(@"LESS:: Compilation already happening!");
        return;
    }
    
    NSString *path = [self getResolvedPathForPath:[textView path]];
    DDLogVerbose(@"LESS:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    DDLogVerbose(@"LESS:: Handling file: %@", path);
    
    [dbQueue inDatabase:^(FMDatabase *db) {
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
            [self performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:parentPath waitUntilDone:false];
            
            
            //Set compilation options
            NSMutableArray * options  = [NSMutableArray array];
        	if([parentFile intForColumn:@"minify"] == 1)
            {
                [options addObject:@"-x"];
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
    if(isCompiling || isDepenencying || (task!= nil && [task isRunning]))
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
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
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
    if([[prefs objectForKey:@"strictMath"] boolValue] == true)
    {
        [arguments addObject:@"--strict-math=on"];
    }
    
    [arguments addObject:lessFile];
    [arguments addObject:cssFile];
    DDLogVerbose(@"LESS:: Node arguments: %@", arguments);
    task.launchPath = [NSString stringWithFormat:@"%@/node", [plugInBundle resourcePath]];
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
//    isCompiling = false;
//    if(task.terminationStatus == 0)
//    {
//        [self displaySuccess];
//    }
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
            if([[prefs objectForKey:@"displayOnError"] integerValue] == 1)
            {
                NSString * sound = nil;
                if([[prefs objectForKey:@"playOnError"] integerValue] == 1)
                {
                    sound = @"Basso";
                }
                
                [self sendUserNotificationWithTitle:@"LESS:: Parse Error" andMessage:[error objectForKey:@"errorMessage"]];
            }
            
            if([[prefs objectForKey:@"openFileOnError"] integerValue] == 1)
            {
                NSError * err;
                CodaTextView * errorTextView = [controller openFileAtPath:[error objectForKey:@"filePath"] error:&err];
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
    if([[prefs objectForKey:@"displayOnSuccess"] intValue] == 1)
    {
        NSString * sound = nil;
        if([[prefs objectForKey:@"playOnSuccess"] intValue] == 1)
        {
            sound = NSUserNotificationDefaultSoundName;
        }
        
        [self sendUserNotificationWithTitle:@"LESS:: Compiled Successfully!" andMessage:@"file compiled successfully!"];
    }
}
#pragma mark - Site Settings
- (IBAction)filePressed:(NSButton *)sender
{
    [self registerFile:[self getFileNameFromUser]];
    [self updateParentFilesListWithCompletion:^{
	    [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];

}

-(void) deleteParentFile:(NSButton *)sender
{
	FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Really Delete %@?", f.fileName.stringValue]];
    [alert setInformativeText:[NSString stringWithFormat:@"Are you sure you want to delete %@ ?", f.fileName.stringValue]];
    NSInteger response = [alert runModal];
    if(response == NSAlertFirstButtonReturn)
    {
        NSDictionary * fileInfo = [currentParentFiles objectAtIndex:f.fileIndex];
        NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
        [self unregisterFile:url];
        [self updateParentFilesListWithCompletion:^{
            [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
        }];
    }
    else
    {
        return;
    }
}

-(void) changeCssFile:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    NSDictionary * fileInfo = [currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
    [self setCssPath:[self getSaveNameFromUser] forPath:url];
    [self updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}

-(void) changeMinify:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    int shouldMinify = [sender state];
    NSDictionary * fileInfo = [currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
    [self setLessFilePreference:@"minify" toValue:[NSNumber numberWithInt:shouldMinify] forPath:url];
    [self updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}


#pragma mark - DraggingDestinationDelegate


-(void) draggingDestinationPerformedDragOperation:(id<NSDraggingInfo>)sender
{
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([[pboard types] containsObject:NSURLPboardType]) {
        
        NSArray *paths = [pboard propertyListForType:NSURLPboardType];
 		for(NSString * aPath in paths)
        {
            if([aPath isEqualToString:@""])
            {
                continue;
            }
            NSURL * aUrl = [NSURL URLWithString:aPath];
            [self registerFile:aUrl];
        }
    }
    
    [self updateParentFilesListWithCompletion:^{
	    [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];

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
