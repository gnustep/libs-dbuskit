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
#import <Foundation/NSException.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <stdint.h>
#include <stdarg.h>
#include <dbus/dbus.h>

@class DKObservation;

@interface DKObservable: NSObject
{
  /**
   * The rules that D-Bus is using to determine which signals to pass to
   * use.
   */
  NSMutableDictionary *rules;
  /**
   * Set of all observation activities for the observable;
   */
  NSHashTable *observations;
}
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

- (id)init
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  // We always observe signals:
  rules = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"signal", @"type", nil];
  observations = [NSHashTable hashTableWithWeakObjects];
  return self;
}

- (void)addObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil == oldObservation)
  {
    [observations addObject: observation];
  }
}

- (void)removeObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil != oldObservation)
  {
    [observations removeObject: oldObservation];
  }
}

- (void)setValue: (NSString*)value
          forKey: (NSString*)key
{
  if (nil == key)
  {
    return;
  }
  if (nil != value)
  {
    [rules setObject: value
              forKey: key];
  }
  else
  {
    [rules removeObjectForKey: key];
  }
}

- (id)valueForKey: (NSString*)key
{
  return [rules objectForKey: key];
}

- (void)filterInterface: (NSString*)interface
{
  [self setValue: interface
          forKey: @"interface"];
}

- (void)filterSignalName: (NSString*)signalName
{
  [self setValue: signalName
          forKey: @"member"];
}

- (void)filterSignal: (DKSignal*)signal
{
  [self filterSignalName: [signal name]];
  [self filterInterface: [[signal parent] name]];
}

-  (void)filterValue: (NSString*)match
  forArgumentAtIndex: (NSUInteger)index
{
  if (index < 64)
  {
    if ((nil == match) || [match isEqual: [NSNull null]])
    {
      match = @"";
    }
    [self setValue: match
            forKey: [NSString stringWithFormat: @"arg%lu", index]];
  }
}

- (void)filterSender: (DKProxy*)proxy
{
  [self setValue: [proxy _service]
          forKey: @"sender"];
  [self setValue: [proxy _path]
          forKey: @"path"];
}


- (void)filterDestination: (DKProxy*)proxy
{
  NSString *uniqueName = [proxy _uniqueName];
  [self setValue: uniqueName
          forKey: @"destination"];
}

- (NSString*)ruleString
{
  NSEnumerator *keyEnum = [rules keyEnumerator];
  NSString *key = nil;
  NSMutableString *string = [NSMutableString string];
  NSUInteger count = 0;
  while (nil != (key = [keyEnum nextObject]))
  {
    NSString *value = [[rules objectForKey: key] stringByReplacingOccurrencesOfString: @"'"
                                                                           withString: @"\\'"];
    if (count != 0)
    {
      [string appendString: @","];
    }
    [string appendFormat: @"%@='%@'", key, value];
    count++;
  }
  return string;
}

- (NSUInteger)hash
{
  return [rules hash];
}

- (NSDictionary*)rules
{
  return [[rules copy] autorelease];
}
- (BOOL)isEqual: (DKObservable*)other
{
  return [rules isEqualToDictionary: [other rules]];
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

- (id)observer
{
  return GS_GC_UNHIDE(observer);
}

- (SEL)selector
{
  return selector;
}

- (DKObservable*)observed
{
  return observed;
}

- (NSUInteger)hash
{
  return (((NSUInteger)(uintptr_t)observer ^ (NSUInteger)selector) ^ [observed hash]);
}

- (BOOL)isEqual: (DKObservation*)other
{
  BOOL sameObserver = (observer == [other observer]);
  BOOL sameSelector = sel_isEqual(selector, [other selector]);
  BOOL sameObserved = [observed isEqual: [other observed]];
  return ((sameObserver && sameSelector) && sameObserved);
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
- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector;
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

  observables = NSCreateHashTable(NSObjectHashCallBacks, 5);
  observers = [NSMapTable mapTableWithWeakToStrongObjects];

  return self;
}


- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  DKObservable *observable = [[DKObservable alloc] init];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }
  [observable filterSignal: signal];
  [observable filterSender: sender];
  NS_DURING
  {
    [self _letObserver: observer
     observeObservable: observable
          withSelector: notifySelector];
  }
  NS_HANDLER
  {
    [observable release];
    [localException raise];
  }
  NS_ENDHANDLER
  [observable release];
}

- (DKObservable*)_observableForSignalName: (NSString*)signalName
                                interface: (NSString*)interfaceName
                                   sender: (DKProxy*)sender
                              destination: (DKProxy*)destination
{
  DKObservable *observable = [[[DKObservable alloc] init] autorelease];
  [observable filterSignalName: signalName];
  [observable filterInterface: interfaceName];
  [observable filterSender: sender];
  [observable filterDestination: destination];
  return observable;
}

-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
              filter: (NSString*)filter
	     atIndex: (NSUInteger)index
{
  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination];
  if (filter != nil)
  {
    [observable filterValue: filter
         forArgumentAtIndex: index];
  }
  [self _letObserver: observer
   observeObservable: observable
        withSelector: notifySelector];
}
-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
{
  [self addObserver: observer
           selector: notifySelector
             signal: signalName
          interface: interfaceName
             sender: sender
        destination: destination
             filter: nil
             atIndex: 0];
}

-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
   filtersAndIndices: (NSString*)firstFilter, NSUInteger nullIndex, ...
{
  va_list filters;
  uintptr_t filterOrIndex = 0;
  NSUInteger count = 1;
  NSString *thisFilter = nil;

  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination];
  [observable filterValue: firstFilter
       forArgumentAtIndex: nullIndex];

  va_start(filters, nullIndex);
  while (0 != (filterOrIndex = va_arg(filters, uintptr_t)))
  {
    if (0 == count)
    {
      thisFilter = (NSString*)filterOrIndex;
      count++;
    }
    else if (1 == count)
    {
      [observable filterValue: thisFilter
           forArgumentAtIndex: (NSUInteger)filterOrIndex];
      count = 0;
    }
  }
  va_end(filters);

  [self _letObserver: observer
   observeObservable: observable
        withSelector: notifySelector];
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

- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector
{
  DKObservation *observation = [[DKObservation alloc] initWithObservable: observable
                                                                observer: observer
                                                                selector: selector];
  DBusError err;
  dbus_error_init(&err);
  dbus_bus_add_match([endpoint DBusConnection],
    [[observable ruleString] UTF8String],
    &err);

  if (dbus_error_is_set(&err))
  {
    [observation release];
    [NSException raise: @"DKSignalMatchException"
                format: @"Error when trying to add match for signal: %s. (%s)",
      err.name, err.message];
  }
  NSHashInsertIfAbsent(observables, (const void*)observable);
  [observable addObservation: observation];
  NSMapInsertIfAbsent(observers, observer, observation);
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
