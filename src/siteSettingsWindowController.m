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
    [self.window setDelegate:Ldb.delegate];
    fileDocumentView = [[flippedView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    
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

-(void) advancedButtonPressed:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    f.isAdvancedToggled = !f.isAdvancedToggled;
    [self scrollToPosition:NSMakePoint(0, f.frame.origin.y)];
    [self relayoutFileViews];
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
        [self performSelectorOnMainThread:@selector(updateFileViewOptions) withObject:nil waitUntilDone:false];
    }];
}

-(void) rebuildFileList
{
    DDLogVerbose(@"LESS:: rebuildFileList");
    
    [fileDocumentView setSubviews:[NSArray array]];
    
    fileViews = [NSMutableArray array];
    
    // if there are no files to display, then display a footer.
    
    if(Ldb.currentParentFilesCount == 0)
    {
        [fileDocumentView setFrame:NSMakeRect(0, 0, 583, self.fileScrollView.frame.size.height - 10)];
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
        
        NSRect fRect = footerView.frame;
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
        
        
        //setup actions and target for all the checkboxes
        [f setupOptionsWithSelector:@selector(userUpdatedLessFilePreference:) andTarget:self];
        
        // set the less and css paths
        NSURL * url = [NSURL fileURLWithPath:[currentFile objectForKey:@"path"] isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:[currentFile objectForKey:@"path"]];
        [f.cssPath setStringValue:[currentFile objectForKey:@"css_path"]];
        
        
        //setup the rest of the non-preference button actions
        [f.deleteButton setAction:@selector(deleteParentFile:)];
        [f.deleteButton setTarget:self];
        [f.changeCssPathButton setAction:@selector(changeCssFile:)];
        [f.changeCssPathButton setTarget:self];
        [f.advancedButton setAction:@selector(advancedButtonPressed:)];
        [f.advancedButton setTarget:self];
        
        f.fileIndex = i;
        
        [fileViews addObject:f];
        [fileDocumentView addSubview:f];
    }
    [self updateFileViewOptions];
    [self relayoutFileViews];
}

-(void) updateFileViewOptions
{
    DDLogVerbose(@"LESS:: updateFileViewOptions");
    for(FileView * f in fileViews)
    {
        NSDictionary * currentFile = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
        
        //now populate the checkboxes with the user's current preferences
        NSData * options = [currentFile objectForKey:@"options"];

        if(options != nil && options != (id)[NSNull null])
        {
            NSDictionary * options = [NSJSONSerialization JSONObjectWithData:[currentFile objectForKey:@"options"] options:0 error:nil];
            [f setCheckboxesForOptions:options];
        }
        
    }
}

-(void) relayoutFileViews
{
    float frameHeight = [self getHeightOfFileViews];

    [fileDocumentView setFrame:NSMakeRect(0, 0, 583, MAX(frameHeight, self.fileScrollView.frame.size.height - 10))];
    
    for(FileView * f in fileViews)
    {
        if(f.fileIndex == 0)
        {
            f.horizontalLine.hidden = true;
        }
        else
        {
            f.horizontalLine.hidden = false;
        }
        float viewHeight = 70;
        float viewWidth = f.frame.size.width;
        if(f.isAdvancedToggled)
        {
            viewHeight = 315;
            f.advancedSettingsView.hidden = false;
        }
        else
        {
            f.advancedSettingsView.hidden = true;
        }
        
        float viewY = frameHeight - viewHeight;
        [f setFrame:NSMakeRect(0, viewY, viewWidth, viewHeight)];
        frameHeight -= viewHeight;
    }
    

	
}


-(float) getHeightOfFileViews
{
    float frameHeight = 0;
    for(FileView * f in fileViews)
    {
        if(f.isAdvancedToggled)
        {
            frameHeight += 315;
        }
        else
        {
            frameHeight += 70;
        }
    }
    return frameHeight;
}


- (void)scrollToPosition:(NSPoint)p {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.37];
    NSClipView* clipView = [self.fileScrollView contentView];
    NSPoint newOrigin = [clipView bounds].origin;
    newOrigin.x = p.x;
    newOrigin.y = p.y;
    [[clipView animator] setBoundsOrigin:newOrigin];
    [self.fileScrollView reflectScrolledClipView: [self.fileScrollView contentView]];
    [NSAnimationContext endGrouping];
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
