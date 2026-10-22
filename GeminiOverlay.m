#import "GeminiOverlay.h"
#import "GeminiClient.h"
#import <AVFoundation/AVFoundation.h>

@interface GeminiVC : UIViewController <UITextFieldDelegate>
@property UITextView *chat; @property UIScrollView *imgs; @property UITextField *input;
@property AVSpeechSynthesizer *tts; @property (copy) void (^onClose)(void);
- (void)send:(NSString *)q;
@end

@implementation GeminiVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.tts = [AVSpeechSynthesizer new];
    UIView *card = [[UIView alloc] initWithFrame:CGRectInset(self.view.bounds, 12, 70)];
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    card.backgroundColor = UIColor.systemBackgroundColor; card.layer.cornerRadius = 20; card.clipsToBounds = YES;
    [self.view addSubview:card];
    CGFloat w = card.bounds.size.width, h = card.bounds.size.height;

    self.chat = [[UITextView alloc] initWithFrame:CGRectMake(0, 44, w, h-44-120-52)];
    self.chat.editable = NO; self.chat.font = [UIFont systemFontOfSize:16];
    self.chat.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.chat.dataDetectorTypes = UIDataDetectorTypeLink;
    [card addSubview:self.chat];

    self.imgs = [[UIScrollView alloc] initWithFrame:CGRectMake(0, h-172, w, 120)];
    self.imgs.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [card addSubview:self.imgs];

    self.input = [[UITextField alloc] initWithFrame:CGRectMake(12, h-46, w-24, 38)];
    self.input.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.input.borderStyle = UITextBorderStyleRoundedRect; self.input.placeholder = @"Ask Gemini a follow-up…";
    self.input.returnKeyType = UIReturnKeySend; self.input.delegate = self;
    [card addSubview:self.input];

    UIButton *x = [UIButton buttonWithType:UIButtonTypeClose]; x.frame = CGRectMake(w-44, 8, 30, 30);
    x.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [x addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:x];
    UIButton *k = [UIButton buttonWithType:UIButtonTypeSystem]; k.frame = CGRectMake(10, 6, 80, 32);
    [k setTitle:@"Get key" forState:UIControlStateNormal];
    [k addTarget:self action:@selector(openKeyPage) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:k];
}
- (void)close { [self.tts stopSpeakingAtBoundary:AVSpeechBoundaryImmediate]; if (self.onClose) self.onClose(); }
- (BOOL)textFieldShouldReturn:(UITextField *)f { NSString *q = f.text; f.text = @""; [f resignFirstResponder]; if (q.length) [self send:q]; return YES; }

- (void)openKeyPage {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://aistudio.google.com/apikey"] options:@{} completionHandler:nil];
}

- (void)append:(NSString *)label text:(NSString *)t {
    NSMutableAttributedString *m = [[NSMutableAttributedString alloc] initWithAttributedString:self.chat.attributedText ?: [NSAttributedString new]];
    UIFont *f = [UIFont systemFontOfSize:16]; UIColor *c = UIColor.labelColor;
    [m appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", label]
        attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:14], NSForegroundColorAttributeName:UIColor.systemBlueColor}]];
    NSMutableAttributedString *body = [[NSMutableAttributedString alloc] initWithString:[t stringByAppendingString:@"\n\n"]
        attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:c}];
    // markdown [text](url) -> tappable link
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\((https?://[^)]+)\\)" options:0 error:nil];
    for (NSTextCheckingResult *r in [[re matchesInString:body.string options:0 range:NSMakeRange(0, body.length)] reverseObjectEnumerator]) {
        NSAttributedString *l = [[NSAttributedString alloc] initWithString:[body.string substringWithRange:[r rangeAtIndex:1]]
            attributes:@{NSFontAttributeName:f, NSLinkAttributeName:[NSURL URLWithString:[body.string substringWithRange:[r rangeAtIndex:2]]]}];
        [body replaceCharactersInRange:r.range withAttributedString:l];
    }
    [m appendAttributedString:body];
    self.chat.attributedText = m;
    [self.chat scrollRangeToVisible:NSMakeRange(m.length, 0)];
}

- (void)send:(NSString *)q {
    if (!GeminiClient.shared.apiKey.length) { [self append:@"SiriGemini" text:@"No API key yet. Tap Get key, sign in with Google, copy the key, then paste it in Settings > SiriGemini."]; return; }
    [self append:@"You" text:q];
    [self append:@"Gemini" text:@"…"];
    [GeminiClient.shared ask:q completion:^(NSString *t, NSError *e) {
        NSString *reply = t ?: e.localizedDescription ?: @"Error";
        // replace the "…" placeholder
        NSMutableAttributedString *m = [self.chat.attributedText mutableCopy];
        NSRange r = [m.string rangeOfString:@"…\n\n" options:NSBackwardsSearch];
        if (r.location != NSNotFound) [m deleteCharactersInRange:r];
        self.chat.attributedText = m;
        [self appendBodyOnly:reply];
        [self showImages:reply];
        AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:reply];
        [self.tts speakUtterance:u];
    }];
}
- (void)appendBodyOnly:(NSString *)t {
    NSMutableAttributedString *m = [self.chat.attributedText mutableCopy];
    [m appendAttributedString:[[NSAttributedString alloc] initWithString:[t stringByAppendingString:@"\n\n"]
        attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:UIColor.labelColor}]];
    self.chat.attributedText = m;
    [self.chat scrollRangeToVisible:NSMakeRange(m.length, 0)];
}
- (void)showImages:(NSString *)t {
    for (UIView *v in self.imgs.subviews) [v removeFromSuperview];
    NSDataDetector *d = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    __block CGFloat x = 8;
    [d enumerateMatchesInString:t options:0 range:NSMakeRange(0, t.length) usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *s) {
        NSString *ext = m.URL.pathExtension.lowercaseString;
        if (![@[@"png",@"jpg",@"jpeg",@"gif",@"webp"] containsObject:ext]) return;
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(x, 6, 108, 108)];
        iv.contentMode = UIViewContentModeScaleAspectFill; iv.clipsToBounds = YES; iv.layer.cornerRadius = 8;
        [self.imgs addSubview:iv]; x += 116; self.imgs.contentSize = CGSizeMake(x, 120);
        [[[NSURLSession sharedSession] dataTaskWithURL:m.URL completionHandler:^(NSData *data, id r, id e) {
            UIImage *img = data ? [UIImage imageWithData:data] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{ iv.image = img; });
        }] resume];
    }];
}
@end

@implementation GeminiOverlay { UIWindow *_win; GeminiVC *_vc; }
+ (instancetype)shared { static GeminiOverlay *o; static dispatch_once_t t; dispatch_once(&t, ^{ o = [GeminiOverlay new]; }); return o; }

- (void)askAndShow:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *pd = [[NSUserDefaults alloc] initWithSuiteName:@"com.sirigemini.tweak"];
        BOOL fresh = ![pd objectForKey:@"newChat"] || [pd boolForKey:@"newChat"];
        if (self->_win && fresh) [self->_vc close];   // new chat every time
        if (!self->_win) {
            UIWindowScene *sc = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
                if ([s isKindOfClass:UIWindowScene.class]) { sc = (UIWindowScene *)s; break; }
            self->_win = sc ? [[UIWindow alloc] initWithWindowScene:sc] : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
            self->_win.windowLevel = UIWindowLevelAlert + 1000;
            self->_vc = [GeminiVC new];
            __weak GeminiOverlay *w = self;
            self->_vc.onClose = ^{ GeminiOverlay *o = w; if (!o) return; o->_win.hidden = YES; o->_win = nil; o->_vc = nil; [GeminiClient.shared reset]; };
            self->_win.rootViewController = self->_vc;
        }
        self->_win.hidden = NO;
        [self->_win makeKeyAndVisible];
        [self->_vc send:text];
    });
}
@end
