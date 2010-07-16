/** Implementation of the DKIntrospectionParserDelegate helper class.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */


#import "DKIntrospectionParserDelegate.h"
#import "DKInterface.h"
#import "DKIntrospectionNode.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSXMLParser.h>


@implementation DKIntrospectionParserDelegate

- (id) initWithParentForNodes: (id)_parent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  nodeParent = _parent;
  interfaces = [NSMutableDictionary new];
  childNodes = [NSMutableArray new];
  return self;
}

- (void) dealloc
{
  [interfaces release];
  [childNodes release];
  [super dealloc];
}


- (NSDictionary*)interfaces
{
  // Return an immutable copy
  return [[interfaces copy] autorelease];
}

- (NSArray*) childNodes
{
  // Return an immutable copy
  return [[childNodes copy] autorelease];
}


- (void)reparentContentsOfCollection: (id)collection
                            toParent: (id)newParent
{
  NSEnumerator *theEnum = [collection objectEnumerator];
  DKIntrospectionNode *theNode = nil;

  while (nil != (theNode = [theEnum nextObject]))
  {
    if ([theNode respondsToSelector: @selector(setParent:)])
    {
      [theNode setParent: newParent];
    }
  }
}

- (void)reparentChildrenTo: (id)newParent
{
  [self reparentContentsOfCollection: interfaces
                            toParent: newParent];
  [self reparentContentsOfCollection: childNodes
                            toParent: newParent];
}

/* Parser delegate methods */

- (void) parser: (NSXMLParser*)aParser
didStartElement: (NSString*)aNode
   namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
     attributes: (NSDictionary*)someAttributes
{
  NSString *theName = [someAttributes objectForKey: @"name"];
  DKIntrospectionNode *newNode = nil;
  xmlDepth++;
  if ([@"node" isEqualToString: aNode])
  {
    BOOL isRoot = YES;
    if ([theName length] > 0)
    {
      if ('/' != [theName characterAtIndex: 0])
      {
	isRoot = NO;
	// relative paths must refer to nodes contained in the main node.
	if ((xmlDepth - 1) == 0)
	{
	  [NSException raise: @"DKIntrospectionException"
	  format: @"Introspection data contains invalid root node named '%@'",
	    theName];
	}
      }
    }
    if (NO == isRoot)
    {
      // TODO: Generate information about child nodes
      // (For now, just create a DKIntrospectionNode to store them)
      newNode = [[DKIntrospectionNode alloc] initWithName: theName
                                                   parent: self];
      [childNodes addObject: newNode];
    }
  }
  else if (([@"interface" isEqualToString: aNode]) && ([theName length] > 0))
  {
    newNode = [[DKInterface alloc] initWithInterfaceName: theName
                                                  parent: self];
    [interfaces setObject: newNode
                   forKey: theName];
  }
  else
  {
    // catch-all node: Will just count xmlDepth and return control to us when
    // the xml tree is balanced.
    newNode = [[DKIntrospectionNode alloc] initWithName: theName
                                                 parent: self];

    // extra -retain so we can use a simple -release for all node-types at the
    // end of this method
    [[newNode retain] autorelease];
  }

  if (newNode != nil)
  {
    // pass on the started node information so that the new delegate knows that
    // it has been opened.
    [newNode parser: aParser
    didStartElement: aNode
       namespaceURI: aNamespaceURI
      qualifiedName: aQualifierName
         attributes: someAttributes];

    // Continue parsing with the new delegate:
    [aParser setDelegate: newNode];

    // newNode has either been retained in an array or dictionary, or we did an
    // extra -retain before autoreleasing a catch-all node.
    [newNode release];
    newNode = nil;
  }
}

- (void) parser: (NSXMLParser*)aParser
  didEndElement: (NSString*)aNode
   namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
{
  NSDebugMLog(@"Ended node: %@", aNode);
  xmlDepth--;
  if (0 == xmlDepth)
  {
    [self reparentChildrenTo: nodeParent];
    NSDebugMLog(@"Ended parsing");
  }
}

@end
