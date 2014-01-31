/* Implementation for NSUserNotification for GNUstep
   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Marcus Mueller <znek@mulle-kybernetik.com>
   Date: 2014

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

// NOTE: for the time being, NSUserNotificationCenter needs this feature.
// Whenever this restriction is lifted, we can get rid of it here as well.
#if __has_feature(objc_default_synthesize_properties)

#define	EXPOSE_NSUserNotification_IVARS	1
#define	EXPOSE_NSUserNotificationCenter_IVARS	1

#import "DKUserNotification.h"
#import <GNUstepBase/GNUstep.h>
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/NSDebug+GNUstepBase.h"
#import <Foundation/NSUserNotification.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import "Foundation/NSException.h"
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <DBusKit/DBusKit.h>

static NSString * const kDBusBusKey  = @"org.freedesktop.Notifications";
static NSString * const kDBusPathKey = @"/org/freedesktop/Notifications";

static NSString * const kButtonActionKey = @"show";


// Desktop Notifications Specification
// see https://people.gnome.org/~mccann/docs/notification-spec/notification-spec-latest.html
@protocol Notifications
- (NSArray *) GetCapabilities;
#if 0
// NOTE: seems to be the logical signature according to spec,
// but not what DBusKit's unmarshalling currently implements (see below)
- (void) GetServerInformation: (NSString **)name : (NSString **)vendor : (NSString **)version;
#else
- (NSArray *)GetServerInformation;
#endif
- (NSNumber *) Notify: (NSString *)app_name : (uint32_t)replaces_id : (NSString *)app_icon : (NSString *)summary : (NSString *)body : (NSArray *)actions : (NSDictionary *)hints : (int)expire_timeout;
- (void)CloseNotification: (uint32_t)notification_id;
@end


@interface NSUserNotification ()
@property (readwrite) NSDate *actualDeliveryDate;
@property (readwrite, getter=isPresented) BOOL presented;
@property (readwrite) NSUserNotificationActivationType activationType;
@end

@interface NSUserNotificationCenter (Private)
- (NSUserNotification *) deliveredNotificationWithUniqueId: (id)uniqueId;
@end

@interface DKUserNotificationCenter (Private)
- (NSString *) cleanupTextIfNecessary: (NSString *)rawText;
@end

@implementation DKUserNotificationCenter

- (id) init
{
	self = [super init];
	if (self)
	{
		NS_DURING
		{
			DKPort *rPort = (DKPort *)[DKPort port];
			DKPort *sPort = [[DKPort alloc] initWithRemote: kDBusBusKey];
			connection = RETAIN([NSConnection connectionWithReceivePort: rPort
											  sendPort: sPort]);
			RELEASE(sPort);
			if (!connection)
			{
				NSLog(@"Unable to create a connection to %@", kDBusBusKey);
				NS_VALUERETURN(nil, self);
			}

			proxy = (id <NSObject, Notifications>)RETAIN([connection proxyAtPath: kDBusPathKey]);
			if (!proxy)
			{
				NSLog(@"Unable to create a proxy for %@", kDBusPathKey);
				NS_VALUERETURN(nil, self);
			}

			NSString *name;
			NSString *vendor;
			NSString *version;
#if 0
			[proxy GetServerInformation: &name : &vendor : &version];
#else
			NSArray *info = [proxy GetServerInformation];
		    name    = [info objectAtIndex:0];
		    vendor  = [info objectAtIndex:1];
		    version = [info objectAtIndex:2];
#endif
			NSDebugLLog(@"NSUserNotification", @"connected to %@ (%@) by %@", name, version, vendor);

			caps = RETAIN([proxy GetCapabilities]);
			if (!caps)
			{
				NSLog(@"No response to GetCapabilities method");
				NS_VALUERETURN(nil, self);
			}
			NSDebugLLog(@"NSUserNotification", @"capabilities: %@", caps);

			DKNotificationCenter *dnc = [DKNotificationCenter sessionBusCenter];
#if 0
			[dnc addObserver: self
				 selector: @selector(receiveNotificationClosedNotification:)
				 signal: @"NotificationClosed"
				 interface: kDBusBusKey
				 sender: (DKProxy *)proxy
				 destination: nil];
#endif
			[dnc addObserver: self
				 selector: @selector(receiveActionInvokedNotification:)
				 signal: @"ActionInvoked"
				 interface: kDBusBusKey
				 sender: (DKProxy *)proxy
				 destination: nil];
		}
		NS_HANDLER
		{
			NSLog(@"%@ during DBus setup: %@",
				  [localException name], [localException description]);
			DESTROY(self);
		}
		NS_ENDHANDLER
	}
	return self;
}

- (void) dealloc
{
	[[DKNotificationCenter sessionBusCenter] removeObserver: self];
	RELEASE(caps);
	RELEASE(proxy);
	RELEASE(connection);
	[super dealloc];
}

- (void) _deliverNotification: (NSUserNotification *)un
{
	// TODO: use [NSBundle mainBundle] or provide a hook for NSApplication?
	NSString *appName   = @"";
	// TODO: map imageName to something sensible or implement one of the
	// available extensions (see spec for details)
	NSString *imageName = @"";

	NSMutableArray *actions = [NSMutableArray array];
	if ([un hasActionButton])
	  {
		NSString *actionButtonTitle = un.actionButtonTitle;
		if (!actionButtonTitle)
			actionButtonTitle = _(@"Show");

		// NOTE: don't use "default", as it's used by convention and seems
		// to remove the actionButton entirely
		// (tested with Notification Daemon (0.3.7))
		[actions addObject: kButtonActionKey];
		[actions addObject: [self cleanupTextIfNecessary: actionButtonTitle]];
	  }

	NSString *summary  = [self cleanupTextIfNecessary: un.title];
	NSString *body     = [self cleanupTextIfNecessary: un.informativeText];
	NSNumber *uniqueId = [proxy Notify: appName
									  : 0
									  : imageName
									  : summary
									  : body
									  : actions
									  : un.userInfo
									  : -1];
	ASSIGN(un->_uniqueId, uniqueId);
  un.presented = YES;
}

- (void)_removeDeliveredNotification:(NSUserNotification *)un
{
	if (un.presented)
		[proxy CloseNotification: [un->_uniqueId unsignedIntValue]];
}

- (NSString *)cleanupTextIfNecessary:(NSString *)rawText
{
	if (!rawText || ![caps containsObject:@"body-markup"])
		return nil;

	NSMutableString *t = (NSMutableString *)[rawText mutableCopy];
	[t replaceOccurrencesOfString: @"&"  withString: @"&amp;"  options: 0 range: NSMakeRange(0, [t length])];  // must be first!
	[t replaceOccurrencesOfString: @"<"  withString: @"&lt;"   options: 0 range: NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString: @">"  withString: @"&gt;"   options: 0 range: NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString: @"\"" withString: @"&quot;" options: 0 range: NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString: @"'"  withString: @"&apos;" options: 0 range: NSMakeRange(0, [t length])];
	return t;
}

// SIGNALS

- (void)receiveNotificationClosedNotification:(NSNotification *)n
{
	id nId = [[n userInfo] objectForKey: @"arg0"];
	NSUserNotification *un = [self deliveredNotificationWithUniqueId: nId];
	NSDebugMLLog(@"NSUserNotification", @"%@", un);
}

- (void)receiveActionInvokedNotification:(NSNotification *)n
{
	id nId = [[n userInfo] objectForKey: @"arg0"];
	NSUserNotification *un = [self deliveredNotificationWithUniqueId: nId];
	NSString *action = [[n userInfo] objectForKey: @"arg1"];

	NSDebugMLLog(@"NSUserNotification", @"%@ -- action: %@", un, action);
	if ([action isEqual:kButtonActionKey])
		un.activationType = NSUserNotificationActivationTypeActionButtonClicked;
	else
		un.activationType = NSUserNotificationActivationTypeContentsClicked;

	if (self.delegate && [self.delegate respondsToSelector:@selector(userNotificationCenter:didActivateNotification:)])
		[self.delegate userNotificationCenter: self didActivateNotification: un];
}

@end

#endif /* __has_feature(objc_default_synthesize_properties) */
