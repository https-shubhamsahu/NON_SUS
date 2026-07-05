# NO SUS — Zero-Cost Cloud Storage Strategy

**The big-brain trick:** you don't hunt for *one* provider with a huge free tier.
You stack many providers' free tiers behind **one storage abstraction** that
presents a single logical namespace. Because almost every provider speaks the
**S3 API**, one client works against all of them — you just swap the endpoint and
credentials per bucket. A tiny index table remembers which provider holds each
object.

This is purely **additive**. It does **not** touch the existing AES upload /
download / sharing flow. It ships as an *optional* new backend behind a flag.

---

## 1. The free tiers worth stacking (verify current terms before relying on them)

| Provider | Free storage | Egress notes | S3-compatible |
|---|---|---|---|
| **Cloudflare R2** | ~10 GB | **$0 egress, ever** | Yes |
| **Backblaze B2** | ~10 GB | free egress up to 3× stored/mo; free to Cloudflare | Yes |
| **Scaleway** (EU) | ~75 GB | generous free egress | Yes |
| **Storj** (decentralized) | ~25 GB historically | ~25 GB egress/mo | Yes |
| **iDrive e2** | ~10 GB | limited | Yes |
| **Filebase** (IPFS) | ~5 GB | limited | Yes |
| **Supabase Storage** (already in app) | ~1 GB | ~5 GB egress | Supabase API |
| **Google Drive** (already in app via drive-proxy) | 15 GB / account | via Drive API | Drive API |

Stack the S3-compatible ones and you cross **100 GB free** without spending a
rupee. The two you already use (Supabase + Google Drive) are extra headroom.

> Free tiers change and accounts can be suspended. **Never keep the only copy of
> important data on a single free tier.** Treat this as cheap bulk capacity, not
> a durability guarantee. Keep the AES layer so no provider ever sees plaintext.

---

## 2. Architecture: one abstraction, many buckets

```
          Flutter (existing AES-encrypted bytes)
                        │
             StorageRouter (new, flag-gated)
                        │
        ┌───────────────┼───────────────┬────────────┐
     R2 bucket      B2 bucket       Scaleway      Storj …
        │               │               │            │
        └────── Supabase table: storage_objects (the index) ──────┘
             logical_path → (provider, bucket, object_key, size)
```

Two rules make this safe and simple:

1. **The index is the source of truth.** A Supabase table maps every logical
   path to the provider that physically holds it. Reads/deletes look up the row
   first, then hit that provider. Never "guess" a provider.
2. **One S3 client, N configs.** R2/B2/Scaleway/Storj/iDrive/Filebase all accept
   the S3 SigV4 protocol. You keep a list of `S3Endpoint { name, endpoint,
   bucket, accessKey, secretKey, freeBytesRemaining }` and pick one at write
   time.

### Routing policies (pick one)

- **Fill-and-overflow (recommended):** write to the cheapest-egress provider
  (R2) until its free tier is ~80% full, then overflow to the next. Keeps hot
  data on the $0-egress bucket.
- **Hash-shard:** `provider = providers[hash(path) % N]`. Even spread, dead
  simple, but hot objects may land on metered-egress buckets.
- **Class-of-service:** thumbnails/previews → R2 (served often, free egress);
  cold archives → Scaleway/Storj (big free tier, rare reads).

---

## 3. Supabase index table (drop-in migration)

```sql
create table if not exists public.storage_objects (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  logical_path  text not null,
  provider      text not null,          -- 'r2' | 'b2' | 'scaleway' | 'storj' ...
  bucket        text not null,
  object_key    text not null,
  size_bytes    bigint not null default 0,
  created_at    timestamptz not null default timezone('utc', now()),
  unique (user_id, logical_path)
);
alter table public.storage_objects enable row level security;
create policy "storage_objects_own" on public.storage_objects
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
```

Provider credentials never go in the app. Keep them as **Edge Function secrets**
and do all uploads/downloads through a `storage-router` Edge Function (same
pattern as `fhe-proxy` and the existing `drive-proxy`). The client sends already
AES-encrypted bytes; the function picks a provider, uploads via S3, and writes
the index row.

---

## 4. Dart interface sketch (behind a flag, additive)

```dart
abstract class BlobStore {
  Future<String> put(String logicalPath, List<int> encryptedBytes); // returns path
  Future<List<int>> get(String logicalPath);
  Future<void> delete(String logicalPath);
}

// Existing behavior is the default. The multi-cloud router is opt-in.
class MultiCloudStore implements BlobStore {
  // Calls the `storage-router` Edge Function, which owns provider selection,
  // S3 credentials, and the storage_objects index. The app stays dumb.
}
```

Gate it exactly like FHE:

```dart
static const bool enableMultiCloudStorage =
    bool.fromEnvironment('STORAGE_MULTICLOUD', defaultValue: false);
```

Existing uploads keep working unchanged; only when the flag is on does new data
route through the multi-cloud path.

---

## 5. Honest trade-offs

- **Operational overhead:** N accounts, N sets of keys, N dashboards to watch.
  Automate free-tier usage alerts.
- **Consistency:** the index must be updated in the same logical step as the
  upload, or you get orphans. Write the row *after* a successful S3 put; run a
  periodic reconciliation sweep.
- **ToS:** splitting *your own app's* data across *your own* free accounts is
  normally fine; reselling storage or creating throwaway accounts to dodge
  limits usually is not. Read each provider's terms.
- **Durability:** free tiers are best-effort. For anything you can't lose, keep
  a second copy (e.g. R2 primary + B2 mirror for critical objects only).
- **Avoid the Telegram/Drive-as-infinite-disk hacks** for production user data —
  they break, rate-limit, and violate ToS. Google Drive via your existing
  service-account proxy is the one "consumer" backend that's legitimate because
  it's a supported API.

**Bottom line:** R2 as the hot, $0-egress primary + Scaleway/Storj/B2 as
cold overflow, all behind a `storage-router` Edge Function with a Supabase
index, gives you 100 GB+ of encrypted capacity for free without touching a line
of the existing upload flow.

Sources: [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/),
[Backblaze B2 pricing](https://www.backblaze.com/cloud-storage/pricing),
[Free S3-compatible storage 2026 (Rilavek)](https://rilavek.com/resources/free-s3-compatible-object-storage-2026),
[Object storage comparison 2026 (Mixpeek)](https://mixpeek.com/blog/object-storage-comparison-2026)
