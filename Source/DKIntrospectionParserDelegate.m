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

#import "DKArgument.h"
#import "DKInterface.h"
#import "DKIntrospectionNode.h"
#import "DKMethod.h"
#import "DKObjectPathNode.h"
#import "DKSignal.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSXMLParser.h>

@interface DKIntrospectionParserDelegate (StackManagement)
- (void)pushToStack: (id)obj;
- (void)popStack;
- (id)leaf;
@end

@implementation DKIntrospectionParserDelegate

- (id) initWithParentForNodes: (id)parent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  stack = [[NSMutableArray alloc] init];
  [self pushToStack: parent];
  return self;
}

- (void) dealloc
{
  [stack release];
  [super dealloc];
}

- (id)leaf
{
  id object = [stack objectAtIndex: ([stack count] - 1)];
  if ([[NSNull null] isEqual: object])
  {
    return nil;
  }
  return object;
}

- (void)popStack
{
  NSUInteger count = [stack count];
  if (0 != count)
  {
    [stack removeObjectAtIndex: (count - 1) ];
  }
}

- (void)pushToStack: (id)obj
{
  if (nil == obj)
  {
    obj = [NSNull null];
  }
  [stack addObject: obj];
}

/* Parser delegate methods */
- (void) parserDidStartDocument: (NSXMLParser*)aParser
{
  NSDebugMLog(@"Started parsing XML");
}

- (void) parserDidEndDocument: (NSXMLParser*)aParser
{
  NSDebugMLog(@"Stopped parsing XML");
}

- (void) parser: (NSXMLParser*)aParser
didStartElement: (NSString*)aNode
   namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
     attributes: (NSDictionary*)someAttributes
{
  NSString *theName = [someAttributes objectForKey: @"name"];
  DKIntrospectionNode *newNode = nil;
  id leaf = [self leaf];
  BOOL isRoot = (0 == xmlDepth);
  xmlDepth++;
  NSDebugLog(@"Starting <%@> node '%@' at depth %lu.",
    aNode,
    theName,
    xmlDepth);

  if ([@"node" isEqualToString: aNode])
  {
    if ([theName length] > 0)
    {
      if (isRoot && ('/' != [theName characterAtIndex: 0]))
      {
	// relative paths must refer to nodes contained in the main node.
	[NSException raise: @"DKIntrospectionException"
	            format: @"Introspection data contains invalid root node named '%@'",
	  theName];
      }
    }

    if (isRoot)
    {
      // For the root node, we just push the leaf we got initially once again:
      newNode = RETAIN(leaf);
    }
    else
    {
      newNode = [[DKObjectPathNode alloc] initWithName: theName
                                                parent: leaf];
      if ([leaf conformsToProtocol: @protocol(DKObjectPathNode)])
      {
        [(id<DKObjectPathNode>)leaf _addChildNode: (DKObjectPathNode*)newNode];
      }
    }
  }
  else if (([@"interface" isEqualToString: aNode]) && ([theName length] > 0))
  {
    newNode = [[DKInterface alloc] initWithName: theName
                                         parent: leaf];
      if ([leaf conformsToProtocol: @protocol(DKObjectPathNode)])
      {
	[(id<DKObjectPathNode>)leaf _addInterface: (DKInterface*)newNode];
      }
  }
  else if (([@"annotation" isEqualToString: aNode]) && ([theName length] > 0))
  {
    id theValue = [someAttributes objectForKey: @"value"];
    if (nil == theValue)
    {
      theValue = [NSNull null];
    }
    if ([leaf respondsToSelector: @selector(setAnnotationValue:forKey:)])
    {
      [leaf setAnnotationValue: theValue
                        forKey: theName];
    }
  }
  else if ([leaf isKindOfClass: [DKInterface class]])
  {
    // Things that should only appear in interfaces (methods, signals,
    // porperties):
    DKInterface *ifLeaf = (DKInterface*)leaf;
    if ([@"method" isEqualToString: aNode])
    {
      newNode = [[DKMethod alloc] initWithName: theName
                                        parent: leaf];
      [ifLeaf addMethod: (DKMethod*)newNode];
    }
    else if ([@"signal" isEqualToString: aNode])
    {
      newNode = [[DKSignal alloc] initWithName: theName
                                        parent: leaf];
      [ifLeaf addSignal: (DKSignal*)newNode];
    }
    else if ([@"property" isEqualToString: aNode])
    {
      //TODO: Implement properties.
    }
  }
  else if (([leaf isKindOfClass: [DKMethod class]])
    || [leaf isKindOfClass: [DKSignal class]])
  {
    // Arguments should only appear in methods or signals
    if ([@"arg" isEqualToString: aNode])
    {
      NSString *direction = [someAttributes objectForKey: @"direction"];
      const char *type = [[someAttributes objectForKey: @"type"] UTF8String];
      newNode = [[DKArgument alloc] initWithDBusSignature: type
                                                     name: theName
						   parent: leaf];
      // DKSignal also implements addArgument:direction: with the same
      // signature.
      [(DKMethod*)leaf addArgument: (DKArgument*)newNode
                         direction: direction];
    }
  }
  else
  {
    NSDebugMLog(@"Ignoring <%@> node '%@' at depth %lu.",
      aNode,
      theName,
      xmlDepth);
    newNode = [[DKIntrospectionNode alloc] initWithName: theName
                                                 parent: leaf];
  }

  [self pushToStack: newNode];

  if (newNode != nil)
  {
    // We did not autorelease the nodes when creating them, so we release them
    // here:
    [newNode release];
  }
}

- (void) parser: (NSXMLParser*)aParser
  didEndElement: (NSString*)aNode
   namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
{
  NSDebugMLog(@"Ended node: %@", aNode);
  xmlDepth--;
  [self popStack];
  if (0 == xmlDepth)
  {
    NSDebugMLog(@"Ended parsing");
  }
}

@end
