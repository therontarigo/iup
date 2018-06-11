/** \file
 * \brief Tree Control
 *
 * See Copyright Notice in iup.h
 */

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <memory.h>
#include <stdarg.h>

#include "iup.h"
#include "iupcbs.h"

#include "iup_object.h"
#include "iup_layout.h"
#include "iup_attrib.h"
#include "iup_str.h"
#include "iup_drv.h"
#include "iup_drvfont.h"
#include "iup_stdcontrols.h"
#include "iup_key.h"
#include "iup_image.h"
#include "iup_array.h"
#include "iup_tree.h"

#include "iup_drvinfo.h"

#include "iupcocoa_drv.h"


// the point of this is we have a unique memory address for an identifier
static const void* IUP_COCOA_TREE_DELEGATE_OBJ_KEY = "IUP_COCOA_TREE_DELEGATE_OBJ_KEY";

static NSView* cocoaTreeGetRootView(Ihandle* ih)
{
	NSView* root_container_view = (NSView*)ih->handle;
	NSCAssert([root_container_view isKindOfClass:[NSView class]], @"Expected NSView");
	return root_container_view;
}

static NSScrollView* cocoaTreeGetScrollView(Ihandle* ih)
{
	NSScrollView* scroll_view = (NSScrollView*)ih->handle;
	NSCAssert([scroll_view isKindOfClass:[NSScrollView class]], @"Expected NSScrollView");
	return scroll_view;
}

static NSOutlineView* cocoaTreeGetOutlineView(Ihandle* ih)
{
	
	NSScrollView* scroll_view = cocoaTreeGetScrollView(ih);
	NSOutlineView* outline_view = (NSOutlineView*)[scroll_view documentView];
	NSCAssert([outline_view isKindOfClass:[NSOutlineView class]], @"Expected NSOutlineView");
	return outline_view;
	
}


@interface IupCocoaTreeItem : NSObject
{
	IupCocoaTreeItem* parentItem;
	NSMutableArray* childrenArray;
	int kind; // ITREE_BRANCH ITREE_LEAF
	NSString* title;
}

@property(nonatomic, assign) int kind;
@property(nonatomic, copy) NSString* title;
@property(nonatomic, weak) IupCocoaTreeItem* parentItem;

- (IupCocoaTreeItem*) childAtIndex:(NSUInteger)the_index;

@end


@implementation IupCocoaTreeItem

@synthesize kind = kind;
@synthesize title = title;
@synthesize parentItem = parentItem;


// Creates, caches, and returns the array of children
// Loads children incrementally
- (NSMutableArray*) childrenArray
{
	return childrenArray;
}


- (IupCocoaTreeItem*) childAtIndex:(NSUInteger)the_index
{
	return [[self childrenArray] objectAtIndex:the_index];
}


- (NSUInteger) numberOfChildren
{
	NSArray* tmp = [self childrenArray];
	return [tmp count];
}


- (instancetype) init
{
	self = [super init];
	if(self)
	{
		childrenArray = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[childrenArray release];
	[title release];
	[super dealloc];
}

@end

@interface IupCocoaTreeRoot : NSObject
{
	// Array of IupCocoaTreeItems
	NSMutableArray* topLevelObjects;
}
@end

@implementation IupCocoaTreeRoot



@end


// We are not using NSComboBoxDataSource
@interface IupCocoaTreeDelegate : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
	NSUInteger numberOfItems;
	
	NSMutableArray* treeRootTopLevelObjects;

}
@property(nonatomic, assign) NSUInteger numberOfItems;
- (void) insertChild:(IupCocoaTreeItem*)tree_item_child withParent:(IupCocoaTreeItem*)tree_item_parent;
- (void) insertPeer:(IupCocoaTreeItem*)tree_item_new withSibling:(IupCocoaTreeItem*)tree_item_prev;
- (void) insertAtRoot:(IupCocoaTreeItem*)tree_item_new;

//- (NSMutableArray*) dataArray;

// NSOutlineViewDataSource
- (NSInteger) outlineView:(NSOutlineView*)outline_view numberOfChildrenOfItem:(nullable id)the_item;
//- (id) outlineView:(NSOutlineView*)outline_view child:(NSInteger)index ofItem:(nullable id)the_item;
- (BOOL) outlineView:(NSOutlineView*)outline_view isItemExpandable:(id)the_item;
// NSOutlineViewDelegate
- (nullable NSView *)outlineView:(NSOutlineView*)outline_view viewForTableColumn:(nullable NSTableColumn*)table_column item:(id)the_item;


@end

@implementation IupCocoaTreeDelegate
@synthesize numberOfItems = numberOfItems;

- (instancetype) init
{
	self = [super init];
	if(self)
	{
		treeRootTopLevelObjects = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[treeRootTopLevelObjects release];
	[super dealloc];
}

- (void) insertChild:(IupCocoaTreeItem*)tree_item_child withParent:tree_item_parent
{
	// IUP always inserts the child in the first position, not the last
	[[tree_item_parent childrenArray] insertObject:tree_item_child atIndex:0];
	[tree_item_child setParentItem:tree_item_parent];
	numberOfItems = numberOfItems + 1;
}

- (void) insertPeer:(IupCocoaTreeItem*)tree_item_new withSibling:(IupCocoaTreeItem*)tree_item_prev
{
	IupCocoaTreeItem* tree_item_parent = [tree_item_prev parentItem];
	[tree_item_new setParentItem:tree_item_parent];
	// insert the new node after reference node
	NSMutableArray* children_array = [tree_item_parent childrenArray];
	NSUInteger prev_index = [children_array indexOfObject:tree_item_prev];
	NSUInteger target_index = prev_index + 1;

	if(target_index > [children_array count])
	{
		[children_array addObject:tree_item_new];
	}
	else
	{
		[children_array insertObject:tree_item_new atIndex:target_index];
	}
	numberOfItems = numberOfItems + 1;
}

- (void) insertAtRoot:(IupCocoaTreeItem*)tree_item_new
{
	// IUP always inserts the child in the first position, not the last
	[treeRootTopLevelObjects insertObject:tree_item_new atIndex:0];
	numberOfItems = numberOfItems + 1;
}


- (NSInteger) outlineView:(NSOutlineView*)outline_view numberOfChildrenOfItem:(nullable id)the_item
{
	// FIXME: temp placeholder
	// FIXME: temp placeholder
	if(nil == the_item)
	{
		NSInteger the_count = [treeRootTopLevelObjects count];
		return the_count;
	}
	else
	{
		NSInteger the_count = [the_item numberOfChildren];
		return the_count;
	}
}

- (id) outlineView:(NSOutlineView*)outline_view child:(NSInteger)the_index ofItem:(nullable id)the_item
{
	// FIXME: temp placeholder
	if(nil == the_item)
	{
//		return nil;
//		IupCocoaTreeItem* dummy = [[[IupCocoaTreeItem alloc] init] autorelease];
// return dummy;
		IupCocoaTreeItem* tree_item = [treeRootTopLevelObjects objectAtIndex:the_index];
		return tree_item;
	}
	else
	{
		return [the_item childAtIndex:the_index];
	}
}

- (BOOL) outlineView:(NSOutlineView*)outline_view isItemExpandable:(id)the_item
{
	// FIXME: temp placeholder
	if ([outline_view parentForItem:the_item] == nil)
	{
		return YES;
	}
	else
	{
		IupCocoaTreeItem* tree_item = (IupCocoaTreeItem*)the_item;
		NSCAssert([tree_item isKindOfClass:[IupCocoaTreeItem class]], @"Expected IupCocoaTreeItem");
		if([tree_item numberOfChildren] > 0)
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
}

/* // Not needed for View based NSOutlineView
- (nullable id)outlineView:(NSOutlineView *)outline_view objectValueForTableColumn:(nullable NSTableColumn *)table_column byItem:(nullable id)the_item
{
	//return (the_item == nil) ? @"/" : @"lower";
	if(nil == the_item)
	{
		return @"Hello World";
	}
	else
	{
		IupCocoaTreeItem* tree_item = (IupCocoaTreeItem*)the_item;
		NSCAssert([tree_item isKindOfClass:[IupCocoaTreeItem class]], @"Expected IupCocoaTreeItem");
		return [tree_item title];
	}
	
}
*/

// NSOutlineViewDelegate
- (nullable NSView *)outlineView:(NSOutlineView*)outline_view viewForTableColumn:(nullable NSTableColumn*)table_column item:(id)the_item
{
	IupCocoaTreeItem* tree_item = (IupCocoaTreeItem*)the_item;
	NSCAssert([tree_item isKindOfClass:[IupCocoaTreeItem class]], @"Expected IupCocoaTreeItem");
	NSString* string_item = [tree_item title];
	
	// Get an existing cell with the MyView identifier if it exists
	NSTextField* the_result = [outline_view makeViewWithIdentifier:@"IupCocoaTreeTableViewCell" owner:self];
 
	// There is no existing cell to reuse so create a new one
	if(nil == the_result)
	{
		
		// Create the new NSTextField with a frame of the {0,0} with the width of the table.
		// Note that the height of the frame is not really relevant, because the row height will modify the height.
		//		the_result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, kIupCocoaDefaultWidthNSPopUpButton, kIupCocoaDefaultHeightNSPopUpButton)];
		the_result = [[NSTextField alloc] initWithFrame:NSZeroRect];
		[the_result setBezeled:NO];
		[the_result setDrawsBackground:NO];
		[the_result setEditable:NO];
		//			[the_label setSelectable:NO];
		// TODO: FEATURE: I think this is really convenient for users
		[the_result setSelectable:YES];
		
		// The identifier of the NSTextField instance is set to MyView.
		// This allows the cell to be reused.
		[the_result setIdentifier:@"IupCocoaTreeTableViewCell"];
		[the_result setFont:[NSFont systemFontOfSize:0.0]];
	}
 
	// result is now guaranteed to be valid, either as a reused cell
	// or as a new cell, so set the stringValue of the cell to the
	// nameArray value at row
	[the_result setStringValue:string_item];
 
	// Return the result
	return the_result;
}

@end

/*****************************************************************************/
/* ADDING ITEMS                                                              */
/*****************************************************************************/

static void cocoaTreeReloadItem(Ihandle* ih, IupCocoaTreeItem* tree_item, NSOutlineView* outline_view)
{
	NSOperatingSystemVersion macosx_1012 = { 10, 12, 0 };
	
	// isOperatingSystemAtLeastVersion officially requires 10.10+, but seems available on 10.9
	if([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:macosx_1012])
	{
		// Starting in 10.12, reloadItem: was fixed to do the right thing. Must link to 10.12 SDK or higher (which you should always link to the lastest on Mac anyway)
		[outline_view reloadItem:tree_item];
	}
	else
	{
		[outline_view reloadData];
	}
}

void iupdrvTreeAddNode(Ihandle* ih, int prev_id, int kind, const char* title, int add)
{
/*
 
 id is the number identifier of a reference node, the reference node is used to position the new node.
 
 kind is the new node type, if it is a branch or a leaf.
 
 add means appending a node at the end of the branch, if 0 means inserting the node in the branch
 
 If the reference node exists then
 if (reference node is a branch and appending)
 insert the new node after the reference node, as first child
 else
 insert the new node after reference node
 else
 add the new node at root
*/
	NSOutlineView* outline_view = cocoaTreeGetOutlineView(ih);
	IupCocoaTreeDelegate* data_source_delegate = (IupCocoaTreeDelegate*)[outline_view dataSource];
	
	

	
	
	InodeHandle* inode_prev = iupTreeGetNode(ih, prev_id);
	

	/* the previous node is not necessary only
	 if adding the root in an empty tree or before the root. */
	if (!inode_prev && prev_id!=-1)
	{
//		return;
	}
	
	if (!title)
	{
		title = "";
	}
	

	
	IupCocoaTreeItem* tree_item_new = [[IupCocoaTreeItem alloc] init];
	[tree_item_new setKind:kind];
	NSString* ns_title = [NSString stringWithUTF8String:title];
	[tree_item_new setTitle:ns_title];
	InodeHandle* inode_new = (InodeHandle*)calloc(1, sizeof(InodeHandle));
	inode_new->userdata = tree_item_new; // NOTE: retain count is 1 from alloc. We are not going to retain it again.
	
	//  If the reference node exists then
	if(inode_prev)
	{
		IupCocoaTreeItem* tree_item_prev = inode_prev->userdata;
		int kind_prev = [tree_item_prev kind];
	
		
		// if (reference node is a branch and appending)
		if((ITREE_BRANCH == kind_prev) && (1 == add))
		{
			// insert the new node after the reference node, as first child
			/* depth+1 */
			[data_source_delegate insertChild:tree_item_new withParent:tree_item_prev];
		}
		else
		{
			// insert the new node after reference node
			/* same depth */
			[data_source_delegate insertPeer:tree_item_new withSibling:tree_item_prev];


		}

		iupTreeAddToCache(ih, add, kind_prev, inode_prev, inode_new);

	}
	else
	{
		//  add the new node at root
		[data_source_delegate insertAtRoot:tree_item_new];

		iupTreeAddToCache(ih, 0, 0, NULL, inode_new);

	}
	// Just reloading the single item (even with children=YES) wasn't working. Do full reloadData
	[outline_view reloadData];
}



int iupdrvTreeTotalChildCount(Ihandle* ih, InodeHandle* node_handle)
{
//	NSOutlineView* outline_view = cocoaTreeGetOutlineView(ih);
//	IupCocoaTreeDelegate* data_source_delegate = (IupCocoaTreeDelegate*)[outline_view dataSource];
	
	IupCocoaTreeItem* tree_item = (IupCocoaTreeItem*)node_handle->userdata;
	NSUInteger number_of_items = [tree_item numberOfChildren];
	return (int)number_of_items;
}

InodeHandle* iupdrvTreeGetFocusNode(Ihandle* ih)
{
	
	
	
	return NULL;
}


void iupdrvTreeUpdateMarkMode(Ihandle *ih)
{
	
}



void iupdrvTreeDragDropCopyNode(Ihandle* src, Ihandle* dst, InodeHandle *itemSrc, InodeHandle *itemDst)
{
	
}


/*****************************************************************************/
/* AUXILIAR FUNCTIONS                                                        */
/*****************************************************************************/



static char* cocoaTreeGetTitleAttrib(Ihandle* ih, int item_id)
{
//	NSOutlineView* outline_view = cocoaTreeGetOutlineView(ih);
//	IupCocoaTreeDelegate* data_source_delegate = (IupCocoaTreeDelegate*)[outline_view dataSource];
	
	InodeHandle* inode_handle = iupTreeGetNode(ih, item_id);

	if(inode_handle)
	{
		IupCocoaTreeItem* tree_item = (IupCocoaTreeItem*)inode_handle->userdata;
		NSString* ns_title = [tree_item title];
		return iupStrReturnStr([ns_title UTF8String]);
	}
	else
	{
		return NULL;
	}
}

static int cocoaTreeSetTitleAttrib(Ihandle* ih, int item_id, const char* value)
{
	InodeHandle* inode_handle = iupTreeGetNode(ih, item_id);
	
	if(inode_handle)
	{
		NSString* ns_title = @"";
		if(value)
		{
			ns_title = [NSString stringWithUTF8String:value];
		}
		
		IupCocoaTreeItem* tree_item = (IupCocoaTreeItem*)inode_handle->userdata;
		[tree_item setTitle:ns_title];
		NSOutlineView* outline_view = cocoaTreeGetOutlineView(ih);

		cocoaTreeReloadItem(ih, tree_item, outline_view);
	}

	return 0;
}



static int cocoaTreeMapMethod(Ihandle* ih)
{
	
	NSBundle* framework_bundle = [NSBundle bundleWithIdentifier:@"br.puc-rio.tecgraf.iup"];
	NSNib* outline_nib = [[NSNib alloc] initWithNibNamed:@"IupOutlineView" bundle:framework_bundle];
	
	
	NSArray* top_level_objects = nil;
	
	
	NSOutlineView* outline_view = nil;
	NSScrollView* scroll_view = nil;
	
	if([outline_nib instantiateWithOwner:nil topLevelObjects:&top_level_objects])
	{
		for(id current_object in top_level_objects)
		{

			if([current_object isKindOfClass:[NSScrollView class]])
			{
				scroll_view = current_object;
				break;
			}
		}
	}
	
	outline_view = (NSOutlineView*)[scroll_view documentView];
	NSCAssert([outline_view isKindOfClass:[NSOutlineView class]], @"Expected NSOutlineView");
	
	// ScrollView is expected to hold on to all the other objects we need
	[scroll_view retain];
	[outline_nib release];
	
	
	
	
	IupCocoaTreeDelegate* tree_delegate = [[IupCocoaTreeDelegate alloc] init];
	[outline_view setDataSource:tree_delegate];
	[outline_view setDelegate:tree_delegate];
	
	
	
	// We're going to use OBJC_ASSOCIATION_RETAIN because I do believe it will do the right thing for us.
	// I'm attaching to the scrollview instead of the outline view because I'm a little worried about circular references and I'm hoping this helps a little
	objc_setAssociatedObject(scroll_view, IUP_COCOA_TREE_DELEGATE_OBJ_KEY, (id)tree_delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[tree_delegate release];
	
	
	ih->handle = scroll_view;
	
	
	
	// All Cocoa views shoud call this to add the new view to the parent view.
	iupCocoaAddToParent(ih);
	
	
	
	
	
	if (iupAttribGetInt(ih, "ADDROOT"))
	{
		iupdrvTreeAddNode(ih, -1, ITREE_BRANCH, "", 0);
	}
	
	/* configure for DRAG&DROP of files */
	if (IupGetCallback(ih, "DROPFILES_CB"))
	{
		iupAttribSet(ih, "DROPFILESTARGET", "YES");
	}
	
//	IupSetCallback(ih, "_IUP_XY2POS_CB", (Icallback)cocoaTreeConvertXYToPos);
	
	iupdrvTreeUpdateMarkMode(ih);

	
	
	return IUP_NOERROR;
}

static void cocoaTreeUnMapMethod(Ihandle* ih)
{
	id root_view = ih->handle;
	
	// FIXME: IupCocoaTreeItem's and InodeHandle's are LEAKING
	
	iupCocoaRemoveFromParent(ih);
	[root_view release];
	ih->handle = NULL;
}




void iupdrvTreeInitClass(Iclass* ic)
{
	/* Driver Dependent Class functions */
	ic->Map = cocoaTreeMapMethod;
	ic->UnMap = cocoaTreeUnMapMethod;
#if 0
	
	/* Visual */
	iupClassRegisterAttribute(ic, "BGCOLOR", NULL, cocoaTreeSetBgColorAttrib, IUPAF_SAMEASSYSTEM, "TXTBGCOLOR", IUPAF_DEFAULT);
	iupClassRegisterAttribute(ic, "FGCOLOR", NULL, cocoaTreeSetFgColorAttrib, IUPAF_SAMEASSYSTEM, "TXTFGCOLOR", IUPAF_DEFAULT);
	
	/* IupTree Attributes - GENERAL */
	iupClassRegisterAttribute(ic, "EXPANDALL", NULL, cocoaTreeSetExpandAllAttrib, NULL, NULL, IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute(ic, "INDENTATION", cocoaTreeGetIndentationAttrib, cocoaTreeSetIndentationAttrib, NULL, NULL, IUPAF_DEFAULT);
	iupClassRegisterAttribute(ic, "SPACING", iupTreeGetSpacingAttrib, cocoaTreeSetSpacingAttrib, IUPAF_SAMEASSYSTEM, "0", IUPAF_NOT_MAPPED);
	iupClassRegisterAttribute(ic, "TOPITEM", NULL, cocoaTreeSetTopItemAttrib, NULL, NULL, IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	
	/* IupTree Attributes - IMAGES */
	iupClassRegisterAttributeId(ic, "IMAGE", NULL, cocoaTreeSetImageAttrib, IUPAF_IHANDLENAME|IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "IMAGEEXPANDED", NULL, cocoaTreeSetImageExpandedAttrib, IUPAF_IHANDLENAME|IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	
	iupClassRegisterAttribute(ic, "IMAGELEAF",            NULL, cocoaTreeSetImageLeafAttrib, IUPAF_SAMEASSYSTEM, "IMGLEAF", IUPAF_IHANDLENAME|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute(ic, "IMAGEBRANCHCOLLAPSED", NULL, cocoaTreeSetImageBranchCollapsedAttrib, IUPAF_SAMEASSYSTEM, "IMGCOLLAPSED", IUPAF_IHANDLENAME|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute(ic, "IMAGEBRANCHEXPANDED",  NULL, cocoaTreeSetImageBranchExpandedAttrib, IUPAF_SAMEASSYSTEM, "IMGEXPANDED", IUPAF_IHANDLENAME|IUPAF_NO_INHERIT);
	
	/* IupTree Attributes - NODES */
	iupClassRegisterAttributeId(ic, "STATE",  cocoaTreeGetStateAttrib,  cocoaTreeSetStateAttrib, IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "DEPTH",  cocoaTreeGetDepthAttrib,  NULL, IUPAF_READONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "KIND",   cocoaTreeGetKindAttrib,   NULL, IUPAF_READONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "PARENT", cocoaTreeGetParentAttrib, NULL, IUPAF_READONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "COLOR",  cocoaTreeGetColorAttrib,  cocoaTreeSetColorAttrib, IUPAF_NO_INHERIT);
#endif
	
	iupClassRegisterAttributeId(ic, "TITLE",  cocoaTreeGetTitleAttrib,  cocoaTreeSetTitleAttrib, IUPAF_NO_INHERIT);
	
#if 0
	iupClassRegisterAttributeId(ic, "TOGGLEVALUE", cocoaTreeGetToggleValueAttrib, cocoaTreeSetToggleValueAttrib, IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "TOGGLEVISIBLE", cocoaTreeGetToggleVisibleAttrib, cocoaTreeSetToggleVisibleAttrib, IUPAF_NO_INHERIT);
	
	/* Change the set method for GTK */
	iupClassRegisterReplaceAttribFunc(ic, "SHOWRENAME", NULL, cocoaTreeSetShowRenameAttrib);
	
	iupClassRegisterAttributeId(ic, "CHILDCOUNT", cocoaTreeGetChildCountAttrib, NULL, IUPAF_READONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "TITLEFONT",  cocoaTreeGetTitleFontAttrib,  cocoaTreeSetTitleFontAttrib, IUPAF_NO_INHERIT);
	
	/* IupTree Attributes - MARKS */
	iupClassRegisterAttributeId(ic, "MARKED", cocoaTreeGetMarkedAttrib, cocoaTreeSetMarkedAttrib, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute  (ic, "MARK",      NULL, cocoaTreeSetMarkAttrib,      NULL, NULL, IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute  (ic, "STARTING",  NULL, cocoaTreeSetMarkStartAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute  (ic, "MARKSTART", NULL, cocoaTreeSetMarkStartAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute  (ic, "MARKEDNODES", cocoaTreeGetMarkedNodesAttrib, cocoaTreeSetMarkedNodesAttrib, NULL, NULL, IUPAF_NO_SAVE|IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	
	iupClassRegisterAttribute(ic, "MARKWHENTOGGLE", NULL, NULL, NULL, NULL, IUPAF_NO_INHERIT);
	
	iupClassRegisterAttribute  (ic, "VALUE", cocoaTreeGetValueAttrib, cocoaTreeSetValueAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	
	/* IupTree Attributes - ACTION */
	iupClassRegisterAttributeId(ic, "DELNODE", NULL, cocoaTreeSetDelNodeAttrib, IUPAF_NOT_MAPPED|IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute(ic, "RENAME", NULL, cocoaTreeSetRenameAttrib, NULL, NULL, IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "MOVENODE", NULL, cocoaTreeSetMoveNodeAttrib, IUPAF_NOT_MAPPED|IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	iupClassRegisterAttributeId(ic, "COPYNODE", NULL, cocoaTreeSetCopyNodeAttrib, IUPAF_NOT_MAPPED|IUPAF_WRITEONLY|IUPAF_NO_INHERIT);
	
	/* IupTree Attributes - GTK Only */
	iupClassRegisterAttribute  (ic, "RUBBERBAND", NULL, NULL, IUPAF_SAMEASSYSTEM, "YES", IUPAF_NO_INHERIT);
#endif
}
