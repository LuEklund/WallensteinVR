# Shader System

WallensteinVR uses a modern shader pipeline with automatic GLSL to SPIR-V compilation.

## Shader Structure

### Current Shaders

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
    // Currently outputs nothing (commented out)
    // outColor = vec4(1.0, 0.0, 0.0, 1.0);
}
```

## Build System Integration

### Automatic Compilation

The `CompileShaders` build step automatically:

1. **Discovers** all shader files in `assets/shaders/`
2. **Compiles** GLSL to SPIR-V using `glslc`
3. **Caches** compiled shaders for incremental builds
4. **Installs** compiled shaders to `bin/shaders/`

### Supported Shader Types

- `.vert` - Vertex shaders
- `.frag` - Fragment shaders
- `.comp` - Compute shaders
- `.geom` - Geometry shaders
- `.tesc` - Tessellation control shaders
- `.tese` - Tessellation evaluation shaders
- `.glsl` - Generic GLSL files

### Build Process

```zig
// In build.zig
const shader_compile_step = addCompileShaders(b, .{
    .in_dir = b.path("assets/shaders"),
});

const install_shaders_step = b.addInstallDirectory(.{
    .source_dir = shader_compile_step.getOutputDir(),
    .install_dir = .bin,
    .install_subdir = "shaders",
});
```

## Shader Loading

### Runtime Loading

Shaders are loaded in the Vulkan pipeline creation:

```zig
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

### Error Handling

The shader loading system provides detailed error messages:
- File not found errors
- SPIR-V validation errors
- Vulkan shader module creation errors

## Development Workflow

### Adding New Shaders

1. **Create** GLSL file in `assets/shaders/`
2. **Build** project - shaders compile automatically
3. **Load** in Vulkan pipeline code
4. **Test** with `zig build run`

### Shader Debugging

**Validation Layers**
- Enable Vulkan validation for shader warnings
- Check SPIR-V output in `zig-cache/o/*/`

**Manual Compilation**
```bash
# Test shader compilation manually
glslc assets/shaders/vertex.vert -o test.spv
spirv-dis test.spv  # Disassemble for inspection
```

## VR-Specific Considerations

### Stereo Rendering

Current shaders render the same content to both eyes. For proper VR:

1. **Add uniform buffer** for eye-specific matrices
2. **Implement view matrices** for left/right eyes
3. **Add projection matrices** for VR FOV
4. **Handle IPD** (interpupillary distance)

### Performance Optimization

- **Minimize state changes** between eye renders
- **Use instanced rendering** for repeated geometry
- **Optimize fragment shaders** for VR fill rates
- **Consider foveated rendering** for performance

## Future Enhancements

### Planned Features

- **Uniform buffer support** for transformation matrices
- **Texture sampling** for realistic materials
- **Lighting calculations** for 3D scenes
- **Multi-pass rendering** for advanced effects
- **Compute shader integration** for physics/particles

### Shader Templates

Consider adding shader templates for common VR scenarios:
- Basic textured quad rendering
- Skybox/environment mapping
- UI overlay rendering
- Hand tracking visualization