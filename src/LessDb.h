//
//  LessDb.h
//  LESSCompile
//
//  Created by Michael on 10/26/14.
//
//

/* This object contains most of the methods for loading and modifying the database. */

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseQueue.h"
#import "BaseCodaPlugin.h"
#import "TaskMan.h"
#import "LessFile.h"
#import "LessPreferences.h"

@protocol LessDbDelegate <NSObject>


@end

@interface LessDb : NSObject
{
    /* indexing tasks and pipes */
    TaskMan * tm;
    
    NSTask * indexTask;
    NSPipe * indexPipe;
    NSPipe * errorPipe;
    NSMutableArray * dependencyQueue;
    NSString * indexOutput;
    NSString * dependsPath;
}
@property (strong) BaseCodaPlugin <LessDbDelegate> * delegate;
@property (strong) FMDatabaseQueue * dbQueue;
@property (strong) FMDatabaseQueue * dbLog;

@property (strong) LessPreferences * internalPreferences;
@property (strong) NSMutableDictionary * prefs;
@property (strong) NSMutableArray * currentParentFiles;
@property (readwrite) int currentParentFilesCount;
@property (readwrite) BOOL isDepenencying;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;



+(LessDb *)sharedLessDb;
-(LessDb *) initWithDelegate:(BaseCodaPlugin <LessDbDelegate> *)d;
-(void) setupDb;
-(void) setupLog;
-(void) updateParentFilesList;
-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val;
-(void) registerFile:(NSURL *)url;
-(void) unregisterFile:(LessFile *)parentFile;
-(void) unregisterFileWithId:(NSManagedObjectID*)fileId;
-(LessFile *) getParentForFilepath:(NSString *)filepath;
-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url;
-(void) updateLessFilePreferences:(NSDictionary *)options forPath:(NSURL *) url;
-(void) addDependencyCheckOnFile:(NSString *)path;

@end
