/** Interface for the DKIntrospectionParserDelegate helper class.
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


#import <Foundation/NSObject.h>

@class NSArray, NSDictionary, NSMutableArray, NSMutableDictionary;

/**
 * DKIntrospectionParserDelegate is the parser delegate used by an
 * NSXMLParser to build an introspection graph for an object. The introspection
 * data can be retrieved by means of the -interfaces and -childNodes methods.
 */
@interface DKIntrospectionParserDelegate: NSObject
{
  /**
   * The stack of objects in the tree.
   */
  NSMutableArray *stack;

  /**
   * The present depth in the tree.
   */
  NSUInteger xmlDepth;
}

/**
 * Initializes the parser delegate so that it will set _parent as the parent of
 * all nodes it creates.
 */
- (id) initWithParentForNodes: (id)_parent;
@end
