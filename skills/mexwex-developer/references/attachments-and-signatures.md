# Attachments & Signatures

Both attachments and signatures use the same two-step pattern: **capture** to a local file, then **persist** that file with a parent context.

## The two-step pattern

```text
1. captureAttachments() / captureSignature()
   → opens native picker / signature screen
   → returns { uri, fileName } pointing at a local file on disk
   → returns null if the user cancels

2. addAttachments() / addSignature()
   → takes the captured file and a parentContextId
   → persists into the native attachment store, queued for upload
```

The two-step split lets you preview the captured file in your UI before persisting (or discard it if the user cancels review).

## Attachments

### Capture

```jsx
const result = await mexBridge.captureAttachments({
  sources: ['camera', 'photoLibrary', 'files'],
})

if (!result) {
  // user cancelled — nothing to do
  return
}

// result is PickedFile[]: [{ uri: '...', fileName: '...' }, ...]
```

Behaviour:

- Pass a single source (e.g. `['camera']`) to skip the chooser sheet and open that picker directly.
- Pass multiple sources to show a bottom-sheet chooser first.
- No timeout — the user can take as long as they like.

### Persist

```jsx
await mexBridge.addAttachments({
  attachments: result,             // the PickedFile[] from capture
  parentContextId: jobId,
  categoryName: 'site_photos',     // optional
})
```

Once `addAttachments` resolves, the attachment is in the native store and queued for upload on the next sync.

### Display

To show attachments under a record:

```jsx
const { attachments } = await mexBridge.getAttachmentsByParentId(jobId)
// attachments is AttachmentMetadata[]: [{ uid, fileName, downloadURL?, status?, contentType? }, ...]
```

This is a one-shot fetch — re-call after `addAttachments` / `removeAttachment` to refresh.

`status` is one of `'uploading' | 'uploaded' | 'failed' | ...`. `downloadURL` is only present once the file is uploaded.

### Removing

```jsx
await mexBridge.removeAttachment(attachment.uid)
```

## Signatures

### Capture

```jsx
const signature = await mexBridge.captureSignature({ enableFullName: true })

if (!signature) {
  // user cancelled
  return
}

// signature: { uri, fileName, fullName? }
```

`enableFullName: true` shows a full-name field on the signature screen and returns the entered value in `signature.fullName`. Defaults to `false`.

### Persist

```jsx
await mexBridge.addSignature({
  signature: {
    uri: signature.uri,
    fullName: signature.fullName,
  },
  parentContextId: jobId,
  categoryName: 'sign_off',         // optional
})
```

Note: `addSignature` ignores `signature.fileName` — the native layer generates its own. Pass `uri` and (optionally) `fullName` only.

## Showing authenticated images

Skedulo `downloadURL`s require a bearer token. A plain `<img src={downloadURL}>` will 401 — the browser doesn't attach auth headers to image requests. Fetch the image as a blob with the token, then display via `URL.createObjectURL`.

```jsx
function AuthImage({ src, alt, style }) {
  const [blobUrl, setBlobUrl] = useState(null)
  const [error, setError] = useState(false)
  const urlRef = useRef(null)

  useEffect(() => {
    if (!src) { setError(true); return }
    let cancelled = false

    ;(async () => {
      try {
        const { accessToken } = await mexBridge.getAuthenticationInfo()
        const res = await fetch(src, {
          headers: { Authorization: `Bearer ${accessToken}` },
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const blob = await res.blob()
        if (cancelled) return
        const url = URL.createObjectURL(blob)
        urlRef.current = url
        setBlobUrl(url)
      } catch {
        if (!cancelled) setError(true)
      }
    })()

    return () => {
      cancelled = true
      if (urlRef.current) URL.revokeObjectURL(urlRef.current)
    }
  }, [src])

  if (error) return <div style={{ ...style, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f0f0f0', color: '#888' }}>Failed</div>
  if (!blobUrl) return <div style={{ ...style, background: '#f0f0f0' }} />
  return <img src={blobUrl} alt={alt} style={style} />
}
```

Critical bits:

- `URL.revokeObjectURL` on unmount — without this, blobs leak.
- The `cancelled` flag prevents state updates if React unmounts mid-fetch.
- Cache the access token lightly (per render) but **don't cache it for the whole session** — tokens can rotate.

## Common patterns

### Capture-preview-confirm

Let the user discard a capture before persisting.

```jsx
const [pending, setPending] = useState(null)

const onCapture = async () => {
  const result = await mexBridge.captureAttachments({ sources: ['camera'] })
  if (result) setPending(result)
}

const onConfirm = async () => {
  await mexBridge.addAttachments({ attachments: pending, parentContextId: jobId })
  setPending(null)
}

const onDiscard = () => setPending(null)

return pending
  ? <PreviewSheet files={pending} onConfirm={onConfirm} onDiscard={onDiscard} />
  : <Button onClick={onCapture}>Add photo</Button>
```

### Multi-attach

Capture multiple files in one go (the picker supports multi-select on `photoLibrary` and `files`).

```jsx
const files = await mexBridge.captureAttachments({ sources: ['photoLibrary'] })
if (files?.length) {
  await mexBridge.addAttachments({ attachments: files, parentContextId: jobId })
}
```

### Refresh after change

```jsx
async function refresh() {
  const { attachments } = await mexBridge.getAttachmentsByParentId(jobId)
  setAttachments(attachments)
}

async function onAdd(files) {
  await mexBridge.addAttachments({ attachments: files, parentContextId: jobId })
  await refresh()
}

async function onRemove(uid) {
  await mexBridge.removeAttachment(uid)
  await refresh()
}
```

## Gotchas

- **Don't try to read picked file URIs as text.** They point at native storage and are not readable from JS.
- **Don't keep the picked URI past form lifetime.** It's a temporary local file. After `addAttachments` succeeds, use the returned `uid` (or the next `getAttachmentsByParentId` result) instead.
- **Always pass `parentContextId`.** Otherwise the attachment has no parent and won't appear under any record. For Jobs forms, this is the Job ID from `metadata.contextObjectId`.
- **Status `'uploading'` is normal** — the file is in the native queue, not yet on the server. Show it as pending in your UI; refresh to see it move to `'uploaded'`.
