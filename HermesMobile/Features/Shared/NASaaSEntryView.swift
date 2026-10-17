import SwiftUI

struct NASaaSEntryView: View {
    @Bindable var authManager: AuthManager
    @StateObject private var saasAuth = NASaaSAuth.shared

    var body: some View {
        Group {
            if saasAuth.isLoggedIn {
                ContentView(authManager: authManager)
            } else {
                NALoginView()
            }
        }
    }
}