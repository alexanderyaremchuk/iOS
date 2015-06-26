#import <UIKit/UIKit.h>
#import "QueueITEngine.h"
#import "QueueITViewController.h"
#import "QueueService.h"
#import "QueueStatus.h"
#import "IOSUtils.h"

@interface QueueITEngine()
@property (nonatomic, strong)UIViewController* host;
@property (nonatomic, strong)NSString* customerId;
@property (nonatomic, strong)NSString* eventId;
@end

@implementation QueueITEngine

-(instancetype)initWithHost:(UIViewController *)host customerId:(NSString*)customerId eventOrAliasId:(NSString*)eventOrAliasId
{
    self = [super init];
    if(self) {
        self.host = host;
        self.customerId = customerId;
        self.eventId = eventOrAliasId;
    }
    return self;
}

-(void)run
{
    NSString * key = [NSString stringWithFormat:@"%@-%@",self.customerId, self.eventId];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary* url2TTL = [defaults dictionaryForKey:key];
    
    if (url2TTL)
    {
        long cachedTime = [[[url2TTL allValues] objectAtIndex:0] longLongValue];
        long currentTime = (long)(NSTimeInterval)([[NSDate date] timeIntervalSince1970]);
        
        if (currentTime < cachedTime)
        {
            NSString* queueUrlCached = [[url2TTL allKeys] objectAtIndex:0];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showQueue:self.host queueUrl:queueUrlCached customerId:self.customerId eventId:self.eventId];
            });
        }
        else
        {
            [self tryEnqueue:self.host customerId:self.customerId eventOrAliasId:self.eventId];
        }
    }
    else
    {
        [self tryEnqueue:self.host customerId:self.customerId eventOrAliasId:self.eventId];
    }
}

-(void)showQueue:(UIViewController*)host queueUrl:(NSString*)queueUrl customerId:(NSString*)customerId eventId:(NSString*)eventId
{
    QueueITViewController *queueVC = [[QueueITViewController alloc] initWithHost:host
                                                                     queueEngine:self
                                                                        queueUrl:queueUrl
                                                                      customerId:customerId eventId:eventId];
    [host presentModalViewController:queueVC animated:YES];
}

-(void)tryEnqueue:(UIViewController *)host customerId:(NSString*)customerId eventOrAliasId:(NSString*)eventOrAliasId
{
    NSString* userId = [IOSUtils getUserId];
    NSString* userAgent = [NSString stringWithFormat:@"%@;%@", [IOSUtils getUserAgent], [IOSUtils getLibraryVersion]];
    NSString* appType = @"iOS";
    
    QueueService* qs = [QueueService sharedInstance];
    [qs enqueue:customerId
 eventOrAliasId:eventOrAliasId
         userId:userId userAgent:userAgent
        appType:appType
        success:^(QueueStatus *queueStatus)
     {
         if (queueStatus.errorType != (id)[NSNull null])
         {
             [self handleServerError:queueStatus.errorType errorMessage:queueStatus.errorMessage];
         }
         if (queueStatus.queueId != (id)[NSNull null] && queueStatus.queueUrlString == (id)[NSNull null] && queueStatus.requeryInterval == 0) //SafetyNet
         {
         }
         else if (queueStatus.queueId != (id)[NSNull null] && queueStatus.queueUrlString != (id)[NSNull null] && queueStatus.requeryInterval == 0) //InQueue
         {
             [self showQueue:host queueUrl:queueStatus.queueUrlString customerId:customerId eventId:eventOrAliasId];
             [self updateCache:queueStatus.queueUrlString urlTTL:queueStatus.queueUrlTTL customerId:customerId eventId:eventOrAliasId];
         }
         else if (queueStatus.queueId == (id)[NSNull null] && queueStatus.queueUrlString != (id)[NSNull null] && queueStatus.requeryInterval == 0) //Idle
         {
             [self showQueue:host queueUrl:queueStatus.queueUrlString customerId:customerId eventId:eventOrAliasId];
         }
         else if (queueStatus.requeryInterval > 0) //Disabled
         {
             dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 [NSThread sleepForTimeInterval:queueStatus.requeryInterval];
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [self tryEnqueue:host customerId:customerId eventOrAliasId:eventOrAliasId];
                 });
             });
         }
     }
        failure:^(NSError *error)
     {
         
     }];
}

-(void)handleServerError:(NSString*)errorType errorMessage:(NSString*)errorMessage
{
    if ([errorType isEqualToString:@"Configuration"])
    {
        @throw [NSException exceptionWithName:@"QueueITConfigurationException" reason:errorMessage userInfo:nil];
    }
    else if ([errorType isEqualToString:@"Runtime"])
    {
        @throw [NSException exceptionWithName:@"QueueITRuntimeException" reason:errorMessage userInfo:nil];
    }
    else if ([errorType isEqualToString:@"Validation"])
    {
        @throw [NSException exceptionWithName:@"QueueITValidationException" reason:errorMessage userInfo:nil];
    }
}

-(void)updateCache:(NSString*)queueUrl urlTTL:(int)queueUrlTTL customerId:(NSString*)customerId eventId:(NSString*)eventId
{
    long currentTime = (long)(NSTimeInterval)([[NSDate date] timeIntervalSince1970]);
    int secondsToAdd = queueUrlTTL * 60.0;
    long timeStapm = currentTime + secondsToAdd;
    
    NSString* urlTtlString = [NSString stringWithFormat:@"%li", timeStapm];
    NSMutableDictionary* url2TTL = [[NSMutableDictionary alloc] init];
    [url2TTL setObject:urlTtlString forKey:queueUrl];
    
    NSString* key = [NSString stringWithFormat:@"%@-%@",customerId, eventId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:url2TTL forKey:key];
    [defaults synchronize];
}

-(void) raiseQueuePassed:(NSString *)queueId
{
    Turn* turn = [[Turn alloc]init:queueId];
    [self.queuePassedDelegate notifyYourTurn:turn];
    
    NSString * key = [NSString stringWithFormat:@"%@-%@", self.customerId, self.eventId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

@end