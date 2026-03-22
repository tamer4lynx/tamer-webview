# @tamer4lynx/tamer-webview

Embedded in-app WebView for [Lynx](https://lynxjs.org) — **iOS** `WKWebView` and **Android** `android.webkit.WebView`. Registers the native `webview` custom element with a clean, flat prop API modelled after [react-native-webview](https://github.com/react-native-webview/react-native-webview).

## Installation

```bash
npm install @tamer4lynx/tamer-webview@prerelease
```

Then run autolink so native projects pick up `lynx.ext.json`, CocoaPods, and Gradle:

```bash
t4l link
```

> **Requirements**
> - Loading non-HTTPS URLs requires app-side configuration: `NSAppTransportSecurity` on iOS, `android:usesCleartextTraffic` on Android.

## Basic usage

After **`t4l link`**, **`.tamer/tamer-components.d.ts`** pulls in **`webview-jsx.d.ts`** so **`<webview>`** is typed—no side-effect import needed for typings.

```tsx
<webview
  uri="https://example.com"
  style={{ flex: 1, width: '100%' }}
  bindload={(e) => console.log(e.detail.url)}
  bindmessage={(e) => console.log('from page:', e.detail.data)}
/>
```

Load inline HTML instead of a URL:

```tsx
<webview html="<h1>Hello</h1>" baseUrl="https://example.com/" />
```

When both `uri` and `html` are provided, `uri` takes priority.

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `uri` | `string` | — | URL to load |
| `html` | `string` | — | Inline HTML string to load |
| `baseUrl` | `string` | — | Base URL used when loading `html` |
| `javaScriptEnabled` | `boolean` | `true` | Enable/disable JavaScript in the page |
| `injectedJavaScript` | `string` | — | Script evaluated after the page finishes loading |
| `injectedJavaScriptBeforeContentLoaded` | `string` | — | Script evaluated before the page's own scripts run |
| `messagingEnabled` | `boolean` | `true` | Expose `window.ReactNativeWebView.postMessage` to the page |
| `userAgent` | `string` | Chrome Mobile UA | Override the WebView user agent string |
| `style` | `string \| CSSProperties` | — | Lynx style object or class string |
| `className` | `string` | — | CSS class name |
| `id` | `string` | — | Element ID for `lynx.createSelectorQuery()` |
| `bindload` | `(e) => void` | — | Fired when a page finishes loading |
| `binderror` | `(e) => void` | — | Fired on navigation error |
| `bindmessage` | `(e) => void` | — | Fired when the page calls `window.ReactNativeWebView.postMessage(data)` |

## Events

### `bindload`

```tsx
bindload={(e) => {
  const { url, title, loading, canGoBack, canGoForward } = e.detail
}}
```

### `binderror`

```tsx
binderror={(e) => {
  const { description, code, domain } = e.detail
}}
```

### `bindmessage`

Receives messages sent from the page via `window.ReactNativeWebView.postMessage(data)`:

```tsx
bindmessage={(e) => {
  console.log(e.detail.data) // string
}}
```

## Messaging

### Page → app

From inside the web page, call:

```js
window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'hello' }))
```

The app receives it via `bindmessage`.

### App → page

Use `callWebViewMethod` to dispatch a `message` event on `window` inside the page:

```tsx
import { useWebViewRef, callWebViewMethod } from '@tamer4lynx/tamer-webview'

function MyScreen() {
  const wvRef = useWebViewRef()

  const sendToPage = () => {
    callWebViewMethod(wvRef, 'postMessage', { data: JSON.stringify({ type: 'ping' }) })
  }

  return (
    <WebView
      ref={wvRef}
      uri="https://example.com"
      bindmessage={(e) => console.log(e.detail.data)}
    />
  )
}
```

The web page listens with:

```js
window.addEventListener('message', (e) => {
  console.log(e.data)
})
```

## Injecting JavaScript

Run a script after the page loads:

```tsx
<WebView
  uri="https://example.com"
  injectedJavaScript="document.body.style.background = 'red';"
/>
```

Run a script before the page's own scripts execute:

```tsx
<WebView
  uri="https://example.com"
  injectedJavaScriptBeforeContentLoaded="window.__APP_CONFIG__ = { theme: 'dark' };"
/>
```

Inject at any time imperatively:

```tsx
callWebViewMethod(wvRef, 'injectJavaScript', { script: 'window.scrollTo(0, 0)' })
```

## Imperative methods

All methods are called via [`NodesRef.invoke`](https://lynxjs.org/api/lynx-api/nodes-ref/nodes-ref-invoke.html) using `callWebViewMethod`, or directly through `lynx.createSelectorQuery()`.

| Method | Params | Description |
|--------|--------|-------------|
| `reload` | — | Reload the current page |
| `goBack` | — | Navigate back in history |
| `goForward` | — | Navigate forward in history |
| `stopLoading` | — | Abort the current load |
| `loadUrl` | `{ url: string }` | Load a new URL |
| `injectJavaScript` | `{ script: string }` | Evaluate a JS string in the page |
| `postMessage` | `{ data: string }` | Dispatch a `message` event on `window` in the page |

```tsx
import { useWebViewRef, callWebViewMethod } from '@tamer4lynx/tamer-webview'

const ref = useWebViewRef()

callWebViewMethod(ref, 'reload')
callWebViewMethod(ref, 'goBack')
callWebViewMethod(ref, 'loadUrl', { url: 'https://example.com' })
callWebViewMethod(ref, 'injectJavaScript', { script: 'alert("hi")' })
```

## See also

- [Custom Element — Lynx docs](https://lynxjs.org/guide/custom-native-component.md)
- [NodesRef `invoke`](https://lynxjs.org/api/lynx-api/nodes-ref/nodes-ref-invoke.html)
- [react-native-webview](https://github.com/react-native-webview/react-native-webview) — API reference this package is modelled after
