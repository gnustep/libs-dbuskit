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
#import "DKSignal.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSXMLParser.h>


@implementation DKIntrospectionParserDelegate

- (id) initWithParentForNodes: (id)_parent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  stack = [[NSMutableArray alloc] init];
  if (nil != _parent)
  {
    [stack addObject: _parent];
  }
  interfaces = [NSMutableDictionary new];
  childNodes = [NSMutableArray new];
  return self;
}

- (void) dealloc
{
  [interfaces release];
  [childNodes release];
  [stack release];
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


- (id)leaf
{
  if (0 == [stack count])
  {
    return nil;
  }
  return [stack objectAtIndex: ([stack count] - 1)];
}

- (void)popStack
{
  if (0 != [stack count])
  {
    [stack removeObjectAtIndex: ([stack count] - 1) ];
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
  xmlDepth++;
  NSDebugLog(@"Starting <%@> node '%@' at depth %lu.",
    aNode,
    theName,
    xmlDepth);
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
                                                   parent: leaf];
      [childNodes addObject: newNode];
    }
  }
  else if (([@"interface" isEqualToString: aNode]) && ([theName length] > 0))
  {
    newNode = [[DKInterface alloc] initWithInterfaceName: theName
                                                  parent: leaf];
    [interfaces setObject: newNode
                   forKey: theName];
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
      newNode = [[DKMethod alloc] initWithMethodName: theName
                                           interface: [ifLeaf name]
                                              parent: leaf];
      [ifLeaf addMethod: (DKMethod*)newNode];
    }
    else if ([@"signal" isEqualToString: aNode])
    {
      //TODO: Implement signals
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

  if (newNode != nil)
  {
    [self pushToStack: newNode];
    // We did not autorelease the nodes when creating them, so we release them
    // here:
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
  [self popStack];
  if (0 == xmlDepth)
  {
    NSDebugMLog(@"Ended parsing");
  }
}

@end
