//
//  preferenceWindowController.m
//  LESSCompile
//
//  Created by Michael on 11/12/14.
//
//

#import "preferenceWindowController.h"
#import "LessDb.h"
#import "FileView.h"
#import "keyPrefButton.h"

@interface preferenceWindowController ()

@end

@implementation preferenceWindowController

-(instancetype)init
{
    if(self = [super initWithWindowNibName:@"preferenceWindowController"])
    {
        Ldb = [LessDb sharedLessDb];
    }
    return self;
}


- (void)windowDidLoad {
    [super windowDidLoad];
    
    for(keyPrefButton * button in self.view.subviews)
    {
        if([button isKindOfClass:[keyPrefButton class]])
        {
            [button setTarget:self];
            [button setAction:@selector(userChangedPreference:)];
            NSString * prefKey = [button valueForKey:@"prefKey"];
            NSNumber * val = [Ldb.prefs objectForKey:prefKey];
            if(val != nil)
            {
                [button setState:[val integerValue]];
            }

        }
    }
    
    [self.lessVersion setStringValue:[Ldb.delegate.bundle objectForInfoDictionaryKey:@"CompilerVersion"]];
    [self.compilerVersion setStringValue:[Ldb.delegate.bundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    
}


- (IBAction)userChangedPreference:(NSButton *)sender
{
    if( ![sender isKindOfClass:[keyPrefButton class]] || [sender valueForKey:@"prefKey"] == nil)
    {
        return;
    }
    
    NSString * pref = [sender valueForKey:@"prefKey"];
    NSNumber * newState = [NSNumber numberWithInteger:[sender state]];
    [Ldb.delegate logMessage:[NSString stringWithFormat:@"LESS:: setting preference %@ : %@", pref, newState]];
    
    [Ldb updatePreferenceNamed:pref withValue:newState];
    
    if([pref isEqualToString:@"verboseLog"])
    {
        if([sender state] == NSOffState)
        {
            Ldb.delegate.verboseLogging = false;
        }
        else if([sender state] == NSOnState)
        {
            Ldb.delegate.verboseLogging = true;
        }
    }
}

- (IBAction)viewGithub:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/mjvotaw/Coda-2-LESS-Compiler"]];
    
}


@end
