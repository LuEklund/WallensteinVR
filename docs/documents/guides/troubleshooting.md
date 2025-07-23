# Troubleshooting

Common issues and solutions for WallensteinVR development and runtime.

## Installation Issues

### Vulkan SDK Problems

**"glslc not found in PATH"**
```bash
# Verify Vulkan SDK installation
which glslc
glslc --version

# Add to PATH if needed (Linux)
export PATH=$PATH:/usr/local/vulkan/bin

# Reinstall Vulkan SDK if missing
# Download from: https://vulkan.lunarg.com/sdk/home
```

**Vulkan validation layers not found**
```bash
# Check available layers
vulkaninfo --summary | grep -A 20 "Instance Layers"

# Install validation layers (Ubuntu)
sudo apt install vulkan-validationlayers-dev

# Set layer path if needed
export VK_LAYER_PATH=/usr/share/vulkan/explicit_layer.d
```

### OpenXR Runtime Issues

**"No OpenXR runtime found"**
```bash
# Check for active runtime
openxr_runtime_list

# Install Monado (recommended)
sudo apt install libopenxr1-monado monado-cli

# Start Monado service
rm -rf /run/user/1000/monado_comp_ipc
monado-service --verbose
```

**OpenXR extensions not available**
```bash
# Check available extensions
openxr_runtime_list --verbose

# Ensure runtime supports required extensions:
# - XR_KHR_vulkan_enable
# - XR_KHR_vulkan_enable2
# - XR_EXT_debug_utils
```

## Build Issues

### Zig Compiler Problems

**Wrong Zig version**
```bash
# Check current version
zig version

# Required: 0.15.0-dev.1147+69cf40da6 or newer
# Download from: https://ziglang.org/download/
```

**Build cache issues**
```bash
# Clear build cache
rm -rf zig-cache zig-out

# Clean rebuild
zig build --summary all
```

### Linking Problems

**System library not found**
```bash
# Install missing libraries (Ubuntu)
sudo apt install libopenxr-dev libvulkan-dev

# Check library paths
ldconfig -p | grep -E "(openxr|vulkan)"

# Set library path if needed
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

## Runtime Issues

### VR Session Problems

**"XrError.ErrorInitializationFailed"**
- Ensure VR runtime is running before starting application
- Check VR headset is connected and detected
- Verify OpenXR runtime permissions

**"XrError.ErrorSessionLost"**
- VR runtime crashed or was restarted
- Restart both runtime and application
- Check system resources (memory, GPU)

**"XrError.ErrorSystemInvalid"**
- No VR hardware detected
- Try with null driver: `monado-service --null`
- Check USB connections and power

### Graphics Issues

**"VkError.ErrorDeviceLost"**
- GPU driver crash or timeout
- Update graphics drivers
- Check GPU temperature and power
- Reduce graphics settings

**"VkError.ErrorOutOfDeviceMemory"**
- GPU memory exhausted
- Close other graphics applications
- Reduce texture/buffer sizes
- Check for memory leaks

**Black screen in VR**
- Shader compilation failed
- Check shader files in `assets/shaders/`
- Verify SPIR-V output in build directory
- Enable Vulkan validation for details

## Performance Issues

### Low Frame Rate

**Symptoms:** Stuttering, dropped frames, motion sickness

**Solutions:**
```bash
# Check VR compositor performance
# (Monado example)
monado-cli --help

# Monitor GPU usage
nvidia-smi  # NVIDIA
radeontop   # AMD

# Check CPU usage
htop
```

**Optimization tips:**
- Enable GPU performance mode
- Close unnecessary applications
- Check thermal throttling
- Verify VSync/frame limiting settings

### High Latency

**Symptoms:** Delayed head tracking, motion blur

**Causes:**
- CPU/GPU bottlenecks
- Inefficient render pipeline
- Driver issues
- USB bandwidth limitations

**Solutions:**
- Profile with RenderDoc or similar tools
- Optimize shader complexity
- Reduce render resolution temporarily
- Check USB 3.0 connection quality

## Development Issues

### Debugging Problems

**Debug layers not working**
```bash
# Verify validation layers
vulkaninfo | grep -A 5 "VK_LAYER_KHRONOS_validation"

# Check OpenXR layers
export XR_API_LAYER_PATH=/usr/share/openxr/1/api_layers/explicit.d/
```

**No debug output**
- Ensure debug messengers are created
- Check console output redirection
- Verify debug layer installation

### Code Issues

**Compilation errors**
- Check Zig version compatibility
- Verify import paths
- Review error messages carefully
- Check for missing dependencies

**Runtime crashes**
- Enable all validation layers
- Use debug build: `zig build -Doptimize=Debug`
- Run with debugger: `gdb ./zig-out/bin/WallensteinVr`
- Check memory usage patterns

## Platform-Specific Issues

### Linux

**Permission denied errors**
```bash
# Add user to input group (for VR devices)
sudo usermod -a -G input $USER

# Set udev rules for VR hardware
sudo cp /usr/share/doc/monado/monado.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

**Wayland compatibility**
```bash
# Some VR runtimes prefer X11
export XDG_SESSION_TYPE=x11

# Or force Wayland support
export XDG_SESSION_TYPE=wayland
```

### Windows

**Currently not officially supported**
- Use WSL2 with Linux instructions
- Or use Linux VM with GPU passthrough
- Native Windows support planned for future

## Diagnostic Commands

### System Information
```bash
# VR system info
openxr_runtime_list --verbose

# Graphics info
vulkaninfo --summary
lspci | grep -i vga

# System resources
free -h
df -h
```

### Application Diagnostics
```bash
# Verbose application run
zig build run 2>&1 | tee debug.log

# Memory usage monitoring
valgrind --tool=massif ./zig-out/bin/WallensteinVr

# GPU profiling
renderdoc  # Launch and attach to process
```

## Getting Help

### Before Reporting Issues

1. **Check this troubleshooting guide**
2. **Enable all debug layers and validation**
3. **Collect system information**
4. **Try with minimal configuration**
5. **Search existing issues on GitHub**

### Information to Include

- **System specs** (OS, GPU, VR headset)
- **Software versions** (Zig, Vulkan SDK, OpenXR runtime)
- **Complete error messages** with stack traces
- **Steps to reproduce** the issue
- **Debug output** with validation enabled

### Support Channels

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions and community help
- **OpenXR Community** - Runtime-specific issues
- **Vulkan Community** - Graphics-related problems

## Quick Fixes Checklist

When something doesn't work, try these in order:

1. ✅ **Restart VR runtime** (`monado-service` or SteamVR)
2. ✅ **Clean rebuild** (`rm -rf zig-cache && zig build`)
3. ✅ **Check connections** (USB, power, display cables)
4. ✅ **Update drivers** (GPU, VR headset firmware)
5. ✅ **Enable validation** (both OpenXR and Vulkan layers)
6. ✅ **Test with null driver** (`monado-service --null`)
7. ✅ **Check system resources** (memory, disk space, CPU)
8. ✅ **Verify prerequisites** (Vulkan SDK, OpenXR runtime)

Most issues are resolved by the first three steps!