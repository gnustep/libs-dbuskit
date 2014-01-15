/** Template to create a implementation of a type-save NSNumber 
    class for marshalling to D-Bus
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


#define DK_NUMBER_IMPLEMENTATION(type, capitalized, numberType, numberMethod, format) \
@implementation DK ## capitalized ## Number \
+ (id)numberWith ## capitalized: (type)num \
{\
  return [[[DK ## capitalized ## Number alloc] initWith ## capitalized: num] autorelease]; \
}\
- (id)initWith ## capitalized: (type)num\
{\
  value = num;\
  return self;\
}\
\
-(const char*)objCType\
{\
  return @encode(type);\
}\
- (BOOL) boolValue\
{\
  return (value == 0) ? NO : YES;\
}\
\
- (numberType)numberMethod\
{\
  return value;\
}\
\
- (NSString*) descriptionWithLocale: (id)aLocale\
{\
  return [[[NSString alloc] initWithFormat: format\
                                    locale: aLocale, value] autorelease];\
}\
- (void) getValue: (void*)buffer\
{\
  type *ptr = buffer;\
  *ptr = value;\
}\
@end
