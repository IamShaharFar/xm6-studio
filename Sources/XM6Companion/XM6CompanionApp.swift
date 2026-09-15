import SwiftUI
import AppKit

@main struct XM6CompanionApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("XM6 Studio", id: "main") {
            MainView(model: model)
                .frame(minWidth: 920, minHeight: 680)
                .tint(.teal)
        }
        .defaultSize(width: 1040, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh headphone controls") { model.refresh() }.keyboardShortcut("r")
                Button("Release controls for Sony app") { model.releaseForPhone() }.keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        MenuBarExtra {
            QuickPanel(model: model).tint(.teal)
        } label: {
            HeadphoneArtwork(size: 22).accessibilityLabel("XM6 Studio")
        }.menuBarExtraStyle(.window)
    }
}
