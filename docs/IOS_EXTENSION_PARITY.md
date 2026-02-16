# iOS vs Extension Feature Parity Notes (Rabby-0.93.77)

This repo contains both the browser extension (under `src/`) and an iOS app (under `mobile/ios/`).
This document maps the major wallet features to their extension “source-of-truth” implementations and the
corresponding iOS managers/views, plus the concrete parity fixes applied in iOS.

## Core State + Services

- Storage / persistence
  - Extension: `src/background/service/*` persists via background storage wrappers.
  - iOS: `mobile/ios/RabbyMobile/Core/StorageManager.swift` + `DatabaseManager.swift`.

- Preferences (language, show testnet, whitelist, theme, etc.)
  - Extension: `src/background/service/preference.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/PreferenceManager.swift`

- OpenAPI
  - Extension: `src/background/service/openapi.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/OpenAPIService.swift`

## Networks / Chain List / Testnets

- Chain list (mainnet/testnet/custom)
  - Extension: chain source is composed from built-in chain list + sync/offline chain service:
    - `src/background/service/offlineChain.ts`
    - `src/background/service/syncChain.ts`
  - iOS:
    - `mobile/ios/RabbyMobile/Core/NetworkManager.swift` (`Chain` + `ChainManager`)
    - `mobile/ios/RabbyMobile/Core/SyncChainManager.swift`

- Show testnet toggle
  - Extension: `src/background/service/preference.ts` (`getIsShowTestnet` / `setIsShowTestnet`)
  - iOS: `mobile/ios/RabbyMobile/Core/PreferenceManager.swift` + UI filters:
    - `mobile/ios/RabbyMobile/Views/Common/ChainSelectorSheet.swift`

- Custom testnet
  - Extension: `src/background/service/customTestnet.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/CustomTestnetManager.swift`
  - Parity fix:
    - When add/update/remove (or logo sync) happens, iOS now calls `ChainManager.shared.refreshCustomTestnets()`
      so chain pickers/chain list reflect changes immediately.

## Custom RPC

- Custom RPC set/enable/ping/fallback
  - Extension: `src/background/service/rpc.ts`
  - iOS:
    - `mobile/ios/RabbyMobile/Core/RPCManager.swift`
    - RPC usage: `mobile/ios/RabbyMobile/Core/NetworkManager.swift` + some RPC-based UI fetches
  - Parity fixes:
    - iOS now resolves “effective RPC” (custom RPC when enabled, otherwise default RPC) inside
      `NetworkManager` for all RPC calls.
    - Gas-estimation UI that directly calls RPC (`GasPriceBarView`, `SendTokenView`) now uses effective RPC too.
    - Xcode project now references `RPCManager.swift` (avoids the earlier misnamed source file reference).

## Connected Sites / Permissions

- Connected sites / permissions
  - Extension: `src/background/service/permission.ts` + UI pages for connected sites.
  - iOS:
    - `mobile/ios/RabbyMobile/Core/TransactionWatcherManager.swift` (`DAppPermissionManager`, browser-origin permissions; source of truth)
    - `mobile/ios/RabbyMobile/Core/ConnectedSitesManager.swift` (unified list: browser + WalletConnect)

## WalletConnect

- WalletConnect sessions (create/restore/disconnect)
  - Extension: keyring integration + session service
    - `src/background/service/keyring/*`
    - `src/background/service/session.ts`
  - iOS:
    - `mobile/ios/RabbyMobile/Core/WalletConnectManager.swift`
    - Unified display in `mobile/ios/RabbyMobile/Core/ConnectedSitesManager.swift`

## NFT Gallery

- NFT list / collections
  - Extension: OpenAPI-backed NFT panels (UI) + service queries.
  - iOS:
    - `mobile/ios/RabbyMobile/Core/NFTManager.swift`
    - `mobile/ios/RabbyMobile/Views/NFT/*`

## Lending / Perps / Bridge / Gas Account / Rabby Points

- Lending
  - Extension: `src/background/service/lending.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/LendingManager.swift`

- Perps
  - Extension: `src/background/service/perps.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/PerpsManager.swift`

- Bridge
  - Extension: `src/background/service/bridge.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/BridgeManager.swift`

- Gas Account
  - Extension: `src/background/service/gasAccount.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/GasAccountManager.swift`

- Rabby Points
  - Extension: `src/background/service/rabbyPoints.ts`
  - iOS: `mobile/ios/RabbyMobile/Core/RabbyPointsManager.swift`

## Approvals (Token / NFT) + Signed Messages

- Token/NFT approvals
  - Extension: approvals panel + OpenAPI pages
  - iOS:
    - `mobile/ios/RabbyMobile/Views/Assets/ApprovalsView.swift` (token + NFT approvals)
    - OpenAPI models in `mobile/ios/RabbyMobile/Core/OpenAPIService.swift`

- Signed messages / sign history
  - Extension: `src/background/service/signTextHistory.ts`
  - iOS:
    - `mobile/ios/RabbyMobile/Core/SignHistoryManager.swift`
    - UI: `mobile/ios/RabbyMobile/Views/More/MiscViews.swift` (Signed Messages section)

## Security Engine (Rules + Server Checks + Simulation)

- Extension: `src/background/service/securityEngine.ts` + UI helper `src/ui/utils/securityEngine.ts`
- iOS:
  - `mobile/ios/RabbyMobile/Core/SecurityEngineManager.swift`
  - `mobile/ios/RabbyMobile/Core/OpenAPIService.swift` (wallet check/simulation endpoints)
  - Integrated into approvals/connect/sign flows:
    - `mobile/ios/RabbyMobile/Views/Approval/TransactionApprovalView.swift`
    - `mobile/ios/RabbyMobile/Views/Approval/MessageApprovalView.swift`
    - `mobile/ios/RabbyMobile/Views/DAppBrowser/DAppConnectSheet.swift`
