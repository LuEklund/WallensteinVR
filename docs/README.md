# WallensteinVR

> **Modern VR application written in Zig using OpenXR and Vulkan for high-performance cross-platform virtual reality experiences**

[![GitHub](https://img.shields.io/badge/GitHub-Repository-blue)](https://github.com/LuEklund/WallensteinVR)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

WallensteinVR demonstrates modern VR development using Zig's memory safety features, OpenXR for cross-platform VR runtime support, and Vulkan for high-performance graphics rendering.

## Features

- **Modern Zig** - Built with Zig for memory safety and optimal performance
- **OpenXR Integration** - Cross-platform VR runtime support (Monado, SteamVR, Oculus)
- **Vulkan Graphics** - Modern graphics API with validation layers
- **Automatic Shader Compilation** - GLSL to SPIR-V compilation via build system
- **VR Session Management** - Complete OpenXR session lifecycle handling
- **Debug-Ready** - Comprehensive validation layers for development
- **Open Source** - MIT licensed with clean, educational codebase

## Installation

### Prerequisites

- **Zig compiler** - Version 0.15.0-dev.1147+69cf40da6 or newer
- **Vulkan SDK** - Required with `glslc` shader compiler in PATH
- **OpenXR runtime** - Monado (recommended) or SteamVR
- **VR Hardware** - Optional (can run with null driver for testing)

### Quick Install

```bash
zig build
```

### Usage

```bash
zig build run
```

### Development Setup

```bash
# Clone the repository
git clone https://github.com/LuEklund/WallensteinVR.git
cd WallensteinVR

# Build the project (auto-generates bindings and compiles shaders)
zig build

# Start VR runtime (Monado example)
monado-service --verbose --null  # Use --null for testing without VR hardware

# Run the application
zig build run
```

## Getting Started

### Basic Architecture

WallensteinVR follows a clean, modular architecture:

```zig
// Main engine initialization
const engine = try Engine.init(allocator, .{
    .xr_extensions = &[_][*:0]const u8{
        loader.c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        loader.c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    },
    .xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
    },
    .vk_layers = &[_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    },
});
defer engine.deinit();

// Start the VR application
try engine.start();
```

### Key Components

- **Engine** - Core application lifecycle and VR session management
- **OpenXR Integration** - Cross-platform VR runtime support
- **Vulkan Pipeline** - Modern graphics rendering with validation
- **Shader System** - Automatic GLSL compilation and management

## Project Structure

```
WallensteinVR/
├── src/                    # Core source code
│   ├── main.zig           # Main engine and application entry
│   ├── openxr.zig         # OpenXR VR runtime integration
│   └── vulkan.zig         # Vulkan graphics pipeline
├── assets/                 # Graphics assets
│   └── shaders/           # GLSL shaders (auto-compiled to SPIR-V)
│       ├── vertex.vert    # Basic vertex shader
│       └── fragment.frag  # Basic fragment shader
├── tools/                  # Build tools and utilities
│   ├── loader-generator.zig # OpenXR/Vulkan binding generator
│   └── loader-generator-base.zig # Base loader functionality
├── build/                  # Build utilities
│   └── CompileShaders.zig # Shader compilation system
├── docs/                   # Documentation website
├── build.zig              # Zig build configuration
└── build.zig.zon          # Project dependencies
```

## Core Components

### Engine Module

The main `Engine` struct manages the complete VR application lifecycle:

- **Initialization** - Sets up OpenXR instance, Vulkan context, and VR session
- **Event Loop** - Handles VR runtime events and state changes
- **Rendering** - Manages stereo swapchains and graphics pipeline
- **Shutdown** - Graceful cleanup of all VR and graphics resources

### OpenXR Integration

- **Cross-platform VR support** for any OpenXR-compatible runtime
- **Session management** with proper state handling
- **Swapchain creation** for stereo rendering
- **Event processing** for VR runtime communication

### Vulkan Graphics

- **Modern Vulkan 1.3** pipeline with validation layers
- **Automatic shader compilation** from GLSL to SPIR-V
- **Physical device selection** with queue family detection
- **Memory-efficient resource management**

## Development Examples

### Adding Custom Shaders

Create new shaders in `assets/shaders/` - they're automatically compiled:

```glsl
// assets/shaders/custom.vert
#version 450

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;

layout(location = 0) out vec3 fragColor;

void main() {
    gl_Position = vec4(position, 1.0);
    fragColor = color;
}
```

### VR Runtime Testing

Test without VR hardware using Monado's null driver:

```bash
# Start null VR runtime
monado-service --verbose --null

# Run application
zig build run
```

### Debug Validation

All validation layers are enabled by default for development:

```bash
# Run with full validation output
zig build run 2>&1 | tee debug.log
```

## Testing

Run the test suite to verify your environment:

```bash
# Run unit tests
zig build test

# Test build system
zig build --summary all

# Verify prerequisites
glslc --version          # Shader compiler
vulkaninfo --summary     # Vulkan support
openxr_runtime_list      # Available VR runtimes
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](docs/community/contributing.md) for details.

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/WallensteinVR.git`
3. Build the project: `zig build`
4. Create a feature branch: `git checkout -b feature-name`
5. Make your changes and test: `zig build test`
6. Test VR functionality: `zig build run`
7. Submit a pull request

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) for a detailed history of changes.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Support

- **Documentation**: [Full documentation](docs/introduction.md)
- **Issues**: [GitHub Issues](https://github.com/LuEklund/WallensteinVR/issues)
- **Discussions**: [GitHub Discussions](https://github.com/LuEklund/WallensteinVR/discussions)
- **Email**: [contact@wallensteinvr.dev](mailto:contact@wallensteinvr.dev)

## Acknowledgments

- **OpenXR Working Group** - For the open VR standard
- **Monado Project** - Open source OpenXR runtime
- **Zig Community** - For the excellent systems programming language
- **Vulkan Community** - For modern graphics API and resources
- **Contributors** - Thanks to everyone who helps improve this project

---

**WallensteinVR** - Modern VR application written in Zig using OpenXR and Vulkan for high-performance cross-platform virtual reality experiences

Made by [LuEklund](https://github.com/LuEklund/WallensteinVR)