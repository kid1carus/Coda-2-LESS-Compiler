//
//  siteSettingsWindowController.m
//  LESSCompile
//
//  Created by Michael on 10/29/14.
//
//

#import "siteSettingsWindowController.h"
#import "LessDb.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "FileView.h"

static int ddLogLevel;

@interface siteSettingsWindowController ()

@end

@implementation siteSettingsWindowController

-(instancetype)init
{
    if(self = [super initWithWindowNibName:@"siteSettingsWindowController"])
    {
        Ldb = [LessDb sharedLessDb];
        DDLogVerbose(@"LESS:: siteSettingsWindowController init'd");
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    DDLogVerbose(@"LESS:: windowDidLoad fired.");
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.fileDropView setDelegate:self];
    [self.window setDelegate:self];
    fileDocumentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    
    [self.fileScrollView setDocumentView:fileDocumentView];
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}


- (IBAction)filePressed:(NSButton *)sender
{
    
    NSURL * openUrl =[Ldb.delegate getFileNameFromUser];
    
    if(openUrl == nil)
    {
        return;
    }
    
    [Ldb registerFile:openUrl];
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
    
}

-(void) deleteParentFile:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Really Delete %@?", f.fileName.stringValue]];
    [alert setInformativeText:[NSString stringWithFormat:@"Are you sure you want to delete %@ ?", f.fileName.stringValue]];
    NSInteger response = [alert runModal];
    if(response == NSAlertFirstButtonReturn)
    {
        NSDictionary * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
        NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
        [Ldb unregisterFile:url];
        [Ldb updateParentFilesListWithCompletion:^{
            [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
        }];
    }
    else
    {
        return;
    }
}

-(void) changeCssFile:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    NSURL * saveUrl = [Ldb.delegate getSaveNameFromUser];
    if(saveUrl == nil)
    {
        return;
    }
    NSDictionary * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
    
    [Ldb setCssPath:saveUrl forPath:url];
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}

-(void) userUpdatedLessFilePreference:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    while(![f isKindOfClass:[FileView class]] && [f superview] != nil)
    {
        f = (FileView *)[f superview];
    }
    
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    NSDictionary * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
    [Ldb updateLessFilePreferences:[f getOptionValues] forPath:url];
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
}

-(void) rebuildFileList
{
    DDLogVerbose(@"LESS:: rebuildFileList");
    
    [fileDocumentView setSubviews:[NSArray array]];
    
    fileViews = [NSMutableArray array];
    NSRect fRect;
    
    [fileDocumentView setFrame:NSMakeRect(0, 0, 583, MAX( (111 * (Ldb.currentParentFilesCount + 1)), self.fileScrollView.frame.size.height - 10))];
    
    // if there are no files to display, then display a footer.
    
    if(Ldb.currentParentFilesCount == 0)
    {
        NSView * footerView;
        NSArray *nibObjects = [Ldb.delegate loadNibNamed:@"FileFooter"];
        
        for(NSView * o in nibObjects)
        {
            if([o isKindOfClass:[NSView class]])
            {
                footerView = o;
                break;
            }
        }
        
        fRect = footerView.frame;
        fRect.origin.y = 0;
        footerView.frame = fRect;
        
        [fileDocumentView addSubview:footerView];
        return;
    }
    
    //otherwise, display the list of files.
    
    for(int i = Ldb.currentParentFilesCount - 1; i >= 0; i--)
    {
        NSDictionary * currentFile = [Ldb.currentParentFiles objectAtIndex:i];
        
        NSArray *nibObjects = [Ldb.delegate loadNibNamed:@"FileView"];
        
        FileView * f;
        for(FileView * o in nibObjects)
        {
            if([o isKindOfClass:[FileView class]])
            {
                f = o;
                break;
            }
        }
        
        if(f == nil)
        {
            DDLogError(@"LESS:: Error loading nib FileView");
        }
        
        
        fRect = f.frame;
        
        [f setupOptionsWithSelector:@selector(userUpdatedLessFilePreference:) andTarget:self];
        NSData * options = [currentFile objectForKey:@"options"];
        
        if(options != nil && options != (id)[NSNull null])
        {
            NSDictionary * options = [NSJSONSerialization JSONObjectWithData:[currentFile objectForKey:@"options"] options:0 error:nil];
            [f setCheckboxesForOptions:options];
        }
        
        NSURL * url = [NSURL fileURLWithPath:[currentFile objectForKey:@"path"] isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:[currentFile objectForKey:@"path"]];
        [f.cssPath setStringValue:[currentFile objectForKey:@"css_path"]];
        
        [f.deleteButton setAction:@selector(deleteParentFile:)];
        [f.deleteButton setTarget:self];
        [f.changeCssPathButton setAction:@selector(changeCssFile:)];
        [f.changeCssPathButton setTarget:self];
        
        f.fileIndex = i;
        
        float frameY = Ldb.currentParentFilesCount > 3 ? i * fRect.size.height : (fileDocumentView.frame.size.height - ((Ldb.currentParentFilesCount - i) * fRect.size.height));
        [f setFrame:NSMakeRect(0, frameY, fRect.size.width, fRect.size.height)];
        [fileViews addObject:f];
        [fileDocumentView addSubview:f];
    }
}

#pragma mark - DraggingDestinationDelegate


-(void) draggingDestinationPerformedDragOperation:(id<NSDraggingInfo>)sender
{
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([[pboard types] containsObject:NSURLPboardType]) {
        
        NSArray *paths = [pboard propertyListForType:NSURLPboardType];
        for(NSString * aPath in paths)
        {
            if([aPath isEqualToString:@""])
            {
                continue;
            }
            NSURL * aUrl = [NSURL URLWithString:aPath];
            [Ldb registerFile:aUrl];
        }
    }
    
    [Ldb updateParentFilesListWithCompletion:^{
        [self performSelectorOnMainThread:@selector(rebuildFileList) withObject:nil waitUntilDone:false];
    }];
    
}

@end
