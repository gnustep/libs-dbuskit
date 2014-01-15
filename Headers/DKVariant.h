/** Helper class for variant typed arguments
   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2014

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

#import <Foundation/NSProxy.h>

/**
 * This protocol can be adopted by classes which want to indicate 
 * to the serialisation logic that their instances need to be 
 * returned as variants in the D-Bus wire protocol. This only 
 * takes effect if they are members of arrays, structures or 
 * dictionaries that are passed inside variant-typed arguments.
 */
@protocol DKVariant
/**
 * Return YES from this method if the D-Bus representation of the 
 * receiver should be a variant.
 */
- (BOOL)isDBusVariant;
@end


/**
 * A lightweight proxy class to encapsulate objects that are supposed
 * to be returned as variants.
 */
@interface DKVariant : NSProxy <DKVariant>
{
  id object;
}
+ (id)variantWithObject: (id)object;
- (id)initWithObject: (id)object;
@end
