import SwiftUI

@main
struct FilescapeApp: App {
    @StateObject private var store = FileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
