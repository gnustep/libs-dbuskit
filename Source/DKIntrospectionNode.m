/** Interface for the DKIntrospectionNode helper class.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

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


#import "DKIntrospectionNode.h"

#import "DKProxy+Private.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLParser.h>

@implementation DKIntrospectionNode

- (id) initWithName: (NSString*)aName
             parent: (id)aParent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGNCOPY(name,aName);
  parent = aParent;
  annotations = [NSMutableDictionary new];
  return self;
}

- (NSString*) name
{
  return name;
}

- (id) parent
{
  return parent;
}

- (void) setParent: aParent
{
  parent = aParent;
}

- (DKProxy*)proxyParent
{
  if ([parent respondsToSelector: @selector(proxyParent)])
  {
    return [parent proxyParent];
  }
  return nil;
}

- (void) setAnnotationValue: (id)value
                     forKey: (NSString*)key
{
  if (0 != [key length])
  {
    if (value == nil)
    {
      value = [NSNull null];

    }
    [annotations setObject: value
                    forKey: key];

  }
}

- (id) annotationValueForKey: (NSString*)key
{
  if (key != nil)
  {
    return [annotations objectForKey: key];
  }
  return nil;
}

- (void)setAnnotations: (NSMutableDictionary*)newAnnotations
{
  ASSIGN(annotations,newAnnotations);
}

- (NSDictionary*)annotations
{
  return [[annotations copy] autorelease];
}

- (id)copyWithZone: (NSZone*)zone
{
  DKIntrospectionNode *newNode = nil;
  NSMutableDictionary *newAnnotations = nil;
  NSString *newName = [[name copyWithZone: zone] autorelease];
  /*
   * Shallow copy is enough for annotations, they only contain immutable
   * strings.
   */
  newAnnotations = [annotations mutableCopyWithZone: zone];
  newNode = [[[self class] alloc] initWithName: newName
                                        parent: parent];
  [newNode setAnnotations: newAnnotations];
  [newAnnotations release];
  return newNode;
}


- (NSArray*)annotationXMLNodes
{
  // We are potentially creating quite a few temporary objects if there are
  // many annotations so it's worth having an extra autorelease pool for them.
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSEnumerator *annotationsEnum = [annotations keyEnumerator];
  NSString *annotationKey = nil;
  NSMutableArray *annotationNodes = [NSMutableArray new];
  while (nil != (annotationKey = [annotationsEnum nextObject]))
  {
    id rawValue = [annotations objectForKey: annotationKey];
    // Set to empty string if it is not a string:
    NSString *stringValue = [rawValue isKindOfClass: [NSString class]] ? rawValue : @"";
    NSXMLNode *theName = [NSXMLNode attributeWithName: @"name"
                                       stringValue: annotationKey];
    NSXMLNode *theValue = [NSXMLNode attributeWithName: @"value"
                                        stringValue: stringValue];
    NSXMLNode *theNode = [NSXMLNode elementWithName: @"annotation"
                                           children: nil
			                 attributes: [NSArray arrayWithObjects: theName, theValue, nil]];
    [annotationNodes addObject: theNode];
  }
  [pool release];
  return [NSArray arrayWithArray: [annotationNodes autorelease]];
}

- (void) dealloc
{
  parent = nil;
  [name release];
  [annotations release];
  [super dealloc];
}


@end
