//
//  siteSettingsWindowController.m
//  LESSCompile
//
//  Created by Michael on 10/29/14.
//
//

#import "siteSettingsWindowController.h"
#import "LessDb.h"
#import "FileView.h"

@interface siteSettingsWindowController ()

@end

@implementation siteSettingsWindowController

-(instancetype)init
{
    if(self = [super initWithWindowNibName:@"siteSettingsWindowController"])
    {
        Ldb = [LessDb sharedLessDb];
        [Ldb.delegate logMessage:[NSString stringWithFormat: @"LESS:: siteSettingsWindowController init'd" ]];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [Ldb.delegate logMessage:[NSString stringWithFormat: @"LESS:: windowDidLoad fired." ]];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.fileDropView setDelegate:self];
    [self.window setDelegate:Ldb.delegate];
    fileDocumentView = [[flippedView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    
    [self.fileScrollView setDocumentView:fileDocumentView];
    [Ldb updateParentFilesList];
    [self rebuildFileList];
}


- (IBAction)filePressed:(NSButton *)sender
{
    
    NSURL * openUrl =[Ldb.delegate getFileNameFromUser];
    
    if(openUrl == nil)
    {
        return;
    }
    
    [Ldb registerFile:openUrl];
    [Ldb updateParentFilesList];
    [self rebuildFileList];
    
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
        LessFile * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
        [Ldb unregisterFile:fileInfo];
        [Ldb updateParentFilesList];
        [self rebuildFileList];
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
    LessFile * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:fileInfo.path];
    
    [Ldb setCssPath:saveUrl forPath:url];
    [Ldb updateParentFilesList];
    [self rebuildFileList];
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
    
    LessFile * fileInfo = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:fileInfo.path];
    [Ldb updateLessFilePreferences:[f getOptionValues] forPath:url];
    [Ldb updateParentFilesList];
//    [self rebuildFileList];
}

-(void) rebuildFileList
{
    [Ldb.delegate logMessage:[NSString stringWithFormat: @"LESS:: rebuildFileList" ]];
    
    [fileDocumentView setSubviews:[NSArray array]];
    
    fileViews = [NSMutableArray array];
    
    // if there are no files to display, then display a footer.
    
    if(Ldb.currentParentFilesCount == 0)
    {
        [fileDocumentView setFrame:NSMakeRect(0, 0, 583, self.fileScrollView.frame.size.height - 10)];
        NSView * footerView = [Ldb.delegate getNibNamed:@"FileFooter" forClass:[NSView class]];
        
        NSRect fRect = footerView.frame;
        fRect.origin.y = 0;
        footerView.frame = fRect;
        
        [fileDocumentView addSubview:footerView];
        return;
    }
    
    //otherwise, display the list of files.
    
    for(int i = Ldb.currentParentFilesCount - 1; i >= 0; i--)
    {
        LessFile * currentFile = [Ldb.currentParentFiles objectAtIndex:i];
        FileView * f = [Ldb.delegate getNibNamed:@"FileView" forClass:[FileView class]];
        
        if(f == nil)
        {
            [Ldb.delegate logMessage:[NSString stringWithFormat: @"LESS:: Error loading nib FileView" ]];
        }
        
        
        //setup actions and target for all the checkboxes
        [f setupOptionsWithSelector:@selector(userUpdatedLessFilePreference:) andTarget:self];
        
        // set the less and css paths
        NSURL * url = [NSURL fileURLWithPath:currentFile.path isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:currentFile.path];
        [f.cssPath setStringValue:currentFile.css_path];
        
        
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
    [Ldb.delegate logMessage:[NSString stringWithFormat: @"LESS:: updateFileViewOptions" ]];
    for(FileView * f in fileViews)
    {
        LessFile * currentFile = [Ldb.currentParentFiles objectAtIndex:f.fileIndex];
        
        //now populate the checkboxes with the user's current preferences
        NSData * options = [currentFile.options dataUsingEncoding:NSUTF8StringEncoding];
        NSError * error;
        if(options != nil && options != (id)[NSNull null])
        {
            NSDictionary * optionsD = [NSJSONSerialization JSONObjectWithData:options options:0 error:&error];
            [f setCheckboxesForOptions:optionsD];
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
            [Ldb.delegate logMessage:[NSString stringWithFormat: @"LESS:: dragged urL: %@", aUrl ]];
//            [Ldb performSelectorOnMainThread:@selector(registerFile:) withObject:aUrl waitUntilDone:true];
            [Ldb registerFile:aUrl];
        }
    }
    
    [Ldb updateParentFilesList];
    [self rebuildFileList];
    
}

@end
