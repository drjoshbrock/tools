import SwiftUI

@main
struct MorningDashboardApp: App {
    @State private var dashboardMode = DashboardMode()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dashboardMode)
        }
    }
}
