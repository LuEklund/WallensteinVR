# Performance Guide

Optimizing VR applications is crucial for maintaining the high frame rates required for comfortable VR experiences. This guide covers performance optimization techniques specific to WallensteinVR.

## VR Performance Requirements

### Frame Rate Targets
- **90 FPS minimum** - Standard for most VR headsets
- **120 FPS preferred** - For high-refresh displays
- **11ms frame budget** - Maximum time per frame at 90 FPS
- **Consistent timing** - Frame drops cause motion sickness

### Performance Metrics
```bash
# Monitor frame timing during development
zig build run 2>&1 | grep "Frame time"

# Use VR runtime performance tools
monado-cli --performance-stats
```

## Vulkan Optimization

### Command Buffer Efficiency
```zig
// Pre-record command buffers when possible
const command_buffer = try vk.createCommandBuffer(device, command_pool);
try vk.recordRenderCommands(command_buffer, render_pass, pipeline);

// Reuse command buffers across frames
try vk.submitCommandBuffer(graphics_queue, command_buffer);
```

### Memory Management
- **Use staging buffers** for large data uploads
- **Pool allocations** to reduce fragmentation
- **Align memory** to GPU requirements
- **Batch transfers** to minimize API calls

### Pipeline State
```zig
// Minimize pipeline state changes
const pipeline_cache = try vk.createPipelineCache(device);
const pipelines = try vk.createGraphicsPipelines(device, pipeline_cache, pipeline_infos);

// Sort draw calls by pipeline state
try sortDrawCallsByPipeline(draw_calls);
```

## Shader Optimization

### Vertex Shaders
```glsl
#version 450

// Use efficient data types
layout(location = 0) in vec3 position;
layout(location = 1) in vec2 texCoord;

// Minimize varying variables
layout(location = 0) out vec2 fragTexCoord;

void main() {
    // Keep vertex shaders simple
    gl_Position = mvpMatrix * vec4(position, 1.0);
    fragTexCoord = texCoord;
}
```

### Fragment Shaders
```glsl
#version 450

// Use precision qualifiers on mobile
precision mediump float;

// Minimize texture lookups
layout(binding = 0) uniform sampler2D colorTexture;

layout(location = 0) in vec2 fragTexCoord;
layout(location = 0) out vec4 outColor;

void main() {
    // Cache texture samples
    vec4 color = texture(colorTexture, fragTexCoord);
    
    // Avoid complex branching
    outColor = color;
}
```

### Shader Compilation
```bash
# Optimize shaders during build
glslc -O -Os shader.vert -o shader.vert.spv
glslc -O -Os shader.frag -o shader.frag.spv
```

## OpenXR Performance

### Swapchain Management
```zig
// Use optimal swapchain formats
const preferred_formats = [_]c.VkFormat{
    c.VK_FORMAT_R8G8B8A8_SRGB,
    c.VK_FORMAT_B8G8R8A8_SRGB,
};

// Size swapchains appropriately
const swapchain_info = c.XrSwapchainCreateInfo{
    .width = recommended_width,
    .height = recommended_height,
    .format = optimal_format,
    .mipCount = 1,
    .faceCount = 1,
    .arraySize = 1,
    .sampleCount = 1,
};
```

### Frame Timing
```zig
// Use predicted display time
var frame_state = c.XrFrameState{
    .type = c.XR_TYPE_FRAME_STATE,
};
try xr.waitFrame(session, null, &frame_state);

// Begin frame with predicted time
try xr.beginFrame(session, null);

// Render using predicted poses
const view_state = try xr.locateViews(session, frame_state.predictedDisplayTime);
```

### Culling and LOD
```zig
// Implement frustum culling
fn cullObjects(objects: []Object, view_matrix: Mat4, projection_matrix: Mat4) []Object {
    var visible_objects = std.ArrayList(Object).init(allocator);
    
    for (objects) |object| {
        if (isInFrustum(object.bounds, view_matrix, projection_matrix)) {
            try visible_objects.append(object);
        }
    }
    
    return visible_objects.toOwnedSlice();
}

// Use level-of-detail based on distance
fn selectLOD(distance: f32) u32 {
    if (distance < 10.0) return 0; // High detail
    if (distance < 50.0) return 1; // Medium detail
    return 2; // Low detail
}
```

## Memory Optimization

### Buffer Management
```zig
// Use memory pools for frequent allocations
const BufferPool = struct {
    buffers: std.ArrayList(c.VkBuffer),
    free_indices: std.ArrayList(u32),
    
    fn getBuffer(self: *BufferPool) !c.VkBuffer {
        if (self.free_indices.items.len > 0) {
            const index = self.free_indices.pop();
            return self.buffers.items[index];
        }
        
        // Create new buffer if pool is empty
        return try vk.createBuffer(device, buffer_info);
    }
};
```

### Texture Streaming
```zig
// Stream textures based on distance
fn updateTextureStreaming(objects: []Object, camera_pos: Vec3) !void {
    for (objects) |*object| {
        const distance = length(object.position - camera_pos);
        const required_mip = calculateRequiredMipLevel(distance);
        
        if (object.current_mip != required_mip) {
            try streamTextureMip(object.texture, required_mip);
            object.current_mip = required_mip;
        }
    }
}
```

## Profiling and Debugging

### Built-in Profiling
```zig
// Add timing measurements
const start_time = std.time.nanoTimestamp();
try renderFrame();
const end_time = std.time.nanoTimestamp();
const frame_time_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

if (frame_time_ms > 11.0) {
    std.log.warn("Frame time exceeded budget: {d:.2}ms", .{frame_time_ms});
}
```

### External Tools
```bash
# Use RenderDoc for graphics debugging
renderdoc --capture ./zig-out/bin/WallensteinVr

# Profile with perf on Linux
perf record -g ./zig-out/bin/WallensteinVr
perf report

# Monitor GPU usage
nvidia-smi -l 1  # NVIDIA
radeontop        # AMD
```

### Validation Layers
```zig
// Enable performance validation
const validation_features = c.VkValidationFeaturesEXT{
    .sType = c.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT,
    .enabledValidationFeatureCount = 1,
    .pEnabledValidationFeatures = &[_]c.VkValidationFeatureEnableEXT{
        c.VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT,
    },
};
```

## Platform-Specific Optimizations

### Linux/Monado
- Use **direct mode** for lowest latency
- Enable **async reprojection** when available
- Optimize for **specific GPU drivers**

### Windows/SteamVR
- Configure **motion smoothing** settings
- Use **SteamVR performance overlay**
- Optimize for **Windows graphics scheduler**

## Performance Checklist

### Before Release
- [ ] Frame rate consistently above 90 FPS
- [ ] No frame drops during normal usage
- [ ] Memory usage stable over time
- [ ] GPU utilization optimized
- [ ] Thermal throttling avoided
- [ ] Battery life acceptable (mobile VR)

### Monitoring
- [ ] Frame timing telemetry
- [ ] Memory leak detection
- [ ] GPU performance counters
- [ ] User comfort metrics
- [ ] Crash reporting system

## Common Performance Issues

### Frame Rate Drops
- **Cause**: Complex shaders or too many draw calls
- **Solution**: Optimize shaders, batch geometry, use LOD

### Memory Leaks
- **Cause**: Unreleased Vulkan resources
- **Solution**: Proper resource cleanup, use RAII patterns

### Thermal Throttling
- **Cause**: Sustained high GPU usage
- **Solution**: Dynamic quality scaling, frame rate limiting

### Motion Sickness
- **Cause**: Inconsistent frame timing
- **Solution**: Predictive rendering, async reprojection

Remember: VR performance optimization is an iterative process. Profile early, profile often, and always test on target hardware.