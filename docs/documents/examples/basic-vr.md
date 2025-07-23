# Basic VR Application

This example demonstrates the minimal code needed to create a VR application with WallensteinVR.

## Complete Example

This is the actual `main.zig` implementation:

```zig
const std = @import("std");
const log = @import("std").log;
const builtin = @import("builtin");
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const loader = @import("loader");
const c = loader.c;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure OpenXR and Vulkan extensions/layers
    const xr_extensions = &[_][*:0]const u8{
        loader.c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        loader.c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
        loader.c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };
    const xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
        "XR_APILAYER_LUNARG_api_dump",
    };
    const vk_layers = &[_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    // Initialize and run the VR engine
    const engine = try Engine.init(allocator, .{
        .xr_extensions = xr_extensions,
        .xr_layers = xr_layers,
        .vk_layers = vk_layers,
    });
    defer engine.deinit();
    
    try engine.start();
}
```

## Step-by-Step Breakdown

### 1. Memory Management

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();
```

WallensteinVR uses Zig's GeneralPurposeAllocator for memory management. The `defer` ensures proper cleanup.

### 2. Configuration

```zig
const config = Engine.Config{
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
};
```

The configuration specifies:
- **OpenXR Extensions**: Required for Vulkan integration and debugging
- **OpenXR Layers**: Validation and API dumping for development
- **Vulkan Layers**: Validation layer for graphics debugging

### 3. Engine Initialization

```zig
const engine = try Engine.init(allocator, config);
defer engine.deinit();
```

The Engine handles:
- OpenXR instance creation
- Vulkan context setup
- VR session establishment
- Resource management

### 4. Main Loop

```zig
try engine.start();
```

The `start()` method enters the main VR loop:
- Event polling
- Frame rendering
- Swapchain management
- Graceful shutdown handling

## Running the Example

1. **Ensure VR runtime is running:**
   ```bash
   monado-service --verbose --null  # For testing without hardware
   ```

2. **Build and run:**
   ```bash
   zig build run
   ```

3. **Expected output:**
   ```
   OpenXR instance created successfully
   Vulkan instance created with validation
   Physical device selected: [Your GPU]
   VR session established
   Entering main loop...
   ```

## Customization Options

### Different VR Runtimes

```zig
// For SteamVR (remove debug layers for production)
const config = Engine.Config{
    .xr_extensions = &[_][*:0]const u8{
        loader.c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        loader.c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
    },
    .xr_layers = &[_][*:0]const u8{},  // No debug layers
    .vk_layers = &[_][*:0]const u8{},  // No validation
};
```

### Error Handling

```zig
const engine = Engine.init(allocator, config) catch |err| switch (err) {
    error.XrErrorInitializationFailed => {
        std.log.err("OpenXR initialization failed. Is a VR runtime running?");
        return;
    },
    error.VkErrorIncompatibleDriver => {
        std.log.err("Vulkan driver incompatible. Update your graphics drivers.");
        return;
    },
    else => return err,
};
```

## Next Steps

- [Custom Shaders](custom-shaders.md) - Add your own graphics
- [Architecture Guide](../guides/architecture.md) - Understand the system
- [API Reference](../api/overview.md) - Detailed function documentation
- [Debugging Guide](../guides/debugging.md) - Development tools