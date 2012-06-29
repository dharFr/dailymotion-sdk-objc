//
//  DMAPICacheInfo.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMAPICacheInfo.h"
#import "DMAPI.h"

static NSString *const DMAPICacheInfoInvalidatedNotification = @"DMAPICacheInfoInvalidatedNotification";

@interface DMAPICacheInfo ()

@property (nonatomic, readwrite) NSDate *date;
@property (nonatomic, readwrite) NSString *namespace;
@property (nonatomic, readwrite) NSArray *invalidates;
@property (nonatomic, readwrite) NSString *etag;
@property (nonatomic, readwrite, assign) BOOL public;
@property (nonatomic, readwrite, assign) NSTimeInterval maxAge;
@property (nonatomic, weak) DMAPI *_api;

@end


@implementation DMAPICacheInfo
{
    BOOL _stalled;
}

- (id)initWithCacheInfo:(NSDictionary *)cacheInfo fromAPI:(DMAPI *)api
{
    if ((self = [super init]))
    {
        _date = [NSDate date];
        _namespace = cacheInfo[@"namespace"];
        _invalidates = cacheInfo[@"invalidates"];
        _etag = cacheInfo[@"etag"];
        _public = [cacheInfo[@"public"] boolValue];
        _maxAge = [cacheInfo[@"maxAge"] floatValue];
        _valid = YES;

        if (_invalidates)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:DMAPICacheInfoInvalidatedNotification
                                                                object:self.invalidates];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(invalidateNamespaces:)
                                                     name:DMAPICacheInfoInvalidatedNotification
                                                   object:nil];

        if (!_public)
        {
            __api = api;
            [__api addObserver:self forKeyPath:@"oauth.session" options:0 context:NULL];
        }
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (!self.public)
    {
        [self._api removeObserver:self forKeyPath:@"oauth.session"];
    }
}

- (BOOL)stalled
{
    return _stalled || [self.date timeIntervalSinceNow] > self.maxAge;
}

- (void)setStalled:(BOOL)stalled
{
    _stalled = stalled;
}

- (void)invalidateNamespaces:(NSNotification *)notification
{
    NSArray *invalidatedNamespaces = notification.object;
    if ([invalidatedNamespaces containsObject:self.namespace])
    {
        self.stalled = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Flush cache of private objects when session change
    if (self._api == object && !self.public && [keyPath isEqualToString:@"oauth.session"])
    {
        self.valid = NO;
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end