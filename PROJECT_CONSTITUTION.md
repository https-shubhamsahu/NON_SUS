# NO SUS — PROJECT CONSTITUTION
> Authoritative, permanent guide on product vision, standards, and rules. This document does NOT track active developments or session logs.

---

## 1. Product Vision
**One-Sentence Vision:**
NO SUS is a secure, tracked, and watermarked document-sharing and private messaging platform that gives creators complete visibility and control over external data access without forcing recipients to register or install applications.

**Target Users:**
1. **Professionals**: Sharing highly sensitive documents (NDAs, financial sheets, draft contracts) with external counterparties.
2. **Privacy-Conscious Communicators**: Exchanging one-time secrets (credentials, private messages) over a zero-knowledge, self-destructing channel.
3. **Academic/Institutional Researchers**: Collaborating on sensitive datasets without raw document exposure.

---

## 2. Founder Philosophy
1. **Zero-Budget, Solo Leverage**: Optimize all architecture for a single developer. Maximize generous free tiers (Supabase, Deno, Cloudflare) and avoid operational overhead.
2. **Viral-Growth Distribution**: To access a SecureSend document or open a Burn Note, the recipient must interact with the platform. The product drives its own distribution.
3. **Cryptographic & Technical Honesty**: Copy and brand claims must never outrun the actual cryptography. Do not claim screenshot-proofing on browsers or total server blindness until client-side key generation (M10) is built.

---

## 3. Version 1 Scope
V1 focuses on shipping a highly stable, low-maintenance, polished web-first document link security tool:
* **SecureSend**: Share links with expiration dates, maximum view counts, touch-to-reveal blur, dynamic recipient-email watermarks, and real-time view logs.
* **Burn Notes**: Client-side AES-256 encrypted short text notes with keys kept in the URL hash fragment (zero-knowledge) and destroyed atomically on read.

---

## 4. Long-Term Vision
* **Sealed (Reciprocity-Gated Intent Graph)**: An FHE-backed matching system where mutual intent is evaluated homomorphically over ciphertext, ensuring the server learns nothing unless a match is established.
* **Private AI Memory**: Users query private data pools where the server computes encrypted similarity without seeing the raw query or documents.
* **Selective Truth / Encrypted Policy Engine**: LLMs receive restricted context only after encrypted permission checks have run.

---

## 5. Engineering & Security Philosophy
* **RLS-First Security**: Every table must have Row-Level Security enabled. RLS policies must prevent data leaks even if client applications are fully compromised.
* **Proxy Boundary**: The mobile/web client must never communicate directly with internal compute services (such as FHE containers) or external cloud storage. All requests go through authenticated Supabase Edge Functions.
* **Client-Side Secret Ownership**: For zero-knowledge features, the keys must be generated, stored, and used entirely in the client browser. No key material may ever touch the server database or logs.
* **Shipping Over Perfection**: Focus on production readiness, simplicity, and maintainability over unnecessary optimizations or architectural complexity.

---

## 6. UI Philosophy
* **Monochrome Paper-Ink Identity**: Clean, distraction-free near-black/near-white visuals. Use `NoSusTheme` spacing, radii, and color tokens.
* **Typography**: Outfit for display/headings (bold, large letter-spacing), Inter for body/labels (high readability).
* **Frictionless Onboarding**: Skip gates, magic links, or OTP recovery should guide users into utility as fast as possible.

---

## 7. Coding Standards & Conventions
* **Clean Architecture**: Core and new features must follow strict separation of layers:
  * `Domain`: Pure Dart interfaces, entities, and business logic.
  * `Data`: Supabase implementations, local/network data sources, and models.
  * `Presentation`: Riverpod state providers, controllers, and UI widgets.
* **Service Singletons**: Legacy or auxiliary features may use simple singleton helper services (`SupabaseService`, `AuditService`, `ScreenshotGuard`) injected via Riverpod providers.
* **No Duplicate Migrations**: SQL migrations must be incremental, idempotent, and fully reversible.
* **Remove Dead Code**: Clean up unused imports, deprecated assets, and unreferenced functions after edits.

---

## 8. Non-Negotiable Rules
1. **Never hardcode secrets** (must use `.env` / `--dart-define-from-file`).
2. **Never bypass repositories** in presentation code.
3. **Never allow unauthenticated INSERTs** into system logs or tables except where explicitly designed (e.g. Burn Notes insert, which is encrypted client-side).
4. **No v2/v3 duplicate files** or split branch iterations.
