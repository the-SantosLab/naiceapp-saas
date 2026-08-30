import SwiftUI

@main
struct NAiceWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @StateObject private var dataStore = WatchDataStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .environmentObject(dataStore)
        }
    }
}