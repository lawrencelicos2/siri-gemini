#import "GeminiClient.h"
#define PREF_SUITE @"com.sirigemini.tweak"

@implementation GeminiClient { NSMutableArray *_history; }

+ (instancetype)shared {
    static GeminiClient *c; static dispatch_once_t o;
    dispatch_once(&o, ^{ c = [GeminiClient new]; c->_history = [NSMutableArray array]; });
    return c;
}
- (NSString *)apiKey {
    return [[[NSUserDefaults alloc] initWithSuiteName:PREF_SUITE] stringForKey:@"apiKey"];
}
- (void)setApiKey:(NSString *)k {
    [[[NSUserDefaults alloc] initWithSuiteName:PREF_SUITE] setObject:k forKey:@"apiKey"];
}
- (void)reset { [_history removeAllObjects]; }

- (void)ask:(NSString *)prompt completion:(void (^)(NSString *, NSError *))cb {
    [_history addObject:@{@"role":@"user", @"parts":@[@{@"text":prompt}]}];
    NSString *model = [[[NSUserDefaults alloc] initWithSuiteName:PREF_SUITE] stringForKey:@"model"] ?: @"gemini-2.5-flash";
    NSURL *url = [NSURL URLWithString:
      [NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/models/%@:generateContent", model]];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:url];
    r.HTTPMethod = @"POST";
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setValue:self.apiKey ?: @"" forHTTPHeaderField:@"x-goog-api-key"];
    NSDictionary *body = @{
        @"contents": _history,
        @"tools": @[@{@"google_search": @{}}],   // lets Gemini return real links
        @"systemInstruction": @{@"parts":@[@{@"text":@"You are Siri's brain. Be concise. Put links as plain URLs. For images, include a direct image URL (.jpg/.png) on its own line."}]}
    };
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e) {
        if (e || !d) { dispatch_async(dispatch_get_main_queue(), ^{ cb(nil, e); }); return; }
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *err = j[@"error"][@"message"];
        NSMutableString *out = [NSMutableString string];
        for (NSDictionary *p in j[@"candidates"][0][@"content"][@"parts"]) if (p[@"text"]) [out appendString:p[@"text"]];
        if (!out.length) [out setString:err ?: @"No response."];
        else [self->_history addObject:@{@"role":@"model", @"parts":@[@{@"text":out}]}];
        dispatch_async(dispatch_get_main_queue(), ^{ cb(out, nil); });
    }] resume];
}
@end
