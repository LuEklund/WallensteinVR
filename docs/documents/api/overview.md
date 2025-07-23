# API Reference

This page documents the main Zig modules and their exported functions.

## Engine (main.zig)

The main `Engine` struct manages the complete VR application lifecycle.

### Engine.Config
```zig
pub const Config = struct {
    xr_extensions: []const [*:0]const u8,
    xr_layers: []const [*:0]const u8,
    vk_layers: []const [*:0]const u8,
};
```

### Engine Methods

- **init(allocator, config)** – Initializes OpenXR instance, Vulkan context, and VR session
- **deinit()** – Cleans up all resources and debug messengers
- **start()** – Enters main VR event loop with rendering pipeline

### Example

```zig
const engine = try Engine.init(allocator, .{
    .xr_extensions = &[_][*:0]const u8{
        loader.c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        loader.c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
        loader.c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    },
    .xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
        "XR_APILAYER_LUNARG_api_dump",
    },
    .vk_layers = &[_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    },
});
defer engine.deinit();
try engine.start();
```

## OpenXR Module (openxr.zig)

### Core Functions

- **createInstance(extensions, layers)** – Creates OpenXR instance with validation
- **createDebugMessenger(dispatcher, instance)** – Sets up OpenXR debug logging
- **getSystem(instance)** – Discovers VR system hardware
- **getVulkanInstanceRequirements()** – Queries required Vulkan extensions
- **getVulkanDeviceRequirements()** – Gets physical device and extensions
- **createSession()** – Establishes VR session with Vulkan binding

### Swapchain Management

```zig
pub const Swapchain = struct {
    handle: c.XrSwapchain,
    format: c.VkFormat,
    width: u32,
    height: u32,
    
    pub fn init(eye_count, allocator, instance, system_id, session) ![]Swapchain
    pub fn getImages(self: *Swapchain, allocator) ![]c.XrSwapchainImageVulkanKHR
};
```

### Dispatcher

```zig
pub const Dispatcher = struct {
    // Function pointers for OpenXR API calls
    pub fn init(instance: c.XrInstance) !Dispatcher
};
```

## Vulkan Module (vulkan.zig)

### Core Functions

- **createInstance(requirements, extensions, layers)** – Creates Vulkan instance
- **createDebugMessenger(dispatcher, instance)** – Sets up Vulkan validation
- **findGraphicsQueueFamily(physical_device)** – Locates graphics queue
- **createLogicalDevice(physical_device, queue_family, extensions)** – Creates device and queue
- **createRenderPass(device, format)** – Sets up VR render pass
- **createCommandPool(device, queue_family)** – Creates command buffer pool
- **createShader(allocator, device, path)** – Loads compiled SPIR-V shaders
- **createPipeline(device, render_pass, layout, vertex_shader, fragment_shader)** – Graphics pipeline

### Dispatcher

```zig
pub const Dispatcher = struct {
    // Function pointers for Vulkan API calls
    pub fn init(instance: c.VkInstance) !Dispatcher
};
```

## Loader Module (Generated)

Auto-generated bindings for OpenXR and Vulkan APIs.

### Error Checking

```zig
pub fn xrCheck(result: c_int) XrError!void
pub fn vkCheck(result: c_int) VkError!void
```

### Error Types

- **XrError** – Comprehensive OpenXR error enumeration
- **VkError** – Complete Vulkan error enumeration

## Build System

### CompileShaders (build/CompileShaders.zig)

Custom build step for automatic shader compilation.

```zig
pub const CompileShaders = struct {
    pub const Options = struct {
        in_dir: LazyPath,
    };
    
    pub fn create(owner: *std.Build, options: Options) *@This()
    pub fn getOutputDir(self: *@This()) LazyPath
};
```

**Features:**
- Automatic GLSL discovery (.vert, .frag, .comp, etc.)
- Incremental compilation with caching
- SPIR-V output with .spv extension
- Integration with Zig build system

### Usage in build.zig

```zig
const shader_compile_step = addCompileShaders(b, .{
    .in_dir = b.path("assets/shaders"),
});
```