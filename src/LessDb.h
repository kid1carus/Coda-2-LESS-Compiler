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

@protocol LessDbDelegate <NSObject>


@end

@interface LessDb : NSObject
{
    /* indexing tasks and pipes */
    NSTask * indexTask;
    NSPipe * indexPipe;
    NSMutableArray * dependencyQueue;
}
@property (strong) BaseCodaPlugin <LessDbDelegate> * delegate;
@property (strong) FMDatabaseQueue * dbQueue;
@property (strong) NSMutableDictionary * prefs;
@property (strong) NSMutableArray * currentParentFiles;
@property (readwrite) int currentParentFilesCount;
@property (readwrite) BOOL isDepenencying;

+(LessDb *)sharedLessDb;
-(LessDb *) initWithDelegate:(BaseCodaPlugin <LessDbDelegate> *)d;


-(void) setupDb;
-(void) replaceDatabase;
-(void) reloadDbPreferences;
-(BOOL) copyDbFile;
-(void) updateParentFilesListWithCompletion:(void(^)(void))handler;

-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val;
-(void) registerFile:(NSURL *)url;
-(void) unregisterFile:(NSURL *)url;
-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url;
-(void) updateLessFilePreferences:(NSDictionary *)options forPath:(NSURL *) url;
-(void) addDependencyCheckOnFile:(NSString *)path;

@end
