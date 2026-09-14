---
category: Burn
---
A QR code of a share link, drawn on a canvas in the browser. The link is never sent anywhere to make the code.

## Usage

```tsx
<div className="p-1.5 bg-white rounded-lg">
  <ShareQr value={link} size={108} />
</div>
```

- `value` is the text to encode, normally the Burn share link. With an empty value the canvas stays blank.
- `size` is the canvas size in px (default 112). BurnTool uses 108 inside a white `p-1.5 rounded-lg` frame.
- The code is black on white, so keep the white frame on dark grounds.
