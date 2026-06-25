# Bridge API Reference — `@skedulo/mexwex-bridge`

Complete reference for every method on the bridge SDK. All methods return a `Promise`. Errors are standard `Error` objects with descriptive messages.

## Import & instance

```typescript
import { mexBridge } from '@skedulo/mexwex-bridge'
// or:
import { MexBridge } from '@skedulo/mexwex-bridge'
const bridge = new MexBridge()
```

`mexBridge` is a singleton — use it unless you have a specific reason to instantiate.

## Calling environment

The SDK assumes it runs inside a React Native WebView host. If `window.ReactNativeWebView` is undefined, every call rejects with:

```text
Error: [MexBridge] Not running inside a React Native WebView
```

Build for this case in dev — see `project-setup.md` for the fallback pattern.

## Timeouts

- Default per-call timeout: **30 seconds**.
- User-interactive methods (`captureSignature`, `captureAttachments`) have **no timeout** — the user can take arbitrarily long. Do not wrap them in your own timeout.
- `collectTapToPayPayment` uses a longer **120-second** timeout because the payment flow includes hardware tap + processing.
- A timeout rejects with `Error: [MexBridge] Timeout: <method> did not respond within <ms>ms`.

## Error model

Errors thrown by handlers on the native side propagate as `Error` instances on the web side. The `.message` is the native error string. Always `try / catch` around bridge calls.

## Methods

### Form data

#### `getInstanceData(): Promise<any>`

Returns the current form's instance data — an object whose shape matches what `instanceFetch.json` defines (or whatever the platform writes for this form). For most MEXWEX forms, `instanceFetch.json` is empty and you fetch your own data, so this returns an empty object.

```typescript
const data = await mexBridge.getInstanceData()
```

#### `getStaticData(): Promise<any>`

Returns the form's shared / static data — shape from `staticFetch.json`. Typically empty for MEXWEX.

```typescript
const shared = await mexBridge.getStaticData()
```

#### `saveInstanceData(data: any): Promise<boolean>`

Persists the supplied object as the form's instance data. The native layer diffs against the original snapshot and syncs to the server. Returns `true` on success.

```typescript
await mexBridge.saveInstanceData({ status: 'in_progress', notes })
```

Call this whenever the user changes meaningful state — on field blur, on step change, or before exit. Local React state is lost when the form closes.

### Form metadata

#### `getMetadata(): Promise<FormMetadata>`

Returns metadata about the form context — the host loads everything (user, form, timezone, organisation preferences, job / shift) on the first call.

```typescript
interface FormMetadata {
  contextObjectId: string
  packageId: string
  formName?: string
  contextObject?: string
  user?: Record<string, any>
  job?: Record<string, any>
  timezone?: Record<string, any>
}
```

Use `contextObjectId` for the parent record ID (e.g. the Job ID for a Jobs-context form), `contextObject` for the type name (`'Jobs'`, `'Resources'`, `'Shifts'`), `user` for the current user, and `timezone` for tenant timezone settings.

### Authentication

#### `getAuthenticationInfo(): Promise<AuthenticationInfo>`

Returns the current user's auth token and the API base URL. Call this fresh whenever you need to make an authenticated HTTP call — tokens may rotate during a long session.

```typescript
interface AuthenticationInfo {
  accessToken: string
  apiUrl: string
  userId?: string
}

const { accessToken, apiUrl } = await mexBridge.getAuthenticationInfo()
```

See `authentication-and-api.md` for the full pattern.

### Localisation

#### `getLocalizedString(key: string): Promise<string | null>`

Looks up `key` in the form's `static_resources/locales/<lang>.json`. Returns the localised string, or `null` if the key is not found.

```typescript
const label = await mexBridge.getLocalizedString('form.title')
```

Most MEXWEX forms manage their own i18n in JS — this method is mainly useful when you want to share strings between Standard MEX and MEXWEX modes of the same form.

### Mandatory status & exit

#### `sendExtensionMandatoryStatus(isCompleted: boolean): Promise<boolean>`

Tells the host whether the form's mandatory requirements are satisfied. The host gates the "save" button on this — if you never call it, the save button stays dimmed.

```typescript
await mexBridge.sendExtensionMandatoryStatus(allRequiredFieldsFilled)
```

Send `true` when the form is complete enough to save; `false` when something is missing. Call this whenever the answer changes.

#### `exit(): Promise<void>`

Closes the form and returns to the host app. Call from your back-from-root handler, or after a successful save flow.

```typescript
await mexBridge.exit()
```

### Attachments — capture and persist

#### `captureAttachments(params?: CaptureAttachmentsParams): Promise<PickedFile[] | null>`

Opens native pickers (camera / photo library / files) and returns the picked files. Returns `null` if the user cancels. **No timeout.**

```typescript
type AttachmentSource = 'camera' | 'photoLibrary' | 'files'

interface CaptureAttachmentsParams {
  sources?: AttachmentSource[]   // defaults to all three
}

interface PickedFile {
  uri: string
  fileName: string
}

const files = await mexBridge.captureAttachments({ sources: ['camera', 'photoLibrary'] })
```

Behavior notes:

- If only one source is passed, the host opens that picker directly (no chooser sheet).
- Multiple sources show a bottom-sheet chooser first.
- The returned `uri` is a local file URI — not yet persisted to the server.

#### `addAttachments(params: AddAttachmentsParams): Promise<any>`

Persists the picked files to the native attachment layer, associated with a parent context record.

```typescript
interface AddAttachmentsParams {
  attachments: PickedFile[]
  parentContextId: string        // the record the attachments hang off (Job ID, Resource ID, etc.)
  categoryName?: string          // optional grouping label
}

await mexBridge.addAttachments({
  attachments: pickedFiles,
  parentContextId: jobId,
  categoryName: 'site_photos',
})
```

After this call the attachment is queued for upload on the next sync cycle. See `attachments-and-signatures.md` for the full flow.

#### `removeAttachment(attachmentId: string): Promise<boolean>`

Removes an attachment by UID.

```typescript
await mexBridge.removeAttachment(attachment.uid)
```

#### `getAttachment(attachmentId: string): Promise<AttachmentMetadata>`

Fetches metadata for a single attachment by UID.

```typescript
interface AttachmentMetadata {
  uid: string
  fileName: string
  downloadURL?: string
  status?: string                // 'uploading' | 'uploaded' | 'failed' | etc.
  contentType?: string
}

const meta = await mexBridge.getAttachment(uid)
```

The `downloadURL` is a Skedulo signed URL — you still need a bearer token to fetch it (see `authentication-and-api.md`).

#### `getAttachmentsByParentId(parentContextId: string): Promise<AttachmentsByParentIdResult>`

One-shot fetch of all attachments under a parent record.

```typescript
interface AttachmentsByParentIdResult {
  attachments: AttachmentMetadata[]
  parentId: string
}

const { attachments } = await mexBridge.getAttachmentsByParentId(jobId)
```

This is a snapshot — there's no observable. Re-fetch after `addAttachments` / `removeAttachment` to refresh.

### Signatures

#### `captureSignature(options?: CaptureSignatureOptions): Promise<CaptureSignatureResult | null>`

Opens the native signature screen. Returns the captured signature, or `null` if the user cancels. **No timeout.**

```typescript
interface CaptureSignatureOptions {
  enableFullName?: boolean       // show a full-name field on the signature screen
}

interface CaptureSignatureResult {
  uri: string                    // local file path to the captured PNG
  fileName: string               // generated filename — informational only
  fullName?: string              // only present when enableFullName === true
}

const signature = await mexBridge.captureSignature({ enableFullName: true })
if (!signature) { /* cancelled */ }
```

#### `addSignature(params: AddSignatureParams): Promise<any>`

Persists a captured signature to the native attachment layer.

```typescript
interface AddSignatureParams {
  signature: { uri: string; fullName?: string }
  parentContextId: string
  categoryName?: string
}

await mexBridge.addSignature({
  signature: { uri: signature.uri, fullName: signature.fullName },
  parentContextId: jobId,
})
```

The `fileName` returned by `captureSignature` is informational only — `addSignature` ignores it.

### Tap-to-Pay

#### `collectTapToPayPayment(params: TapToPayParams): Promise<TapToPayResult>`

Initiates a Stripe Terminal Tap-to-Pay session on the device. Hardware-backed payment, supported on iPhone (Tap-to-Pay on iPhone) and Android (Tap-to-Pay on Android, where available). 120-second timeout.

```typescript
interface TapToPayParams {
  connectionToken: string        // Stripe Terminal connection token from your backend
  clientSecret: string           // Stripe PaymentIntent client secret from your backend
  locationId: string             // Stripe Terminal location ID
}

interface TapToPayResult {
  success: boolean
  paymentIntentId?: string
  error?: string
}
```

This is a niche capability — most forms will not use it. If you do:

- Your custom-function backend is responsible for creating the Stripe `PaymentIntent`, supplying connection tokens, and verifying the payment server-side after the SDK reports success.
- The SDK does not handle Stripe configuration — for terminal setup, locations, and `PaymentIntent` shape, refer to Stripe's own Terminal documentation.
- Always re-verify payment status server-side; do not trust `success: true` alone for fulfilment decisions.
