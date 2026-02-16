# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rabby Wallet is a multi-chain crypto wallet with browser extension, web, API, and iOS mobile implementations in a monorepo structure.

**Node Version**: >=22 (using Yarn 1.22.22)

## Monorepo Structure

```
Rabby-0.93.77/
├── src/                    # Browser extension (main product)
├── apps/
│   ├── web/               # Web wallet frontend (Vite + React 18)
│   ├── api/               # Backend API (Express + TypeScript)
│   └── admin/             # Admin dashboard (Vite + React 18)
├── mobile/ios/            # iOS native app (SwiftUI)
├── packages/
│   └── shared/            # Shared types, constants, utils
└── docs/                  # Architecture and development docs
```

## Common Commands

### Browser Extension (Main Product)

```bash
# Development build with hot reload (Chrome MV3)
yarn dev:hot

# Development build with file watching
yarn build:dev

# Production build
yarn build:pro

# Debug build
yarn build:debug

# Linting and fixing
yarn lint:fix

# Run tests
yarn test
```

**Loading extension in Chrome:**
1. Build with `yarn build:dev` or `yarn build:pro`
2. Open `chrome://extensions/`
3. Enable "Developer mode"
4. Click "Load unpacked" and select the `dist/` folder

### Web App (apps/web)

```bash
# Development server (runs on http://localhost:5173)
yarn --cwd apps/web dev

# Production build
yarn --cwd apps/web build

# Preview build
yarn --cwd apps/web preview
```

### API Backend (apps/api)

```bash
# Development server with auto-reload (runs on http://localhost:3001)
yarn --cwd apps/api dev

# Build TypeScript
yarn --cwd apps/api build

# Production start
yarn --cwd apps/api start
```

### Admin Dashboard (apps/admin)

```bash
# Development server (runs on http://localhost:5174)
yarn --cwd apps/admin dev

# Production build
yarn --cwd apps/admin build
```

### iOS Mobile App (mobile/ios)

```bash
# Build and run in simulator
cd mobile/ios
./build_and_run.sh

# Or use Xcode directly
open RabbyMobile.xcworkspace
```

Build using workspace: `RabbyMobile.xcworkspace` (NOT .xcodeproj)
Scheme: `RabbyMobile`
Destination: iOS Simulator

### Shared Package

```bash
# Build shared package (required before building other apps)
yarn --cwd packages/shared build

# Or from root
yarn shared:build
```

**Important**: Always build `packages/shared` first when:
- Starting fresh development
- Modifying types/constants in shared package
- Other apps show "Cannot find module '@rabby/shared'" errors

## Browser Extension Architecture

The extension consists of 4 separate script contexts:

### 1. `background.js`
- Handles async requests and encryption
- Stores keyrings, passwords, and preferences in Chrome local storage
- Controllers:
  - `walletController`: Exposes methods to UI via `runtime.getBackgroundPage`
  - `providerController`: Handles dapp requests

### 2. `content-script`
- Injected at `document_start`
- Bridges `pageProvider.js` and `background.js`
- Uses `broadcastChannel` for communication

### 3. `pageProvider.js`
- Injected into dapp context
- Mounts `window.ethereum`
- Sends requests to content-script via `broadcastChannel`

### 4. UI Scripts
- Shared by 3 pages with different HTML templates:
  - `popup.html`: Extension icon popup
  - `notification.html`: Dapp permission requests
  - `index.html`: Full tab view

**Key Services** (in `src/background/service/`):
- `keyring/`: HD and simple keyrings
- `openapi.ts`: API client and type definitions
- `preference.ts`: User settings
- `transaction.ts`: Transaction signing and tracking
- `bridge.ts`: Cross-chain bridge integration
- `gasAccount.ts`: Gas account management

## TypeScript Path Aliases

```typescript
"@rabby/shared"     → "./packages/shared/src"
"@/utils"           → "./src/utils"
"@/*"               → "./src/*"
"ui/*"              → "./src/ui/*"
"background/*"      → "./src/background/*"
"consts"            → "./src/constant/index"
"assets"            → "./src/ui/assets"
```

## Web App Architecture (apps/web)

See `apps/web/CONVENTIONS.md` for detailed conventions.

**Key Patterns:**
- **State Management**: Zustand (NOT Redux)
- **Routing**: React Router 6
- **Styling**: Tailwind CSS utility-first
- **API Client**: Centralized in `services/api/` using fetch
- **Internationalization**: JSON-based via `i18n/` directory

**Directory Structure:**
```
apps/web/src/
├── types/              # TypeScript types (re-exports @rabby/shared)
├── constants/          # App constants
├── utils/              # Utility functions
├── services/
│   ├── api/           # API clients (balance, token, chain, swap, bridge)
│   ├── keyring/       # HD and simple keyrings
│   └── storage/       # Storage abstraction
├── store/             # Zustand stores (account, chain, preference, transaction)
├── hooks/             # React hooks (useWallet, useCurrentAccount, etc.)
├── components/
│   ├── ui/            # Base UI components
│   ├── address/       # Address display components
│   ├── chain/         # Chain selector/icon
│   ├── token/         # Token input/selector
│   └── layout/        # Page layouts
├── pages/             # Page components organized by feature
└── i18n/              # Internationalization files
```

**Import Order:**
1. React / third-party libraries
2. @rabby/shared types
3. services / store
4. hooks
5. components
6. utils / constants
7. styles

**Component Naming:**
- Files: `camelCase.ts` (utils) / `PascalCase.tsx` (components)
- Components: `PascalCase`
- Hooks: `use` prefix + `camelCase`
- Constants: `UPPER_SNAKE_CASE`

## iOS Development

**Tech Stack**: SwiftUI, native iOS 16+

**Architecture:**
- Core logic: `mobile/ios/RabbyMobile/Core/`
- Views: `mobile/ios/RabbyMobile/Views/`
- Utils: `mobile/ios/RabbyMobile/Utils/`

**Key Managers:**
- `KeyringManager`: Account and key management (BIP39/BIP44)
- `NetworkManager`: Chain and RPC management
- `TransactionManager`: Transaction signing and history
- `StorageManager`: Secure storage (Keychain)
- `BiometricAuthManager`: Face ID / Touch ID
- `LocalizationManager`: JSON-based i18n (15 languages, live switching)
- `OpenAPIService`: API client matching extension functionality

**Localization:**
- Uses custom JSON-based system (NOT NSLocalizedString)
- Supports app-internal language switching without restart
- Shares translation files with extension
- 15 supported languages: en, zh-CN, zh-HK, ja, ko, de, es, fr-FR, pt, pt-BR, ru, tr, vi, id, uk-UA
- See `mobile/ios/LOCALIZATION_GUIDE.md` for implementation guide

**Important:**
- Always use `RabbyMobile.xcworkspace`, not `.xcodeproj`
- CocoaPods dependencies managed via Podfile
- Run `pod install` after checking out or updating dependencies

## Development Workflow

### Initial Setup

```bash
# 1. Install dependencies
yarn install

# 2. Build shared package (required)
yarn shared:build

# 3. Start development
yarn dev:hot           # Extension
yarn web:dev          # Web app
yarn api:dev          # API server
yarn admin:dev        # Admin dashboard
```

### After Modifying Shared Package

```bash
# Rebuild shared
yarn shared:build

# Restart dependent apps (web/api/admin will auto-reload if running)
```

### Parallel Development

Run in separate terminals:
```bash
# Terminal 1
yarn api:dev

# Terminal 2
yarn web:dev

# Terminal 3
yarn admin:dev
```

## Production Server & Deployment

### Server Connection

**SSH Access:**
```bash
# Server IP: 154.89.152.172
# SSH Port: 33216 (NOT default 22)
# Username: root

ssh -p 33216 root@154.89.152.172
```

**Important**: Always use port **33216** for SSH connections to the production server.

### Deployment Configuration

**Server Location**: `/root/projects/RABBY-qianbao/`

**Running Services (PM2):**
```bash
# View all services
pm2 list

# API service
pm2 restart rabby-api
pm2 logs rabby-api

# Check service status
pm2 status rabby-api
```

**Nginx Configuration**: `/etc/nginx/sites-available/bocail.com`

### Production URLs

- **Main Website**: https://bocail.com
- **Admin Dashboard**: https://bocail.com/admin
- **API Endpoint**: https://bocail.com/api/

**Admin Login Credentials:**
- Username: `1019683427`
- Password: `xie080886`
- Role: `super_admin`

### Database Configuration

**PostgreSQL Database:**
```bash
# Database: rabby_db
# User: rabby_user
# Password: rabby_password_2024
# Host: localhost
# Port: 5432

# Connect to database
psql -U rabby_user -d rabby_db
```

**Important Tables:**
- `admins`: Admin users with roles (admin, super_admin)
- `dapps`: DApp directory
- `security_rules`: Security rules and alerts
- `wallets`: Wallet backup data (if implemented)

### Common Deployment Tasks

**Update API Code:**
```bash
ssh -p 33216 root@154.89.152.172

cd /root/projects/RABBY-qianbao/apps/api
# Make changes to dist files or rebuild
pm2 restart rabby-api
pm2 logs rabby-api --lines 50
```

**Update Admin Frontend:**
```bash
# Build locally
cd /Users/macbook/Downloads/Rabby-0.93.77/apps/admin
yarn build

# Upload to server
scp -P 33216 -r dist/* root@154.89.152.172:/root/projects/RABBY-qianbao/apps/admin/dist/

# No restart needed (static files)
```

**Update Nginx Configuration:**
```bash
ssh -p 33216 root@154.89.152.172

nano /etc/nginx/sites-available/bocail.com
nginx -t  # Test configuration
systemctl reload nginx
```

**Database Migration:**
```bash
ssh -p 33216 root@154.89.152.172

cd /root/projects/RABBY-qianbao/apps/api/db/migrations
psql -U rabby_user -d rabby_db -f 001_migration.sql
```

### Troubleshooting

**Check Logs:**
```bash
# PM2 logs
pm2 logs rabby-api

# Nginx access logs
tail -f /var/log/nginx/access.log

# Nginx error logs
tail -f /var/log/nginx/error.log

# System logs
journalctl -u nginx -f
```

**Common Issues:**

1. **403 Forbidden on Admin APIs**
   - Check `auth.js` middleware supports `super_admin` role
   - Verify JWT token is valid and not expired
   - Solution: Update `adminRequired` function to accept both `admin` and `super_admin`

2. **API Not Responding**
   - Check PM2 status: `pm2 status rabby-api`
   - Restart: `pm2 restart rabby-api`
   - Check logs: `pm2 logs rabby-api --lines 100`

3. **Database Connection Errors**
   - Verify PostgreSQL is running: `systemctl status postgresql`
   - Check credentials in `/root/projects/RABBY-qianbao/apps/api/dist/apps/api/src/config.js`
   - Test connection: `psql -U rabby_user -d rabby_db`

4. **Static Files Not Loading**
   - Check Nginx configuration for correct `alias` paths
   - Verify file permissions: `ls -la /root/projects/RABBY-qianbao/apps/admin/dist/`
   - Clear browser cache or use incognito mode

## Manifest Types

The extension supports both Chrome MV3 and Firefox MV2:

```bash
# Chrome Manifest V3 (default)
MANIFEST_TYPE=chrome-mv3 yarn build:dev

# Firefox Manifest V2
MANIFEST_TYPE=firefox-mv2 yarn build:dev
```

## Testing

```bash
# Run all tests
yarn test

# Extension-specific tests
cd src && yarn test
```

## Important Files & Locations

**Extension Core:**
- Type definitions: `src/background/service/openapi.ts`
- Constants: `src/constant/` (re-exports from `@rabby/shared`)
- UI views: `src/ui/views/`
- UI components: `src/ui/component/`
- Hooks: `src/ui/hooks/`

**Web App Reference:**
- Extension patterns to reference: `src/ui/` structure
- API types source: `src/background/service/openapi.ts`
- Web conventions: `apps/web/CONVENTIONS.md`

**Shared Types:**
- Chain enums: `packages/shared/src/constants/chains.ts`
- Common types: `packages/shared/src/types/index.ts`

## Build Output

- Extension: `dist/`
- Web app: `apps/web/dist/`
- API: `apps/api/dist/`
- Admin: `apps/admin/dist/`
- Shared: `packages/shared/dist/`
- iOS: `~/Library/Developer/Xcode/DerivedData/RabbyMobile-*/`

## Known Issues

- Extension webpack build has compatibility issues with terser-webpack-plugin (affects production builds, not TypeScript compilation)
- Always build shared package before other apps to avoid import errors
- iOS BIP44 derivation and transaction signing need EIP-155 compliance fixes (see `mobile/ios/code_fixes_summary.md`)

## Additional Documentation

- Architecture: `docs/new-architecture.md`
- Development setup: `docs/development-setup.md`
- Extension background: `docs/background.md`
- Extension UI: `docs/ui.md`
- Translation guide: `docs/translation.md`
- iOS localization: `mobile/ios/LOCALIZATION_GUIDE.md`
- iOS testing: `mobile/ios/TESTING_GUIDE.md`
- Migration status: `docs/migration-gap-report.md`
