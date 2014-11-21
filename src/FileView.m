//
//  FileView.m
//  LESSCompile
//
//  Created by Michael on 10/30/13.
//
//

#import "FileView.h"
#import "keyPrefButton.h"

@implementation FileView

-(void) setupOptionsWithSelector:(SEL)aSelector andTarget:(id)target;
{
    NSArray * subviews = [self.subviews arrayByAddingObjectsFromArray:self.advancedSettingsView.subviews];
    
    //get all of the regular checkboxes
    for(NSButton * button in subviews)
    {
        if([button isKindOfClass:[keyPrefButton class]] && [button valueForKey:@"prefKey"] != nil)
        {
            [button setAction:aSelector];
            [button setTarget:target];
        }
    }
    //line numbers
    [self.lineNumbers removeAllItems];
    [self.lineNumbers addItemsWithTitles:@[@"Off", @"comments", @"mediaquery", @"all"]];
    [self.lineNumbers setAction:aSelector];
    [self.lineNumbers setTarget:target];
    
}



-(void) setCheckboxesForOptions:(NSDictionary *)options
{
    NSArray * subviews = [self.subviews arrayByAddingObjectsFromArray:self.advancedSettingsView.subviews];
    
    //get all of the regular checkboxes
    for(NSButton * button in subviews)
    {
        if([button isKindOfClass:[keyPrefButton class]] &&[button valueForKey:@"prefKey"] != nil)
        {
            NSString * option = [button valueForKey:@"prefKey"];
            if([options objectForKey:option] != nil)
            {
                [button setState:[[options objectForKey:option] integerValue]];
            }
        }
    }
    
    //Now setup any weird dropdowns or anything
    
    for(NSString * ln in self.lineNumbers.itemTitles)
    {
        NSString * lineNumberOption = [NSString stringWithFormat:@"--line-numbers=%@", ln ];
        if([options objectForKey:lineNumberOption] != nil && [[options objectForKey:lineNumberOption] integerValue] == 1 )
        {
            [self.lineNumbers selectItemWithTitle:ln];
        }
    }
}

-(NSDictionary *) getOptionValues
{
    NSMutableDictionary * options = [NSMutableDictionary dictionary];
    NSArray * subviews = [self.subviews arrayByAddingObjectsFromArray:self.advancedSettingsView.subviews];
    
    //get all of the regular checkboxes
    for(NSButton * button in subviews)
    {
        if([button isKindOfClass:[keyPrefButton class]] &&[button valueForKey:@"prefKey"] != nil)
        {
            NSString * option = [button valueForKey:@"prefKey"];
            [options setObject:@(button.state) forKey:option];
        }
    }
    
    //now get any weird dropdowns or anything
    
    if(![[self.lineNumbers titleOfSelectedItem] isEqualTo:@"Off"])
    {
        NSString * lineNumberOption = [NSString stringWithFormat:@"--line-numbers=%@", [self.lineNumbers titleOfSelectedItem] ];
        [options setObject:@(1) forKey:lineNumberOption];
    }
    
    return options;
}

@end
