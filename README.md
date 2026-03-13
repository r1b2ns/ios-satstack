<p align="center">
  <img src="AppIconDev_Preview_1024x1024.png" width="128" height="128" style="border-radius: 22%;" alt="SatStack App Icon" />
</p>

# SatStack

An iOS app for monitoring Bitcoin transactions in the mempool. Enter a transaction ID and the app starts a **Live Activity** that displays real-time status — confirmations, value, and fee — directly on the Lock Screen and Dynamic Island.

Updates are delivered via **APNs (Apple Push Notification service)**, with no need to keep the connection to the server open.

---

## Screenshots

<p align="center">
  <img src="snapshots/iPhone_6.9_01.png" width="15%" alt="Home" />
  <img src="snapshots/iPhone_6.9_02.png" width="15%" alt="Wallets" />
  <img src="snapshots/iPhone_6.9_03.png" width="15%" alt="Wallet Detail" />
  <img src="snapshots/iPhone_6.9_04.png" width="15%" alt="Send Bitcoin" />
  <img src="snapshots/iPhone_6.9_05.png" width="15%" alt="Settings" />
  <img src="snapshots/iPhone_6.9_06.png" width="15%" alt="Live Activity" />
</p>

| # | Description |
|---|---|
| 1 | **Home** — real-time dashboard with Greed & Fear Index, block height, fee estimates, wallet balance, next halving and BTC price |
| 2 | **Wallets** — list of wallets with aggregated total balance |
| 3 | **Wallet Detail** — imported wallet with balance, latest transactions, Receive and Send actions |
| 4 | **Send Bitcoin** — compose a transaction with recipient address, amount and fee rate (slow / medium / fast) |
| 5 | **Settings** — push notifications, network (mainnet/signet), balance format and preferences |
| 6 | **Live Activity** — real-time transaction tracking on the Lock Screen and Dynamic Island |

---

## Requirements

- Xcode 16+
- iPhone running iOS 17+ (Live Activities do not work on the Simulator)
- [XcodeGen](https://github.com/yonatankra/XcodeGen) installed (`brew install xcodegen`)
- **Apple Developer account** with push notifications capability
- **APNs Key** (`.p8`) generated in the Apple Developer Portal — required by the server to send pushes

> Actual monitoring depends on the **[api-mempool-monitor](https://github.com/rubensmachion/api-mempool-monitor)** server, which watches the blockchain and dispatches notifications via APNs.

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/rubensmachion/ios-mempool-monitor.git
cd ios-mempool-monitor
```

### 2. Set up local configuration

```bash
cp MempoolMonitor/Configs/Local.xcconfig.template MempoolMonitor/Configs/Local.xcconfig
```

Edit `Configs/Local.xcconfig` with your own values:

```
PRODUCT_BUNDLE_IDENTIFIER        = com.yourcompany.satstack
PRODUCT_BUNDLE_IDENTIFIER_WIDGET = com.yourcompany.satstack.widget
PRODUCT_BUNDLE_IDENTIFIER_TESTS  = com.yourcompany.satstack.tests

# api-mempool-monitor server host (without http://)
MEMPOOL_MONITOR_HOST = 192.168.x.x:3000
```

### 3. Generate the Xcode project

```bash
xcodegen generate --spec MempoolMonitor/project.yml
```

### 4. Open in Xcode and run on device

```bash
open MempoolMonitor/SatStack.xcodeproj
```

Select the **SatStack** scheme, connect an iPhone, and run with `⌘R`.

---

## Server

For monitoring to work, the **[api-mempool-monitor](https://github.com/rubensmachion/api-mempool-monitor)** server must be running and configured with:

- The **APNs Key** (`.p8`) generated in the Apple Developer Portal
- Your Apple account's **Team ID** and **Key ID**
- Access to the public [mempool.space](https://mempool.space) API

See the server's README for setup instructions.

---

## Running the tests

```bash
xcodebuild test \
  -project MempoolMonitor/SatStack.xcodeproj \
  -scheme SatStackTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or from Xcode: select the **SatStack** scheme and press `⌘U`.
