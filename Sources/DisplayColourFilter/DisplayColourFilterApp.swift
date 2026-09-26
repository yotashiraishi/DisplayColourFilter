import SwiftUI

@main
struct DisplayColourFilterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Display Colour Filter", systemImage: "camera.filters") {
            MenuView(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = FilterController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 終了したらシステム設定どおりの状態に戻す
        controller.restoreSystemState()
    }
}
