//
//  CbfClient+Extensions.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 7/30/25.
//

import BitcoinDevKit
import Foundation

enum CbfClientEvents {
    case progress(UInt32, Double?)
    case blockReceived(String)
    case connectionsMet
    case successfulHandshake
}

extension NSNotification.Name {
    static let cbfClientConnected = NSNotification.Name("cbfClientConnected")
    static let cbfClientDisconnected = NSNotification.Name("cbfClientDisconnected")
}

extension CbfClient {
    // Track monitoring tasks per client for clean cancellation
    private static var monitoringTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private static var warningTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private static var heartbeatTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private static var lastInfoAt: [ObjectIdentifier: Date] = [:]
    private static let monitoringTasksQueue = DispatchQueue(label: "space.cbf.monitoring.tasks")

    static func createComponents(
        wallet: BitcoinDevKit.Wallet,
        scanType: ScanType,
        peers: [Peer],
        handleEvent: @escaping @Sendable (CbfClientEvents?) -> Void
    ) -> (client: CbfClient, node: CbfNode) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let path = documentsDir.appendingPathComponent("kyoto").path
        
        let network = wallet.network()
        let dataDir = path
        Log.print.info("[Kyoto] Preparing CBF components – network: \(String(describing: network)), dataDir: \(dataDir), peers: \(peers.count), scanType: \(String(describing: scanType))")

        let components = CbfBuilder()
            .scanType(scanType: scanType)
            .dataDir(dataDir: dataDir)
            .peers(peers: peers)
            .build(wallet: wallet)

        components.node.run()

        components.client.startBackgroundMonitoring(handleEvent: handleEvent)

        return (client: components.client, node: components.node)
    }

    func startBackgroundMonitoring(
        handleEvent: @escaping @Sendable (CbfClientEvents?) -> Void
    ) {
        let id = ObjectIdentifier(self)

        let task = Task { [self] in
            while true {
                if Task.isCancelled { break }
                do {
                    let info = try await self.nextInfo()
                    CbfClient.monitoringTasksQueue.sync { Self.lastInfoAt[id] = Date() }
                    switch info {
                    case .progress(let chainHeight, let filtersDownloadedPercent):
                        Log.print.info("[Kyoto] Progress — height: \(chainHeight), filters: \(filtersDownloadedPercent)%")
                        handleEvent(.progress(chainHeight, Double(filtersDownloadedPercent)))
                        
                        NotificationCenter.default.post(name: .cbfClientConnected, object: nil)

                    case .blockReceived(let blockHash):
                        Log.print.info("[Kyoto] Block received — hash: \(blockHash)")
                        handleEvent(.blockReceived(blockHash))

                    case .connectionsMet:
                        Log.print.info("[Kyoto] Connections met — peer threshold reached")
                        handleEvent(.connectionsMet)
                        NotificationCenter.default.post(name: .cbfClientConnected, object: nil)

                    case .successfulHandshake:
                        Log.print.info("[Kyoto] Successful handshake with peer")
                        handleEvent(.successfulHandshake)
                        NotificationCenter.default.post(name: .cbfClientConnected, object: nil)
                        
                    }
                } catch is CancellationError {
                    break
                } catch {
                    // ignore
                }
            }
        }

        Self.monitoringTasksQueue.sync {
            Self.monitoringTasks[id] = task
            Self.lastInfoAt[id] = Date()
        }

        // Heartbeat task to signal idleness while awaiting Info events
        let heartbeat = Task {
            while true {
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                var idleFor: TimeInterval = 0
                CbfClient.monitoringTasksQueue.sync {
                    if let last = Self.lastInfoAt[id] { idleFor = Date().timeIntervalSince(last) }
                }
            }
        }

        Self.monitoringTasksQueue.sync {
            Self.heartbeatTasks[id] = heartbeat
        }

        // Minimal warnings listener for visibility while syncing
        let warnings = Task { [self] in
            while true {
                if Task.isCancelled { break }
                do {
                    let warning = try await self.nextWarning()
                    switch warning {
                    case .needConnections:
                        Log.print.info("[Kyoto] Need more connections")
                        NotificationCenter.default.post(name: .cbfClientDisconnected, object: nil)
                        
                    case let .transactionRejected(wtxid, reason):
                        if let reason {
                            Log.print.warning("[Kyoto] Rejected tx \(wtxid): \(reason)")
                        } else {
                            Log.print.warning("[Kyoto] Rejected tx \(wtxid)")
                        }
                    default:
                        break
                    }
                } catch is CancellationError {
                    break
                } catch {
                    // ignore
                }
            }
        }

        Self.monitoringTasksQueue.sync {
            Self.warningTasks[id] = warnings
        }
    }

    func stopBackgroundMonitoring() {
        let id = ObjectIdentifier(self)
        NotificationCenter.default.post(name: .cbfClientDisconnected, object: nil)
        Self.monitoringTasksQueue.sync {
            guard let task = Self.monitoringTasks.removeValue(forKey: id) else { return }
            task.cancel()
            if let hb = Self.heartbeatTasks.removeValue(forKey: id) { hb.cancel() }
            if let wt = Self.warningTasks.removeValue(forKey: id) { wt.cancel() }
            Self.lastInfoAt.removeValue(forKey: id)
        }
    }

    static func cancelAllMonitoring() {
        NotificationCenter.default.post(name: .cbfClientDisconnected, object: nil)
        Self.monitoringTasksQueue.sync {
            for (_, task) in Self.monitoringTasks { task.cancel() }
            for (_, wt) in Self.warningTasks { wt.cancel() }
            for (_, hb) in Self.heartbeatTasks { hb.cancel() }
            Self.monitoringTasks.removeAll()
            Self.warningTasks.removeAll()
            Self.heartbeatTasks.removeAll()
            Self.lastInfoAt.removeAll()
        }
    }
}
