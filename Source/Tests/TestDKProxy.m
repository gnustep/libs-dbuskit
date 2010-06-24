/* Unit tests for DKPort
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
#import <Foundation/NSObject.h>
#import <UnitKit/UnitKit.h>
#define INCLUDE_RUNTIME_H
#include "../config.h"
#undef INCLUDE_RUNTIME_H

#import "../../Headers/DKProxy.h"
#import "../DKEndpoint.h"


@interface DKProxy (Private)
- (SEL)_unmangledSelector: (SEL)selector
            boxingRequest: (BOOL*)shallBox
                interface: (NSString**)interface;
@end

@interface TestDKProxy: NSObject <UKTest>
@end

@implementation TestDKProxy
- (void)testSelectorUnmangling
{

  NSString *mangledString = @"_DKNoBox_DKIf_org_gnustep_fake_DKIfEnd_release";
  SEL mangledSelector = 0;
  SEL unmangledSel = 0;
  BOOL shallBox = YES;
  NSString *interface = nil;

  /*
   * Initialize a dummy proxy that won't work. FIXME: Will fail when DKProxy is
   * rewritten to check the endpoint passed in the initializer.
   */
  DKProxy *proxy = [[DKProxy alloc] initWithEndpoint: (DKEndpoint*)[NSNull null]
                                          andService: @"dummy"
                                             andPath: @"/"];

  // Since nobody really calls this selector, we must register it manually with
  // the runtime.
  sel_registerName([mangledString UTF8String]);
  mangledSelector = NSSelectorFromString(mangledString);

  unmangledSel = [proxy _unmangledSelector: mangledSelector
                             boxingRequest: &shallBox
                                 interface: &interface];
  UKObjectsEqual(@"release", NSStringFromSelector(unmangledSel));
  UKFalse(shallBox);

  NSWarnMLog(@"FIXME: This test will fail until the handling of D-Bus interfaces is implemented");
  UKObjectsEqual(@"org.gnustep.fake", interface);
  [proxy release];
}
@end
