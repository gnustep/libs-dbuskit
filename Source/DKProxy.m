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



/*
 * Definitions of the strings used for selector mangling.
 */
#define SEL_MANGLE_NOBOX_STRING @"_DKNoBox_"
#define SEL_MANGLE_IFSTART_STRING @"_DKIf_"
#define SEL_MANGLE_IFEND_STRING @"_DKIfEnd_"

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

/**
 * Overrides NSProxy.
 */
- (Class)classForPortCoder
{
  return [DKProxy class];
}



/**
 * Returns the DKMethod that handles the selector.
 */
- (DKMethod*)DBusMethodForSelector: (SEL)selector
{
  if (0 == selector)
  {
    return nil;
  }
  return NSMapGet(selectorToMethodMap, selector);
}


/**
 * Returns the interface corresponding to the mangled version in which all dots
 * have been replaced with underscores.
 */
- (NSString*)DBusInterfaceForMangledString: (NSString*)string
{
  //TODO: Implement
  return nil;
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
  // Ranges for string manipulation;
  NSRange noBoxRange = [selectorString rangeOfString: SEL_MANGLE_NOBOX_STRING];
  // We cannot set the other ranges now, because they change when the mangled
  // metadata is removed.
  NSRange ifStartRange = NSMakeRange(NSNotFound, 0);
  NSRange ifEndRange = NSMakeRange(NSNotFound, 0);
  // defaults:
  *shallBox = YES;
  *interface = nil;
  if (0 == selector)
  {
    return 0;
  }

  /*
   * First, strip potential information about not boxing the arguments.
   */
  if (NSNotFound != noBoxRange.location)
  {
    /*
     * We need to look ahead for _DKIf_ to perserve the underscore. So we skip
     * ahead one character less then the length of this range to find the range
     * where it could be.
     */
    NSRange lookAhead = NSMakeRange((noBoxRange.location + (noBoxRange.length - 1)),
      [SEL_MANGLE_IFSTART_STRING length]);

    /*
     * And we also need to look behind for _DK_IfEnd_, so we skip the
     * appropriate ammount of characters back.
     */
    NSUInteger ifEndLength = [SEL_MANGLE_IFEND_STRING length];
    NSRange lookBehind;


    // Make sure there are enough characters to look for.
    if (noBoxRange.location >= ifEndLength)
    {
      lookBehind = NSMakeRange((noBoxRange.location - (ifEndLength - 1)),
        ifEndLength);
    }
    else
    {
      lookBehind = NSMakeRange(NSNotFound, 0);
    }

    // Check whether the range fits within the selectorString.
    if (NSMaxRange(lookAhead) <= [selectorString length])
    {
      // Check whether _DKIf_ exists after _DKNoBox
      if ([SEL_MANGLE_IFSTART_STRING isEqualToString: [selectorString substringWithRange: lookAhead]])
      {
	// If so, reduce the length in order to perserve the underscore.
        noBoxRange.length--;
      }
    }

    // Check wheter it is senible to look behind
    if (NSNotFound != lookBehind.location)
    {
      // Check whether DKNoBox_ is preceeded by _DKEndIf_
      if ([SEL_MANGLE_IFEND_STRING isEqualToString: [selectorString substringWithRange: lookBehind]])
      {
	// If so, move the index one character to the right to perserve the underscore.
        noBoxRange.location++;
	// Also reduce the length.
	noBoxRange.length--;
      }
    }

    // Do not try to dereference NULL
    if (shallBox != NULL)
    {
      *shallBox = NO;
    }

    // Remove the _DK_NoBox_ but leave underscores that might be needed
    [selectorString deleteCharactersInRange: noBoxRange];
  }


  ifStartRange = [selectorString rangeOfString: SEL_MANGLE_IFSTART_STRING];
  ifEndRange = [selectorString rangeOfString: SEL_MANGLE_IFEND_STRING];
  // Sanity check for presence and order of both the starting and the ending
  // string.
  if ((NSNotFound != ifStartRange.location)
    && (NSNotFound != ifEndRange.location)
    && (NSMaxRange(ifStartRange) < ifEndRange.location))
  {
    // Do not dereference NULL
    if (interface != NULL)
    {
      // Calculate the range of the interface string between the two:
      NSUInteger ifIndex = NSMaxRange(ifStartRange);
      NSUInteger ifLength = (ifEndRange.location - ifIndex);
      NSRange ifRange = NSMakeRange(ifIndex, ifLength);

      // Extract and unmangle the information
      NSString *mangledIf = [selectorString substringWithRange: ifRange];
      *interface = [self DBusInterfaceForMangledString: mangledIf];
    }

    // Throw away the whole _DKIf_*_DKEndIf_ portion.
    [selectorString deleteCharactersInRange: NSUnionRange(ifStartRange, ifEndRange)];
  }

  unmangledSelector = NSSelectorFromString(selectorString);
  [selectorString release];
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
