import SwiftUI

@main
struct EntryLogApp: App {

    var body: some Scene {
        WindowGroup("Entry Log") {
            EntryListView()
                .frame(minWidth: 460, minHeight: 420)
        }
        .defaultSize(width: 620, height: 760)
        .commands {
            // Nothing here creates documents.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
