import SwiftUI

@main
struct EntryLogApp: App {

    /// Held here rather than in the view so that the menu bar can
    /// reach it: a command has no view to ask.
    @State private var model = EntryLogModel()

    var body: some Scene {
        WindowGroup("Entry Log") {
            EntryListView(model: model)
                .frame(minWidth: 460, minHeight: 420)
        }
        .defaultSize(width: 620, height: 760)
        .commands {
            // Nothing here creates documents.
            CommandGroup(replacing: .newItem) {}

            CommandMenu("View") {

                Button("Larger Text") { model.resize(by: 1) }
                    .keyboardShortcut("+")
                    .disabled(!model.textScale.canGrow)

                Button("Smaller Text") { model.resize(by: -1) }
                    .keyboardShortcut("-")
                    .disabled(!model.textScale.canShrink)

                Button("Actual Size") { model.resetTextSize() }
                    .keyboardShortcut("0")

                Divider()

                Toggle("Demo Data", isOn: $model.isDemo)
                    .keyboardShortcut("d", modifiers: [.command, .option])
            }
        }
    }
}
