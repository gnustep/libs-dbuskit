/** Helper classes for type-save boxed numbers
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

#import <Foundation/NSValue.h>

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKInt8Number : NSNumber
{
  int8_t value;
}
+ (id)numberWithInt8: (int8_t)num;
- (id)initWithInt8: (int8_t)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKUInt8Number : NSNumber
{
  uint8_t value;
}
+ (id)numberWithUInt8: (uint8_t)num;
- (id)initWithUInt8: (uint8_t)num;
@end


/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKInt16Number : NSNumber
{
  int16_t value;
}
+ (id)numberWithInt16: (int16_t)num;
- (id)initWithInt16: (int16_t)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKUInt16Number : NSNumber
{
  uint16_t value;
}
+ (id)numberWithUInt16: (uint16_t)num;
- (id)initWithUInt16: (uint16_t)num;
@end


/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKInt32Number : NSNumber
{
  int32_t value;
}
+ (id)numberWithInt32: (int32_t)num;
- (id)initWithInt32: (int32_t)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKUInt32Number : NSNumber
{
  uint32_t value;
}
+ (id)numberWithUInt32: (uint32_t)num;
- (id)initWithUInt32: (uint32_t)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKInt64Number : NSNumber
{
  int64_t value;
}
+ (id)numberWithInt64: (int64_t)num;
- (id)initWithInt64: (int64_t)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKUInt64Number : NSNumber
{
  uint64_t value;
}
+ (id)numberWithUInt64: (uint64_t)num;
- (id)initWithUInt64: (uint64_t)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKFloatNumber : NSNumber
{
  float value;
}
+ (id)numberWithFloat: (float)num;
- (id)initWithFloat: (float)num;
@end

/**
 * This class ensures that serialisation of the object 
 * number within a variant-typed D-Bus argument is type-safe. 
 * This means that the object will not be promoted to a larger 
 * type by NSNumber, which could otherwise break expectations
 * of the bus peers.
 */
@interface DKDoubleNumber : NSNumber
{
  double value;
}
+ (id)numberWithDouble: (double)num;
- (id)initWithDouble: (double)num;
@end




