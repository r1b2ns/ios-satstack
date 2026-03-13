import Foundation

/// Connection status of the Kyoto CBF light client node.
///
/// Shared between the main app target and the widget extension so both
/// can read and display the current node state.
enum KyotoNodeConnectionStatus: String, Codable {

    /// The node has connected to peers and synced successfully.
    case connected

    /// The node is starting up and connecting to peers.
    case connecting

    /// The node is not running.
    case disconnected
}
