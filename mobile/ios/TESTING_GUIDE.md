# iOS App Testing Guide - Mnemonic & Password Debugging

## Current Status ✅

- **Build Status**: ✅ Successful
- **App Installed**: ✅ iPhone 17 Pro Simulator
- **Bundle ID**: `com.bocail.pay`
- **App Running**: ✅ PID 8934

---

## Issues Fixed in This Session

### 1. ✅ WalletConnectURI Deprecation Warning
**File**: `RabbyMobile/Core/WalletConnectManager.swift:156`

**Problem**: Using deprecated `init?(string:)` initializer

**Fix**: Switched to throwing initializer:
```swift
do {
    guard let parsedURI = try WalletConnectURI(string: uri) else {
        throw WCError.invalidURI
    }
    walletConnectURI = parsedURI
} catch {
    print("[WC] Failed to parse WalletConnect URI: \(error)")
    throw WCError.invalidURI
}
```

### 2. ✅ rsync Sandbox Permission Errors
**Problem**: CocoaPods framework copy phase failing with sandbox permission errors

**Fix**:
- Disabled `ENABLE_USER_SCRIPT_SANDBOXING` in `Podfile`
- Disabled in `RabbyMobile.xcodeproj/project.pbxproj`

### 3. 🔍 Deep Debugging for Mnemonic Issue
**Problem**: "Mnemonic phrase is not set for this keyring" error

**Changes Made** (from previous session):
1. Added validation to prevent empty string mnemonics:
```swift
guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
    throw KeyringError.mnemonicNotSet
}
```

2. Added comprehensive logging with emoji markers:
- 🔵 HDKeyring initialization
- 🟡 addAccounts() calls
- 🟢 serialize() operations
- ❌ Error conditions

**Files Modified**:
- `RabbyMobile/Core/KeyringManager.swift`
- `RabbyMobile/Views/Wallet/CreateWalletView.swift`

---

## Testing the Mnemonic Issue

### Test Scenario 1: Create New Wallet

1. **Open the app** on iPhone 17 Pro simulator
2. **Tap "Create Wallet"**
3. **Set password**: Use a simple password like `12345678`
4. **Backup phrase**: Write down the 12 words shown
5. **Verify phrase**: Select words in correct order (now supports duplicate words!)
6. **Complete creation**

**Expected Logs**:
```
[HDKeyring] 🔵 Initializing with mnemonic: 12 words
[HDKeyring] 🔵 Mnemonic stored: YES
[HDKeyring] 🟡 addAccounts called, count: 1
[HDKeyring] 🟡 Current mnemonic status: SET
[HDKeyring] 🟢 serialize() called
[KeyringManager] Persisting 1 keyring(s)...
[KeyringManager] Vault saved successfully
[CreateWallet] ✓ Wallet creation complete
```

### Test Scenario 2: Import Wallet with Your Mnemonic

**Your Mnemonic**: `wine paper pony prefer west include artist sting rage beef slice lens`

1. **Open the app**
2. **Choose "Import Wallet"** (if available)
3. **Enter mnemonic**: `wine paper pony prefer west include artist sting rage beef slice lens`
4. **Set password**: e.g., `test1234`
5. **Complete import**

### Test Scenario 3: Unlock Wallet After Creation

1. **Create or import a wallet** (Scenario 1 or 2)
2. **Close/restart the app**
3. **Enter the password** you set earlier
4. **Verify unlock succeeds**

**Expected Logs**:
```
[KeyringManager] Verifying password...
[KeyringManager] Password verified successfully
[KeyringManager] Unlocking wallet...
[HDKeyring] Deserialized with 1 accounts, mnemonic: 12 words
```

---

## How to Monitor Logs

### Method 1: Real-time Log Stream (Recommended)

Open a new terminal and run:
```bash
log stream --predicate 'process == "RabbyMobile"' --style compact --level debug | grep -E "(🔵|🟡|🟢|❌|KeyringManager|HDKeyring|CreateWallet|Mnemonic|ERROR)"
```

Then perform actions in the app and watch the logs appear.

### Method 2: Check Recent Logs

```bash
log show --predicate 'process == "RabbyMobile"' --last 5m --style compact | grep -E "(🔵|🟡|🟢|❌|KeyringManager|HDKeyring)"
```

### Method 3: Xcode Console

1. Open Xcode
2. Window → Devices and Simulators
3. Select iPhone 17 Pro
4. Click "Open Console" button
5. Filter for "RabbyMobile"

---

## Expected Behavior

### ✅ Wallet Creation Should:
1. Generate valid 12-word mnemonic
2. Allow verification even with duplicate words
3. Save mnemonic securely to Keychain
4. Create account successfully
5. Display success message

### ✅ Password Verification Should:
1. Accept correct password
2. Reject incorrect password
3. Unlock wallet successfully
4. Restore mnemonic from Keychain

### ❌ Should NOT Happen:
1. "Words are not in the correct order" error when words are correct
2. "Mnemonic phrase is not set" error after creation
3. "Incorrect password" error with correct password
4. Empty mnemonic being saved

---

## Debug Log Legend

| Emoji | Stage | Meaning |
|-------|-------|---------|
| 🔵 | Initialization | HDKeyring created with mnemonic |
| 🟡 | Usage | addAccounts() or other operations |
| 🟢 | Persistence | Serialization/saving to Keychain |
| ❌ | Error | Something went wrong |

---

## Quick Launch Commands

### Rebuild and Run:
```bash
cd /Users/macbook/Downloads/Rabby-0.93.77/mobile/ios
xcodebuild -workspace RabbyMobile.xcworkspace -scheme RabbyMobile -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install "iPhone 17 Pro" ~/Library/Developer/Xcode/DerivedData/RabbyMobile-*/Build/Products/Debug-iphonesimulator/RabbyMobile.app
xcrun simctl launch "iPhone 17 Pro" com.bocail.pay
```

### Clean Wallet Data (Reset):
```bash
xcrun simctl uninstall "iPhone 17 Pro" com.bocail.pay
xcrun simctl install "iPhone 17 Pro" ~/Library/Developer/Xcode/DerivedData/RabbyMobile-*/Build/Products/Debug-iphonesimulator/RabbyMobile.app
xcrun simctl launch "iPhone 17 Pro" com.bocail.pay
```

---

## Next Steps

1. **Test wallet creation** and watch for debug logs
2. **Test password unlock** after creation
3. **Report any errors** you see with the debug logs
4. If issues persist, I'll add even more detailed logging

The app is ready to test! 🚀
