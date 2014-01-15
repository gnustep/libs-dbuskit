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

#import <DBusKit/DKNumber.h>
#import <Foundation/NSString.h>
#import "DKNumberTemplate.h"
#import <inttypes.h>

DK_NUMBER_IMPLEMENTATION(int8_t, Int8, signed char, charValue, @"%i")
DK_NUMBER_IMPLEMENTATION(uint8_t, UInt8, unsigned char, unsignedChar, @"%u")
DK_NUMBER_IMPLEMENTATION(int16_t, Int16, short, shortValue, @"%i")
DK_NUMBER_IMPLEMENTATION(uint16_t, UInt16, unsigned short, unsignedShortValue, @"%u")
DK_NUMBER_IMPLEMENTATION(int32_t, Int32, int, intValue, @"%d")
DK_NUMBER_IMPLEMENTATION(uint32_t, UInt32, unsigned int, unsignedIntValue, @"%u")
DK_NUMBER_IMPLEMENTATION(int64_t, Int64, long long, longLongValue, @"%"PRIi64)
DK_NUMBER_IMPLEMENTATION(uint64_t, UInt64, unsigned long long, unsignedLongLongValue, @"%"PRIu64)
DK_NUMBER_IMPLEMENTATION(float, Float, float, floatValue, @"%0.7g")
DK_NUMBER_IMPLEMENTATION(double, Double, double, doubleValue, @"%0.16g")
