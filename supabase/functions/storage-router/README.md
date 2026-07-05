# NO SUS Storage Router

`storage-router` is an optional Edge Function that stores already-protected file
bytes across S3-compatible free tiers while keeping Supabase as the metadata and
authorization source of truth.

Existing Supabase Storage remains the default. Enable this path in Flutter with:

```powershell
flutter run --dart-define-from-file=.env --dart-define=STORAGE_MULTICLOUD=true
```

## Secrets

Set one JSON secret containing the providers. Credentials stay server-side.

```powershell
supabase secrets set STORAGE_ROUTER_PROVIDERS='[
  {
    "name": "r2",
    "endpoint": "https://<account-id>.r2.cloudflarestorage.com",
    "region": "auto",
    "bucket": "nosus-hot",
    "accessKeyId": "<r2-access-key>",
    "secretAccessKey": "<r2-secret-key>",
    "freeBytes": 10737418240,
    "priority": 100
  },
  {
    "name": "b2",
    "endpoint": "https://s3.<region>.backblazeb2.com",
    "region": "<region>",
    "bucket": "nosus-cold",
    "accessKeyId": "<b2-key-id>",
    "secretAccessKey": "<b2-application-key>",
    "freeBytes": 10737418240,
    "priority": 50
  }
]'
```

## Deploy

```powershell
supabase db push
supabase functions deploy storage-router
```

## Behavior

- `POST /upload` verifies the user JWT, checks group membership, creates the
  `secure_files` row, uploads to the selected provider, and writes
  `storage_objects`.
- `GET /download` verifies group membership, resolves the indexed provider, and
  streams bytes back with no-store cache headers.
- `DELETE /delete` allows the file owner or group admin to delete the provider
  object. The Flutter repository still deletes the normal `secure_files` row
  afterward.

Provider choice is fill-and-overflow: highest-priority provider first until the
indexed active bytes reach 80% of its configured `freeBytes`, then overflow.
