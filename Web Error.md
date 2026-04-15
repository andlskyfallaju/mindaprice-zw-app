# Web Errors Log (MindaPrice ZW)

This document tracks lingering issues identified during the initial web deployment and execution.

## 1. Hero Tag Collisions
> [!WARNING]
> **Error**: `Another exception was thrown: There are multiple heroes that share the same tag within a subtree.`

- **Context**: Occurs when multiple `Hero` widgets with the same `tag` exist in the same widget tree (e.g., in a list of products where every product uses the same avatar or logo placeholder).
- **Impact**: Breaks transitions and causes console spam.
- **Potential Fix**: Ensure hero tags are unique (e.g., use product IDs or index-based tags).

## 2. Network Image Rate Limiting (429)
> [!IMPORTANT]
> **Error**: `NetworkImageLoadException was thrown resolving an image stream (HTTP 429 Too Many Requests)`

- **Context**: Likely triggered by the sudden loading of many high-res product images from Cloudinary or another asset host.
- **Impact**: Images fail to display, replaced by error icons/empty space.
- **Potential Fix**: Implement image caching or batch loading; check Cloudinary rate limits.

## 3. Service Worker MIME Type Error
> [!CAUTION]
> **Error**: `Failed to register a ServiceWorker: The script has an unsupported MIME type ('text/html').`

- **Context**: The browser tried to load `firebase-messaging-sw.js` but the server (or development environment) returned an HTML page (likely a 404 handler) instead of the JavaScript file.
- **Impact**: Firebase Cloud Messaging (notifications) will not work on the web.
- **Potential Fix**: Ensure `firebase-messaging-sw.js` exists in the `web/` directory and is correctly served.

## 4. Generic Hero Animation Warnings
- Multiple repetitions of the Hero tag error suggest this is widespread across several screens (Marketplace, Profile, etc.).

---
*Logged on: 2026-04-15*
