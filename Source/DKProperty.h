/** Interface for DKPorperty class encapsulating D-Bus property information.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: September 2010

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

   <title>DKProperty class reference</title>
   */

#import "DKIntrospectionNode.h"
@class NSLock, NSString, DKArgument, DKPropertyAccessor, DKPropertyMutator;

/**
 * DKProperty encapsulates information about D-Bus properties.
 */
@interface DKProperty: DKIntrospectionNode
{
  /**
   * The D-Bus type of the property.
   */
  DKArgument *type;

  /**
   * Mutator method.
   */
  DKPropertyMutator *mutator;

  /**
   * Accessor method.
   */
  DKPropertyAccessor *accessor;
}

- (id)initWithDBusSignature: (const char*)characters
           accessAttributes: (NSString*)attributes
                       name: (NSString*)name
                     parent: (NSString*)parent;

- (DKPropertyMutator*)mutatorMethod;

- (DKPropertyAccessor*)accessorMethod;

- (DKArgument*)type;

- (BOOL)isReadable;

- (BOOL)isWritable;

- (NSString*)interface;

/**
 * Emits a property declaration for the property. If useObjC2 is set to YES, a
 * "@property" declaration will be produced. Otherwise, method declarations for
 * accessors and mutators are generated. The generated string ends with a
 * newline.
 */
- (NSString*)propertyDeclarationForObjC2: (BOOL)useObjC2;
@end
