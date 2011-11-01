//
//  NPReachability.m
//  
//  Copyright (c) 2011, Nick Paulson
//  All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  Neither the name of the Nick Paulson nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "NPReachability.h"

NSString *NPReachabilityChangedNotification = @"NPReachabilityChangedNotification";

@interface NPReachability ()
- (NSArray *)_handlers;

@property (nonatomic, readwrite) SCNetworkReachabilityFlags currentReachabilityFlags;
@end

void NPNetworkReachabilityCallBack(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
	NPReachability *reach = (NPReachability *)info;
    
    // NPReachability maintains its own copy of |flags| so that KVO works 
    // correctly. Note that +keyPathsForValuesAffectingCurrentlyReachable
    // ensures that this also fires KVO for the |currentlyReachable| property.
    [reach setCurrentReachabilityFlags:flags];
    
	NSArray *allHandlers = [reach _handlers];
	for (void (^currHandler)(SCNetworkReachabilityFlags flags) in allHandlers) {
		currHandler(flags);
	}
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NPReachabilityChangedNotification object:reach];
}

const void * NPReachabilityRetain(const void *info) {
	NPReachability *reach = (NPReachability *)info;
	return (void*)[reach retain];
}
void NPReachabilityRelease(const void *info) {
	NPReachability *reach = (NPReachability *)info;
	[reach release];
}
CFStringRef NPReachabilityCopyDescription(const void *info) {
	NPReachability *reach = (NPReachability *)info;
	return (CFStringRef)[reach description];
}

@implementation NPReachability

@synthesize currentReachabilityFlags;
@dynamic currentlyReachable;

- (id)init {
	if ((self = [super init])) {
		_handlerByOpaqueObject = [[NSMutableDictionary alloc] init];
		
		struct sockaddr zeroAddr;
		bzero(&zeroAddr, sizeof(zeroAddr));
		zeroAddr.sa_len = sizeof(zeroAddr);
		zeroAddr.sa_family = AF_INET;
		
		_reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *) &zeroAddr);
		
		SCNetworkReachabilityContext context;
		context.version = 0;
		context.info = (void *)self;
		context.retain = NPReachabilityRetain;
		context.release = NPReachabilityRelease;
		context.copyDescription = NPReachabilityCopyDescription;
		
		if (SCNetworkReachabilitySetCallback(_reachabilityRef, NPNetworkReachabilityCallBack, &context)) {
			SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		}
	}
	return self;
}

- (void)dealloc {
    if (_reachabilityRef != NULL) {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFRelease(_reachabilityRef);
        _reachabilityRef = NULL;
    }
	
	[_handlerByOpaqueObject release];
	_handlerByOpaqueObject = nil;
    
    [super dealloc];
}

- (NSArray *)_handlers {
	return [_handlerByOpaqueObject allValues];
}

- (id)addHandler:(void (^)(SCNetworkReachabilityFlags flags))handler {
	NSString *obj = [[NSProcessInfo processInfo] globallyUniqueString];
	[_handlerByOpaqueObject setObject:[[handler copy] autorelease] forKey:obj];
	return obj;
}

- (void)removeHandler:(id)opaqueObject {
	[_handlerByOpaqueObject removeObjectForKey:opaqueObject];
}

- (BOOL)isCurrentlyReachable {
	return [[self class] isReachableWithFlags:[self currentReachabilityFlags]];
}

+ (NSSet *)keyPathsForValuesAffectingCurrentlyReachable {
    return [NSSet setWithObject:@"currentReachabilityFlags"];
}

+ (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags {
	
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
		// if target host is not reachable
		return NO;
	}
	
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
		// if target host is reachable and no connection is required
		//  then we'll assume (for now) that your on Wi-Fi
		return YES;
	}
	
	
	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
		 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
		// ... and the connection is on-demand (or on-traffic) if the
		//     calling application is using the CFSocketStream or higher APIs
		
		if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
			// ... and no [user] intervention is needed
			return YES;
		}
	}
	
	return NO;
}

#pragma mark - Singleton Methods

static NPReachability *sharedInstance = nil;

+ (NPReachability *)sharedInstance
{
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedInstance] retain];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

@end
