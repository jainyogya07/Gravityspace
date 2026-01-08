import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var engine = SimulationEngine()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                MetalView(engine: engine)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let u = Float(value.location.x / geometry.size.width)
                                let v = Float(value.location.y / geometry.size.height)
                                engine.brushPosition = SIMD2<Float>(u, v)
                                engine.brushMass = 1.0
                            }
                            .onEnded { _ in engine.brushMass = 0.5 } // Lower gravity on release
                    )
            }
            .edgesIgnoringSafeArea(.all)
            
            // HUD
            VStack(spacing: 8) {
                Text("CONTROLS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                
                HStack(spacing: 20) {
                    ControlBadge(key: "SPACE", action: "Pause")
                    ControlBadge(key: "R", action: "Reset")
                    ControlBadge(key: "1", action: "Neon")
                    ControlBadge(key: "2", action: "Fire")
                    ControlBadge(key: "3", action: "Ice")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.bottom, 40)
        }
        // KEYBOARD LISTENERS
        .focusable() 
        .onKeyPress(.space) { engine.isPaused.toggle(); return .handled }
        .onKeyPress(KeyEquivalent("r")) { engine.resetParticles(); return .handled }
        .onKeyPress(KeyEquivalent("1")) { engine.colorMode = 0; return .handled }
        .onKeyPress(KeyEquivalent("2")) { engine.colorMode = 1; return .handled }
        .onKeyPress(KeyEquivalent("3")) { engine.colorMode = 2; return .handled }
    }
}

struct ControlBadge: View {
    let key: String
    let action: String
    var body: some View {
        VStack {
            Text(key).font(.system(size: 14, weight: .bold, design: .rounded))
            Text(action).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 50)
    }
}

struct MetalView: NSViewRepresentable {
    @ObservedObject var engine: SimulationEngine
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = engine.device
        mtkView.delegate = engine
        mtkView.preferredFramesPerSecond = 120
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = false 
        return mtkView
    }
    func updateNSView(_ nsView: MTKView, context: Context) {}
}