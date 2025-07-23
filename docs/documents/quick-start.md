# Quick Start

Get WallensteinVR running in minutes with this streamlined setup guide.

## Prerequisites Check

Before starting, ensure you have:
- ✅ **Vulkan SDK** installed with `glslc` in PATH
- ✅ **Zig compiler** version `0.15.0-dev.1147+69cf40da6` or newer
- ✅ **VR Runtime** (Monado or SteamVR) installed

Quick verification:
```bash
# Check Zig version
zig version

# Check Vulkan tools
glslc --version
vulkaninfo --summary

# Check OpenXR runtime
openxr_runtime_list
```

## 5-Minute Setup

### 1. Clone and Build
```bash
git clone https://github.com/LuEklund/WallensteinVR.git
cd WallensteinVR
zig build
```

### 2. Start VR Runtime
```bash
# For Monado (recommended for development)
monado-service --verbose --null  # No VR hardware needed

# Or for SteamVR
# Launch SteamVR through Steam
```

### 3. Run Application
```bash
zig build run
```

You should see:
```
OpenXR instance created successfully
Vulkan instance created with validation
Physical device selected: [Your GPU]
VR session established
Entering main loop...
```

## What You'll See

The application creates a basic VR environment with:
- **Stereo rendering** for both eyes
- **Debug validation** layers active
- **Graceful shutdown** on Ctrl+C
- **Console logging** for development

## Next Steps

### Explore the Code
- **`src/main.zig`** - Main engine and application lifecycle
- **`src/openxr.zig`** - VR runtime integration
- **`src/vulkan.zig`** - Graphics pipeline
- **`assets/shaders/`** - GLSL shaders (auto-compiled)

### Development Workflow
1. **Modify shaders** in `assets/shaders/` - they auto-compile
2. **Edit Zig code** in `src/` directory
3. **Rebuild** with `zig build`
4. **Test** with `zig build run`

### Common Development Tasks

**Add new shaders:**
```bash
# Create new shader file
echo '#version 450
void main() { gl_Position = vec4(0.0); }' > assets/shaders/new.vert

# Build automatically compiles it
zig build
```

**Debug with validation:**
```bash
# All validation layers are enabled by default
zig build run 2>&1 | tee debug.log
```

**Test without VR hardware:**
```bash
# Use Monado's null driver
monado-service --verbose --null
zig build run
```

## Troubleshooting Quick Fixes

**Build fails:**
```bash
# Clean and rebuild
rm -rf zig-cache zig-out
zig build
```

**OpenXR errors:**
```bash
# Restart VR runtime
pkill monado-service
monado-service --verbose --null
```

**Vulkan errors:**
```bash
# Check GPU drivers
vulkaninfo
# Update if needed
```

## Ready to Develop?

You now have a working VR application! Check out:
- [Architecture Guide](guides/architecture.md) - Understand the system design
- [API Reference](api/overview.md) - Detailed function documentation
- [Shader Development](guides/shaders.md) - Graphics pipeline details
- [Debugging Guide](guides/debugging.md) - Development tools and techniques

Happy VR development! 🥽