# Introduction

WallensteinVR is a modern VR application written in Zig, demonstrating high-performance virtual reality development using OpenXR and Vulkan. The project showcases memory-safe systems programming with cross-platform VR runtime support.

## Project Goals

- **Cross-Platform VR** - Support any OpenXR-compatible VR runtime
- **High Performance** - Leverage Vulkan for optimal graphics performance  
- **Memory Safety** - Use Zig's compile-time safety features
- **Developer Experience** - Provide clean, well-documented VR development patterns
- **Open Source** - Demonstrate modern VR development techniques

## Key Features

### VR Integration
- **OpenXR instance creation** with extension support
- **VR session management** with state handling
- **Swapchain creation** for stereo rendering
- **Multiple runtime support** (Monado, SteamVR, Oculus)
- **Event-driven architecture** for VR state changes
- **Graceful shutdown handling** with signal processing

### Graphics System
- **Vulkan instance creation** with validation layers
- **Physical device selection** with queue family detection
- **Basic graphics pipeline** with shader modules
- **Render pass and framebuffer setup**
- **Debug messenger integration** for development

### Development Features
- **Comprehensive error handling** with Zig error types
- **Automatic shader compilation** from GLSL to SPIR-V
- **Debug validation layers** for both OpenXR and Vulkan
- **Cross-platform signal handling** for graceful shutdown
- **Modular architecture** with separate OpenXR and Vulkan modules

### Build System
- **Custom shader compilation** via CompileShaders.zig
- **Automatic API binding generation** via loader-generator
- **System library linking** for OpenXR and Vulkan
- **Asset management** with shader compilation pipeline

## Architecture Overview

WallensteinVR uses a clean, modular architecture:

- **Engine** (`main.zig`) - Core application lifecycle management
- **OpenXR Module** (`openxr.zig`) - VR runtime integration
- **Vulkan Module** (`vulkan.zig`) - Graphics pipeline management
- **Build Tools** (`build/`) - Custom build steps and utilities
- **Assets** (`assets/`) - Shaders and resources

## Getting Started

1. **Install Prerequisites** - Vulkan SDK, OpenXR runtime, Zig compiler
2. **Start VR Runtime** - Launch Monado or SteamVR
3. **Build Project** - `zig build`
4. **Run Application** - `zig build run`

See the [Installation Guide](installation.md) for detailed setup instructions.

## Target Audience

This project is designed for:
- **VR Developers** learning OpenXR and Vulkan
- **Zig Enthusiasts** exploring systems programming
- **Graphics Programmers** interested in modern rendering
- **Open Source Contributors** wanting to improve VR tooling

The codebase serves as both a functional VR application and an educational resource for modern VR development techniques.