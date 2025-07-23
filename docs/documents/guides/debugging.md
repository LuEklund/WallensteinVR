# Debugging Guide

WallensteinVR includes comprehensive debugging features for both OpenXR and Vulkan development.

## Debug Layers

### OpenXR Debug Layers

The application automatically enables OpenXR validation layers:

```zig
const xr_layers = &[_][*:0]const u8{
    "XR_APILAYER_LUNARG_core_validation",
    "XR_APILAYER_LUNARG_api_dump",
};
```

**Core Validation**
- Validates OpenXR API usage
- Checks parameter correctness
- Detects common mistakes

**API Dump**
- Logs all OpenXR API calls
- Shows parameter values
- Useful for understanding call flow

### Vulkan Debug Layers

Vulkan validation is enabled by default:

```zig
const vk_layers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};
```

**Validation Features**
- Memory usage validation
- API usage correctness
- Performance warnings
- Best practices suggestions

## Debug Messengers

### OpenXR Debug Messenger

Captures OpenXR runtime messages:

```zig
const xr_debug_messenger: c.XrDebugUtilsMessengerEXT = 
    try xr.createDebugMessenger(xrd, xr_instance);
```

**Message Types**
- Errors - Critical issues
- Warnings - Potential problems
- Info - General information
- Verbose - Detailed tracing

### Vulkan Debug Messenger

Handles Vulkan validation layer output:

```zig
const vk_debug_messenger: c.VkDebugUtilsMessengerEXT = 
    try vk.createDebugMessenger(vkid, vk_instance);
```

## Error Handling

### Zig Error System

All API calls are wrapped with proper error handling:

```zig
pub fn xrCheck(result: c_int) XrError!void {
    if (result == c.XR_SUCCESS) return;
    return wrapXrError(result);
}

pub fn vkCheck(result: c_int) VkError!void {
    if (result == c.VK_SUCCESS) return;
    return wrapVkError(result);
}
```

### Error Types

**OpenXR Errors**
- `XrError.ErrorInitializationFailed`
- `XrError.ErrorInstanceLost`
- `XrError.ErrorSessionLost`
- And many more...

**Vulkan Errors**
- `VkError.ErrorOutOfHostMemory`
- `VkError.ErrorOutOfDeviceMemory`
- `VkError.ErrorDeviceLost`
- Complete enumeration available

## Debugging Techniques

### Runtime Debugging

**Check VR Runtime Status**
```bash
# List available OpenXR runtimes
openxr_runtime_list

# Check Monado status
systemctl --user status monado
```

**Vulkan Debugging**
```bash
# Verify Vulkan installation
vulkaninfo

# Check available devices
vkcube  # Simple Vulkan test
```

### Application Debugging

**Enable Verbose Logging**
```bash
# Run with debug output
zig build run 2>&1 | tee debug.log
```

**GDB Debugging**
```bash
# Build debug version
zig build -Doptimize=Debug

# Debug with GDB
gdb ./zig-out/bin/WallensteinVr
(gdb) run
```

### Memory Debugging

**Zig Allocator Debugging**
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{
    .verbose_log = true,  // Enable verbose logging
}){};
```

**Valgrind (Linux)**
```bash
# Check for memory leaks
valgrind --leak-check=full ./zig-out/bin/WallensteinVr
```

## Common Issues

### OpenXR Issues

**"No OpenXR runtime found"**
- Install and start VR runtime (Monado/SteamVR)
- Check `XR_RUNTIME_JSON` environment variable
- Verify runtime with `openxr_runtime_list`

**"Extension not supported"**
- Check available extensions with validation layers
- Verify VR runtime supports required extensions
- Update VR runtime if needed

### Vulkan Issues

**"No suitable GPU found"**
- Update graphics drivers
- Check Vulkan support: `vulkaninfo`
- Verify GPU supports required features

**"Validation layer not found"**
- Install Vulkan SDK completely
- Check `VK_LAYER_PATH` environment variable
- Verify layer availability: `vulkaninfo --summary`

### Build Issues

**"glslc not found"**
- Install complete Vulkan SDK
- Add Vulkan bin directory to PATH
- Verify: `glslc --version`

**Shader compilation errors**
- Check GLSL syntax in shader files
- Review glslc error messages
- Test manual compilation: `glslc shader.vert -o test.spv`

## Performance Debugging

### Profiling Tools

**RenderDoc**
- Capture Vulkan frames
- Analyze GPU performance
- Debug rendering pipeline

**Tracy Profiler**
- CPU/GPU profiling
- Memory allocation tracking
- Frame time analysis

### VR-Specific Debugging

**Frame Rate Monitoring**
- Monitor VR compositor frame rates
- Check for dropped frames
- Analyze render timing

**Latency Analysis**
- Motion-to-photon latency
- Tracking prediction accuracy
- Render pipeline timing

## Debug Output Examples

### Successful Initialization
```
OpenXR instance created successfully
Vulkan instance created with validation
Physical device selected: NVIDIA GeForce RTX 3080
VR session established
Entering main loop...
```

### Error Example
```
Error: OpenXR initialization failed
Caused by: XrError.ErrorRuntimeFailure
Debug: No active OpenXR runtime found
Solution: Start Monado with: monado-service --verbose
```

## Development Tips

### Debugging Workflow

1. **Start simple** - Test with null VR driver first
2. **Enable all validation** - Catch issues early
3. **Check logs carefully** - Debug messages contain solutions
4. **Test incrementally** - Add features one at a time
5. **Use proper tools** - RenderDoc for graphics, GDB for crashes

### Best Practices

- Always check return values
- Enable debug layers in development
- Use proper resource cleanup (RAII)
- Test with different VR runtimes
- Validate shaders before runtime