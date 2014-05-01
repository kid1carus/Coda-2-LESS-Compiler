//
//  PreferenceView.m
//  LESSCompile
//
//  Created by Michael on 5/1/14.
//
//

#import "PreferenceView.h"

@implementation PreferenceView


-(BOOL)acceptsFirstResponder
{
    return true;
}

-(void)cancelOperation:(id)sender
{
    [self.window close];
}

@end
