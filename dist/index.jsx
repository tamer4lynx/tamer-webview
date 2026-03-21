import { useRef } from '@lynx-js/react';
import './webview-jsx';
/** Returns a ref object whose `.current` exposes imperative WebView methods. */
export function useWebViewRef() {
    return useRef(null);
}
/**
 * Convenience helper to call a WebView UI method via a NodesRef.
 * Mirrors how react-native-webview exposes `.injectJavaScript()` on a ref.
 */
export function callWebViewMethod(ref, method, params) {
    ref.current
        ?.invoke({
        method,
        params: params ?? {},
        success: () => { },
        fail: () => { },
    })
        .exec();
}
export function WebView(props) {
    const { uri, html, baseUrl, injectedJavaScript, injectedJavaScriptBeforeContentLoaded, javaScriptEnabled = true, messagingEnabled = true, userAgent, bindload, binderror, bindmessage, style, className, id, } = props;
    return (<webview uri={uri} html={html} baseUrl={baseUrl} injectedJavaScript={injectedJavaScript} injectedJavaScriptBeforeContentLoaded={injectedJavaScriptBeforeContentLoaded} javaScriptEnabled={javaScriptEnabled} messagingEnabled={messagingEnabled} userAgent={userAgent} bindload={bindload} binderror={binderror} bindmessage={bindmessage} style={style} className={className} id={id}/>);
}
