//
//  WCBreakpoint.m
//  WabbitStudio
//
//  Created by William Towe on 2/18/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import "WCBreakpoint.h"
#import "NSBezierPath+StrokeExtensions.h"

static NSString *const WCBreakpointTypeKey = @"type";
static NSString *const WCBreakpointAddressKey = @"address";
static NSString *const WCBreakpointPageKey = @"page";
static NSString *const WCBreakpointActiveKey = @"active";

@implementation WCBreakpoint

- (id)copyWithZone:(NSZone *)zone {
	WCBreakpoint *copy = [[WCBreakpoint alloc] init];
	
	copy->_type = _type;
	copy->_address = _address;
	copy->_page = _page;
	copy->_breakpointFlags = _breakpointFlags;
	
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	WCBreakpoint *copy = [[WCBreakpoint alloc] init];
	
	copy->_type = _type;
	copy->_address = _address;
	copy->_page = _page;
	copy->_breakpointFlags = _breakpointFlags;
	
	return copy;
}

- (NSDictionary *)plistRepresentation {
	NSMutableDictionary *retval = [NSMutableDictionary dictionaryWithDictionary:[super plistRepresentation]];
	
	[retval setObject:[NSNumber numberWithUnsignedInt:[self type]] forKey:WCBreakpointTypeKey];
	[retval setObject:[NSNumber numberWithUnsignedShort:[self address]] forKey:WCBreakpointAddressKey];
	[retval setObject:[NSNumber numberWithUnsignedChar:[self page]] forKey:WCBreakpointPageKey];
	[retval setObject:[NSNumber numberWithBool:[self isActive]] forKey:WCBreakpointActiveKey];
	
	return [[retval copy] autorelease];
}

- (id)initWithPlistRepresentation:(NSDictionary *)plistRepresentation {
	if (!(self = [super initWithPlistRepresentation:plistRepresentation]))
		return nil;
	
	_type = [[plistRepresentation objectForKey:WCBreakpointTypeKey] unsignedIntValue];
	_address = [[plistRepresentation objectForKey:WCBreakpointAddressKey] unsignedShortValue];
	_page = [[plistRepresentation objectForKey:WCBreakpointPageKey] unsignedCharValue];
	_breakpointFlags.active = [[plistRepresentation objectForKey:WCBreakpointActiveKey] boolValue];
	
	return self;
}

+ (id)breakpointOfType:(WCBreakpointType)type address:(uint16_t)address page:(uint8_t)page; {
	return [[[[self class] alloc] initWithType:type address:address page:page] autorelease];
}
- (id)initWithType:(WCBreakpointType)type address:(uint16_t)address page:(uint8_t)page; {
	if (!(self = [super init]))
		return nil;
	
	_type = type;
	_address = address;
	_page = page;
	_breakpointFlags.active = YES;
	
	return self;
}

+ (NSGradient *)activeBreakpointFillGradient; {
	static NSGradient *retval;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		retval = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.9 alpha:1.0],0.0,[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.8 alpha:1.0],0.5,[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.75 alpha:1.0],0.5,[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.65 alpha:1.0],1.0, nil];
	});
	return retval;
}
+ (NSGradient *)inactiveBreakpointFillGradient; {
	static NSGradient *retval;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		retval = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.9 alpha:0.5],0.0,[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.8 alpha:0.5],0.5,[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.75 alpha:0.5],0.5,[NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.65 alpha:0.5],1.0, nil];
	});
	return retval;
}
+ (NSColor *)activeBreakpointFillColor; {
	return [NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.55 alpha:1.0];
}
+ (NSColor *)inactiveBreakpointFillColor; {
	return [NSColor colorWithCalibratedHue:212.0/360.0 saturation:0.45 brightness:0.55 alpha:0.5];
}

+ (NSImage *)breakpointIconWithSize:(NSSize)size type:(WCBreakpointType)type active:(BOOL)active; {
	static const CGFloat kCornerRadius = 3.0;
	static const CGFloat kTriangleInset = 6.0;
	NSImage *retval = [[[NSImage alloc] initWithSize:size] autorelease];
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	[path moveToPoint:NSMakePoint(size.width, floor(size.height/2.0))];
	[path lineToPoint:NSMakePoint(size.width-kTriangleInset, size.height)];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(kCornerRadius, size.height-kCornerRadius) radius:kCornerRadius startAngle:90.0 endAngle:180.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(kCornerRadius, kCornerRadius) radius:kCornerRadius startAngle:180.0 endAngle:270.0];
	[path lineToPoint:NSMakePoint(size.width-kTriangleInset, 0.0)];
	[path closePath];
	
	[retval lockFocus];
	
	if (active)
		[[self activeBreakpointFillGradient] drawInBezierPath:path angle:270.0];
	else
		[[self inactiveBreakpointFillGradient] drawInBezierPath:path angle:270.0];
	
	if (active)
		[[self activeBreakpointFillColor] setStroke];
	else
		[[self inactiveBreakpointFillColor] setStroke];
	
	[path strokeInside];
	
	[retval unlockFocus];
	
	return retval;
}

@synthesize type=_type;
@synthesize address=_address;
@synthesize page=_page;
@dynamic active;
- (BOOL)isActive {
	return _breakpointFlags.active;
}
- (void)setActive:(BOOL)active {
	_breakpointFlags.active = active;
}
@dynamic icon;
- (NSImage *)icon {
	return [[self class] breakpointIconWithSize:NSMakeSize(24.0, 12.0) type:[self type] active:[self isActive]];
}
+ (NSSet *)keyPathsForValuesAffectingIcon {
	return [NSSet setWithObjects:@"active", nil];
}

@end
