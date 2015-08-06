//
//  LessFile.h
//  LESSCompile
//
//  Created by Michael Votaw on 8/6/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class LessFile;

@interface LessFile : NSManagedObject

@property (nonatomic, retain) NSString * css_path;
@property (nonatomic, retain) NSString * options;
@property (nonatomic, retain) NSString * path;
@property (nonatomic, retain) NSString * site_uuid;
@property (nonatomic, retain) LessFile *parent;

@end
