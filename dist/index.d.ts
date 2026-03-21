import { useRef } from '@lynx-js/react';
import type { NodesRef } from '@lynx-js/types';
import './webview-jsx';
import type { WebViewProps } from './types';
export type { WebViewProps } from './types';
export type WebViewRef = {
    /** Inject and run a JS string in the current page context. */
    injectJavaScript: (script: string) => void;
    /** Send a message to the page — the page receives it as `window.addEventListener('message', ...)`. */
    postMessage: (data: string) => void;
    reload: () => void;
    goBack: () => void;
    goForward: () => void;
    stopLoading: () => void;
    loadUrl: (url: string) => void;
};
/** Returns a ref object whose `.current` exposes imperative WebView methods. */
export declare function useWebViewRef(): ReturnType<typeof useRef<NodesRef>> & {
    current: NodesRef | null;
};
/**
 * Convenience helper to call a WebView UI method via a NodesRef.
 * Mirrors how react-native-webview exposes `.injectJavaScript()` on a ref.
 */
export declare function callWebViewMethod(ref: {
    current: NodesRef | null;
}, method: string, params?: Record<string, unknown>): void;
export declare function WebView(props: WebViewProps): import("@lynx-js/react").JSX.Element;
//# sourceMappingURL=index.d.ts.map