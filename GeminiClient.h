#import <Foundation/Foundation.h>
@interface GeminiClient : NSObject
+ (instancetype)shared;
@property (nonatomic, copy) NSString *apiKey;
- (void)ask:(NSString *)prompt completion:(void (^)(NSString *text, NSError *err))cb;
- (void)reset;
@end
