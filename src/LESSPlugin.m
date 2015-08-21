#import "LESSPlugin.h"
#import "CodaPlugInsController.h"
#import "FileView.h"

@interface LESSPlugin ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation LESSPlugin

//2.0 and lower
- (id)initWithPlugInController:(CodaPlugInsController*)aController bundle:(NSBundle*)aBundle
{
    return [self initWithController:aController];
}


//2.0.1 and higher
- (id)initWithPlugInController:(CodaPlugInsController*)aController plugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    return [self initWithController:aController andPlugInBundle:p];
}

- (id)initWithController:(CodaPlugInsController*)inController andPlugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    if ( (self = [super initWithController:inController andPlugInBundle:p]) != nil )
	{
        [self registerActions];
        Ldb = [[LessDb alloc] initWithDelegate:self];
        if([[Ldb.prefs objectForKey:@"verboseLog"] intValue] == 1)
        {
            self.verboseLogging = true;
        }
        [self logMessage:@"hey does this work?"];
        [self logError:@"This is an error message"];
    }
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		self.controller = inController;
        [self registerActions];
    }
	return self;
}

-(void) registerActions
{
    [self.controller registerActionWithTitle:@"Site Settings" underSubmenuWithTitle:nil target:self selector:@selector(openSitesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    
    [self.controller registerActionWithTitle:@"Preferences" underSubmenuWithTitle:nil target:self selector:@selector(openPreferencesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    //preference menu can always be opened.
    if([[menuItem title] isEqualToString:@"Preferences"])
    {
        return true;
    }
    
    return [self isSiteOpen];
}

- (NSString*)name
{
	return @"LESS Compiler";
}

-(void)textViewWillSave:(CodaTextView *)textView
{
    NSString *path = [textView path];
    if([path length] > 0)
    {
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        if([[url pathExtension] isEqualToString:@"less"])
        {
            [self performSelector:@selector(handleLessFile:) withObject:[self getResolvedPathForPath:path] afterDelay:0.01];
//            [self performSelectorOnMainThread:@selector(handleLessFile:) withObject:textView waitUntilDone:true];
        }
    }
}

#pragma mark - Menu methods

-(void) openSitesMenu
{
    if(siteSettingsController != nil)
    {
        [siteSettingsController showWindow:self];
        return;
    }
    
    [self updateCurrentSiteUUID];
    siteSettingsController = [[siteSettingsWindowController alloc] init];
    [siteSettingsController showWindow:self];
}

-(void) openPreferencesMenu
{
    if(preferenceController != nil)
    {
        [preferenceController showWindow:self];
        return;
    }
    
    preferenceController = [[preferenceWindowController alloc] init];
    [preferenceController showWindow:self];
}

#pragma mark - NSWindowDelegate methods


-(void)windowWillClose:(NSNotification *)notification
{
    if([[notification object] isEqualTo:siteSettingsController.window])
    {
        siteSettingsController = nil;
    }
    
    if([[notification object] isEqualTo:preferenceController.window ])
    {
        preferenceController = nil;
    }
}


#pragma mark - LESS methods

-(void) handleLessFile:(NSString *)path
{
    if(isCompiling || Ldb.isDepenencying || (task!= nil && [task isRunning]))
    {
        [self logMessage:[NSString stringWithFormat:@"LESS:: Compilation already happening!" ]];
        return;
    }
    
    [self logMessage:[NSString stringWithFormat:@"LESS:: ++++++++++++++++++++++++++++++++++++++++++++++++++++++" ]];
    [self logMessage:[NSString stringWithFormat:@"LESS:: Handling file: %@", path ]];
    
    LessFile * parent = [Ldb getParentForFilepath:path];
    if(parent == nil)
    {
        return;
    }
    NSString * parentPath = parent.path;
    NSString * cssPath = parent.css_path;
    
    
    [self logMessage:[NSString stringWithFormat:@"LESS:: parent Path: %@", parentPath ]];
    [self logMessage:[NSString stringWithFormat:@"LESS:: css Path: %@", cssPath ]];
    
    //Set compilation options
    NSMutableArray * options  = [NSMutableArray array];
    NSData * optionsData = [parent.options dataUsingEncoding:NSUTF8StringEncoding];
    
    if(optionsData != nil && ![optionsData isEqual:[NSNull null]])
    {
        NSDictionary * parentFileOptions = [NSJSONSerialization JSONObjectWithData:optionsData options:0 error:nil];
        if(parentFileOptions != nil && parentFileOptions != (id)[NSNull null])
        {
            for(NSString * optionName in parentFileOptions.allKeys)
            {
                if([[parentFileOptions objectForKey:optionName] intValue] == 1)
                {
                    [options addObject:optionName];
                }
            }
        }
    }
    
    [self logMessage:[NSString stringWithFormat:@"LESS:: compiling" ]];
    int resultCode = [self compileFile:parentPath toFile:cssPath withOptions:options];
    if(resultCode == 0)
    {
        [self logMessage:[NSString stringWithFormat:@"LESS:: starting dependency check" ]];
        [Ldb addDependencyCheckOnFile:parentPath];
        [self logMessage:[NSString stringWithFormat:@"LESS:: dependency check ended." ]];
    }
}

-(int) compileFile:(NSString *)lessFile toFile:(NSString *)cssFile withOptions:(NSArray *)options
{
    if(isCompiling || Ldb.isDepenencying || (task!= nil && [task isRunning]))
    {
        [self logMessage:[NSString stringWithFormat:@"LESS:: Compilation task is already running." ]];
        return -1;
    }
    isCompiling = true;
    compileCount++;
    [self logMessage:[NSString stringWithFormat:@"LESS:: Compiling file: %@ to file: %@", lessFile, cssFile ]];
    [self logMessage:[NSString stringWithFormat:@"LESS:: Compile count: %d", compileCount ]];

    NSString * launchPath = [NSString stringWithFormat:@"%@/node", [self.pluginBundle resourcePath]];
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [self.pluginBundle resourcePath]];
    NSMutableArray * arguments = [NSMutableArray array];
    [arguments addObject:lessc];
    [arguments addObject:@"--no-color"];
    if(options)
    {
        for(NSString * arg in options)
        {
            [arguments addObject:arg];
        }
    }
    
    [arguments addObject:lessFile];
    [arguments addObject:cssFile];
    [self logMessage:[NSString stringWithFormat:@"LESS:: Node arguments: %@", arguments ]];
    
    
    
    task = [[TaskMan alloc] initWithLaunchPath:launchPath AndArguments:arguments];
    [task launch];
    outputText = [task getOutput];
    errorText = [task getError];
    int resultCode = [task resultCode];
    [self logMessage:[NSString stringWithFormat:@"LESS:: Task terminated with status: %d", resultCode ]];
    [self logMessage:[NSString stringWithFormat:@"LESS:: =====================================================" ]];
    
    if(resultCode == 0)
    {
        [self displaySuccess];
    }
    else
    {
        [self displayError:errorText];
    }

    isCompiling = false;
    task = nil;
    return resultCode;
}

/* parse the error message and pull the useful bits from it. */

-(NSDictionary *) getErrorMessage:(NSString *)fullError
{
    NSError * error = nil;
    NSDictionary * output = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.*?)Error:(.*?) in (.*?less) on line (.*?), column (.*?):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        NSString * errorType = 	  [fullError substringWithRange:[ntcr rangeAtIndex:1]];
        NSString * errorName = 	  [fullError substringWithRange:[ntcr rangeAtIndex:2]];
        NSString * filePath = 	  [fullError substringWithRange:[ntcr rangeAtIndex:3]];
        NSString * fileName = 	  [[fullError substringWithRange:[ntcr rangeAtIndex:3]] lastPathComponent];
        NSNumber * lineNumber =   [NSNumber numberWithInteger: [[fullError substringWithRange:[ntcr rangeAtIndex:4]] integerValue]];
        NSNumber * columnNumber = [NSNumber numberWithInteger: [[fullError substringWithRange:[ntcr rangeAtIndex:5]] integerValue]];
        
        NSString * errorMessage = [NSString stringWithFormat:@"%@ in %@, on line %@ column %@", errorName, fileName, lineNumber, columnNumber];
        
        output = @{@"errorMessage": errorMessage,
                   @"errorType": errorType,
                   @"filePath": filePath,
                   @"fileName": fileName,
                   @"lineNumber":lineNumber,
                   @"columnNumber":columnNumber};
        
    }
    [self logMessage:[NSString stringWithFormat:@"LESS:: Error: %@", output ]];
    return output;
}

-(NSString *) getFileNameFromError:(NSString *)fullError
{
    NSError * error = nil;
    NSString * output = [NSString stringWithFormat:@""];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ParseError:(.*?) in (.*?less) (.*):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        output = [fullError substringWithRange:[ntcr rangeAtIndex:2]];
    }
    return output;
}



-(void) displaySuccess
{
    if([[Ldb.prefs objectForKey:@"displayOnSuccess"] intValue] == 1)
    {
        NSString * sound = nil;
        if([[Ldb.prefs objectForKey:@"playOnSuccess"] intValue] == 1)
        {
            sound = NSUserNotificationDefaultSoundName;
        }
        
        [self sendUserNotificationWithTitle:@"LESS:: Compiled Successfully!" andMessage:@"file compiled successfully!"];
    }
}

-(void) displayError:(NSString *)errorText
{
    NSDictionary * error = [self getErrorMessage:errorText];
    if(error != nil)
    {
        if([[Ldb.prefs objectForKey:@"displayOnError"] integerValue] == 1)
        {
            NSString * sound = nil;
            if([[Ldb.prefs objectForKey:@"playOnError"] integerValue] == 1)
            {
                sound = @"Basso";
            }
            
            [self sendUserNotificationWithTitle:@"LESS:: Parse Error" andMessage:[error objectForKey:@"errorMessage"]];
        }
        
        if([[Ldb.prefs objectForKey:@"openFileOnError"] integerValue] == 1)
        {
            NSError * err;
            CodaTextView * errorTextView = [self.controller openFileAtPath:[error objectForKey:@"filePath"] error:&err];
            if(err)
            {
                [self logMessage:[NSString stringWithFormat:@"LESS:: error opening file: %@", err ]];
                return;
            }
            
            [errorTextView goToLine:[[error objectForKey:@"lineNumber"] integerValue] column:[[error objectForKey:@"columnNumber"] integerValue] ];
        }
    }

}
@end
