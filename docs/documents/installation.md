# Installation Guide

## Prerequisites

- **Vulkan SDK** - Required with `glslc` shader compiler in PATH
- **OpenXR loader and runtime** - Monado (recommended) or SteamVR
- **Zig compiler** - Minimum version `0.15.0-dev.1147+69cf40da6`

### Linux Installation (Recommended)

#### Ubuntu/Debian
```sh
# OpenXR dependencies
sudo apt update
sudo apt install libopenxr-loader1 libopenxr-dev xr-hardware openxr-layer-corevalidation

# Monado runtime (recommended)
sudo apt install libopenxr1-monado monado-cli monado-gui
```

#### Arch Linux
```sh
sudo pacman -S openxr vulkan-devel
```

### VR Runtime Setup

#### Monado (Open Source)
```sh
# Start Monado service
rm -rf /run/user/1000/monado_comp_ipc && monado-service --verbose

# For testing without VR hardware
monado-service --verbose --null
```

#### SteamVR
Install through Steam for commercial VR headset support.

## Building

```sh
zig build
```

The build system automatically:
- Generates OpenXR/Vulkan bindings via `loader-generator`
- Compiles GLSL shaders to SPIR-V using `glslc`
- Links required system libraries

### Build Options

```sh
# Debug build (default)
zig build

# Release build
zig build -Doptimize=ReleaseFast

# Clean build
zig build --summary all
```

## Running

```sh
# Ensure VR runtime is running first
zig build run
```

The application:
1. Initializes OpenXR instance with debug layers
2. Creates Vulkan context with validation
3. Sets up VR session and swapchains
4. Enters main event loop
5. Handles graceful shutdown on Ctrl+C

## Testing

Run the unit tests to verify your environment:

```sh
zig build test
```

## Troubleshooting

**"glslc not found in PATH"**
- Install Vulkan SDK and add to PATH
- Verify: `glslc --version`

**OpenXR initialization fails**
- Start VR runtime first
- Check runtime with: `openxr_runtime_list`
- Try null driver: `monado-service --null`

**Vulkan errors**
- Update graphics drivers
- Verify support: `vulkaninfo`