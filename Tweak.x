#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "GeminiOverlay.h"

// Siri still hears you normally and the heard text is never changed.
// We only read it, ask Gemini, and show/speak Gemini's answer.
static NSString *TextFrom(id r) {
    if ([r isKindOfClass:NSString.class]) return r;
    for (NSString *n in @[@"bestTextInterpretation", @"formattedText", @"text", @"stringValue"]) {
        SEL sel = NSSelectorFromString(n);
        if ([r respondsToSelector:sel]) {
            id v = ((id (*)(id, SEL))objc_msgSend)(r, sel);
            if ([v isKindOfClass:NSString.class] && [(NSString *)v length]) return v;
        }
    }
    return nil;
}

static NSString *lastText; static NSDate *lastTime;

// ⚠️ VERIFY on iOS 16.7: the method name and how TextFrom() gets the transcript.
%hook AFConnection
- (void)speechRecognized:(id)recognition {
    %orig;
    NSLog(@"[SiriGemini] speechRecognized: %@", recognition);   // send me this log line
    NSString *t = TextFrom(recognition);
    if (!t.length) return;
    if ([t isEqualToString:lastText] && [[NSDate date] timeIntervalSinceDate:lastTime] < 5) return; // dedupe
    lastText = t; lastTime = [NSDate date];
    [[GeminiOverlay shared] askAndShow:t];
}
%end
