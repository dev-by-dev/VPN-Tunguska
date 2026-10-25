import Foundation
import SwiftUI
import TunguskaCore

@main
struct TunguskaApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        #if DEBUG
        KeychainSelfTest.runIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup("Tunguska") {
            RootView()
                .environmentObject(appModel)
                .frame(minWidth: 980, minHeight: 660)
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appModel)
        } label: {
            Label("Tunguska", systemImage: appModel.tunnelController.statusImageName)
        }
        .menuBarExtraStyle(.window)
    }
}
