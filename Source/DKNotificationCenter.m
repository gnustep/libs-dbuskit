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
#import <Foundation/NSString.h>

#include <stdint.h>
#include <dbus/dbus.h>

typedef struct _DKObservable DKObservable;
typedef struct _DKObservation DKObservation;
typedef struct _DKObservationTables DKObservationTables;

/**
 * The DKObservable structure denotes specific signal/filter combinations that
 * can be the object of multiple observation activities.
 */
struct _DKObservable
{
  /**
   * The rules that D-Bus is using to determine which signals to pass to
   * use.
   */
  NSDictionary *rules;

  /**
   * Pointer to the linked list of observers.
   */
  DKObservation *observation;

  /**
   * Pointer back to the observation tables that reference the strucutre.
   */
   DKObservationTables *tables;

  /**
   * Number of times this structure is used.
   */
   NSUInteger refCount;
};

/* Hash table callbacks: */
static NSUInteger
DKObservableHash(NSHashTable *t, const void *observable);

static BOOL
DKObservableIsEqual(NSHashTable *t, const void *first, const void *second);

static void
DKObservableRetain(NSHashTable *t, const void *observable);

static void
DKObservableRelease(NSHashTable *t, void *observable);


static NSHashTableCallBacks DKObservableCallbacks = {DKObservableHash,
  DKObservableIsEqual,
  DKObservableRetain,
  DKObservableRelease,
  NULL};

/**
 * The DKObservation structure is a doubly-linked list denoting the individual
 * Objective-C objects that are watching for D-Bus signals and encapsulates all
 * information necessary to dispatch the signal.
 */
struct _DKObservation
{
  /**
   * The object that wants to watch the signal.
   * FIXME: Make sure that observers are not picked up by the GC mechanism
   * because we are onl meant to weakly reference them.
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

  /**
   * Keeps track of the number of times the observation structure has been
   * added.
   */
  NSUInteger refCount;

  /**
   * The previous element in the linked list
   */

  DKObservation *previous;

  /**
   * Next element in the linked list.
   */
  DKObservation *next;

  /**
   * Pad to 32/64 bytes depending on the platform. This should make
   * sizeof(DKObservation) == (2 * sizeof(DKObservable))
   */
  void *padding;
};

/* Hash table callbacks: */
static NSUInteger
DKObservationHash(NSHashTable *t, const void *observable);

static BOOL
DKObservationIsEqual(NSHashTable *t, const void *first, const void *second);

static void
DKObservationRetain(NSHashTable *t, const void *observable);

static void
DKObservationRelease(NSHashTable *t, void *observable);

static NSHashTableCallBacks DKObservationCallbacks = {DKObservationHash,
  DKObservationIsEqual,
  DKObservationRetain,
  DKObservationRelease,
  NULL};


struct _DKObservationTables
{
  /** The zone from which to allocate memory. */
  NSZone *zone;
  /** Hash table all DKObservables */
  NSHashTable *observables;
  /**
    * Map tables that relates observer objects to the observation actions they
    * requested.
    */
  NSMapTable *observers;
};


#define TABLES ((DKObservationTables*)dispatchTables)
#define T_ZONE TABLES->zone
#define T_OBSERVABLES TABLES->observables
#define T_OBSERVERS TABLES->observers

static DKNotificationCenter *systemCenter;
static DKNotificationCenter *sessionCenter;

static DBusHandlerResult
DKHandleSignal(DBusConnection *connection, DBusMessage *msg, void *userData);

@interface DKNotificationCenter (DKNotificationCenterPrivate)
- (id)initWithBusType: (DKDBusBusType)type;
@end

@implementation DKNotificationCenter
+ (void)initialize
{
  if ([DKNotificationCenter class] == self)
  {
    systemCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSystemBus];
    sessionCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSessionBus];
  }
  else
  {
    //FIXME: Remove the else-branch once DKObservationCallbacks is used.
    void *foo = &DKObservationCallbacks;
    if (foo != &DKObservationCallbacks)
    {
      //NoOp:
    }
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

  dispatchTables = malloc(sizeof(DKObservationTables));
  if (NULL == dispatchTables)
  {
    [self release];
    return nil;
  }
  memset(dispatchTables, '\0', sizeof(DKObservationTables));

  /*
   * Create a NSZone for the DKObservable and DKObservation structures,
   * preallocating space for five pairs of them and continuing to allocate them
   * on a granuarity of DKObservation because.
   */
  T_ZONE = NSCreateZone(((5 * sizeof(DKObservation)) + (5 * sizeof(DKObservable))),
   sizeof(DKObservation),
   YES);
  if (NULL == T_ZONE)
  {
    [self release];
    return nil;
  }
  NSSetZoneName(T_ZONE, @"DBusKit signal observation zone");

  T_OBSERVABLES = NSCreateHashTable(DKObservableCallbacks, 5);
  T_OBSERVERS = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    5);

  return self;
}


- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender
{
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
- (BOOL)registerNotificationName: (NSString*)notificationName
                        asSignal: (NSString*)signalName
                     inInterface: (NSString*)interface
{
  return NO;
}

- (void)registerSignal: (DKSignal*)aSignal
{
  NSString *interfaceName = [[aSignal parent] name];
  NSString *signalName = [aSignal name];
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
  if ([[theSignal annotationValueForKey: @"org.gnustep.DBusKit.StubSignal"] boolValue])
  {
    [theInterface removeSignalNamed: signalName];
  }

  // Add the signal if necessary
  if (nil == theSignal)
  {
    theSignal = [aSignal copy];
    [theInterface addSignal: theSignal];
    [theSignal setParent: theInterface];
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

-   (void)_addMatch: (NSString*)match
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


static NSUInteger
DKObservableHash(NSHashTable *t, const void *observable)
{
  DKObservable *o = (DKObservable*)observable;
  return [o->rules hash];
}

static BOOL
DKObservableIsEqual(NSHashTable *t, const void *first, const void *second)
{
  DKObservable *f = (DKObservable*)first;
  DKObservable *s = (DKObservable*)second;
  return [f->rules isEqualToDictionary: s->rules];
}

static void
DKObservableRetain(NSHashTable *t, const void *observable)
{
  DKObservable *o = (DKObservable*)observable;
  DKObservation *observation = o->observation;

  o->refCount++;
  [o->rules retain];

  while (NULL != observation)
  {
    DKObservationRetain(NULL, observation);
    observation = observation->next;
  }
}

static void
DKObservableRelease(NSHashTable *t, void *observable)
{
  DKObservable *o = (DKObservable*)observable;
  DKObservation *observation = o->observation;
  BOOL willFree = NO;
  o->refCount--;

  willFree = (0 == o->refCount);
  [o->rules release];

  while (NULL != observation)
  {
    DKObservationRelease(NULL, observation);
    observation = observation->next;
  }

  if (willFree)
  {
    observation = o->observation;
    while (NULL != observation)
    {
      observation->observed = NULL;
      observation = observation->next;
    }
    NSZoneFree(o->tables->zone, observable);
  }
}

static NSUInteger
DKObservationHash(NSHashTable *t, const void *observation)
{
  /*
   * We just generate the hash by XOR-ing the the relevant elements of the
   * structure.
   */
  DKObservation *o = (DKObservation*)observation;
  return (((uintptr_t)o->observer ^ (uintptr_t)o->selector) ^ DKObservableHash(NULL, o->observed));
}

static BOOL
DKObservationIsEqual(NSHashTable *t, const void *first, const void *second)
{
  DKObservation *f = (DKObservation*)first;
  DKObservation *s = (DKObservation*)second;
  return (((f->observer == s->observer) && (f->selector == s->selector))
    && DKObservableIsEqual(NULL, (const void*)f->observed, (const void*)s->observed));
}

static void
DKObservationRetain(NSHashTable *t, const void *observation)
{
  DKObservation *o = (DKObservation*)observation;
  o->refCount++;
}

static void
DKObservationRelease(NSHashTable *t, void *observation)
{
  DKObservation *o = (DKObservation*)observation;
  o->refCount--;
  if (0 == o->refCount)
  {
    // Before we free ourselves, we adjust the links in the list:
    DKObservation *myPrevious = o->previous;
    DKObservation *myNext = o->next;

    if ((NULL == myPrevious) && (NULL != o->observed))
    {
      // Beginning of the list. Adjust the head in the observable (if set). This
      // also yields the correct result if we are the only element in the list
      // (i.e. the list of active observations for an observable is set to
      // NULL.)
      o->observed->observation = myNext;
    }
    else
    {
      // This is also okay if we are the end of the list;
      myPrevious->next = myNext;
    }

    if (NULL != myNext)
    {
      // This is also okay if we are at the beginning of the list
      myNext->previous = myPrevious;
    }

    if (NULL != o->observed)
    {
      NSZoneFree(o->observed->tables->zone, observation);
    }
    else
    {
      free(observation);
    }
  }
}
