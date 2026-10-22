#import <UIKit/UIKit.h>
@interface GeminiOverlay : NSObject
+ (instancetype)shared;
- (void)askAndShow:(NSString *)text;   // call with Siri's recognized text
@end
