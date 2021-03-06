//----------------------------------------------------------------
//  Copyright (c) Microsoft Corporation. All rights reserved.
//----------------------------------------------------------------

#import <Foundation/Foundation.h>

#import "SBTokenProvider.h"
#import "SBLocalStorage.h"


@interface SBNotificationHub : NSObject
{
@private
    NSString* _path;
    NSURL* _serviceEndPoint;
    SBTokenProvider* tokenProvider;
    SBLocalStorage* storageManager;
}

+ (NSString*) version;

- (SBNotificationHub*) initWithConnectionString:(NSString*) connectionString notificationHubPath:(NSString*)notificationHubPath;

// Async operations
- (void) registerNativeWithDeviceToken:(NSData*)deviceToken tags:(NSSet<NSString*>*)tags completion:(void (^)(NSError* error))completion;
- (void) registerTemplateWithDeviceToken:(NSData*)deviceToken name:(NSString*)name jsonBodyTemplate:(NSString*)bodyTemplate expiryTemplate:(NSString*)expiryTemplate tags:(NSSet<NSString*>*)tags completion:(void (^)(NSError* error))completion;

- (void) retrieveAllRegistrationsWithDeviceTokenData:(NSData*)deviceTokenData completion:(void (^)(NSArray<SBRegistration*>*, NSError*))completion;

- (void) unregisterNativeWithCompletion:(void (^)(NSError* error))completion;
- (void) unregisterTemplateWithName:(NSString*)name completion:(void (^)(NSError* error))completion;

- (void) unregisterAllWithDeviceToken:(NSData*)deviceToken completion:(void (^)(NSError* error))completion;

// sync operations
- (BOOL) registerNativeWithDeviceToken:(NSData*)deviceToken tags:(NSSet<NSString*>*)tags error:(NSError**)error;
- (BOOL) registerTemplateWithDeviceToken:(NSData*)deviceToken name:(NSString*)templateName jsonBodyTemplate:(NSString*)bodyTemplate expiryTemplate:(NSString*)expiryTemplate tags:(NSSet<NSString*>*)tags error:(NSError**)error;

- (NSArray<SBRegistration*>*) retrieveAllRegistrationsWithDeviceTokenData:(NSData*)deviceTokenData error:(NSError**)error;

- (BOOL) unregisterNativeWithError:(NSError**)error;
- (BOOL) unregisterTemplateWithName:(NSString*)name error:(NSError**)error;

- (BOOL) unregisterAllWithDeviceToken:(NSData*)deviceToken error:(NSError**)error;

@end
