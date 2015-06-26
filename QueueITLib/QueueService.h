#import <Foundation/Foundation.h>
#import "QueueStatus.h"

typedef void (^QueueServiceSuccess)(NSData *data);
typedef void (^QueueServiceFailure)(NSError *error);

@interface QueueService : NSObject
+ (QueueService *)sharedInstance;

-(NSString*)enqueue:(NSString*)customerId
     eventOrAliasId:(NSString*)eventorAliasId
             userId:(NSString*)userId
          userAgent:(NSString*)userAgent
            appType:(NSString*)appType
            success:(void(^)(QueueStatus* queueStatus))success
            failure:(QueueServiceFailure)failure;


@end