//
//  preferenceWindowController.m
//  LESSCompile
//
//  Created by Michael on 11/12/14.
//
//

#import "preferenceWindowController.h"
#import "LessDb.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "FileView.h"
#import "keyPrefButton.h"

static int ddLogLevel;
static NSString * COMPVERSION = @"1.1.2";
static NSString * LESSVERSION = @"2.2.0";
@interface preferenceWindowController ()

@end

@implementation preferenceWindowController

-(instancetype)init
{
    if(self = [super initWithWindowNibName:@"preferenceWindowController"])
    {
        Ldb = [LessDb sharedLessDb];
        DDLogVerbose(@"LESS:: preferenceWindowController init'd");
    }
    return self;
}


- (void)windowDidLoad {
    [super windowDidLoad];
    if(Ldb.prefs == nil)
    {
        DDLogVerbose(@"LESS:: prefs is nil");
    }
    
    for(keyPrefButton * button in self.view.subviews)
    {
        if([button isKindOfClass:[keyPrefButton class]])
        {
            [button setTarget:self];
            [button setAction:@selector(userChangedPreference:)];
            NSString * prefKey = [button valueForKey:@"prefKey"];
            NSNumber * val = [Ldb.prefs objectForKey:prefKey];
            DDLogVerbose(@"LESS:: Preference: %@ : %@", prefKey, val);
            if(val != nil)
            {
                [button setState:[val integerValue]];
            }

        }
    }
    
    [self.lessVersion setStringValue:LESSVERSION];
    [self.compilerVersion setStringValue:COMPVERSION];
    
}


- (IBAction)userChangedPreference:(NSButton *)sender
{
    if( ![sender isKindOfClass:[keyPrefButton class]] || [sender valueForKey:@"prefKey"] == nil)
    {
        return;
    }
    
    NSString * pref = [sender valueForKey:@"prefKey"];
    NSNumber * newState = [NSNumber numberWithInteger:[sender state]];
    DDLogVerbose(@"LESS:: setting preference %@ : %@", pref, newState);
    [Ldb updatePreferenceNamed:pref withValue:newState];
    
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

- (IBAction)viewGithub:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/mjvotaw/Coda-2-LESS-Compiler"]];
    
}


@end
