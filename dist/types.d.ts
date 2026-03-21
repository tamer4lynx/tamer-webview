import type { BaseEvent, CSSProperties } from '@lynx-js/types';
export type WebViewProps = {
    uri?: string;
    html?: string;
    baseUrl?: string;
    injectedJavaScript?: string;
    injectedJavaScriptBeforeContentLoaded?: string;
    javaScriptEnabled?: boolean;
    messagingEnabled?: boolean;
    userAgent?: string;
    style?: string | CSSProperties;
    className?: string;
    id?: string;
    bindload?: (e: BaseEvent<'load', {
        url: string;
        title: string;
        loading: boolean;
        canGoBack: boolean;
        canGoForward: boolean;
    }>) => void;
    binderror?: (e: BaseEvent<'error', {
        domain?: string;
        code?: number;
        description?: string;
    }>) => void;
    bindmessage?: (e: BaseEvent<'message', {
        data: string;
    }>) => void;
};
//# sourceMappingURL=types.d.ts.map