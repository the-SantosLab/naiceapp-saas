import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: WatchDataStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BriefingView()
                .tabItem { Label("Briefing", systemImage: "sun.max.fill") }
                .tag(0)

            MoodLogView()
                .tabItem { Label("Mood", systemImage: "face.smiling") }
                .tag(1)

            HabitsView()
                .tabItem { Label("Habits", systemImage: "figure.walk") }
                .tag(2)

            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(3)

            ChatView()
                .tabItem { Label("Agent", systemImage: "brain.head.profile") }
                .tag(4)
        }
        .onAppear {
            WatchConnectivityManager.shared.requestData()
        }
    }
}