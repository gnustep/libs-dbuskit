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

   <title>DKIntrospectionNode class reference</title>
   */

#import <Foundation/NSObject.h>
@class DKProxy, NSString, NSXMLNode, NSXMLParser, NSMutableDictionary;
/**
 * DKIntrospectionNode is the common superclass of all elements that make up the
 * introspection graph for a D-Bus entity.
 */
@interface DKIntrospectionNode: NSObject <NSCopying>
{
  NSString *name;
  NSMutableDictionary *annotations;
  id parent;
}

/**
 * Initializes with a name and a string.
 */
- (id) initWithName: (NSString*)aName
             parent: (id)parent;

/**
 * Returns the name.
 */
- (NSString*) name;

/**
 * Returns the parent of the node.
 */
- (id) parent;

/**
 * Changes the parent to a new one.
 */
- (void) setParent: (id)parent;

/**
 * Returns the next parent proxy in the tree.
 */
- (DKProxy*) proxyParent;


/**
 * Returns the dictionary of all annotations for the node.
 */
- (NSDictionary*)annotations;

/**
 * Returns an array of NSXMLNodes representing the annotations on the receiver.
 */
- (NSArray*)annotationXMLNodes;

/**
 * Records metadata for the node.
 */
- (void) setAnnotationValue: (id)value
                     forKey: (NSString*)key;

/**
 * Returns the value of the specified annotation key.
 */
- (id) annotationValueForKey: (NSString*)key;

/**
 * Returns an XML node representing the introspection node.
 */
- (NSXMLNode*)XMLNode;
@end
