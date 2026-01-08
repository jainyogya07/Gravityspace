import SwiftUI

@main
struct GravityPaintApp: App {
    // We will initialize the Physics Engine here later to keep it alive
    // across the app's lifecycle.
    // @StateObject private var engine = SimulationEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Force a dark theme to make the "Space" aesthetic pop
                .preferredColorScheme(.dark) 
                .background(Color.black)
        }
        // Restrict the window size for the MVP so the GPU load is predictable
        // while we test the physics equations.
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Add custom menu commands here later (e.g., "Reset Universe")
            CommandGroup(replacing: .newItem) {
                Button("New Universe") {
                    // Reset logic will go here
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}