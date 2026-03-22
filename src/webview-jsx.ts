/// <reference types="@lynx-js/types" />
import type { WebViewProps } from './types'

declare module '@lynx-js/types' {
  interface IntrinsicElements {
    webview: WebViewProps
  }
}
