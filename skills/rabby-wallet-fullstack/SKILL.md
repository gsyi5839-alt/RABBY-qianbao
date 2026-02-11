---
name: rabby-wallet-fullstack
description: Full-stack Rabby wallet development and migration across this repo. Use when modifying or migrating features between the browser extension (src/) and the web/admin/API apps (apps/web, apps/admin, apps/api), or when updating shared types/components in packages/shared and packages/ui.
---

# Rabby Wallet Fullstack

## Overview
Use this skill to implement or migrate wallet features from the extension to the web + admin + API stack in this repository. Keep shared logic in packages and follow the UI/UX migration spec.

## Workflow
1. Identify the target surface: extension (src/), web (apps/web), admin (apps/admin), API (apps/api), or shared (packages/shared, packages/ui).
2. Locate the source of truth in the extension (src/ui, src/background, src/utils) and decide what must move to web or API.
3. Map platform differences:
   - Extension storage/message APIs -> REST endpoints + local storage in web.
   - Popup/notification UI -> full-page routes or modals.
4. Update shared types first (packages/shared/src/types) when interfaces change.
5. Implement or update API handlers in apps/api and adjust the client layers:
   - apps/web/src/services/*
   - apps/admin/src/services/*
6. Build/verify the UI against docs/ui-ux-design.md and packages/ui tokens/components.
7. Add tests for behavior changes; keep security constraints (never send raw secrets to server).

## Command hints (run only when needed)
- Extension dev: `yarn dev`
- Web: `yarn web:dev`
- Admin: `yarn admin:dev`
- API: `yarn api:dev`
- Lint/test: `yarn lint:fix`, `yarn test`

## References
- Read `references/repo-map.md` for structure and command map.
- Read `references/extension-to-web.md` for migration patterns and guardrails.
- Use `docs/ui-ux-design.md` for page-by-page UI migration; search by route name or feature.
