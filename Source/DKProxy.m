/** Implementation of the DKProxy class representing D-Bus objects on the
    GNUstep side.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2010

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

#import "DKEndpoint.h"
#import "DKMethod.h"
#import "DBusKit/DKProxy.h"

#import <Foundation/NSCoder.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>



@implementation DKProxy

+ (id)proxyWithEndpoint: (DKEndpoint*)anEndpoint
             andService: (NSString*)aService
                andPath: (NSString*)aPath
{
  return [[[self alloc] initWithEndpoint: anEndpoint
                              andService: aService
                                 andPath: aPath] autorelease];
}

- (id)initWithEndpoint: (DKEndpoint*)anEndpoint
            andService: (NSString*)aService
               andPath: (NSString*)aPath
{
  // This class derives from NSProxy, hence no call to -[super init].
  if ((((nil == anEndpoint)) || (nil == aService)) || (nil == aPath))
  {
    [self release];
    return nil;
  }
  ASSIGNCOPY(service, aService);
  ASSIGNCOPY(path, aPath);
  ASSIGN(endpoint, anEndpoint);
  return self;
}

- (id)initWithCoder: (NSCoder*)coder
{
  if ([coder allowsKeyedCoding])
  {
    endpoint = [coder decodeObjectForKey: @"DKProxyEndpoint"];
    service = [coder decodeObjectForKey: @"DKProxyService"];
    path = [coder decodeObjectForKey: @"DKProxyPath"];
  }
  else
  {
    [coder decodeValueOfObjCType: @encode(id) at: &endpoint];
    [coder decodeValueOfObjCType: @encode(id) at: &service];
    [coder decodeValueOfObjCType: @encode(id) at: &path];
  }
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  if ([coder allowsKeyedCoding])
  {
    [coder encodeObject: endpoint forKey: @"DKProxyEndpoint"];
    [coder encodeObject: service forKey: @"DKProxyService"];
    [coder encodeObject: path forKey: @"DKProxyPath"];
  }
  else
  {
    [coder encodeObject: endpoint];
    [coder encodeObject: service];
    [coder encodeObject: path];
  }
}

/**
 * Overrides the implementation in NSProxy, which would wrap this proxy in an
 * NSDistantObject
 */
- (id)replacementObjectForPortCoder: (NSPortCoder*)coder
{
  return self;
}

- (Class)classForPortCoder
{
  return [DKProxy class];
}
/**
 * This method strips the metadata mangled into the selector string and
 * returns it at shallBox and interface.
 */

- (SEL)_unmangledSelector: (SEL)selector
            boxingRequest: (BOOL*)shallBox
                interface: (NSString**)interface
{
  NSMutableString *selectorString = [NSStringFromSelector(selector) mutableCopy];
  SEL unmangledSelector = 0;

  // defaults:
  *shallBox = YES;
  *interface = nil;

  /*
   * First, strip potential information about not boxing the arguments.
   */
  if ([selectorString hasPrefix: @"_DKNoBox_"])
  {
    [selectorString deleteCharactersInRange: NSMakeRange(0,9)];
    if (shallBox != NULL)
    {
      *shallBox = NO;
    }
  }

  /*
   * Check whether the selector includes interface information.
   */
  if (![selectorString hasPrefix: @"_DKIf_"])
  {
    unmangledSelector = NSSelectorFromString(selectorString);
    return unmangledSelector;
  }

  // TODO: Unmangle interfaces

  return unmangledSelector;
}

- (NSMethodSignature*)methodSignatureForSelector: (SEL)aSelector
{
  /*
   * For simple cases we can simply look up the selector in the table and return
   * the signature from the associated method.
   */
  DKMethod *method = NSMapGet(selectorToMethodMap, aSelector);
  //NSString *selectorName = nil;
  if (nil != method)
  {
    return [method methodSignature];
  }

  return nil;
}

- (void)forwardInvocation: (NSInvocation*)inv
{
  id dummyReturn = nil;
  // TODO: Implement
  NSLog(@"Trying to forward invocation for %@", NSStringFromSelector([inv selector]));
  [inv setReturnValue: &dummyReturn];
}

- (BOOL)isKindOfClass: (Class)aClass
{
  if (aClass == [DKProxy class])
  {
    return YES;
  }
  return NO;
}
/*
 * Dummy method to test the proxy
 */
- (void) describeProxy
{
  NSLog(@"DKProxy connected to endpoint %@, service %@, path %@.", endpoint,
    service, path);
}

- (DKEndpoint*)_endpoint
{
  return endpoint;
}

- (NSString*)_service
{
  return service;
}

- (NSString*)_path
{
  return path;
}

- (BOOL) hasSameScopeAs: (DKProxy*)aProxy
{
  BOOL sameService = [service isEqualToString: [aProxy _service]];
  BOOL sameEndpoint = [endpoint isEqual: [aProxy _endpoint]];
  return (sameService && sameEndpoint);
}

- (void) dealloc
{
  [endpoint release];
  [service release];
  [path release];
  [super dealloc];
}
@end
