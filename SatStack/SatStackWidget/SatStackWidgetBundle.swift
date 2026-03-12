import WidgetKit
import SwiftUI

@main
struct SatStackWidgetBundle: WidgetBundle {
    var body: some Widget {
        SatStackLiveActivity()
        WalletSyncLiveActivity()
    }
}
