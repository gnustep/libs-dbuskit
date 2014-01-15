/** Helper class to indicate that something should be returned as a
    D-Bus variant type argument.
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

#import "DBusKit/DKVariant.h"
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>

@implementation DKVariant

+ (id) variantWithObject: (id)obj
{
  return [[[self alloc] initWithObject: obj] autorelease];
}

- (id) forwardingTargetForSelector: (SEL)aSelector
{
  if ([object respondsToSelector: aSelector])
    {
      return object;
    }
  return nil;
}
- (id) initWithObject: (id)anObject
{
  if (anObject == nil)
    {
      [self release];
      return nil;
    }
  ASSIGN(object, anObject);
  return self;
}

- (void)dealloc
{
  [object release];
  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat: @"<DKVariant: %@>", [object description]];
}

- (NSString*)descriptionWithLocale: (NSLocale*)l
{
  return [NSString stringWithFormat: @"<DKVariant: %@>", [object descriptionWithLocale: l]];
}

- (BOOL)respondsToSelector: (SEL)aSelector
{
  if ([object respondsToSelector: aSelector])
    {
      return YES;
    }
  const char *name = sel_getName(aSelector);
  if ((NULL == name) || ('\0' == *name))
    {
      return NO;
    }
  return (0 == strcmp(name,"isDBusVariant"));
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  if ([object respondsToSelector: aSelector])
  {
    return [object methodSignatureForSelector: aSelector];
  }
  return nil;
}

- (BOOL)isDBusVariant
{
  return YES;
}

- (void) forwardInvocation: (NSInvocation *)anInvocation
{
  if ([object respondsToSelector: [anInvocation selector]])
  {
    [anInvocation invokeWithTarget: object];
  }
}
@end

