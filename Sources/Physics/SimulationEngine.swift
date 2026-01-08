import MetalKit
import SwiftUI
import CoreGraphics

// MARK: - SHADERS
let SHADER_SOURCE = """
#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;
    float2 velocity;
};

struct Uniforms {
    float2 brushPos;
    float brushMass;
    float time;
    int colorMode;
};

// KERNEL 1: CLEAR (Wipe to Black)
kernel void clearCanvas(
    texture2d<float, access::write> output [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    output.write(float4(0, 0, 0, 1), gid);
}

// KERNEL 2: FADE (Create Trails)
kernel void fadeCanvas(
    texture2d<float, access::read_write> output [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float4 color = output.read(gid);
    output.write(color * 0.91, gid);
}

// KERNEL 3: PARTICLES
kernel void updateParticles(
    device Particle *particles [[buffer(0)]],
    texture2d<float, access::write> output [[texture(0)]],
    constant Uniforms &uni [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint id = gid.x;
    Particle p = particles[id];
    
    // Physics Logic
    float2 diff = uni.brushPos - p.position;
    float aspect = float(output.get_width()) / float(output.get_height());
    diff.x *= aspect;
    float distSq = dot(diff, diff);
    float forceStrength = (uni.brushMass * 0.002) / (distSq + 0.005);
    float2 force = normalize(diff) * forceStrength;
    
    if (abs(uni.brushMass) > 0.01) { p.velocity += force; }
    p.velocity *= 0.99;
    p.position += p.velocity;
    
    // Wrap
    if (p.position.x < 0) p.position.x += 1.0;
    if (p.position.x > 1) p.position.x -= 1.0;
    if (p.position.y < 0) p.position.y += 1.0;
    if (p.position.y > 1) p.position.y -= 1.0;
    
    particles[id] = p;
    
    // Color Logic
    float speed = length(p.velocity) * 150.0;
    float3 c = float3(0.5 + 0.5 * sin(p.position.x * 6.28), 0.5, 1.0) + float3(speed * 0.5);
    
    uint2 pixelPos = uint2(p.position * float2(output.get_width(), output.get_height()));
    if (pixelPos.x < output.get_width() && pixelPos.y < output.get_height()) {
        output.write(float4(c, 1.0), pixelPos);
    }
}
"""

// MARK: - SWIFT ENGINE
struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
}

struct Uniforms {
    var brushPos: SIMD2<Float>
    var brushMass: Float
    var time: Float
    var colorMode: Int32
}

@MainActor
class SimulationEngine: NSObject, ObservableObject, MTKViewDelegate {
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var clearPipeline: MTLComputePipelineState!
    var fadePipeline: MTLComputePipelineState!
    var particlePipeline: MTLComputePipelineState!
    var particleBuffer: MTLBuffer!
    var canvasTexture: MTLTexture!
    
    let particleCount = 200_000
    @Published var brushPosition: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    @Published var brushMass: Float = 1.0
    @Published var colorMode: Int = 0
    @Published var isPaused: Bool = false
    
    var startTime = Date()
    var needsTextureClear = false
    
    override init() {
        super.init()
        setupMetal()
        initParticles()
    }
    
    private func setupMetal() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else { fatalError() }
        self.device = defaultDevice
        self.commandQueue = device.makeCommandQueue()
        
        do {
            let library = try device.makeLibrary(source: SHADER_SOURCE, options: nil)
            guard let clearFn = library.makeFunction(name: "clearCanvas"),
                  let fadeFn = library.makeFunction(name: "fadeCanvas"),
                  let partFn = library.makeFunction(name: "updateParticles") else { fatalError() }
            
            self.clearPipeline = try device.makeComputePipelineState(function: clearFn)
            self.fadePipeline = try device.makeComputePipelineState(function: fadeFn)
            self.particlePipeline = try device.makeComputePipelineState(function: partFn)
        } catch { fatalError("\(error)") }
    }
    
    private func initParticles() {
        var particles = [Particle]()
        for _ in 0..<particleCount {
            // "Big Bang" Initialization: Center start
            let pos = SIMD2<Float>(0.5, 0.5) + SIMD2<Float>(Float.random(in: -0.005...0.005), Float.random(in: -0.005...0.005))
            let vel = SIMD2<Float>(Float.random(in: -0.002...0.002), Float.random(in: -0.002...0.002))
            particles.append(Particle(position: pos, velocity: vel))
        }
        let size = particles.count * MemoryLayout<Particle>.stride
        self.particleBuffer = device.makeBuffer(bytes: particles, length: size, options: .storageModeShared)
    }
    
    // Public method to reset particles (called from ContentView)
    func resetParticles() {
        var particles = [Particle]()
        for _ in 0..<particleCount {
            // Reset to Center
            let pos = SIMD2<Float>(0.5, 0.5) + SIMD2<Float>(Float.random(in: -0.005...0.005), Float.random(in: -0.005...0.005))
            let vel = SIMD2<Float>(Float.random(in: -0.002...0.002), Float.random(in: -0.002...0.002))
            particles.append(Particle(position: pos, velocity: vel))
        }
        let size = particles.count * MemoryLayout<Particle>.stride
        if let newBuffer = device.makeBuffer(bytes: particles, length: size, options: .storageModeShared) {
            self.particleBuffer = newBuffer
        }
        
        // Flag to clear canvas on next frame
        needsTextureClear = true
    }
    
    // Create texture and IMMEDIATELEY clear it via Render Pass
    private func createTexture(width: Int, height: Int) {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = width
        descriptor.height = height
        // ADD renderTarget usage for Hardware Clear
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private
        
        guard let newTexture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create canvas texture")
        }
        
        self.canvasTexture = newTexture
        
        // HARDWARE CLEAR (Render Pass)
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = newTexture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }
        
        // We don't need to draw anything. Starting the pass triggers the clear.
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted() // Force sync wait
        
        self.needsTextureClear = false
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        canvasTexture = nil
        needsTextureClear = true
    }
    
    func draw(in view: MTKView) {
        let width = Int(view.drawableSize.width)
        let height = Int(view.drawableSize.height)
        
        // Create texture if needed
        if canvasTexture == nil && width > 0 && height > 0 {
            print("🔵 Creating new texture: \(width)x\(height)")
            createTexture(width: width, height: height)
            print("🟢 Texture created and cleared")
            // CRITICAL: Skip this ENTIRE frame after creating texture
            return
        }
        
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let canvasTexture = canvasTexture else { return }
        
        // STEP 0: Clear if requested (Visual Reset)
        if needsTextureClear, let clearEncoder = commandBuffer.makeComputeCommandEncoder() {
            clearEncoder.setComputePipelineState(clearPipeline)
            clearEncoder.setTexture(canvasTexture, index: 0)
            
            let w = clearPipeline.threadExecutionWidth
            let h = clearPipeline.maxTotalThreadsPerThreadgroup / w
            let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (canvasTexture.width + w - 1) / w,
                height: (canvasTexture.height + h - 1) / h,
                depth: 1
            )
            
            clearEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            clearEncoder.endEncoding()
            
            needsTextureClear = false
        }

        // STEP 1: Fade the canvas (create trails)
        if let fadeEncoder = commandBuffer.makeComputeCommandEncoder() {
            fadeEncoder.setComputePipelineState(fadePipeline)
            fadeEncoder.setTexture(canvasTexture, index: 0)
            
            let w = fadePipeline.threadExecutionWidth
            let h = fadePipeline.maxTotalThreadsPerThreadgroup / w
            let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (canvasTexture.width + w - 1) / w,
                height: (canvasTexture.height + h - 1) / h,
                depth: 1
            )
            
            fadeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            fadeEncoder.endEncoding()
        }
        
        // STEP 2: Update and draw particles
        if !isPaused, let particleEncoder = commandBuffer.makeComputeCommandEncoder() {
            var uniforms = Uniforms(
                brushPos: brushPosition,
                brushMass: brushMass,
                time: Float(Date().timeIntervalSince(startTime)),
                colorMode: Int32(colorMode)
            )
            
            particleEncoder.setComputePipelineState(particlePipeline)
            particleEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            particleEncoder.setTexture(canvasTexture, index: 0)
            particleEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            
            let threadsPerGroup = MTLSize(width: 256, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(width: (particleCount + 255) / 256, height: 1, depth: 1)
            
            particleEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            particleEncoder.endEncoding()
        }
        
        // STEP 3: Copy canvas to drawable
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.copy(
                from: canvasTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: canvasTexture.width, height: canvasTexture.height, depth: 1),
                to: drawable.texture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            blitEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}