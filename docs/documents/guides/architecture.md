# Architecture

WallensteinVR is built with a modular architecture that separates VR management, graphics rendering, and application logic.

## System Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   VR Runtime    │    │   Graphics      │
│   (main.zig)    │◄──►│   (OpenXR)      │    │   (Vulkan)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Build System  │
                    │   (Zig + Tools) │
                    └─────────────────┘
```

## Core Components

### Engine (`src/main.zig`)

The main engine struct manages the entire VR application lifecycle:

```zig
pub const Engine = struct {
    // OpenXR components
    xr_instance: c.XrInstance,
    xr_session: c.XrSession,
    xr_system_id: c.XrSystemId,
    
    // Vulkan components
    vk_instance: c.VkInstance,
    vk_logical_device: c.VkDevice,
    graphics_queue_family_index: u32,
    
    // Dispatchers for API calls
    xrd: xr.Dispatcher,
    vkid: vk.Dispatcher,
};
```

**Responsibilities:**
- Initialize OpenXR and Vulkan
- Manage VR session lifecycle
- Handle system events and state changes
- Coordinate rendering pipeline

### OpenXR Integration (`src/openxr.zig`)

Handles all VR-specific functionality:

- **Instance Management** - Create and configure OpenXR instance
- **System Discovery** - Find and select VR system
- **Session Management** - Handle VR session states
- **Swapchain Management** - Manage eye render targets
- **Event Processing** - Handle runtime events

**Key Functions:**
- `createInstance()` - Initialize OpenXR with required extensions
- `getSystem()` - Discover VR hardware
- `createSession()` - Establish VR session
- `Swapchain.init()` - Set up stereo rendering targets

### Vulkan Graphics (`src/vulkan.zig`)

Modern graphics pipeline implementation:

- **Instance Creation** - Initialize Vulkan with OpenXR requirements
- **Device Selection** - Choose appropriate GPU
- **Pipeline Setup** - Create render passes and graphics pipelines
- **Resource Management** - Handle buffers, textures, and memory

**Pipeline Components:**
- Render passes for VR eye rendering
- Shader modules (vertex/fragment)
- Command pools and buffers
- Descriptor sets for uniforms

### Build System

#### Shader Compilation (`build/CompileShaders.zig`)

Custom build step that automatically compiles GLSL shaders to SPIR-V:

```zig
pub const CompileShaders = struct {
    step: Step,
    in_dir: LazyPath,
    out_dir: std.Build.GeneratedFile,
};
```

**Features:**
- Automatic shader discovery in `assets/shaders/`
- Incremental compilation with caching
- Support for all shader types (.vert, .frag, .comp, etc.)
- Integration with Zig build system

#### Loader Generation (`tools/loader-generator.zig`)

Generates Zig bindings for OpenXR and Vulkan APIs:
- Creates type-safe wrappers
- Handles function loading
- Provides error checking utilities

## Data Flow

### Initialization Sequence

1. **Engine.init()**
   - Create OpenXR instance with required extensions
   - Initialize debug messenger
   - Get VR system ID
   - Query Vulkan requirements from OpenXR
   - Create Vulkan instance and device
   - Create VR session

2. **Engine.start()**
   - Initialize swapchains for stereo rendering
   - Create Vulkan render pass and pipeline
   - Set up command pools and descriptor sets
   - Enter main event loop

### Main Loop

```
┌─────────────────┐
│ Poll XR Events  │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Handle Events   │
│ - State Changes │
│ - User Input    │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Render Frame    │
│ - Begin Frame   │
│ - Draw Eyes     │
│ - End Frame     │
└─────────┬───────┘
          │
          └─────────┐
                    │
          ┌─────────▼───────┐
          │ Check Quit      │
          └─────────────────┘
```

## Memory Management

### Allocation Strategy
- Uses Zig's GeneralPurposeAllocator for main allocations
- Careful resource cleanup in deinit() methods
- RAII patterns for Vulkan resources

### Resource Lifecycle
- OpenXR and Vulkan resources tied to Engine lifetime
- Swapchain images managed by OpenXR runtime
- Shader modules loaded once during initialization

## Error Handling

### Zig Error System
```zig
pub fn vkCheck(result: c_int) VkError!void {
    if (result == c.VK_SUCCESS) return;
    return wrapVkError(result);
}
```

### Graceful Shutdown
- Signal handling for SIGINT/SIGTERM
- Proper resource cleanup on exit
- VR session state management

## Extension Points

### Adding New Shaders
1. Place GLSL files in `assets/shaders/`
2. Build system automatically compiles them
3. Load in Vulkan pipeline creation

### VR Runtime Support
- OpenXR provides runtime abstraction
- Support for Monado, SteamVR, Oculus, etc.
- Runtime-specific optimizations possible

### Graphics Features
- Modular Vulkan pipeline design
- Easy to add new render passes
- Descriptor set layouts for uniforms