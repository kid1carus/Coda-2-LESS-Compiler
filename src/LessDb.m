//
//  LessDb.m
//  LESSCompile
//
//  Created by Michael on 10/26/14.
//
//

#import "LessDb.h"

static float COMPATIBLEDB = 0.6;
static float VERY_OLD_DB = 0.4;
static LessDb * sharedDb;

@implementation LessDb

-(LessDb *)initWithDelegate:(BaseCodaPlugin<LessDbDelegate> *)d
{
    if(self = [super init])
    {
        self.delegate = d;
        sharedDb = self;
        [self reloadDbPreferences];
        [self runCoreDataMigration];
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

#pragma mark - database setup

-(void) runCoreDataMigration
{
    if(![_delegate doesPersistantFileExist:@"db.sqlite"])
    {
        return;
    }
    
    // get dbQueue
    NSURL * dbFile = [_delegate urlForPeristantFilePath:@"db.sqlite"];
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[dbFile path]];
    
    
    // get parent files
    NSArray * parentFiles = [self getParentFiles];
    
    for(NSDictionary * parentFile in parentFiles)
    {
        LessFile * newFile = [self newObjectForEntityForName:@"LessFile"];
        newFile.path = [parentFile objectForKey:@"path"];
        newFile.css_path = [parentFile objectForKey:@"css_path"];
        newFile.site_uuid = [parentFile objectForKey:@"site_uuid"];
        newFile.options = [parentFile objectForKey:@"options"];
        [[self managedObjectContext] save:nil];
        [self addDependencyCheckOnFile:newFile.path];
    }
    
    // get preferences
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * prefs = [db executeQuery:@"SELECT * from preferences"];
        if([prefs next])
        {
            NSData * jsonData = [prefs dataForColumn:@"json"];
            LessPreferences * newPreferences = [self getDbPreferences];
            newPreferences.json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [[self managedObjectContext] save:nil];
        }
        [prefs close];
    }];
    
    [_dbQueue close];
    _dbQueue = nil;
    
    // and delete the db file, because we don't need it anymore.
    [_delegate removeFileFromPersistantStorage:[dbFile path]];
}


// This is intended to be used only when updating the database file. It pulls specific values that are common to previous versions of the database,
// So we can restore these values when db.sqlite is replaced.
-(NSArray *) getParentFiles;
{
    NSMutableArray * parentPaths = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * files = [db executeQuery:@"SELECT * FROM less_files WHERE parent_id = :parent_id" withParameterDictionary:@{@"parent_id" : @(-1)}];
        while([files next])
        {
            NSMutableDictionary * fields = [@{@"path": [files stringForColumn:@"path"],
                                              @"site_uuid": [files stringForColumn:@"site_uuid"],
                                              @"css_path": [files stringForColumn:@"css_path"],
                                              @"parent_id": @([files intForColumn:@"parent_id"])} mutableCopy];
            if([files stringForColumn:@"options"] != nil)
            {
                fields[@"options"] = [files stringForColumn:@"options"];
            }
            
            [parentPaths addObject: fields];
        }
    }];
    return parentPaths;
}

#pragma mark - general preferences

// retrieve the preferences from the database, and create an NSDictionary from them
-(LessPreferences *) getDbPreferences
{
    
    NSArray * f = [self fetchResultsForEntityNamed:@"Preferences"];
    if(f.count == 0)
    {
        LessPreferences * p = [self newObjectForEntityForName:@"Preferences"];
        p.json = @"{\
        \"displayOnError\":1,\
        \"displayOnSuccess\":1,\
        \"openFileOnError\":0,\
        \"playOnSuccess\":0,\
        \"playOnError\":1\
        }";
        [[self managedObjectContext] save:nil];
        return p;
    }
    return f[0];
}


-(void) reloadDbPreferences
{
    _internalPreferences = [self getDbPreferences];
    _prefs = [[NSJSONSerialization JSONObjectWithData:[_internalPreferences.json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] mutableCopy];
    
    [self updateParentFilesList];
}


// Update the given preference, and push the change to the database
-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val
{
    if(_prefs == nil)
    {
        _prefs = [NSMutableDictionary dictionary];
    }
    [_prefs setObject:val forKey:pref];
    [self setPreferences:_prefs];
}

// Take the given preferences and save them as a json object in the database
-(void) setPreferences:(NSDictionary *)preferences
{
    
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:preferences options:kNilOptions error:nil];
    NSString * preferenceString = [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding];
    [_internalPreferences setJson:preferenceString];
    [[self managedObjectContext] save:nil];
}

#pragma mark - file registration

// For a given url, determine if it is a file we should register (is it even a .less file? Is it a dependency of an existing registered file?).
// If so, save it to the database, and check if it has any dependencies that need to be tracked as well.

-(void) registerFile:(NSURL *)url
{
    [_delegate logMessage:[NSString stringWithFormat:@"LESS:: registering file: %@", url]];
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
    
    
    
    NSArray * existingFiles = [self fetchResultsForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@", fileName]];
    LessFile * newFile;
    if(existingFiles.count == 0)
    {
        newFile = [self newObjectForEntityForName:@"LessFile"];
    }
    else
    {
        newFile = existingFiles[0];
    }
    
    newFile.css_path = cssFile;
    newFile.path = fileName;
    newFile.site_uuid = [_delegate getCurrentSiteUUID];
    
    NSError * error;
    [_managedObjectContext save:&error];
    [self addDependencyCheckOnFile:fileName];
}


// Delete any references to the given url and its dependencies.
-(void) unregisterFile:(LessFile *)parentFile
{
    if(parentFile)
    {
        NSArray * childFiles = [self fetchResultsForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"parent == %@", parentFile]];
        
        for(LessFile * child in childFiles)
        {
            [self.managedObjectContext deleteObject:child];
        }
        [self.managedObjectContext deleteObject:parentFile];
    }
    [self.managedObjectContext save:nil];
}

-(void) unregisterFileWithId:(NSManagedObjectID*)fileId
{
    
    LessFile * parentFile = (LessFile *)[[self managedObjectContext] objectWithID:fileId];
    if(parentFile)
    {
        NSArray * childrenFiles = [self fetchResultsForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"parent == %@", parentFile]];
        for(LessFile* child in childrenFiles)
        {
            [[self managedObjectContext] deleteObject:child];
        }
        [[self managedObjectContext] deleteObject:parentFile];
    }
    [self.managedObjectContext save:nil];
}

#pragma  mark - depenencyCheck queue
/* To avoid calling multiple dependency checks at once, let's make a simple queue to process them in order. */

-(void) addDependencyCheckOnFile:(NSString *) path
{
    [_delegate logMessage:[NSString stringWithFormat:@"LESS:: Adding path to dependencyQueue: %@", path]];
    if(dependencyQueue == nil)
    {
        dependencyQueue = [NSMutableArray array];
    }
    
    @synchronized(dependencyQueue)
    {
        [dependencyQueue addObject:path];
        if(indexTask == nil || indexTask.isRunning == false)
        {
            [self runDependencyQueue];
        }
    }
}

-(void) runDependencyQueue
{
    [_delegate logMessage:[NSString stringWithFormat:@"LESS:: runDependencyQueue"]];
    @synchronized(dependencyQueue)
    {
        if(dependencyQueue.count == 0)
        {
            [_delegate logMessage:[NSString stringWithFormat:@"LESS:: queue is empty!"]];
            return;
        }
        NSString * path = [dependencyQueue firstObject];
        [dependencyQueue removeObjectAtIndex:0];
        [self performDependencyCheckOnFile:path];
    }
}

// Setup an NSTask to run the less compiler, parse the output to get the list of all dependency files,
// and register them as dependencies.

-(void) performDependencyCheckOnFile:(NSString *)path
{
    if(_isDepenencying)
    {
        [_delegate logMessage:[NSString stringWithFormat:@"LESS:: Already checking Dependencies!"]];
        return;
    }
    [_delegate logMessage:[NSString stringWithFormat:@"LESS:: Performing dependency check on %@", path]];
    _isDepenencying = true;
    
    dependsPath = [_delegate getResolvedPathForPath:[[_delegate urlForPeristantFilePath:@"DEPENDS"] path]];
    
    NSArray * parentFiles = [self fetchResultsForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@", path]];
    if(parentFiles.count == 0)
    {
        return;
    }
    
    
    //run less to get dependencies list
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [_delegate.pluginBundle resourcePath]];
    NSString * launchPath = [NSString stringWithFormat:@"%@/node", [_delegate.pluginBundle resourcePath]];
    tm = [[TaskMan alloc] initWithLaunchPath:launchPath AndArguments:@[lessc, @"--depends", path, dependsPath]];
    [tm launch];
    NSString * output = [tm getOutput];
    NSArray * dependencies = [self parseDependencies:output];
    
    for(LessFile * parentFile in parentFiles)
    {
        // add/update dependencies
        for(NSString * fileName in dependencies)
        {
            NSString * resolvedName = [_delegate getResolvedPathForPath:fileName];
            
            LessFile * dependentFile = [self fetchSingleResultForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@ AND parent == %@", resolvedName, parentFile]];
            if(dependentFile == nil)
            {
                dependentFile = (LessFile *)[self newObjectForEntityForName:@"LessFile"];
            }
            
            dependentFile.path = fileName;
            dependentFile.parent = parentFile;
            dependentFile.site_uuid = parentFile.site_uuid;
            
            [self.managedObjectContext save:nil];
        }
        
        // find any dependencies that exist in the db but NOT in our current depencies list. These need to be removed
        NSArray * oldDependencies = [self fetchResultsForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"parent == %@ AND NOT (path IN %@)", parentFile, dependencies]];
        
        for(LessFile * oldFile in oldDependencies)
        {
            [self.managedObjectContext deleteObject:oldFile];
        }
        
        [self.managedObjectContext save:nil];
    }
    
    _isDepenencying = false;
    [self performSelectorOnMainThread:@selector(runDependencyQueue) withObject:nil waitUntilDone:false];
}


-(NSArray *) parseDependencies:(NSString *)outStr
{
    NSMutableArray * depencyList = [NSMutableArray array];
                  
    outStr = [outStr stringByReplacingOccurrencesOfString:dependsPath withString:@""];
    NSError * error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(/.*?\\.less)" options:nil error:&error];
    if(error != nil)
    {
        [_delegate logMessage:[NSString stringWithFormat:@"LESS:: error with regex: %@", error]];
    }
    NSArray * dependencies = [regex matchesInString:outStr options:nil range:NSMakeRange(0, [outStr length])];
    if([dependencies count] > 0)
    {
        for(NSTextCheckingResult * ntcr in dependencies)
        {
            NSString * fileName =   [_delegate getResolvedPathForPath:[outStr substringWithRange:[ntcr range]]];
            [depencyList addObject:fileName];
        }
    }
    return depencyList;
}

# pragma mark - other things

// Make sure our local copy of _currentParentFiles is up to date.


-(LessFile *)getParentForFilepath:(NSString *)filepath
{
    NSString * resolvedName = [_delegate getResolvedPathForPath:filepath];
    
    LessFile * file = [self fetchSingleResultForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"path == %@", resolvedName]];
    
    if(file && file.parent)
    {
        return file.parent;
    }
    
    return file;
    
}

-(void) updateParentFilesList
{
    if([_delegate getCurrentSiteUUID] == nil)
    {
        return;
    }
    
    NSArray * parentFiles = [self fetchResultsForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"site_uuid == %@ AND parent == NULL", [_delegate getCurrentSiteUUID]]];
    
    _currentParentFiles = [parentFiles mutableCopy];
    _currentParentFilesCount = parentFiles.count;
}

// If the user chooses to update the css path of a less file to somewhere else.
-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url
{
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    NSString * cssFileName = [_delegate getResolvedPathForPath:[cssUrl path]];
    
    
    LessFile * file = [self fetchSingleResultForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"site_uuid == %@ AND path == %@", [_delegate getCurrentSiteUUID], fileName]];
    
    if(file)
    {
        file.css_path = cssFileName;
    }
    [self.managedObjectContext save:nil];
}

// Update preferences specific to each less file.
-(void) updateLessFilePreferences:(NSDictionary *)options forPath:(NSURL *) url
{
    
    NSData * preferenceData = [NSJSONSerialization dataWithJSONObject:options options:kNilOptions error:nil];
    NSString * preferenceString = [[NSString alloc] initWithData:preferenceData encoding:NSUTF8StringEncoding];
    [_delegate logMessage:[NSString stringWithFormat:@"LESS:: updating preferences to: %@", preferenceString]];
    
    NSString * fileName = [_delegate getResolvedPathForPath:[url path]];
    LessFile * file = [self fetchSingleResultForEntityNamed:@"LessFile" WithPredicate:[NSPredicate predicateWithFormat:@"site_uuid == %@ AND path == %@", [_delegate getCurrentSiteUUID], fileName ]];
    
    if(file)
    {
        file.options = preferenceString;
    }
    
    [self.managedObjectContext save:nil];
}

-(void) logToDatabase: (NSString *)format, ...
{
    va_list vl;
    va_start(vl, format);
    NSString* str = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    [self sendLineToLog:str :@"info"];
}

-(void) errorToDatabase: (NSString *)format, ...
{
    va_list vl;
    va_start(vl, format);
    NSString* str = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    [self sendLineToLog:str :@"error"];
}

-(void) sendLineToLog:(NSString *)line :(NSString *)type
{
//    NSString * date = [NSDateFormatter localizedStringFromDate:[NSDate date]
//                                                     dateStyle:NSDateFormatterShortStyle
//                                                     timeStyle:NSDateFormatterLongStyle];
//    NSDictionary * args = @{@"time": date, @"text": line, @"type":type };
//    [_dbLog inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"INSERT INTO log (time, text, type) VALUES (:time, :text, :type)" withParameterDictionary:args];
//    }];
}



#pragma mark - coredata

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[_delegate bundle] URLForResource:@"Model" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    if(![_delegate doesPersistantStorageDirectoryExist])
    {
        [_delegate createPersistantStorageDirectory];
    }
    
    NSURL *storeURL = [_delegate urlForPeristantFilePath:@"db_core_data.sqlite"];
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:@{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES} error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


#pragma mark - core data helpers

-(NSArray *) fetchResultsForEntityNamed:(NSString *)entityName WithPredicate:(NSPredicate *)predicate AndSortDescriptors:(NSArray *)sortDescriptors
{
    NSFetchRequest * fetch = [[NSFetchRequest alloc] init];
    [fetch setEntity: [[self managedObjectModel] entitiesByName ][entityName] ];
    [fetch setPredicate: predicate];
    [fetch setSortDescriptors: sortDescriptors];
    
    NSArray * results = [[self managedObjectContext] executeFetchRequest:fetch error:nil];
    return results;
}

-(NSArray *)fetchResultsForEntityNamed:(NSString *)entityName WithPredicate:(NSPredicate *)predicate
{
    return [self fetchResultsForEntityNamed:entityName WithPredicate:predicate AndSortDescriptors:nil];
}

-(NSArray *)fetchResultsForEntityNamed:(NSString *)entityName
{
    return [self fetchResultsForEntityNamed:entityName WithPredicate:nil AndSortDescriptors:nil];
}

-(id) fetchSingleResultForEntityNamed:(NSString *)entityName WithPredicate:(NSPredicate *)predicate
{
    NSArray * results = [self fetchResultsForEntityNamed:entityName WithPredicate:predicate AndSortDescriptors:nil];
    if(results.count == 0)
    {
        return nil;
    }
    return results[0];
}

-(id)newObjectForEntityForName:(NSString *)entityName
{
    return [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:[self managedObjectContext]];
}


@end
