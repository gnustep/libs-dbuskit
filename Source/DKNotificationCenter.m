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
#import "DKArgument.h"
#import "DKInterface.h"
#import "DKSignal.h"
#import "DKProxy+Private.h"

#import "DKEndpoint.h"
#import "DKEndpointManager.h"

#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <stdint.h>
#include <stdarg.h>
#include <sched.h>
#include <dbus/dbus.h>

@class DKObservation;

/**
 * DKObservable encapsulates information about a specific signal configuration
 * that is being observed by an object. It contains a match rule for userInfo
 * dictionaries created from signals and managed the observers for the signal.
 */
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

  /**
   * Specifies whether the observable is watching for changes in the owner of a
   * name. This is required to prevent an infinite loop, because observables
   * might be created when removing an observation activity.
   */
  BOOL isWatchingNameChanges;
  /**
   * The bus-type that should be used when making queries to the D-Bus object.
   */
   DKDBusBusType type;
}

- (void)addObservation: (DKObservation*)observation;
@end

/**
 * DKObservation modells the fact that an <ivar>observer</ivar> is watching for
 * a specific <ivar>observable</ivar> and wants to be notified by calling the
 * <ivar>selector</ivar> specified.
 */
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
}

/**
 * Creates an observation for the given observable.
 */
- (id)initWithObserver: (id)observer
              selector: (SEL)selector;

/**
 * Schedules the delivery of the notification on the current run loop.
 */
- (void)notifyWithNotification: (NSNotification*)notification;

/**
 * Returns the observer which will be notified by this notification.
 */
- (id)observer;
@end

@implementation DKObservable

- (id)initWithBusType: (DKDBusBusType)aType;
{
  NSPointerFunctionsOptions strongObjectOptions =
    (NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory);
  if (nil == (self = [super init]))
  {
    return nil;
  }
  // We always observe signals:
  type = aType;
  rules = [[NSMutableDictionary alloc] initWithObjectsAndKeys: @"signal", @"type", nil];
  observations = [[NSHashTable alloc] initWithOptions: strongObjectOptions
                                             capacity: 5];
  return self;
}

/**
 * Adds a DKObservation (i.e. observer/selector-pair.) to the observable.
 * Whenever a signal matching the observable is received, the corresponding
 * notification will be delivered to the observation.
 */
- (void)addObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = nil;
  if (nil == observation)
  {
    return;
  }
  if (NO == [observation isKindOfClass: [DKObservation class]])
  {
    return;
  }
  oldObservation = [observations member: observation];
  if (nil == oldObservation)
  {
    [observations addObject: observation];
  }
}

/**
 * Removes the observation from the table.
 */
- (void)removeObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil != oldObservation)
  {
    [observations removeObject: oldObservation];
  }
}

/**
 * Removes all observations for the given observer.
 */
- (void)removeObservationsForObserver: (id)observer
{
  NSHashEnumerator theEnum = NSEnumerateHashTable(observations);
  // Construct a table to hold the observables to remove because we can't modify
  // the table while enumerating.
  NSHashTable *removeTable = [[NSHashTable alloc] initWithOptions: (NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory)
                                                         capacity: 10];
  DKObservation *thisObservation = nil;
  NS_DURING
  {
    while (nil != (thisObservation = NSNextHashEnumeratorItem(&theEnum)))
    {
      if (observer == [thisObservation observer])
      {
        NSHashInsert(removeTable,thisObservation);
      }
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&theEnum);
    NS_DURING
    {
      [observations minusHashTable: removeTable];
    }
    NS_HANDLER
    {
      [removeTable release];
      [localException raise];
    }
    NS_ENDHANDLER
    [removeTable release];
    [localException raise];
  }
  NS_ENDHANDLER
  NSEndHashTableEnumeration(&theEnum);
  NS_DURING
  {
    [observations minusHashTable: removeTable];
  }
  NS_HANDLER
  {
    [removeTable release];
    [localException raise];
  }
  NS_ENDHANDLER
  [removeTable release];
}

/**
 * Deliver <var>notification</var> to all registered observers.
 */
- (void)notifyWithNotification: (NSNotification*)notification
{
  NSHashEnumerator obsEnum = NSEnumerateHashTable(observations);
  DKObservation *thisObservation = nil;
  while (nil != (thisObservation = NSNextHashEnumeratorItem(&obsEnum)))
  {
    [thisObservation notifyWithNotification: notification];
  }
  NSEndHashTableEnumeration(&obsEnum);
}

/**
 * Sets a key in the rule dictionary.
 */
- (void)setRule: (NSString*)value
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

/**
 * Retrieves a specific rule.
 */
- (id)ruleForKey: (NSString*)key
{
  return [rules objectForKey: key];
}

/**
 * Adds a filter rule for a D-Bus interface (e.g.
 * <code>org.freedesktop.DBus</code>.
 */
- (void)filterInterface: (NSString*)interface
{
  [self setRule: interface
         forKey: @"interface"];
}

/**
 * Adds a filter rule of a D-Bus signal name (e.g.
 * <code>NameOwnerChanged</code>.
 */
- (void)filterSignalName: (NSString*)signalName
{
  [self setRule: signalName
         forKey: @"member"];
}

/**
 * Adds a filter rule matching <var>signal</var>.
 */
- (void)filterSignal: (DKSignal*)signal
{
  [self filterSignalName: [signal name]];
  [self filterInterface: [[signal parent] name]];
}

/**
 * Adds a filter rule for the string argument at <var>index</var>. The
 * observable will only match if <var>match</var> is equal to the value of the
 * argument.
 */
-  (void)filterValue: (NSString*)match
  forArgumentAtIndex: (NSUInteger)index
{
  if (index < 64)
  {
    if ((nil == match) || [match isEqual: [NSNull null]])
    {
      match = @"";
    }
    [self setRule: match
           forKey: [NSString stringWithFormat: @"arg%lu", index]];
  }
}


/**
 * Called by the notification center when the unique name of the sender changes.
 */
- (void)nameChanged: (NSNotification*)notification
{
  NSString *newName = [[notification userInfo] objectForKey: @"arg2"];

  if (0 != [newName length])
  {
    [self setRule: newName
           forKey: @"sender"];
  }
}

/**
 * Adds a filter rule matching on the <var>proxy</var> object emitting the
 * signal.
 */
- (void)filterSender: (DKProxy*)proxy
{
  if (nil == proxy)
  {
    return;
  }
  // We need to put the unique name here to avoid reentrancy when handling
  // signals.
  [self setRule: [proxy _uniqueName]
         forKey: @"sender"];
  [self setRule: [proxy _path]
         forKey: @"path"];

  // To keep the name up to date we watch for NameOwnerChanged with the name
  // specified. (But don't do this for the bus object).
  if ([@"org.freedesktop.DBus" isEqualToString: [proxy _service]])
  {
    return;
  }
  [[DKNotificationCenter centerForBusType: type] addObserver: self
                                                    selector: @selector(nameChanged:)
                                                      signal: @"NameOwnerChanged"
                                                   interface: @"org.freedesktop.DBus"
                                                      sender: [DKDBus busWithBusType: type]
                                                 destination: nil
                                                      filter: [proxy _service]
                                                     atIndex: 0];
  isWatchingNameChanges = YES;
}

/**
 * Adds a filter rule for the destination <var>proxy</var> the signal is
 * intended for.
 */
- (void)filterDestination: (DKProxy*)proxy
{
  NSString *uniqueName = [proxy _uniqueName];
  [self setRule: uniqueName
         forKey: @"destination"];
}

/**
 * Generates a string suitable for use as a match rule in dbus_bus_add_match().
 */
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

/**
 * The observable is hashed by its <ivar>rules</ivar> dictionary.
 */
- (NSUInteger)hash
{
  return [rules hash];
}

/**
 * Return the rules dictionary for the observable.
 */
- (NSDictionary*)rules
{
  return [[rules copy] autorelease];
}

/**
 * Two observables are considered equal if they have the same set of
 * <ivar>rules</ivar>.
 */
- (BOOL)isEqual: (DKObservable*)other
{
  return [rules isEqualToDictionary: [other rules]];
}

/**
 * Returns a reference to the hash table of all observations in progress for
 * this observable.
 */
- (NSHashTable*)observations
{
  return observations;
}

- (NSUInteger)observationCount
{
  return NSCountHashTable(observations);
}
/**
 * Determine whether a given notification's userInfo dictionary will be matched
 * by the receiver. A userInfo dictionary will be considered to match a given
 * set of rules if every individual rule entry from <ivar>rules</ivar> is equal
 * to the corresponding value in <var>dict</var>.
 * Take for example the following rule set:
 * <example> {member = "NameOwnerChanged", interface="org.freedesktop.DBus",
 * arg0="org.foo.bar"} </example>
 * This will cause the value of the "member", "interface", and "arg0" keys of
 * the ruleset to be compared for equality with the values of the corresponding
 * keys in <var>dict</var>. If all comparisons succeed, <var>dict</var> will be
 * considered to  match <ivar>rules</ivar>, no matter what other keys are
 * present in the dictionary. E.g. the following dictionary would be a valid
 * match:
 * <example {member = "NameOwnerChanged", interface="org.freedesktop.DBus",
 * sender = "org.freedesktop.DBus", destination = ":1.139",  arg0="org.foo.bar",
 * arg1 = ":1.345", arg2=":1.139"} </example>
 */
- (BOOL)matchesUserInfo: (NSDictionary*)dict
{
  NSEnumerator *keyEnum = [rules keyEnumerator];
  NSString *thisKey = nil;
  while (nil != (thisKey = [keyEnum nextObject]))
  {
    NSString *thisRule = [rules objectForKey: thisKey];
    if ([@"type" isEqualToString: thisKey])
    {
      // We ignore the type, it's always 'signal'.
      continue;
    }

    if (nil != thisRule)
    {
      id thisValue = [dict objectForKey: thisKey];

      // For proxies we want to match the object paths:
      if ([thisValue conformsToProtocol: @protocol(DKObjectPathNode)])
      {
	thisValue = [(DKProxy*)thisValue _path];
      }

      // We only match string values.
      if (NO == [thisValue isKindOfClass: [NSString class]])
      {
	return NO;
      }

      // Complete matches only
      if (NO == [thisRule isEqualToString: (NSString*)thisValue])
      {
	return NO;
      }
    }
  }
  return YES;
}

- (void)dealloc
{
  if (isWatchingNameChanges)
  {
    [[DKNotificationCenter centerForBusType: type] removeObserver: self];
  }
  [rules release];
  [observations release];
  [super dealloc];
}
@end

@implementation DKObservation

- (id)initWithObserver: (id)anObserver
              selector: (SEL)aSelector
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  observer = GS_GC_HIDE(anObserver);
  selector = aSelector;

  // Make sure the necessary components are there and that the selector takes a
  // sane number of arguments.
  if (((anObserver == nil) || (selector == 0))
    || (3 != [[anObserver methodSignatureForSelector: selector] numberOfArguments]))
  {
    [self release];
    return nil;
  }
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

- (NSUInteger)hash
{
  return ((NSUInteger)(uintptr_t)observer ^ (uintptr_t)selector);
}

- (BOOL)isEqual: (DKObservation*)other
{
  BOOL sameObserver = (observer == [other observer]);
  BOOL sameSelector = sel_isEqual(selector, [other selector]);
  return (sameObserver && sameSelector);
}

- (void)notifyWithNotification: (NSNotification*)notification
{
  // We are still in the code path coming from libdbus' message handling
  // callback and need to avoid the reentrancy. We do this by scheduling
  // delivery of the notification on the run loop.
  [[NSRunLoop currentRunLoop] performSelector: selector
                                      target: GS_GC_UNHIDE(observer)
				    argument: notification
				       order: UINT_MAX
				       modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

- (void)dealloc
{
  [super dealloc];
}
@end



static DKNotificationCenter *systemCenter;
static DKNotificationCenter *sessionCenter;

/**
 * The result handling function called by libdbus. It is important to keep in
 * mind that we cannot do any D-Bus related stuff in the code path originating
 * from this function, because libdbus doesn't handle reentrancy very
 * gracefully.
 */
static DBusHandlerResult
DKHandleSignal(DBusConnection *connection, DBusMessage *msg, void *userData);

@interface DKNotificationCenter (DKNotificationCenterPrivate)
- (id)initWithBusType: (DKDBusBusType)type;

- (DKSignal*)_signalForNotificationName: (NSString*)name;

- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector;

- (void)_createObservation: (DKObservation*)observation
             forObservable: (DKObservable*)observable;

- (void)_removeObserver: (id)observer
          forObservable: (DKObservable*)observable;

- (DKObservable*)_observableForSignalName: (NSString*)signalName
                                interface: (NSString*)interfaceName
                                   sender: (DKProxy*)sender
                              destination: (DKProxy*)destination
                        filtersAndIndices: (NSString*)firstFilter, NSUInteger firstIndex, va_list filters;

- (void)_installHandler;

- (void)_removeHandler;
@end

static DKEndpointManager *manager;
@implementation DKNotificationCenter
+ (void)initialize
{
  if ([DKNotificationCenter class] == self)
  {
    manager = [DKEndpointManager sharedEndpointManager];
    [manager enterInitialize];
    systemCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSystemBus];
    sessionCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSessionBus];
    [manager leaveInitialize];
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
  if (nil == (self = [super init]))
  {
    return nil;
  }
  // Trigger initialization of the bus proxy:
  bus = [DKDBus busWithBusType: type];

  if (nil == bus)
  {
    [self release];
    return nil;
  }

  lock = [[NSRecursiveLock alloc] init];
  signalInfo = [[NSMutableDictionary alloc] init];
  notificationNames = [[NSMutableDictionary alloc] init];
  notificationNamesBySignal = [[NSMapTable alloc]initWithKeyOptions: NSPointerFunctionsObjectPersonality
                                                       valueOptions: NSPointerFunctionsObjectPersonality
                                                           capacity: 5];
  observables = NSCreateHashTable(NSObjectHashCallBacks, 5);

  // Install the observer for the Disconnected signal on the bus object. We need
  // to do that here, because DKNotificationCenter depends on the existance of
  // the bus object and doing it from the bus object would create a circular
  // dependency.
  [self addObserver: bus
           selector: @selector(_disconnected:)
	     signal: @"Disconnected"
	  interface: [NSString stringWithUTF8String: DBUS_INTERFACE_LOCAL]
	     sender: nil
	destination: nil];

  // Also trigger installation of the signals:
  [bus _registerSignalsWithNotificationCenter: self];
  return self;
}

// -addObserver:... methods on different granularities
- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     sender: (DKProxy*)sender
	destination: (DKProxy*)destination
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }

  [self addObserver: observer
           selector: notifySelector
             signal: [signal name]
          interface: [[signal parent] name]
             sender: sender
        destination: destination
  filtersAndIndices: nil, 0, nil];
}

- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }

  [self addObserver: observer
           selector: notifySelector
             signal: [signal name]
          interface: [[signal parent] name]
             sender: sender
        destination: nil
  filtersAndIndices: nil, 0, nil];
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
  filtersAndIndices: nil, 0, nil];
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
  [self addObserver: observer
           selector: notifySelector
             signal: signalName
          interface: interfaceName
             sender: sender
        destination: destination
  filtersAndIndices: filter, index, nil];
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
  DKObservable *observable = nil;
  va_start(filters, nullIndex);

  observable = [self _observableForSignalName: signalName
                                    interface: interfaceName
                                       sender: sender
                                  destination: destination
                            filtersAndIndices: firstFilter, nullIndex, filters];
  va_end(filters);

  [self _letObserver: observer
   observeObservable: observable
        withSelector: notifySelector];
}

// Observation removal methods on different levels of granularity:

- (void)removeObserver: (id)observer
{
  // Specify a match-all observable to catch all instances of the observer.
  [self removeObserver: observer
                signal: nil
             interface: nil
                sender: nil
           destination: nil
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot remove notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }
  [self removeObserver: observer
                signal: [signal name]
             interface: [[signal parent] name]
                sender: sender
           destination: destination
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                object: (DKProxy*)sender
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot remove notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }
  [self removeObserver: observer
                signal: [signal name]
             interface: [[signal parent] name]
                sender: sender
           destination: nil
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
{
  [self removeObserver: observer
                signal: signalName
             interface: interfaceName
                sender: sender
           destination: destination
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
	        filter: (NSString*)filter
    	       atIndex: (NSUInteger)index
{
  [self removeObserver: observer
                signal: signalName
             interface: interfaceName
                sender: sender
           destination: destination
     filtersAndIndices: filter, index, nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (DKProxy*)sender
{
  [self removeObserver: observer
                signal: signalName
             interface: interfaceName
                sender: sender
           destination: nil
     filtersAndIndices: nil, 0, nil];
}

-  (void)removeObserver: (id)observer
                 signal: (NSString*)signalName
              interface: (NSString*)interfaceName
                 sender: (DKProxy*)sender
            destination: (DKProxy*)destination
      filtersAndIndices: (NSString*)firstFilter, NSUInteger nullIndex, ...
{
  va_list filters;
  DKObservable *observable = nil;
  va_start(filters, nullIndex);

 observable = [self _observableForSignalName: signalName
                                   interface: interfaceName
                                      sender: sender
                                 destination: destination
                           filtersAndIndices: firstFilter, nullIndex, filters];
  va_end(filters);

  [self _removeObserver: observer
          forObservable: observable];
}

// Observation management methods doing the actual work:

/**
 * Create an observable matching the information specified. The va_start and
 * va_end calls for <var>filters</var> should be done by calling code.
 */
- (DKObservable*)_observableForSignalName: (NSString*)signalName
                                interface: (NSString*)interfaceName
                                   sender: (DKProxy*)sender
                              destination: (DKProxy*)destination
                        filtersAndIndices: (NSString*)firstFilter, NSUInteger firstIndex, va_list filters
{
  int thisIndex = 0;
  NSString *thisFilter = nil;
  BOOL processNextFilter = NO;
  DKObservable *observable = [[[DKObservable alloc] initWithBusType: [[bus _endpoint] DBusBusType]] autorelease];

  [observable filterSignalName: signalName];
  [observable filterInterface: interfaceName];
  [observable filterSender: sender];
  [observable filterDestination: destination];
  if (firstFilter != nil)
  {
    [observable filterValue: firstFilter
         forArgumentAtIndex: firstIndex];
  }

  do
  {
    thisFilter = va_arg(filters, id);
    if (thisFilter != nil)
    {
      thisIndex = va_arg(filters, int);
    }

    if ((thisFilter != nil) && (thisIndex != 0))
    {
      [observable filterValue: thisFilter
           forArgumentAtIndex: thisIndex];
      processNextFilter = YES;
    }
    else
    {
      processNextFilter = NO;
    }
  } while (processNextFilter);
  return observable;
}

/**
 * Return an array of all observables that will match for <var>userInfo</var>.
 */
- (NSArray*)_observablesMatchingUserInfo: (NSDictionary*)userInfo
{
  NSHashEnumerator obsEnum;
  DKObservable *thisObservable = nil;
  NSMutableArray *array = nil;
  [lock lock];
  NS_DURING
  {
    obsEnum = NSEnumerateHashTable(observables);
    while (nil != (thisObservable = NSNextHashEnumeratorItem(&obsEnum)))
    {
      if ([thisObservable matchesUserInfo: userInfo])
      {
	if (nil == array)
	{
	  array = [NSMutableArray array];
	}
	[array addObject: thisObservable];
      }
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&obsEnum);
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  NSEndHashTableEnumeration(&obsEnum);
  [lock unlock];
  return array;
}

- (void) _createObservationForDictionary: (NSDictionary*)dict
{
  // We obtain the (recursive lock) in order to make sure that we will succeed
  // in inserting the observation.
  if (NO == [lock tryLock])
  {
    // if we could not obtain the lock, try again:
    [manager boolReturnForPerformingSelector: @selector(_createObservationForDictionary:)
                                      target: self
                                        data: (void*)dict
                               waitForReturn: NO];
    return;
  }
  // we still have the (recursive) lock:
  [self _createObservation: [dict objectForKey: @"observation"]
             forObservable: [dict objectForKey: @"observable"]];

  // Release the dictionary, it is not needed any more
  [dict release];
  // Cast to void to suppress warning
  (void)__sync_fetch_and_sub(&queueCount, 1);
  [lock unlock];
}

/**
 * Schedules creation of the observation:
 */
- (void)_enqueueObservation: (DKObservation*)observation
              forObservable: (DKObservable*)observable
{
  NSDictionary *obsDict = nil;
  if ((nil == observation) || (nil == observable))
  {
    return;
  }
  /*
   * The dictionary is created with a retain count of 1 because it needs to
   * survive the trip through the ring buffer.
   */
  obsDict = [[NSDictionary alloc] initWithObjectsAndKeys: observation, @"observation",
    observable, @"observable", nil];
  // Cast to void to suppress "value computed is not used"-warning:
  (void)__sync_fetch_and_add(&queueCount, 1);

  // Retain the dictionary so that it doesn't go away while in the ring-buffer.
  [manager boolReturnForPerformingSelector: @selector(_createObservationForDictionary:)
                                    target: self
                                      data: (void*)obsDict
                             waitForReturn: NO];
}

- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector
{
  DKObservation *observation = [[[DKObservation alloc] initWithObserver: observer
                                                               selector:
							       selector] autorelease];
  [self _createObservation: observation
             forObservable: observable];
}

/**
 * Installs the necessary entries for observables and observations in the
 * respective tables and adds the D-Bus match rule if necessary.
 */
- (void)_createObservation: (DKObservation*)observation
             forObservable: (DKObservable*)observable
{
  DKObservable *oldObservable = nil;
  BOOL firstObservation = NO;
  if (NO == [bus _isConnected])
  {
    return;
  }

  if (NO == [lock tryLock])
  {

    // If we could not obtain the lock, we schedule creation of the observation.
    [self _enqueueObservation: observation
                forObservable: observable];
    return;

  }

  NS_DURING
  {
    firstObservation = (0 == NSCountHashTable(observables));
    if (firstObservation)
    {
      [self _installHandler];
    }

    oldObservable = NSHashInsertIfAbsent(observables, (const void*)observable);

    if (nil != oldObservable)
    {
      // Use the prexisting observable if possible:
      observable = oldObservable;
    }
    else
    {
      [(id<DKDBusStub>)bus AddMatch: [observable ruleString]];
    }
    [observable addObservation: observation];
  }
  NS_HANDLER
  {
    if (firstObservation)
    {
      [self _removeHandler];
    }
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  [lock unlock];
}

/**
 * Removes the observer/observable combination from all tables it appears in.
 * Also removes match rules and handlers if necessary.
 */
- (void)_removeObserver: (id)observer
          forObservable: (DKObservable*)observable
{
  NSHashEnumerator observableEnum;
  NSHashEnumerator cleanupEnum;
  NSHashTable *cleanupTable = NSCreateHashTable(NSObjectHashCallBacks, 10);
  NSUInteger initialCount = 0;
  NSUInteger iteration = 0;
  if (nil == observable)
  {
    return;
  }

  /*
   * We need for the insertion queue to drain prior to removing the observation.
   * Otherwise insert-remove sequences might be reordered and notifications
   * might go to observers that have long been deallocated.
   */
  while (queueCount)
  {
    if ((++iteration % 16) == 0)
    {
      sched_yield();
    }
  }


  [lock lock];
  // Count the table so we know how many observables there were before we
  // started removing stuff.

  initialCount = NSCountHashTable(observables);

  /*
   * First stage of cleanup: Remove references to the observation from the
   * observables that will be matched by the one specified.
   */
  NS_DURING
  {
    DKObservable *thisObservable = nil;
    SEL matchSel = @selector(matchesUserInfo:);
    IMP matchesUserInfo = [observable methodForSelector: matchSel];
    SEL ruleSel = @selector(rules);
    IMP getRules = [observable methodForSelector: ruleSel];
    observableEnum = NSEnumerateHashTable(observables);

    while (nil != (thisObservable = NSNextHashEnumeratorItem(&observableEnum)))
    {
      NSDictionary *rules = getRules(thisObservable, ruleSel);
      if ((BOOL)(uintptr_t)matchesUserInfo(observable, matchSel, rules))
      {
        [thisObservable removeObservationsForObserver: observer];
	// If we removed the last observation, add the observable to the cleanup
	// table because we cannot modify the table we are enumerating.
	if (0 == ([thisObservable observationCount]))
	{
	  NSHashInsertIfAbsent(cleanupTable, thisObservable);
	}
      }
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&observableEnum);
    [cleanupTable release];
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  NSEndHashTableEnumeration(&observableEnum);

  /*
   * Second stage of cleanup: If we left an empty observable, remove it and the
   * corresponding match rule.
   */
  NS_DURING
  {
    DKObservable *thisObservable = nil;
    cleanupEnum = NSEnumerateHashTable(cleanupTable);
    while(nil != (thisObservable = NSNextHashEnumeratorItem(&cleanupEnum)))
    {
      /*
       * NOTE: We don't really care if removing the match rule fails. Once we
       * waive all references to the observable, we will just ignore the
       * callbacks libdbus generates for the match rule.
       */
      NS_DURING
      {
        [(id<DKDBusStub>)bus RemoveMatch: [thisObservable ruleString]];
      }
      NS_HANDLER
      {
	NSWarnMLog(@"Could not remove match rule from D-Bus: %@", localException);
      }
      NS_ENDHANDLER
      NSHashRemove(observables, thisObservable);
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&cleanupEnum);
    [cleanupTable release];
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  NSEndHashTableEnumeration(&cleanupEnum);
  [cleanupTable release];
  /*
   * Third stage of cleanup: If we have no observables left, also remove the
   * D-Bus message handler until we have further signals to watch.
   */
  if (0 == NSCountHashTable(observables) && (0 != initialCount))
  {
    [self _removeHandler];
  }
  [lock unlock];
}


// Notification posting methods:
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


/**
 * Tries to find a preexisting signal specification and creates a stub signal if
 * none exists.
 */
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

/**
 * Retrieves the signal for the notification. If the signal did not yet exist,
 * it might be created as a stub signal.
 */
- (DKSignal*)_signalForNotificationName: (NSString*)name
{
  DKSignal *signal = nil;
  [lock lock];
  signal = [notificationNames objectForKey: name];
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
      [lock unlock];
      return nil;
    }
    ifName = [stripped substringToIndex: (sepRange.location - 1)];
    signalName = [stripped substringFromIndex: (sepRange.location + 1)];
    [lock unlock];
    return [self _signalWithName: signalName
                     inInterface: ifName];
  }
  [lock unlock];
  return nil;
}

/**
 * Retrieves the notification name for the signal. This is either the name
 * specified in an annotation or the default name.
 */
- (NSString*)_notificationNameForSignal: (DKSignal*)signal
{
  NSString *name = nil;
  [lock lock];
  name = NSMapGet(notificationNamesBySignal, signal);
  if (nil != name)
  {
    [lock unlock];
    return name;
  }
  [lock unlock];
  return [NSString stringWithFormat: @"DKSignal_%@_%@",
    [[signal parent] name], [signal name]];
}

/**
 * Registers the <var>signal</var> under the <var>notificationName</var>.
 */
- (BOOL)_registerNotificationName: (NSString*)notificationName
                         asSignal: (DKSignal*)signal
{
  BOOL retVal = NO;
  if ((nil == notificationName) || (nil == signal))
  {
    return retVal;
  }
  [lock lock];
  NS_DURING
  {
    if (nil == [notificationNames objectForKey: notificationName])
    {
      [notificationNames setObject: signal
                            forKey: notificationName];

      NSDebugMLog(@"Registered signal '%@' (from interface '%@') with notification name '%@'.",
        [signal name],
        [[signal parent] name],
        notificationName);
      NS_DURING
      {
        NSMapInsertIfAbsent(notificationNamesBySignal, signal, notificationName);
      }
      NS_HANDLER
      {
	//Roll-back:
	[notificationNames removeObjectForKey: notificationName];
	[localException raise];
      }
      NS_ENDHANDLER
      [lock unlock];
      retVal = YES;
    }
    else
    {
      NSDebugMLog(@"Cannot register signal '%@' (from interface '%@') with notification name '%@' (already registered).",
        [signal name],
        [[signal parent] name],
        notificationName);
    }
  }
  NS_HANDLER
  {
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [lock unlock];
  return retVal;
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

/**
 * Register a signal with its default name.
 */
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
  if ([theSignal isStub])
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
  if (NO == [bus _isConnected])
  {
    return;
  }
  NSDebugMLog(@"Started monitoring for D-Bus signals.");
  dbus_connection_add_filter([[bus _endpoint] DBusConnection],
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
  if (NO == [bus _isConnected])
  {
    return;
  }
  NSDebugMLog(@"Stopped monitoring for D-Bus signals.");
  dbus_connection_remove_filter([[bus _endpoint] DBusConnection],
    DKHandleSignal,
    (void*)self);
}

/**
 * This method will be called from the runloop and will replace the standins with
 * an actual proxies before sending out the notification.
 */
- (void)_fixupProxyAndNotify: (NSDictionary*)infoDict
{
  DKSignal *signal = [infoDict objectForKey: @"signal"];
  DKProxyStandin *standin = [infoDict objectForKey: @"standin"];
  NSDictionary *userInfo = [infoDict objectForKey: @"userInfo"];
  NSMutableDictionary *fixedInfo = [NSMutableDictionary dictionary];
  NSNotification  *notification = nil;
  DKProxy *senderProxy = (NO == [[NSNull null] isEqual: standin]) ? (id)[standin proxy] : nil ;
  NSArray *matchingObservables = [infoDict objectForKey: @"matches"];
  NSEnumerator *userInfoEnum = [userInfo keyEnumerator];
  NSString *key = nil;

  //Fixup the userInfo:
  while (nil != (key = [userInfoEnum nextObject]))
  {
    id object = [userInfo objectForKey: key];
    if ([object isKindOfClass: [DKProxyStandin class]])
    {
      object = [(DKProxyStandin*)object proxy];
    }
    [fixedInfo setObject: object
                  forKey: key];
  }
  notification = [NSNotification notificationWithName: [self _notificationNameForSignal: signal]
                                               object: senderProxy
					     userInfo: fixedInfo];
  [matchingObservables makeObjectsPerformSelector: @selector(notifyWithNotification:)
                                       withObject: notification];

}

/**
 * Handles a message caught by the handler. If the signal is not yet known to
 * the center, this will generate arguments from the D-Bus signature. This
 * method also deserializes the message into an userInfo dictionary for use in
 * the notification. This is necessary to determine whether the message matches
 * one or more of the registered observables. If so, generation and dispatching
 * to the observers will be scheduled.
 */
- (BOOL)_handleMessage: (DBusMessage*)msg
{
  const char *cSignal = dbus_message_get_member(msg);
  NSString *signal = nil;
  const char *cInterface = dbus_message_get_interface(msg);
  NSString *interface = nil;
  const char *cSender = dbus_message_get_sender(msg);
  NSString *sender = nil;
  const char *cPath = dbus_message_get_path(msg);
  NSString *path = nil;
  const char *cDestination = dbus_message_get_destination(msg);
  NSString *destination = nil;
  const char *signature = dbus_message_get_signature(msg);
  id theNull = [NSNull null];

  // We cannot add nil to the userInfo, so we replace empty things with NSNull
  signal = (NULL != cSignal) ? [NSString stringWithUTF8String: cSignal] : theNull;
  interface = (NULL != cInterface) ? [NSString stringWithUTF8String: cInterface] : theNull;
  sender = (NULL != cSender) ? [NSString stringWithUTF8String: cSender] : theNull;
  path = (NULL != cPath) ? [NSString stringWithUTF8String: cPath]: theNull;
  destination = (NULL != cDestination) ? [NSString stringWithUTF8String: cDestination] : theNull;


  [lock lock];
  NS_DURING
  {
    DBusMessageIter iter;
    NSMutableDictionary *userInfo = nil;
    NSDictionary *infoDict = nil;
    NSArray *matchingObservables = nil;

    /*
     * Copying the signal allows us to set the sender as its parent (circumventing
     * the interface at this time. This is needed because the arguments might need
     * to construct object paths and such. We also need to reference the
     * original signal because we need it to look up the notification name.
     */
    DKSignal *origSignal = [self _signalWithName: signal
                                     inInterface: interface];
    DKSignal *theSignal = [[origSignal copy] autorelease];

    /* Construct a intermediary proxy for the object emitting the signal: */
    DKProxyStandin *senderNode = (id)theNull;
    if (NO == [theNull isEqual: sender])
    {
      // Sender will only be nil for in process signals:
      senderNode = [[[DKProxyStandin alloc] initWithEndpoint: [bus _endpoint]
                                                     service: sender
                                                        path: path] autorelease];
      [theSignal setParent: senderNode];
    }

    userInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys: signal, @"member",
      interface, @"interface",
      sender, @"sender",
      path, @"path",
      destination, @"destination",
      nil];

    if (([theSignal isStub]) && (NULL != signature))
    {
      if ('\0' != signature[0])
      {
        DBusSignatureIter iter;
        NSMutableArray *args = [NSMutableArray array];
        dbus_signature_iter_init(&iter, signature);
        do
        {
          char *sig = dbus_signature_iter_get_signature(&iter);
  	  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: sig
	                                                         name: nil
	                                                       parent: theSignal];
	  [args addObject: arg];
        } while (dbus_signature_iter_next(&iter));
        [theSignal setArguments: args];
      }
    }

    dbus_message_iter_init(msg, &iter);
    [userInfo addEntriesFromDictionary: [theSignal userInfoFromIterator: &iter]];

    matchingObservables = [self _observablesMatchingUserInfo: userInfo];
    if (nil == matchingObservables)
    {
      NSDebugMLog(@"Signal %@ is not being observed by the notification center.", signal);
      [lock unlock];
      return NO;
    }
    infoDict = [NSDictionary dictionaryWithObjectsAndKeys: senderNode, @"standin",
      userInfo, @"userInfo",
      origSignal, @"signal",
      matchingObservables, @"matches", nil];
    // Schedule sending out the notifications:
    [[NSRunLoop currentRunLoop] performSelector: @selector(_fixupProxyAndNotify:)
                                         target: self
                                       argument: infoDict
                                          order: 0
                                          modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
  }
  NS_HANDLER
  {
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [lock unlock];
  return YES;
}

/**
 * This method is called when recovering from a bus failure. It will reinstall
 * the D-Bus signal handler and instruct the daemon do forward signals matching
 * our observables to us.
 */
- (void)_syncStateWithBus
{
  [lock lock];
  NS_DURING
  {
    if (0 != NSCountHashTable(observables))
    {
      NSHashEnumerator theEnum = NSEnumerateHashTable(observables);
      NS_DURING
      {
        DKObservable *thisObs = nil;
        [self _installHandler];
        while (nil != (thisObs = NSNextHashEnumeratorItem(&theEnum)))
        {
	  NS_DURING
	  {
            [(id<DKDBusStub>)bus AddMatch: [thisObs ruleString]];
	  }
	  NS_HANDLER
	  {
	    NSWarnMLog(@"Failed to add match for observable: %@", localException);
	    NSHashRemove(observables, thisObs);
	  }
	  NS_ENDHANDLER
        }
      }
      NS_HANDLER
      {
        NSEndHashTableEnumeration(&theEnum);
	[localException raise];
      }
      NS_ENDHANDLER

      NSEndHashTableEnumeration(&theEnum);
    } //end of if-statement
  }
  NS_HANDLER
  {
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [lock unlock];
}

- (void)dealloc
{
  bus = nil;
  [signalInfo release];
  [notificationNames release];
  NSFreeMapTable(notificationNamesBySignal);
  NSFreeHashTable(observables);
  [lock release];
  [super dealloc];
}

// Singelton pattern:

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
DKHandleSignal (DBusConnection *connection, DBusMessage *msg, void *center)
{
  BOOL centerDidHandle = NO;
  if (DBUS_MESSAGE_TYPE_SIGNAL != dbus_message_get_type(msg))
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }
  centerDidHandle = [(DKNotificationCenter*)center _handleMessage: msg];
  if (centerDidHandle)
  {
    return DBUS_HANDLER_RESULT_HANDLED;
  }
  return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}
