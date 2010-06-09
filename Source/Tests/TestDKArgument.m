/* Unit tests for DKArgument
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
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <UnitKit/UnitKit.h>

#import "../../Headers/DKProxy.h"
#import "../DKArgument.h"

@interface TestDKArgument: NSObject <UKTest>
@end

static NSArray *basicSigs;
static NSDictionary *basicSigsAndClasses;

@implementation TestDKArgument
+ (void) initialize
{
  if (self == [TestDKArgument class])
  {
    basicSigs = [[NSArray alloc] initWithObjects:
      @"y", @"b", @"n", @"q", @"i", @"u", @"x", @"t", @"d", @"s", @"o", @"g", nil];
    basicSigsAndClasses = [[NSDictionary alloc] initWithObjectsAndKeys:
      [NSNumber class], @"y",
      [NSNumber class], @"b",
      [NSNumber class], @"n",
      [NSNumber class], @"q",
      [NSNumber class], @"i",
      [NSNumber class], @"u",
      [NSNumber class], @"x",
      [NSNumber class], @"t",
      [NSNumber class], @"d",
      [NSString class], @"s",
      [DKProxy class], @"o",
      [DKArgument class], @"g", nil];
  }

}

/*
 * We shall ignore arguments with an invalid signature.
 */
- (void) testRejectInvalid
{
  UKNil([[DKArgument alloc] initWithDBusSignature: "k"
                                             name: nil
                                           parent: nil]);
}

/*
 * We shall ignore arguments with multiple complete types (unless they are
 * contained somehow).
 */
- (void) testRejectMultiple
{
  UKNil([[DKArgument alloc] initWithDBusSignature: "iiu"
                                             name: nil
                                           parent: nil]);
}

- (void) testSimpleRoundtrip
{
  NSEnumerator *enumerator = [basicSigs objectEnumerator];
  NSString *sig = nil;
  while (nil != (sig = [enumerator nextObject]))
  {
    DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: [sig UTF8String]
                                                          name: nil
                                                        parent: nil];
    UKObjectsEqual([arg DBusTypeSignature],sig);
    [arg release];
  }
}

- (void)testSimpleObjCEquivs
{
  NSEnumerator *enumerator = [basicSigs objectEnumerator];
  NSString *sig = nil;
  while (nil != (sig = [enumerator nextObject]))
  {
    DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: [sig UTF8String]
                                                          name: nil
                                                        parent: nil];
    UKObjectsEqual([basicSigsAndClasses objectForKey: sig] ,[arg objCEquivalent]);
  }
}

- (void) testArrayTypeRoundtrip
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "as"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"as");
  [arg release];
}

- (void) testArrayTypeEquiv
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "as"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg objCEquivalent], [NSArray class]);
  [arg release];
}

- (void) testStructTypeRoundtrip
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "(iiu)"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"(iiu)");
  [arg release];
}

- (void) testStructTypeEquiv
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "(iiu)"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg objCEquivalent], [NSArray class]);
  [arg release];
}

- (void) testVariantTypeRoundtrip
{
  // Yes, it is confusing that variant is a container type.
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"v");
  [arg release];
}

- (void) testVariantTypeEquiv
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                         name: nil
                                                       parent: nil];
  /* Variant types will be dynamically boxed and unboxed depending on the
   * marshalled value.
   */
  UKNil([arg objCEquivalent]);
  [arg release];
}

- (void) testDictEntryTypeRoundtrip
{
  // Dict entries don't appear on their own
  DKContainerTypeArgument *superArg = [[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                                           name: nil
                                                                         parent: nil];
  DKArgument *arg = [[superArg children] objectAtIndex: 0];
  UKObjectsEqual([arg DBusTypeSignature], @"{su}");
  [superArg release];
}

- (void) testDictEntryTypeEquiv
{
  DKContainerTypeArgument *superArg = [[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                                           name: nil
                                                                         parent: nil];
  DKArgument *arg = [[superArg children] objectAtIndex: 0];
  // They are also not supposed to carry their own ObjC equivalent class.
  UKNil([arg objCEquivalent]);
  [superArg release];
}

- (void) testDictionaryDetection
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg objCEquivalent], [NSDictionary class]);
}

- (void)testNestedTypeRoundTrip
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "(ua{s(iu)}bv)"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"(ua{s(iu)}bv)");
  [arg release];
}
@end
