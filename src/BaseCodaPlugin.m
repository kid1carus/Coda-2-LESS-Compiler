#import "BaseCodaPlugin.h"


@interface BaseCodaPlugin ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation BaseCodaPlugin

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
    if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
    plugInBundle = p;
    bundle = [NSBundle bundleWithIdentifier:[p bundleIdentifier]];
    currentSiteUUID = @"*"; //
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
	return self;
}


-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return true;
}


#pragma mark - Site methods

- (void)didLoadSiteNamed:(NSString*)name
{
    if([controller.focusedTextView respondsToSelector:@selector(siteUUID)])
    {
    	currentSiteUUID = controller.focusedTextView.siteUUID;
    }
    else
    {
        currentSiteUUID = name;
    }
    if(currentSiteUUID == nil)
    {
        currentSiteUUID = @"*";
    }
}

#pragma mark - Menu methods

-(NSURL *) getFileNameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    if([controller respondsToSelector:@selector(focusedTextView)] && [controller focusedTextView] != nil)
    {
    	[openDlg setDirectoryURL: [NSURL fileURLWithPath:[[controller focusedTextView] siteLocalPath] ]];
    }
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    
    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];
    
    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];
    
    // Display the dialog. If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [openDlg URLs];
        
        // Loop through all the files and process them.
        for(NSURL * url in files)
        {
            chosenFile = url;
        }
    }
    return chosenFile;
}

-(NSURL *) getSaveNameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    if([controller respondsToSelector:@selector(focusedTextView)] && [controller focusedTextView] != nil)
    {
    	[saveDlg setDirectoryURL: [NSURL fileURLWithPath:[[controller focusedTextView] siteLocalPath] ]];
    }
    
    [saveDlg setCanCreateDirectories:TRUE];
    
    if ( [saveDlg runModal] == NSOKButton )
    {
        chosenFile = [saveDlg URL];
    }
    return chosenFile;
}


#pragma mark - persistant storage methods
/* these methods can be used to store files in NSHomeDirectory(), to protect these files from being deleted when plugins/Coda are updated. 
 */

-(BOOL) doesPersistantFileExist:(NSString *)path
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
	NSURL * url = [self urlForPeristantFilePath:path];
    return  [fileManager fileExistsAtPath:[url path]];
}

-(BOOL) doesPersistantStorageDirectoryExist
{
    return [self doesPersistantFileExist:@""];
}

-(NSURL *) urlForPeristantFilePath:(NSString *)path
{
    NSURL * url = [NSURL fileURLWithPath:NSHomeDirectory()];
    url = [url URLByAppendingPathComponent:[NSString stringWithFormat:@".%@/%@", [self name], path]];
    return url;
}

-(NSError *) createPersistantStorageDirectory
{
    NSError * error;
    NSURL * url = [self urlForPeristantFilePath:@""];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtURL:url withIntermediateDirectories:NO attributes:nil error:&error];
    return error;
}

-(NSError *) copyFileToPersistantStorage:(NSString *)path
{
    NSError * error = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString * filename = [path lastPathComponent];
    NSURL * url = [self urlForPeristantFilePath: filename];
    if(![self doesPersistantStorageDirectoryExist])
    {
        error = [self createPersistantStorageDirectory];
        if(error != nil)
        {
            return error;
        }
    }
    if([self doesPersistantFileExist:filename])
    {
        [fileManager moveItemAtPath:[url path] toPath:[[self urlForPeristantFilePath:[NSString stringWithFormat:@"%@.%ld", filename, time(nil)]] path] error:&error];
        if(error != nil)
        {
            return error;
        }
    }
    
    [fileManager copyItemAtPath:path toPath: [url path] error:&error];
    return error;
}


#pragma mark - url/path helper methods


-(NSString *) getResolvedPathForPath:(NSString *)path
{
    NSURL * url = [NSURL fileURLWithPath:path];
    url = [NSURL URLWithString:[url absoluteString]];	//absoluteString returns path in file:// format
	NSString * newPath = [[url URLByResolvingSymlinksInPath] path];	//URLByResolvingSymlinksInPath expects file:// format for link, then resolves all symlinks
    return newPath;
}

#pragma mark - NSUserNotification

-(void) sendUserNotificationWithTitle:(NSString *)title sound:(NSString *)sound andMessage:(NSString * ) message
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    notification.soundName = sound;
    
	if([[NSUserNotificationCenter defaultUserNotificationCenter] delegate] == nil)
    {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

@end
