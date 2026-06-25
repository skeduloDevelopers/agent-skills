# Form Lifecycle

The full sequence from "user opens the form" to "user closes the form", and how to wire each step.

## End-to-end sequence

```text
1. User taps the form on a record (e.g. a Job).
2. Host loads the bundled index.html into the WebView.
3. React app boots, mexBridge initialises automatically (constructor wires window.onNativeMessage).
4. App calls getMetadata() once for context.
5. App fetches initial data — either getInstanceData() / getStaticData(), or your own API calls using getAuthenticationInfo().
6. App renders. User edits.
7. App calls saveInstanceData(data) when state should persist (on blur, on step change, or before exit).
8. App calls sendExtensionMandatoryStatus(true) once required fields are satisfied.
9. User finishes. App calls exit() — or the user presses back from the root, your onExit handler calls exit().
```

## Boot

`mexBridge` is a singleton instantiated when the module is imported. Its constructor:

1. Sets `window.onNativeMessage` to a handler that parses native responses and resolves pending promises.
2. Marks the bridge as initialised.

You don't need to call any init method. Just import and use:

```jsx
import { mexBridge } from '@skedulo/mexwex-bridge'
```

## Loading initial state

Pattern: an effect on app mount that loads metadata and any data the form needs.

```jsx
function App() {
  const [metadata, setMetadata] = useState(null)
  const [loadError, setLoadError] = useState(null)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const meta = await mexBridge.getMetadata()
        if (cancelled) return
        setMetadata(meta)
      } catch (e) {
        if (!cancelled) setLoadError(e)
      }
    })()
    return () => { cancelled = true }
  }, [])

  if (loadError) return <ErrorScreen error={loadError} />
  if (!metadata) return <Loading />
  return <FormUI metadata={metadata} />
}
```

The `cancelled` flag prevents state updates if React unmounts mid-fetch (e.g. during dev hot-reload).

## Persisting form state

`saveInstanceData(data)` is the only way to write back to the native cache (and from there, to the server). Local React / Zustand state is **lost** when the form closes.

Two common patterns:

### Continuous save (small forms)

Save on every meaningful change, debounced.

```jsx
const debouncedSave = useDebouncedCallback(async (data) => {
  await mexBridge.saveInstanceData(data)
}, 500)

useEffect(() => {
  debouncedSave(formState)
}, [formState])
```

### Save on transition (multi-step forms)

Save when the user moves between steps, or before exit.

```jsx
const handleNext = async () => {
  await mexBridge.saveInstanceData(formState)
  navigate('next')
}
```

Both are valid — pick one and stick to it. Mixing them is fine but adds bookkeeping.

## Mandatory status

`sendExtensionMandatoryStatus(boolean)` controls the host's save button. If you never call it, the host treats the form as incomplete and the user can't save.

```jsx
useEffect(() => {
  const complete = isFormValid(formState)
  mexBridge.sendExtensionMandatoryStatus(complete)
}, [formState])
```

Call this whenever validity changes. Cheap call — don't bother debouncing.

## Exit

Three ways the form closes:

1. User presses back from the root — your `onExit` handler in the navigation provider calls `mexBridge.exit()`.
2. App finishes a flow (e.g. payment succeeds) and explicitly calls `mexBridge.exit()`.
3. User force-quits the app — no callback fires; `saveInstanceData` writes are durable so partial state is preserved on next open.

```jsx
async function finishAndExit() {
  await mexBridge.saveInstanceData(formState)
  await mexBridge.exit()
}
```

Always save before you exit if you have unpersisted changes.

## Android hardware back button

The host catches Android hardware-back and forwards it into the WebView by calling `window.onNativeBackPress()` if defined. The navigation provider in `navigation-and-ui.md` registers this — when the stack has more than one route, back pops; at the root, it calls `onExit` (which usually calls `mexBridge.exit()`).

If you're not using the navigation provider, register your own:

```jsx
useEffect(() => {
  window.onNativeBackPress = () => {
    if (canGoBack) {
      navigateBack()
    } else {
      mexBridge.exit()
    }
  }
  return () => { delete window.onNativeBackPress }
}, [canGoBack, navigateBack])
```

Without this, the user gets stuck — the OS back gesture does nothing.

## Error handling at lifecycle boundaries

Bridge calls can fail for plenty of reasons (no network on a sync, native module panic, timeout). Always `try / catch` at lifecycle boundaries:

```jsx
async function onSave() {
  try {
    await mexBridge.saveInstanceData(formState)
    setStatus({ type: 'success', message: 'Saved' })
  } catch (e) {
    setStatus({ type: 'error', message: e.message })
    // Do NOT exit — let the user retry.
  }
}
```

Common failure cases:

- Network down during a save → user sees error, can retry. Do not call `exit()`.
- Bridge timeout → tell the user, offer retry.
- Save succeeds but a downstream API call fails → form data is saved; surface the API error separately.

## Long-running operations

For operations that take seconds (Tap-to-Pay, file uploads), give the user constant feedback:

```jsx
<Button buttonType="primary" loading={paying} disabled={paying} onClick={onPay}>
  Pay
</Button>
{processing && <Alert type="info">Processing payment…</Alert>}
```

Disable controls that could fire the same operation again — replays are expensive (duplicate charges, duplicate writes).

## Lifecycle cheat sheet

| Phase | Bridge call | When |
|---|---|---|
| Boot | (auto via import) | Once, at module load |
| Load context | `getMetadata()` | Once, after boot |
| Load data | `getInstanceData()` / API fetch | Once, after metadata |
| Edit | (none) | While user types |
| Persist | `saveInstanceData(data)` | On blur / step / before exit |
| Mandatory | `sendExtensionMandatoryStatus(bool)` | Whenever validity changes |
| Back from root | `exit()` | Via `onExit` |
| Finish | `saveInstanceData` then `exit()` | After flow complete |
