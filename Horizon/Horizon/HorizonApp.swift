import SwiftUI

@main
struct HorizonApp: App {
    @State private var dashboardMode = DashboardMode()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dashboardMode)
        }
    }
}
