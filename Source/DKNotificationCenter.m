/** DKNotificationCenter class to handle D-Bus signals.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: August 2010

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

#import "DBusKit/DKNotificationCenter.h"
#import "DBusKit/DKPort.h"
#import "DKInterface.h"
#import "DKSignal.h"
#import "DKProxy+Private.h"

#import "DKEndpoint.h"

#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <stdint.h>
#include <dbus/dbus.h>

@class DKObservation;

@interface DKObservable: NSObject
{
  /**
   * The rules that D-Bus is using to determine which signals to pass to
   * use.
   */
  NSDictionary *rules;
  /**
   * Set of all observation activities for the observable;
   */
  NSCountedSet *observations;
}
- (id)initWithRules: (NSDictionary*)rules;
- (void)addObservation: (DKObservation*)observation;
@end

@interface DKObservation: NSObject
{
  /**
   * The object that wants to watch the signal.
   * Note: In a GC environment, this ivar will not point to the object itself,
   * which hides it from the garbage collector.
   */
  id observer;

  /**
   * The selector specifying the selector to call back to.
   */
  SEL selector;

  /**
   * Pointer to the method implementation for the callback.
   */
  IMP method;

  /**
   * A pointer back to the information about the observed signal.
   */
  DKObservable *observed;
}

- (id)initWithObservable: (DKObservable*)observable
                observer: (id)observer
                selector: (SEL)selector;
@end

@implementation DKObservable

- (id)initWithRules: (NSDictionary*)someRules
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGN(rules,someRules);
  observations = [[NSCountedSet alloc] init];
  return self;
}

- (void)addObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil != oldObservation)
  {
    [observations addObject: oldObservation];
  }
  else
  {
    [observations addObject: observation];
  }
}

- (void)dealloc
{
  [rules release];
  [observations release];
  [super dealloc];
}
@end

@implementation DKObservation

- (id)initWithObservable: (DKObservable*)anObservable
                observer: (id)anObserver
                selector: (SEL)aSelector
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGN(observed, anObservable);
  observer = GS_GC_HIDE(anObserver);
  selector = aSelector;
  //TODO: IMP caching.
  return self;
}

- (NSUInteger)hash
{
  return (((NSUInteger)(uintptr_t)observer ^ (NSUInteger)selector) ^ [observed hash]);
}

- (void)dealloc
{
  [observed release];
  [super dealloc];
}
@end


static DKNotificationCenter *systemCenter;
static DKNotificationCenter *sessionCenter;

static DBusHandlerResult
DKHandleSignal(DBusConnection *connection, DBusMessage *msg, void *userData);

@interface DKNotificationCenter (DKNotificationCenterPrivate)
- (id)initWithBusType: (DKDBusBusType)type;
- (DKSignal*)_signalForNotificationName: (NSString*)name;
@end

@implementation DKNotificationCenter
+ (void)initialize
{
  if ([DKNotificationCenter class] == self)
  {
    systemCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSystemBus];
    sessionCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSessionBus];
  }
}

+ (id)allocWithZone: (NSZone*)zone
{
  if ((nil == systemCenter) || (nil == sessionCenter))
  {
    return [super allocWithZone: zone];
  }
  return nil;
}

+ (id)sessionBusCenter
{
  return [self centerForBusType: DKDBusSessionBus];
}

+ (id)systemBusCenter
{
  return [self centerForBusType: DKDBusSystemBus];
}

+ (id)centerForBusType: (DKDBusBusType)type
{
  DKNotificationCenter *center = nil;
  switch (type)
  {
    case DKDBusSystemBus:
      if (systemCenter == nil)
      {
	systemCenter = [[DKNotificationCenter alloc] initWithBusType: type];
      }
      center = systemCenter;
      break;
    case DKDBusSessionBus:
      if (sessionCenter == nil)
      {
	sessionCenter = [[DKNotificationCenter alloc] initWithBusType: type];
      }
      center = sessionCenter;
      break;
    default:
      break;
  }
  return center;
}

- (id)initWithBusType: (DKDBusBusType)type
{
  DKEndpoint *ep = nil;

  if (nil == (self = [super init]))
  {
    return nil;
  }
  ep = [[DKEndpoint alloc] initWithWellKnownBus: (DBusBusType)type];

  if (nil == ep)
  {
    [self release];
    return nil;
  }
  ASSIGN(endpoint,ep);
  [ep release];

  lock = [[NSLock alloc] init];
  signalInfo = [[NSMutableDictionary alloc] init];
  notificationNames = [[NSMutableDictionary alloc] init];

  observables = [[NSMutableSet alloc] init];
  observers = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    5);

  return self;
}


- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  //NSMutableDictionary *ruleDict = [NSMutableDictionary new];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }
  //ruleDict = [self _ruleDictionaryForSignal: signal];
  //TODO: Finish
  return;
}

-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              object: (DKProxy*)sender
   filtersAndIndices: (NSString*)firstFilter, NSUInteger firstindex, ...
{

}
- (void)removeObserver: (id)observer
{
}

- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                object: (DKProxy*)sender
{
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (DKProxy*)sender
{
}

- (void)postNotification: (NSNotification*)notification
{

}
- (void)postNotificationName: (NSString*)name
                      object: (id)sender
{
}

- (void)postSignalName: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (id)sender
{
}

- (void)postNotificationName: (NSString*)name
                      object: (id)sender
                    userInfo: (NSDictionary*)info
{
}

- (void)postSignalName: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (id)sender
              userInfo: (NSDictionary*)info
{

}

- (DKSignal*)_signalWithName: (NSString*)name
                 inInterface: (NSString*)interfaceName
{
  DKInterface *theInterface = nil;
  DKSignal *signal = nil;
  [lock lock];
  theInterface = [signalInfo objectForKey: interfaceName];

  // Add the interface if necessary:
  if (theInterface == nil)
  {
    DKInterface *stubIf = [[DKInterface alloc] initWithName: interfaceName
                                                     parent: nil];
    [signalInfo setObject: stubIf
                   forKey: interfaceName];
    theInterface = stubIf;
    [stubIf release];
  }

  if (nil != (signal = [[theInterface signals] objectForKey: name]))
  {
    [lock unlock];
    //Don't generate new stubs for signals we already have.
    return signal;
  }
  signal = [[[DKSignal alloc] initWithName: name
                                    parent: theInterface] autorelease];
  [signal setAnnotationValue: @"YES"
                      forKey: @"org.gnustep.dbuskit.signal.stub"];

  [theInterface addSignal: signal];
  [lock unlock];
  return signal;
}

- (DKSignal*)_signalForNotificationName: (NSString*)name
{
  DKSignal *signal = [notificationNames objectForKey: name];
  if (nil != signal)
  {
    return signal;
  }
  else if (([name hasPrefix: @"DKSignal_"]) && ([name length] >= 9))
  {
    NSString *stripped = [name substringFromIndex: 9];
    NSUInteger len = [stripped length];
    NSRange sepRange = [stripped rangeOfString: @"_"];
    NSString *ifName = nil;
    NSString *signalName = nil;
    // Don't continue if the separator was not found or appeared at the begining
    // or end of the string:
    if ((NSNotFound == sepRange.location)
      || (len == (sepRange.location + 1))
      || (0 == sepRange.location))
    {
      return nil;
    }
    ifName = [stripped substringToIndex: (sepRange.location - 1)];
    signalName = [stripped substringFromIndex: (sepRange.location + 1)];
    return [self _signalWithName: signalName
                     inInterface: ifName];
  }
  return nil;
}

- (BOOL)_registerNotificationName: (NSString*)notificationName
                         asSignal: (DKSignal*)signal
{
  if ((nil == notificationName) || (nil == signal));
  {
    return NO;
  }

  if (nil == [notificationNames objectForKey: notificationName])
  {
    [notificationNames setObject: signal
                          forKey: notificationName];

    NSDebugMLog(@"Registered signal '%@' (from interface '%@') with notification name '%@'.",
      [signal name],
      [[signal parent] name],
      notificationName);
    return YES;
  }
  else
  {
    NSDebugMLog(@"Cannot register signal '%@' (from interface '%@') with notification name '%@' (already registered).",
      [signal name],
      [[signal parent] name],
      notificationName);
  }
  return NO;
}

- (BOOL)registerNotificationName: (NSString*)notificationName
                        asSignal: (NSString*)signalName
                     inInterface: (NSString*)interface
{
  DKSignal *signal = nil;
  BOOL success = NO;
  if (notificationName == nil)
  {
    return NO;
  }
  [lock lock];
  signal = [[[signalInfo objectForKey: interface] signals] objectForKey: signalName];
  if (nil == signal)
  {
    signal = [self _signalWithName: signalName
                       inInterface: interface];
  }
  if (nil == signal)
  {
    return NO;
  }
  success = [self _registerNotificationName: notificationName
                                   asSignal: signal];
  [lock unlock];
  return success;
}

- (void)_registerSignal: (DKSignal*)aSignal
{
  NSString *interfaceName = [[aSignal parent] name];
  NSString *signalName = [aSignal name];
  NSString *notificationName = [aSignal notificationName];
  DKInterface *theInterface = nil;
  DKSignal *theSignal = nil;
  [lock lock];
  theInterface = [signalInfo objectForKey: interfaceName];

  // Add the interface if necessary:
  if (theInterface == nil)
  {
    DKInterface *stubIf = [[DKInterface alloc] initWithName: interfaceName
                                                     parent: nil];
    [signalInfo setObject: stubIf
                   forKey: interfaceName];
    theInterface = stubIf;
    [stubIf release];
  }

  // Get the signal:
  theSignal = [[theInterface signals] objectForKey: signalName];

  // Check whether the notification center itself did add a stub for this signal.
  if ([[theSignal annotationValueForKey: @"org.gnustep.dbuskit.signal.stub"] boolValue])
  {
    [theInterface removeSignalNamed: signalName];
    theSignal = nil;
  }

  // Add the signal if necessary
  if (nil == theSignal)
  {
    theSignal = [aSignal copy];
    [theInterface addSignal: theSignal];
    [theSignal setParent: theInterface];
    if (nil != notificationName)
    {
      [self _registerNotificationName: notificationName
                             asSignal: theSignal];
    }
    NSDebugMLog(@"Registered signal '%@' (interface: '%@') in notification center.",
      [theSignal name],
      [theInterface name]);
    [theSignal release];
  }

  [lock unlock];
}

/**
 * Installs a handler on the D-Bus connection to catch signals once there are
 * active observation activities.
 */
- (void)_installHandler
{
  NSDebugMLog(@"Started monitoring for D-Bus signals.");
  dbus_connection_add_filter([endpoint DBusConnection],
    DKHandleSignal,
    (void*)self,
    NULL); // the notification center is static, we'd never actually free it
}

/**
 * Removes the handler from the D-Bus connection once all observation activities
 * have ceased.
 */
- (void)_removeHandler
{
  NSDebugMLog(@"Stopped monitoring for D-Bus signals.");
  dbus_connection_remove_filter([endpoint DBusConnection],
    DKHandleSignal,
    (void*)self);
}

- (NSDictionary*)_ruleDictionaryForSignal: (DKSignal*)aSignal
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"signal", @"type", nil];
  NSString *signalName = [aSignal name];
  NSString *ifName = [[aSignal parent] name];
  NSDictionary *returnDict = nil;
  if (nil != signalName)
  {
    [dict setObject: signalName
             forKey: @"member"];
  }
  if (nil != ifName)
  {
    [dict setObject: ifName
             forKey: @"interface"];
  }
  returnDict = [[dict copy] autorelease];
  [dict release];
  return returnDict;
}

-  (void)_addMatch: (NSString*)match
forArgumentAtIndex: (NSUInteger)index
  toRuleDictionary: (NSMutableDictionary*)rules
{
  if (index < 64)
  {
    if ((nil == match) || [match isEqual: [NSNull null]])
    {
      match = @"";
    }
    [rules setObject: match
              forKey: [NSString stringWithFormat: @"arg%lu", index]];
  }
}

- (void)_addMatchForSender: (DKProxy*)proxy
          toRuleDictionary: (NSMutableDictionary*)dict
{
  [dict setObject: [proxy _service]
           forKey: @"sender"];
  [dict setObject: [proxy _path]
           forKey: @"path"];
}


- (void)_addMatchForDestination: (DKProxy*)proxy
               toRuleDictionary: (NSMutableDictionary*)dict
{
  NSString *uniqueName = [proxy _uniqueName];
  if (nil != uniqueName)
  {
    [dict setObject: uniqueName
             forKey: @"destination"];
  }
}

- (NSString*)_ruleStringForRuleDictionary: (NSDictionary*)ruleDict
{
  NSEnumerator *keyEnum = [ruleDict keyEnumerator];
  NSString *key = nil;
  NSMutableString *string = [NSMutableString string];
  while (nil != (key = [keyEnum nextObject]))
  {
    NSString *value = [[ruleDict objectForKey: key] stringByReplacingOccurrencesOfString: @"'"
                                                                              withString: @"\\'"];
    [string appendFormat: @"%@='%@'", key, value];
  }
  return string;
}

- (void)dealloc
{
  [endpoint release];
  [signalInfo release];
  [notificationNames release];
  // TODO: Free the dispatch tables!
  [lock release];
  [super dealloc];
}
- (NSUInteger)retainCount
{
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (id)autorelease
{
  return self;
}

- (void)release
{
  // No-Op.
}
@end

static DBusHandlerResult
DKHandleSignal (DBusConnection *connection, DBusMessage *msg, void *userData)
{
  if (DBUS_MESSAGE_TYPE_SIGNAL != dbus_message_get_type(msg))
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }
  NSLog(@"Handling signal!");
  return DBUS_HANDLER_RESULT_HANDLED;
}
