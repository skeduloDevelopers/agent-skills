# Navigation & UI

The WebView is a single full-screen surface. There are no host-provided navigation chrome, headers, or tab bars. Build them inside the bundle.

## In-bundle stack navigation

A simple stack-based navigation pattern that mirrors native push / pop animations.

### NavigationContext

```jsx
// src/navigation/NavigationContext.jsx
import { createContext, useContext, useState, useRef, useCallback, useEffect } from 'react'

const DURATION = 350
const NavigationContext = createContext(null)

export function useNavigation() {
  const ctx = useContext(NavigationContext)
  if (!ctx) throw new Error('useNavigation must be used within a NavigationProvider')
  return ctx
}

export function NavigationProvider({ routes, initialRoute, onExit }) {
  const [stack, setStack] = useState([initialRoute])
  const currentRoute = stack[stack.length - 1]
  const canGoBack = stack.length > 1

  const navigate = useCallback((routeName) => {
    if (!routes[routeName]) {
      console.warn(`[Navigation] Unknown route: ${routeName}`)
      return
    }
    setStack(prev => [...prev, routeName])
  }, [routes])

  const goBack = useCallback(() => {
    if (!canGoBack) {
      onExit?.()                   // root → exit form
      return
    }
    setStack(prev => prev.slice(0, -1))
  }, [canGoBack, onExit])

  // Forward Android hardware-back into the stack.
  useEffect(() => {
    window.onNativeBackPress = () => goBack()
    return () => { delete window.onNativeBackPress }
  }, [goBack])

  const Component = routes[currentRoute]?.component
  return (
    <NavigationContext.Provider value={{ navigate, goBack, currentRoute, canGoBack, stack }}>
      {Component && <Component />}
    </NavigationContext.Provider>
  )
}
```

Use it from `App.jsx`:

```jsx
import { mexBridge } from '@skedulo/mexwex-bridge'
import { NavigationProvider } from './navigation/NavigationContext'

const routes = {
  home:        { title: 'Form',         component: HomePage },
  attachments: { title: 'Attachments',  component: AttachmentsPage },
}

export default function App() {
  return (
    <NavigationProvider
      routes={routes}
      initialRoute="home"
      onExit={() => mexBridge.exit()}
    />
  )
}
```

`onExit` runs when the user presses back from the root — closes the form via the bridge.

### Why hook `window.onNativeBackPress`?

The native host catches the Android hardware back button and forwards it into the WebView by calling `window.onNativeBackPress()` if defined. Register a handler so back behaves correctly. iOS swipe-back is handled the same way — the host calls the same global.

## Header

The host does not render a header. If you want one, build it. A minimal Skedulo-flavoured header:

```jsx
export function Header({ title, onBack }) {
  return (
    <>
      <div style={{
        position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100,
        background: '#0461cb', paddingTop: 'env(safe-area-inset-top)',
        display: 'flex', alignItems: 'center', height: '44px',
        paddingLeft: 'env(safe-area-inset-left)', paddingRight: 'env(safe-area-inset-right)',
      }}>
        <button onClick={onBack} style={{ background: 'none', border: 'none', color: '#fff', padding: '0 8px', cursor: 'pointer' }}>
          <svg width="12" height="20" viewBox="0 0 12 20" fill="none">
            <path d="M10 2L2 10L10 18" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </button>
        <span style={{ color: '#fff', fontSize: '17px', fontWeight: 600, position: 'absolute', left: 0, right: 0, textAlign: 'center', pointerEvents: 'none' }}>
          {title}
        </span>
      </div>
      <div style={{ height: 'calc(44px + env(safe-area-inset-top))', flexShrink: 0 }} />
    </>
  )
}
```

Critical bits:

- `paddingTop: 'env(safe-area-inset-top)'` keeps the header out of the iOS notch / Dynamic Island.
- The trailing spacer `<div>` reserves layout height equal to the fixed header so page content doesn't slide under it.

## Layout: full height, scrollable content, no overscroll

WebViews on iOS and Android default to elastic overscroll, which feels wrong for app UI. Clamp it.

```jsx
<div style={{
  display: 'flex',
  flexDirection: 'column',
  height: '100vh',
  background: '#F3F5F9',
  overscrollBehavior: 'none',  // no rubber-banding
  overflow: 'hidden',
}}>
  <Header title="Form" onBack={onBack} />
  <div style={{ flex: 1, overflowY: 'auto', overscrollBehavior: 'none' }}>
    {/* scrollable page content */}
  </div>
</div>
```

`overscrollBehavior: 'none'` blocks pull-to-refresh and bounce. `overflowY: 'auto'` on the inner div is the only scroller — page content scrolls under the fixed header.

## Breeze UI conventions

`@skedulo/breeze-ui-react` provides Skedulo's mobile design system as React components. Use them rather than hand-rolling buttons / inputs / cards.

```jsx
import {
  GlobalStyles, Button, Card, CardHeader, CardFooter, Column,
  Heading, InputText, InputTextarea, Alert, ButtonGroup, InputCheckbox,
} from '@skedulo/breeze-ui-react'

<GlobalStyles>
  <Card>
    <CardHeader>
      <Heading level={2} size="m">Section</Heading>
    </CardHeader>
    <Column>
      <InputText
        label="Name"
        labelPosition="top"
        size="full"
        value={name}
        onInputChange={(e) => setName(e.detail.value)}
      />
      <Button buttonType="primary" onClick={onSave} loading={saving}>
        Save
      </Button>
      {status && <Alert type={status.type} clearable onClear={() => setStatus(null)}>{status.message}</Alert>}
    </Column>
  </Card>
</GlobalStyles>
```

Notes on the API:

- Wrap the app once in `<GlobalStyles>` — it injects design tokens and base CSS variables.
- Inputs are **web components** under the hood; their change event is `onInputChange` and the value is on `e.detail.value` (not `e.target.value`).
- `Button` accepts `loading` and `disabled` — use them while bridge or API calls are in flight.
- `Alert type` is `'info' | 'success' | 'warning' | 'error'`.
- Override Breeze CSS variables with the `style` prop when you must (`'--brz-input-textarea-min-height': '120px'`), but try to live with the defaults — they encode mobile-correct sizing.

## Page container pattern

Wrap each page in a small container so spacing is consistent.

```jsx
function PageContainer({ children }) {
  return (
    <div style={{ padding: '8px', maxWidth: '480px', margin: '0 auto' }}>
      <Column>{children}</Column>
    </div>
  )
}
```

## Showing authenticated images

Skedulo attachment URLs require a bearer token — a plain `<img src>` will 401. See `references/attachments-and-signatures.md` for the `AuthImage` component pattern.

## State management

For small forms, `useState` and `useReducer` are enough. For multi-page forms with shared data:

- **Zustand** is a good fit — small, no provider boilerplate, plays well with the navigation pattern above.
- **Context + useReducer** also works without an extra dep.

Avoid Redux unless the form is genuinely complex; the bundle cost is rarely worth it on a single-form WebView.

## Accessibility quick wins

- Use Breeze components — they have correct labels, focus rings, and aria attributes built in.
- Set `<html lang="...">` in `index.html` to the form's locale.
- Make tap targets at least 44×44 px (Breeze defaults already meet this).
- Run the form once with VoiceOver / TalkBack before shipping.
