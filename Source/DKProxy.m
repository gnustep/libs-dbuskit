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
#import "DKInterface.h"
#import "DKMethod.h"
#import "DKMethodCall.h"
#import "DBusKit/DKProxy.h"

#define INCLUDE_RUNTIME_H
#include "config.h"
#undef INCLUDE_RUNTIME_H

#include "AsyncBehavior.h"

#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>


/*
 * Definitions of the strings used for selector mangling.
 */
#define SEL_MANGLE_NOBOX_STRING @"_DKNoBox_"
#define SEL_MANGLE_IFSTART_STRING @"_DKIf_"
#define SEL_MANGLE_IFEND_STRING @"_DKIfEnd_"

enum
{
  NO_TABLES,
  NO_CACHE,
  HAVE_CACHE
};

@interface DKProxy (DKProxyPrivate)

- (void)_setupTables;
- (DKMethod*)_methodForSelector: (SEL)aSelector
                          block: (BOOL)doBlock;
- (void)_buildMethodCache;
- (void)_installIntrospectionMethod;
- (void)_installMethod: (DKMethod*)aMethod
      inInterfaceNamed: (NSString*)anInterface
      forSelectorNamed: (NSString*)selName;

- (DKEndpoint*)_endpoint;
- (NSString*)_service;
- (NSString*)_path;
- (BOOL)_isLocal;
/* Define introspect on ourselves. */
- (NSString*)Introspect;
@end

#if HAVE_TOYDISPATCH == 1
static dispatch_queue_t cacheBuilderQueue;
#endif

static inline void
DKProxyBuildMethodCache(void* proxy);

@implementation DKProxy

+ (void)initialize
{
  if ([DKProxy class] == self)
  {
    ASYNC_INIT_QUEUE(cacheBuilderQueue, "DKProxy method cache generator queue");
    // Trigger generation of static introspection method:
    [DKMethod class];
  }

}

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
  tableLock = [[NSConditionLock alloc] initWithCondition: NO_TABLES];
  [self _setupTables];
  [self _installIntrospectionMethod];
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
  tableLock = [[NSConditionLock alloc] initWithCondition: NO_TABLES];
  [self _setupTables];
  [self _installIntrospectionMethod];
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
  DKMethod *method = [self _methodForSelector: aSelector
                                        block: YES];
  if (nil == method)
  {
    //Fall back to the untyped version
    method = [self _methodForSelector: sel_getUid(sel_getName(aSelector))
                                block: YES];
  }
  NSDebugMLog(@"Got method %@ (%@) for %p (%@)",
    method,
    [method name],
    aSelector,
    NSStringFromSelector(aSelector));
  if (nil != method)
  {
    return [method methodSignature];
  }

  return nil;
}

- (DKMethod*) _methodForSelector: (SEL)aSel
                           block: (BOOL)doBlock
{
  DKMethod *m = nil;

  if (nil != activeInterface)
  {
    // If an interface was marked active, try to find the selector there first
    // (the interface will perform its own locking).
    m = [activeInterface methodForSelector: aSel];
  }
  if (nil == m)
  {
    if (([@"Introspect" isEqualToString: NSStringFromSelector(aSel)])
      || (NO == doBlock))
    {
      // For the introspection selector, just lock the table because the
      // introspection selector has been installed on init time. Also, when
      // doBlock == NO, we won't wait for the correct state but simply lock the
      // table.
      [tableLock lock];
    }
    else if (doBlock)
    {
      // Else, we need to wait for the correct state to be signaled by the
      // caching thread.
      [tableLock lockWhenCondition: HAVE_CACHE];
    }
    m = NSMapGet(selectorToMethodMap, aSel);
    [tableLock unlock];
  }
  return m;
}
- (void)forwardInvocation: (NSInvocation*)inv
{
# if HAVE_TYPED_SELECTORS == 1
  SEL selector = [inv selector];
# else
  // If we cannot generate typed selectors, only test for the untyped version
  SEL selector = sel_getUid(sel_getName([inv selector]));
# endif

  NSMethodSignature *signature = [inv methodSignature];
  BOOL isBoxed = YES;
  DKMethod *method = [self _methodForSelector: selector
                                        block: NO];
  DKMethodCall *call = nil;


  if ((nil == method) && (HAVE_CACHE != [tableLock condition]))
  {
    /*
     * We retain ourselves once be cause we might build the cache in a separate
     * thread. The DKProxyBuildMethodCache() function will do the release.
     */
    [self retain];
    // Build method cache
    ASYNC_IF_POSSIBLE(cacheBuilderQueue, DKProxyBuildMethodCache, self);

    // This time, we will try to get the method an block until the cache has
    // been built
    method = [self _methodForSelector: selector
                                block: YES];
  }


  if (nil == method)
  {
    // Test whether this selector is already untyped:
    SEL newSel = sel_getUid(sel_getName(selector));
    if (sel_isEqual(newSel, selector))
    {
      // If so, we cannot do anything more:
      [NSException raise: @"DKInvalidArgumentException"
                  format: @"D-Bus object %@ for service %@ does not recognize %@",
        path,
        service,
       NSStringFromSelector(selector)];
    }
    //else, we can start again with the new selector
    [inv setSelector: newSel];
    [self forwardInvocation: inv];
  }

  if ([method isEqualToMethodSignature: signature
                                 boxed: YES])
  {
    isBoxed = YES;
  }
  else if ([method isEqualToMethodSignature: signature
                                      boxed: NO])
  {
    isBoxed = NO;
  }
  else
  {
    [NSException raise: @"DKInvalidArgumentException"
                format: @"D-Bus object %@ for service %@: Mismatched method signature.",
      path,
      service];
  }

  call = [[DKMethodCall alloc] initWithProxy: self
                                      method: method
                                  invocation: inv
                                      boxing: YES];

  //TODO: Implement asynchronous method calls using futures
  [call sendSynchronouslyAndWaitUntil: 0];
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

- (BOOL)_isLocal
{
  // True only for outgoing proxies representing local objects.
  return NO;
}
- (BOOL) hasSameScopeAs: (DKProxy*)aProxy
{
  BOOL sameService = [service isEqualToString: [aProxy _service]];
  BOOL sameEndpoint = [endpoint isEqual: [aProxy _endpoint]];
  return (sameService && sameEndpoint);
}

- (void)_installMethod: (DKMethod*)aMethod
           inInterface: (DKInterface*)anInterface
           forSelector: (SEL)aSel
{
  // NOTE: The caller is responsible for obtaining the tableLock
  if ((0 == aSel) || (nil == aMethod))
  {
    NSWarnMLog(@"Not inserting invalid selector/method pair.");
    return;
  }
  if (NULL != NSMapInsertIfAbsent(selectorToMethodMap, aSel, aMethod))
  {
    NSDebugMLog(@"Overloaded selector %@ for method %@",
      NSStringFromSelector(aSel),
      aMethod);
  }

  [anInterface installMethod: aMethod
                 forSelector: aSel];
  // NOTE: The caller is responsible for unlocking the tables.
}

- (void)_installMethod: (DKMethod*)aMethod
      inInterfaceNamed: (NSString*)anInterface
      forSelectorNamed: (NSString*)selName
{
  // NOTE: The caller is responsible for obtaining the tableLock
  DKInterface *theIf = [interfaces objectForKey: anInterface];

  const char* selectorString;
  SEL untypedSelector = 0;

# if HAVE_TYPED_SELECTORS == 1
  SEL typedBoxingSelector = 0;
  SEL typedNonBoxingSelector = 0;
  const char* boxedTypes = [aMethod objCTypesBoxed: YES];
  const char* nonBoxedTypes = [aMethod objCTypesBoxed: NO];
# endif

  if (nil == selName)
  {
    selectorString = [[aMethod name] UTF8String];
  }
  else
  {
    selectorString = [selName UTF8String];
  }

  if (NULL == selectorString)
  {
    NSWarnMLog(@"Cannot register selector with empty name for method %@");
    return;
  }

  untypedSelector = sel_registerName(selectorString);
  [self _installMethod: aMethod
           inInterface: theIf
	   forSelector: untypedSelector];
  NSDebugMLog(@"Registered %s as %p (untyped)",
    selectorString,
    untypedSelector);
# if HAVE_TYPED_SELECTORS == 1
  if (NULL == boxedTypes)
  {
    NSWarnMLog(@"Not registering typed selector for %@ (empty type string)",
      aMethod);
  }
  else
  {
    typedBoxingSelector = sel_registerTypedName_np(selectorString, boxedTypes);
    [self _installMethod: aMethod
             inInterface: theIf
             forSelector: typedBoxingSelector];
  NSDebugMLog(@"Registered %s as %p (%s)",
    selectorString,
    typedBoxingSelector,
    boxedTypes);
  }
  if (NULL == nonBoxedTypes)
  {
    NSWarnMLog(@"Not registering typed selector for %@ (empty type string)",
      aMethod);
  }
  else
  {
    typedNonBoxingSelector = sel_registerTypedName_np(selectorString, nonBoxedTypes);
    [self _installMethod: aMethod
             inInterface: theIf
             forSelector: typedNonBoxingSelector];
  NSDebugMLog(@"Registered %s as %p (%s)",
    selectorString,
    typedNonBoxingSelector,
    nonBoxedTypes);
  }
# endif
  // NOTE: The caller is responsible for unlocking the tables.
}

- (void) _installIntrospectionMethod
{
  if ([tableLock tryLockWhenCondition: NO_CACHE])
  {
    [self _installMethod: _DKMethodIntrospect
        inInterfaceNamed: nil
        forSelectorNamed: nil];
    [tableLock unlockWithCondition: NO_CACHE];
  }
}


- (void)_setupTables
{
  if ((nil == interfaces) || (NULL == selectorToMethodMap))
  {
    if ([tableLock tryLockWhenCondition: NO_TABLES])
    {
      if (nil == interfaces)
      {
	interfaces = [NSMutableDictionary new];
      }

      if (NULL == selectorToMethodMap)
      {
	selectorToMethodMap = NSCreateMapTable(NSIntMapKeyCallBacks,
	  NSObjectMapValueCallBacks,
	  10);
      }
      [tableLock unlockWithCondition: NO_CACHE];
    }
  }
}

- (void)_buildMethodCache
{
  NSString *introspectionXML = [self Introspect];
  NSDebugMLog(@"Building method cache for:\n%@", introspectionXML);
}
- (void) dealloc
{
  [endpoint release];
  [service release];
  [path release];
  [tableLock release];
  [interfaces release];
  [super dealloc];
}
@end

static inline void
DKProxyBuildMethodCache(void* proxy)
{
  DKProxy *p = (DKProxy*)proxy;
  NS_DURING
  {
    [p _buildMethodCache];
  }
  NS_HANDLER
  {
    [p release];
    [localException raise];
  }
  NS_ENDHANDLER

  // We did one extra retain to keep the proxy from going away while we build
  // the cache.
  [p release];
}
