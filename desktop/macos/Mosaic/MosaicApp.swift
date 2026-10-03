import SwiftUI
@main struct MosaicApp: App {
    var body: some Scene {
        WindowGroup { EditorView().frame(minWidth: 900, minHeight: 620) }
            .defaultSize(width: 1220, height: 820)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}
