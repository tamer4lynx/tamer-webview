#import "TamerWebViewElement.h"

#import <Lynx/LynxEvent.h>
#import <Lynx/LynxPropsProcessor.h>
#import <Lynx/LynxUIMethodProcessor.h>
#import <WebKit/WebKit.h>

static NSString *const kMessageHandlerName = @"ReactNativeWebView";
static NSString *const kDefaultUA =
    @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 "
     "(KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1";

// Polyfill injected at document-start so window.ReactNativeWebView.postMessage is always available.
static NSString *const kBridgePolyfill =
    @"(function(){"
     "if(window.ReactNativeWebView&&window.ReactNativeWebView._tamerBridgeInstalled)return;"
     "window.ReactNativeWebView={"
     "  _tamerBridgeInstalled:true,"
     "  postMessage:function(d){"
     "    window.webkit.messageHandlers.ReactNativeWebView.postMessage(String(d));"
     "  }"
     "};"
     "})();";

@interface TamerWebViewWeakScriptDelegate : NSObject <WKScriptMessageHandler>
@property(nonatomic, weak) TamerWebViewElement *owner;
@end

@interface TamerWebViewHostView : UIView
@property(nonatomic, weak) WKWebView *hostedWebView;
@end

@implementation TamerWebViewHostView

- (void)layoutSubviews {
  [super layoutSubviews];
  self.hostedWebView.frame = self.bounds;
}

@end

@interface TamerWebViewElement () <WKNavigationDelegate, WKUIDelegate>
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, copy, nullable) NSString *uri;
@property(nonatomic, copy, nullable) NSString *html;
@property(nonatomic, copy, nullable) NSString *baseUrl;
@property(nonatomic, copy, nullable) NSString *injectedJS;
@property(nonatomic, copy, nullable) NSString *injectedJSBeforeLoad;
@property(nonatomic, assign) BOOL javaScriptEnabled;
@property(nonatomic, assign) BOOL messagingEnabled;
@property(nonatomic, copy, nullable) NSString *userAgentOverride;
@property(nonatomic, strong) TamerWebViewWeakScriptDelegate *scriptBridge;
- (void)handleScriptMessageBody:(id)body;
@end

@implementation TamerWebViewWeakScriptDelegate

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  TamerWebViewElement *owner = self.owner;
  if (owner == nil) return;
  if (![message.name isEqualToString:kMessageHandlerName]) return;
  [owner handleScriptMessageBody:message.body];
}

@end

@implementation TamerWebViewElement

- (instancetype)init {
  self = [super init];
  if (self) {
    _javaScriptEnabled = YES;
    _messagingEnabled = YES;
  }
  return self;
}

- (void)emitEvent:(NSString *)name detail:(NSDictionary *)detail {
  LynxDetailEvent *eventInfo =
      [[LynxDetailEvent alloc] initWithName:name targetSign:self.sign detail:detail];
  [self.context.eventEmitter dispatchCustomEvent:eventInfo];
}

- (void)handleScriptMessageBody:(id)body {
  NSString *dataStr = @"";
  if ([body isKindOfClass:[NSString class]]) {
    dataStr = (NSString *)body;
  } else if (body != nil) {
    dataStr = [body description];
  }
  [self emitEvent:@"message" detail:@{@"data" : dataStr}];
}

- (void)applyContent {
  if (self.webView == nil) return;
  NSString *u = self.uri;
  if ([u isKindOfClass:[NSString class]] && u.length > 0) {
    NSURL *url = [NSURL URLWithString:u];
    if (url != nil) {
      NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
      [self.webView loadRequest:req];
    }
    return;
  }
  NSString *h = self.html;
  if ([h isKindOfClass:[NSString class]] && h.length > 0) {
    NSString *base = self.baseUrl;
    NSURL *baseURL = ([base isKindOfClass:[NSString class]] && base.length > 0)
        ? [NSURL URLWithString:base]
        : nil;
    [self.webView loadHTMLString:h baseURL:baseURL];
  }
}

- (UIView *)createView {
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

  WKPreferences *prefs = [[WKPreferences alloc] init];
  if (@available(iOS 14.0, *)) {
    config.defaultWebpagePreferences.allowsContentJavaScript = self.javaScriptEnabled;
  } else {
    prefs.javaScriptEnabled = self.javaScriptEnabled;
  }
  config.preferences = prefs;

  WKUserContentController *ucc = [[WKUserContentController alloc] init];

  // Bridge polyfill — injected at document-start in all frames
  WKUserScript *polyfillScript = [[WKUserScript alloc]
      initWithSource:kBridgePolyfill
       injectionTime:WKUserScriptInjectionTimeAtDocumentStart
    forMainFrameOnly:NO];
  [ucc addUserScript:polyfillScript];

  // injectedJavaScriptBeforeContentLoaded
  if (self.injectedJSBeforeLoad.length > 0) {
    WKUserScript *beforeScript = [[WKUserScript alloc]
        initWithSource:[NSString stringWithFormat:@"(function(){\n%@\n})();", self.injectedJSBeforeLoad]
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:YES];
    [ucc addUserScript:beforeScript];
  }

  if (self.messagingEnabled) {
    self.scriptBridge = [[TamerWebViewWeakScriptDelegate alloc] init];
    self.scriptBridge.owner = self;
    [ucc addScriptMessageHandler:self.scriptBridge name:kMessageHandlerName];
  }

  config.userContentController = ucc;

  WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
  wv.navigationDelegate = self;
  wv.UIDelegate = self;
  wv.backgroundColor = [UIColor clearColor];
  wv.opaque = NO;
  wv.scrollView.backgroundColor = [UIColor clearColor];
  if (@available(iOS 11.0, *)) {
    wv.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  }
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  if (@available(iOS 13.0, *)) {
    wv.scrollView.automaticallyAdjustsScrollIndicatorInsets = NO;
  }
#endif

  NSString *ua = self.userAgentOverride.length > 0 ? self.userAgentOverride : kDefaultUA;
  wv.customUserAgent = ua;

  self.webView = wv;
  [self applyContent];

  TamerWebViewHostView *host = [[TamerWebViewHostView alloc] initWithFrame:CGRectZero];
  host.clipsToBounds = YES;
  host.hostedWebView = wv;
  [host addSubview:wv];
  return host;
}

- (void)layoutDidFinished {
  [super layoutDidFinished];
  self.webView.frame = self.view.bounds;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  // injectedJavaScript runs after page finishes
  if (self.injectedJS.length > 0) {
    NSString *wrapped = [NSString stringWithFormat:@"(function(){\n%@\n})();", self.injectedJS];
    [webView evaluateJavaScript:wrapped completionHandler:nil];
  }
  [self emitEvent:@"load"
           detail:@{
             @"url"          : webView.URL.absoluteString ?: @"",
             @"title"        : webView.title ?: @"",
             @"loading"      : @NO,
             @"canGoBack"    : @(webView.canGoBack),
             @"canGoForward" : @(webView.canGoForward),
           }];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  [self emitEvent:@"error"
           detail:@{
             @"domain"      : error.domain ?: @"",
             @"code"        : @(error.code),
             @"description" : error.localizedDescription ?: @"",
           }];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
  [self emitEvent:@"error"
           detail:@{
             @"domain"      : error.domain ?: @"",
             @"code"        : @(error.code),
             @"description" : error.localizedDescription ?: @"",
           }];
}

#pragma mark - Props

LYNX_PROP_SETTER("uri", setUriProp, NSString *) {
  self.uri = value ?: @"";
  [self applyContent];
}

LYNX_PROP_SETTER("html", setHtmlProp, NSString *) {
  self.html = value ?: @"";
  [self applyContent];
}

LYNX_PROP_SETTER("baseUrl", setBaseUrlProp, NSString *) {
  self.baseUrl = value ?: @"";
  [self applyContent];
}

LYNX_PROP_SETTER("injectedJavaScript", setInjectedJSProp, NSString *) {
  self.injectedJS = value ?: @"";
}

LYNX_PROP_SETTER("injectedJavaScriptBeforeContentLoaded", setInjectedJSBeforeLoadProp, NSString *) {
  self.injectedJSBeforeLoad = value ?: @"";
}

LYNX_PROP_SETTER("javaScriptEnabled", setJavaScriptEnabledProp, NSNumber *) {
  self.javaScriptEnabled = value != nil ? value.boolValue : YES;
}

LYNX_PROP_SETTER("messagingEnabled", setMessagingEnabledProp, NSNumber *) {
  self.messagingEnabled = value != nil ? value.boolValue : YES;
}

LYNX_PROP_SETTER("userAgent", setUserAgentProp, NSString *) {
  self.userAgentOverride = (value.length > 0) ? value : nil;
  if (self.webView != nil) {
    self.webView.customUserAgent = self.userAgentOverride ?: kDefaultUA;
  }
}

#pragma mark - UI Methods

LYNX_UI_METHOD(reload) {
  [self.webView reload];
  callback(kUIMethodSuccess, nil);
}

LYNX_UI_METHOD(goBack) {
  if (self.webView.canGoBack) [self.webView goBack];
  callback(kUIMethodSuccess, nil);
}

LYNX_UI_METHOD(goForward) {
  if (self.webView.canGoForward) [self.webView goForward];
  callback(kUIMethodSuccess, nil);
}

LYNX_UI_METHOD(injectJavaScript) {
  NSString *script = params[@"script"];
  if (![script isKindOfClass:[NSString class]] || script.length == 0) {
    callback(kUIMethodParamInvalid, @{@"message" : @"missing script"});
    return;
  }
  [self.webView
      evaluateJavaScript:script
       completionHandler:^(id _Nullable result, NSError *_Nullable error) {
         if (error) {
           callback(kUIMethodOperationError, error.localizedDescription);
         } else {
           callback(kUIMethodSuccess, nil);
         }
       }];
}

/** Send a message to the web page — the page receives it as a `message` event on `window`. */
LYNX_UI_METHOD(postMessage) {
  NSString *data = params[@"data"];
  if (![data isKindOfClass:[NSString class]]) {
    callback(kUIMethodParamInvalid, @{@"message" : @"missing data"});
    return;
  }
  // JSON-encode the data string so it survives arbitrary characters safely.
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[data] options:0 error:nil];
  NSString *jsonArray = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  // jsonArray is e.g. ["hello world"] — extract element 0 for a safe JS string literal.
  NSString *script = [NSString stringWithFormat:
      @"(function(){"
       "var d = %@[0];"
       "try{"
       "window.dispatchEvent(new MessageEvent('message',{data:d}));"
       "}catch(e){"
       "var evt=document.createEvent('MessageEvent');"
       "evt.initMessageEvent('message',true,true,d,'','',window,null);"
       "window.dispatchEvent(evt);"
       "}"
       "})();",
      jsonArray];
  [self.webView evaluateJavaScript:script completionHandler:^(id _Nullable r, NSError *_Nullable e) {
    callback(kUIMethodSuccess, nil);
  }];
}

LYNX_UI_METHOD(loadUrl) {
  NSString *urlStr = params[@"url"];
  if (![urlStr isKindOfClass:[NSString class]] || urlStr.length == 0) {
    callback(kUIMethodParamInvalid, @{@"message" : @"missing url"});
    return;
  }
  NSURL *url = [NSURL URLWithString:urlStr];
  if (url == nil) {
    callback(kUIMethodParamInvalid, @{@"message" : @"invalid url"});
    return;
  }
  [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
  callback(kUIMethodSuccess, nil);
}

LYNX_UI_METHOD(stopLoading) {
  [self.webView stopLoading];
  callback(kUIMethodSuccess, nil);
}

- (void)dealloc {
  if (_webView != nil && _messagingEnabled) {
    [_webView.configuration.userContentController
        removeScriptMessageHandlerForName:kMessageHandlerName];
  }
}

@end
