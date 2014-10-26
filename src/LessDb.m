//
//  LessDb.m
//  LESSCompile
//
//  Created by Michael on 10/26/14.
//
//

#import "LessDb.h"
#import "DDLog.h"
#import "DDASLLogger.h"

static int ddLogLevel = LOG_LEVEL_ERROR;
static float COMPATIBLEDB = 0.6;
static LessDb * sharedDb;

@implementation LessDb

-(LessDb *)initWithDelegate:(BaseCodaPlugin<LessDbDelegate> *)d
{
    if(self = [super init])
    {
        self.delegate = d;
        sharedDb = self;
    }
    return self;
}

+(LessDb *)sharedLessDb
{
    if(sharedDb == nil)
    {
        sharedDb = [[LessDb alloc] init];
    }
    return sharedDb;
}

-(void) setupDb
{
    //Create Db file if it doesn't exist
    NSError * error;
    NSURL * dbFile;
    if (![_delegate doesPersistantFileExist:@"db.sqlite"]) {
        DDLogVerbose(@"LESS:: db file does not exist. Attempting to create.");
        if(![self copyDbFile])
        {
            return;
        }
    }
    dbFile = [_delegate urlForPeristantFilePath:@"db.sqlite"];
    DDLogVerbose(@"LESS:: dbFile: %@", dbFile);
    
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
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
    
    dbFile = [_delegate urlForPeristantFilePath:@"db.sqlite"];
    DDLogVerbose(@"LESS:: dbFile: %@", dbFile);
    
    [_dbQueue close];
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    [self getDbPreferences];
}

-(void) getDbPreferences
{
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * prefSet = [db executeQuery:@"SELECT * FROM preferences"];
        if([prefSet next])
        {
            _prefs = [[NSJSONSerialization JSONObjectWithData:[[prefSet stringForColumn:@"json"] dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] mutableCopy];
            DDLogVerbose(@"LESS:: prefs: %@", _prefs);
        }
        else
        {
            DDLogVerbose(@"LESS:: no preferences found!");
            _prefs = [NSMutableDictionary dictionaryWithObjectsAndKeys: nil];
        }
        
        if([_prefs objectForKey:@"verboseLog"] != nil && [[_prefs objectForKey:@"verboseLog"] intValue] == 1)
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
    if(![_delegate doesPersistantStorageDirectoryExist])
    {
        error = [_delegate createPersistantStorageDirectory];
        if(error)
        {
            DDLogError(@"LESS:: Error creating Persistant Storage Directory: %@", error);
            return false;
        }
    }
    DDLogVerbose(@"LESS:: path for resource: %@",[_delegate.pluginBundle pathForResource:@"db" ofType:@"sqlite"]);
    error = [_delegate copyFileToPersistantStorage:[_delegate.pluginBundle pathForResource:@"db" ofType:@"sqlite"]];
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
    if([_delegate getCurrentSiteUUID] == nil)
    {
        return;
    }
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        DDLogVerbose(@"LESS:: updateParentFilesWithCompletion");
        FMResultSet * d = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE parent_id == -1 AND site_uuid == '%@'", [_delegate getCurrentSiteUUID]] ];
        if(_currentParentFiles == nil)
        {
            _currentParentFiles = [NSMutableArray array];
        }
        else
        {
            [_currentParentFiles removeAllObjects];
        }
        while([d next])
        {
            [_currentParentFiles addObject:[d resultDictionary]];
        }
        
        FMResultSet *s = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM less_files WHERE parent_id == -1 AND site_uuid == '%@'", [_delegate getCurrentSiteUUID]] ];
        if ([s next])
        {
            _currentParentFilesCount = [s intForColumnIndex:0];
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
    [_dbQueue inDatabase:^(FMDatabase *db) {
        [_prefs setObject:val forKey:pref];
        NSData * jData = [NSJSONSerialization dataWithJSONObject:_prefs options:kNilOptions error:nil];
        [db executeUpdate:@"UPDATE preferences SET json = :json WHERE id == 1" withParameterDictionary:@{@"json" : jData}];
    }];
}


-(void) registerFile:(NSURL *)url
{
    if(url == nil)
    {
        return;
    }
    
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    if(![[fileName pathExtension] isEqualToString:@"less"])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Hey that file isn't a Less file"];
        [alert setInformativeText:[NSString stringWithFormat:@"The file '%@' doesn't appear to be a Less file.", [fileName lastPathComponent]]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[[_delegate.controller focusedTextView] window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        return;
    }
    NSString *cssFile = [fileName stringByReplacingOccurrencesOfString:[url lastPathComponent] withString:[[url lastPathComponent] stringByReplacingOccurrencesOfString:@"less" withString:@"css"]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
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
                    
                    [alert beginSheetModalForWindow:[[_delegate.controller focusedTextView] window] modalDelegate:self didEndSelector:nil contextInfo:nil];
                    [parent close];
                    [file close];
                    return;
                }
                [parent close];
            }
            //otherwise, we could maybe throw another alert here. But instead, let's just re-register the file.
        }
        [file close];
        
        NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", cssFile, @"css_path", fileName, @"path", [NSNumber numberWithInteger:-1], @"parent_id", [_delegate getCurrentSiteUUID], @"site_uuid", nil];
        
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
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
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
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    NSString * cssFileName = [_delegate getResolvedPathForPath:[cssUrl path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
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

-(void) updateLessFilePreferences:(NSDictionary *)options forPath:(NSURL *) url
{
    
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:options options:kNilOptions error:nil];
    
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        if([db executeUpdate:@"UPDATE less_files SET options == :val WHERE path == :path" withParameterDictionary:@{@"val": preferenceData, @"path" : fileName}])
        {
            DDLogVerbose(@"LESS:: updateLessFilePreferences: successfully updated preference for %@", fileName);
            DDLogVerbose(@"LESS:: updateLessFilePreferences: updated preferences to: %@", [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding]);
        }
        else
        {
            DDLogError(@"LESS:: updateLessFilePreferences: error: %@", [db lastError]);
        }
    }];
    
}


-(void) performDependencyCheckOnFile:(NSString *)path
{
    if(_isDepenencying)
    {
        DDLogVerbose(@"LESS:: Already checking Dependencies!");
        return;
    }
    DDLogVerbose(@"LESS:: Performing dependency check on %@", path);
    _isDepenencying = true;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        
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
        
        NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [_delegate.pluginBundle resourcePath]];
        
        indexTask.launchPath = [NSString stringWithFormat:@"%@/node", [_delegate.pluginBundle resourcePath]];
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
            
            [_dbQueue inDatabase:^(FMDatabase *db) {
                for(NSTextCheckingResult * ntcr in dependencies)
                {
                    NSString * fileName =   [_delegate getResolvedPathForPath:[outStr substringWithRange:[ntcr rangeAtIndex:1]]];
                    
                    NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", @"", @"css_path", fileName, @"path", [NSNumber numberWithInteger:parentId], @"parent_id", [_delegate getCurrentSiteUUID], @"site_uuid", nil];
                    
                    if([db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id, site_uuid) VALUES (:minify, :css_path, :path, :parent_id, :site_uuid)" withParameterDictionary:args])
                    {
                        DDLogVerbose(@"LESS:: dependency update succeeded: %@", fileName);
                    }
                    else
                    {
                        DDLogError(@"LESS:: dependency update failed: %@", fileName);
                    }
                }
                _isDepenencying = false;
            }];
        }];
        
        [indexTask launch];
        
    }];
}

@end
