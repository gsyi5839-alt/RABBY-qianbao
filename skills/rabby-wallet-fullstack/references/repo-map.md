# Repo map (Rabby 0.93.77)

## Surfaces
- src/: browser extension (MV3) code
  - src/ui/: extension UI
  - src/background/: background service
  - src/content-script/: content scripts
- apps/web: Vite + React 18 web wallet
- apps/admin: Vite + React 18 admin console
- apps/api: Express API server
- packages/shared: shared types and utilities
- packages/ui: shared UI tokens and components
- docs/ui-ux-design.md: UI/UX migration spec (web/admin)

## Common clients
- apps/web/src/services/client.ts and apps/web/src/services/api/*
- apps/admin/src/services/client.ts and apps/admin/src/services/admin.ts

## Build/test commands
- yarn dev / yarn web:dev / yarn admin:dev / yarn api:dev
- yarn test / yarn lint:fix
- Node >= 22, Yarn 1.22.22
