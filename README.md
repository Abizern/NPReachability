#NPReachability
- Originally By [Nick Paulson](http://twitter.com/nckplsn)
- KVO support added by [Adam Ernst](http://www.adamernst.com/)
- ARC support and changes to the interface by [Abizer Nasir](http://abizern.org)

NPReachability is an extension of Apple's Reachability class which provides information about the network status.

It is written as a singleton so make sure you reference it as:

    NPReachability *reachability = [NPReachability sharedInstance];

This class can take a block handler to process changes in status, but also supports KVO and traditional notifications as well. It is written to support Automatic Reference Counting (ARC)

## Block support

Handlers are declared as

    typedef void (^ReachabilityHandler)(NPReachability *curReach);

This takes the NPReachability object as a parameter. As originally written this class passed the `SCNetworkReachabilityFlags` as a parameter, but you can get that and more by messaging the object directly

You add blocks to be executed when the network status changes by using:

    - (id)addHandler:(ReachabilityHandler)handler;

This returns an opaque object which you should use to remove the handler at the appropriate time (in a `dealloc`, say) with:

    - (void)removeHandler:(id)opaqueObject;

## KVO support

Two properties can observed for changes to the network status:

    @property (nonatomic, readonly, getter=isCurrentlyReachable) BOOL currentlyReachable;
	@property (nonatomic, readonly) SCNetworkReachabilityFlags currentReachabilityFlags;

## NSNotification

When the network status changes a `NPReachabilityChangedNotification` is sent with the NPReachability instance as the notification object.

## Dependencies

- Xcode 4.2+ for ARC support and compatibility libraries
- THe SystemConfiguration Framework should be added to your projects

Please use and improve!

I'd love it if you could send me a note as to which app you're using it with!