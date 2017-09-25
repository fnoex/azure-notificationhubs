//----------------------------------------------------------------
//  Copyright (c) Microsoft Corporation. All rights reserved.
//----------------------------------------------------------------

#import "SBURLConnection.h"
#import "SBNotificationHubHelper.h"

@interface SBURLConnection ()

@property (strong, nonatomic) NSURLSession* session;

@end


@implementation SBURLConnection

StaticHandleBlock _staticHandler;

+ (void) setStaticHandler:(StaticHandleBlock)staticHandler
{
    _staticHandler = staticHandler;
}

- (id)init {
    if (self = [super init])
    {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[NSURLSession sharedSession].delegateQueue];
    }

    return self;
}

- (void) sendRequest: (NSURLRequest*) request completion:(void (^)(NSHTTPURLResponse*,NSData*,NSError*))completion;
{
    if( self)
    {
        self->_request = request;
        self->_completion = completion;
    }
 
    if( _staticHandler != nil)
    {
        SBStaticHandlerResponse* mockResponse = _staticHandler(request);
        if( mockResponse != nil)
        {
            if(completion)
            {
                NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:nil headerFields:mockResponse.Headers];
                completion(response,mockResponse.Data,nil);
            }
            return;
        }
    }

    if (request != nil)
    {
        NSURLSessionTask *task = [self.session dataTaskWithRequest:request];

        if (task != nil)
        {
            [task resume];
        }
        else if (completion != nil)
        {
            NSString* msg = [NSString stringWithFormat:@"Initiate request failed for %@",[request description]];
            completion(nil,nil,[SBNotificationHubHelper errorWithMsg:msg code:-1]);
        }
    }
    else if (completion != nil)
    {
        completion(nil,nil,[SBNotificationHubHelper errorWithMsg:@"No URL request provided" code:-1]);
    }
}

- (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(__autoreleasing NSURLResponse **)response error:(__autoreleasing NSError **)error
{
    if( _staticHandler != nil)
    {
        SBStaticHandlerResponse* mockResponse  = _staticHandler(request);
        if( mockResponse != nil)
        {
            (*response) = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:nil headerFields:mockResponse.Headers];
            return mockResponse.Data;
        }
    }

    // synchronous NSURLSessionTask execution by Quinn "The Eskimo!" at Apple
    // see https://forums.developer.apple.com/thread/11519
    dispatch_semaphore_t sem;
    __block NSData *result;

    result = nil;
    sem = dispatch_semaphore_create(0);

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *innerResponse, NSError *innerError)
      {
          if (error != NULL)
          {
              *error = innerError;
          }

          if (response != NULL)
          {
              *response = innerResponse;
          }

          if (innerError == nil)
          {
              result = data;
          }

          dispatch_semaphore_signal(sem);
      }] resume];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if (!self->_completion) {
        completionHandler(NSURLSessionResponseAllow);
        return;
    }

    self->_response = (NSHTTPURLResponse*)response;

    NSInteger statusCode = [self->_response statusCode];
    if( statusCode != 200 && statusCode != 201)
    {
        if(statusCode != 404)
        {
            NSLog(@"URLRequest failed:");
            NSLog(@"URL:%@",[[self->_request URL] absoluteString]);
            NSLog(@"Headers:%@",[self->_request allHTTPHeaderFields]);
        }

        NSString* msg = [NSString stringWithFormat:@"URLRequest failed for %@ with status code: %@",[self->_request description], [NSHTTPURLResponse localizedStringForStatusCode:statusCode]];

        self->_completion(self->_response,nil,[SBNotificationHubHelper errorWithMsg:msg code:statusCode]);
        self->_completion = nil;
        completionHandler(NSURLSessionResponseAllow);
        return;
    }

    if([[self->_request HTTPMethod] isEqualToString:@"DELETE"])
    {
        self->_completion(self->_response,nil,nil);
        self->_completion =nil;
        completionHandler(NSURLSessionResponseAllow);
        return;
    }

    // if it's create registration id request, we need to execute callback here.
    if([[self->_request HTTPMethod] isEqualToString:@"POST"] && [[self->_response URL].path rangeOfString:@"/registrationids" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        self->_completion(self->_response,nil,nil);
        self->_completion =nil;
        completionHandler(NSURLSessionResponseAllow);
        return;
    }

    _data = [[NSMutableData alloc]init];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{

    if (self->_completion)
    {
        NSData* data = (error == nil) ? _data : nil;
        self->_completion(self->_response,data,error);
        self->_completion = nil;
    }

    if (error != nil)
    {
        _data = nil;
    }
}

@end
