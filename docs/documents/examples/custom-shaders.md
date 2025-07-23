# Custom Shaders

Learn how to work with the shader system in WallensteinVR.

## Current Shader Implementation

WallensteinVR includes a basic shader pipeline with automatic GLSL to SPIR-V compilation.

### Existing Shaders

**Vertex Shader (`assets/shaders/vertex.vert`)**
```glsl
#version 450
#extension GL_ARB_separate_shader_objects : enable

void main() {
    if (0 == 0) {
        gl_Position = vec4(0.0, -0.5, 0.0, 1.0); // Bottom-middle
    } else if (1 == 1) {
        gl_Position = vec4(0.5, 0.5, 0.0, 1.0);  // Top-right
    } else { // gl_VertexIndex == 2
        gl_Position = vec4(-0.5, 0.5, 0.0, 1.0); // Top-left
    }
}
```

**Fragment Shader (`assets/shaders/fragment.frag`)**
```glsl
#version 450
#extension GL_ARB_separate_shader_objects : enable

void main() {
    // Basic fragment shader - currently outputs default color
}
```

### Build System Integration

The build system automatically compiles shaders:

```bash
zig build  # Compiles vertex.vert -> vertex.vert.spv
           #          fragment.frag -> fragment.frag.spv
```

### Shader Loading in Code

The engine loads shaders in the Vulkan pipeline setup:

```zig
// From src/main.zig - how shaders are currently loaded
const vertex_shader: c.VkShaderModule = try vk.createShader(
    self.allocator, 
    self.vk_logical_device, 
    "shaders/vertex.vert.spv"
);
const fragment_shader: c.VkShaderModule = try vk.createShader(
    self.allocator, 
    self.vk_logical_device, 
    "shaders/fragment.frag.spv"
);
```

## Shader Development

### Current Architecture

The shader system includes:
- **Automatic compilation** from GLSL to SPIR-V via `glslc`
- **Descriptor set layout** for uniform buffers
- **Basic pipeline** with vertex and fragment stages
- **VR swapchain integration** for stereo rendering

### Extending the Shaders

To modify the existing shaders:

1. **Edit shader files** in `assets/shaders/`
2. **Build project** - shaders compile automatically
3. **Test changes** with `zig build run`

### Future Development

The current implementation provides a foundation for:
- Uniform buffer integration
- Texture sampling
- Multi-pass rendering
- VR-specific optimizations

## Development Workflow

### 1. Basic Development Cycle

```bash
# 1. Edit existing shader files
vim assets/shaders/vertex.vert
vim assets/shaders/fragment.frag

# 2. Build automatically compiles shaders
zig build

# 3. Run and test
zig build run

# 4. Check for shader errors in output
# Vulkan validation will report SPIR-V issues
```

### 2. Debugging Shaders

**Manual Compilation**
```bash
# Compile shader manually for testing
glslc assets/shaders/vertex.vert -o test.spv

# Validate SPIR-V
spirv-val test.spv
```

**Validation Layers**
Vulkan validation is enabled by default in the engine:
```zig
const vk_layers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};
```

### 3. Build System Integration

The build system uses `CompileShaders.zig` to automatically:
- Discover `.vert` and `.frag` files in `assets/shaders/`
- Compile them to `.spv` files using `glslc`
- Include them in the build output

## Next Steps

- [Architecture Guide](../guides/architecture.md) - Understand the graphics pipeline
- [API Reference](../api/overview.md) - Vulkan integration details
- [Debugging Guide](../guides/debugging.md) - Shader debugging techniques
- [Performance Guide](../guides/performance.md) - VR optimization tips