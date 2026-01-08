#include <metal_stdlib>
using namespace metal;

// The "Einstein Brush" Kernel
// This calculates how light bends around a mass
kernel void schwarzschildLens(
    texture2d<float, access::write> output [[texture(0)]],
    texture2d<float, access::read> background [[texture(1)]],
    constant float2 &massPosition [[buffer(0)]],
    constant float &massValue [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // 1. Get current pixel coordinates
    float2 widthHeight = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / widthHeight;
    
    // 2. Calculate distance from the "Mass" (the brush stroke)
    float2 diff = uv - massPosition;
    float dist = length(diff);
    
    // 3. Calculate bending (simplified Einstein deflection angle)
    // As we get closer to mass, distortion increases
    float distortionStrength = massValue / (dist + 0.01); 
    
    // 4. Calculate where to read the pixel from (Lensing)
    float2 offset = normalize(diff) * distortionStrength * 0.05;
    float2 readUV = uv - offset;
    
    // 5. Read from background and write to output
    // (This creates the "warped" space effect)
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    float4 color = background.sample(textureSampler, readUV);
    
    output.write(color, gid);
}
