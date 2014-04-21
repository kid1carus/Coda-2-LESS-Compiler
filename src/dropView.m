//
//  dropView.m
//  LESSCompile
//
//  Created by Michael on 4/21/14.
//
//

#import "dropView.h"
#import "DDLog.h"
#import "DDASLLogger.h"
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
@implementation dropView

- (id)initWithCoder:(NSCoder *)coder
{
    self=[super initWithCoder:coder];
    if (self) {
		[self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
   return NSDragOperationEvery;
}

-(NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationEvery;
}
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return true;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    if(self.delegate)
    {
        [self.delegate draggingDestinationPerformedDragOperation:sender];
    }
    
    return true;
}

@end
