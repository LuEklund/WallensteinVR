# Downloads

Get WallensteinVR and start developing VR applications with Zig, OpenXR, and Vulkan.

## Latest Release

### Development Version (Recommended)

**Current Status:** Active Development  
**Stability:** Alpha - suitable for learning and experimentation

```bash
# Clone the latest development version
git clone https://github.com/LuEklund/WallensteinVR.git
cd WallensteinVR

# Build from source
zig build
```

**What's Included:**
- Complete source code with examples
- Automatic shader compilation system
- Comprehensive documentation
- Debug validation layers
- Cross-platform VR runtime support

## Prerequisites

Before downloading, ensure you have the required dependencies:

### Required Software
- **[Zig Compiler](https://ziglang.org/download/)** - Version 0.15.0-dev.1147+69cf40da6 or newer
- **[Vulkan SDK](https://vulkan.lunarg.com/sdk/home)** - Complete SDK with `glslc` shader compiler
- **OpenXR Runtime** - Choose one:
  - **[Monado](https://monado.freedesktop.org/)** (Recommended for Linux)
  - **[SteamVR](https://store.steampowered.com/app/250820/SteamVR/)** (Windows/Linux)
  - **[Oculus Runtime](https://developer.oculus.com/downloads/package/oculus-openxr-mobile-sdk/)** (Windows)

### System Requirements

**Minimum:**
- **OS:** Linux (Ubuntu 20.04+, Arch, Fedora)
- **GPU:** Vulkan 1.1 compatible graphics card
- **RAM:** 4GB system memory
- **Storage:** 2GB free space

**Recommended:**
- **OS:** Linux with recent kernel (5.15+)
- **GPU:** Dedicated graphics card with 4GB+ VRAM
- **RAM:** 8GB+ system memory
- **VR Hardware:** OpenXR-compatible VR headset

## Installation Methods

### Method 1: Git Clone (Recommended)

```bash
# Clone repository
git clone https://github.com/LuEklund/WallensteinVR.git
cd WallensteinVR

# Verify prerequisites
zig version                    # Should be 0.15.0-dev.1147+69cf40da6+
glslc --version               # Vulkan shader compiler
vulkaninfo --summary          # Vulkan support
openxr_runtime_list           # Available VR runtimes

# Build project
zig build

# Test installation
zig build test
```

### Method 2: Download Archive

**Coming Soon** - Pre-built releases will be available once the project reaches beta status.

### Method 3: Package Managers

**Future Plans:**
- **Arch AUR** - Community package
- **Homebrew** - macOS support
- **Snap/Flatpak** - Universal Linux packages

## Platform Support

### ✅ Fully Supported
- **Linux** - Primary development platform
  - Ubuntu 20.04+ (tested)
  - Arch Linux (tested)
  - Fedora 35+ (community tested)
  - Other distributions (should work)

### 🚧 In Development
- **Windows** - Native support in progress
  - WSL2 may work with GPU passthrough
  - Native Windows OpenXR/Vulkan integration planned

### 📋 Planned
- **macOS** - MoltenVK integration planned
  - Limited VR ecosystem on macOS
  - Lower priority than Windows support

## VR Runtime Compatibility

### OpenXR Runtimes

**✅ Tested and Supported:**
- **Monado** - Open source OpenXR runtime (recommended)
- **SteamVR** - Valve's VR runtime
- **Oculus Runtime** - Meta's OpenXR implementation

**🔄 Should Work (untested):**
- **Windows Mixed Reality** - Microsoft's OpenXR runtime
- **Pico Runtime** - ByteDance VR runtime
- **Varjo Runtime** - Enterprise VR runtime

### VR Hardware

**✅ Confirmed Working:**
- Meta Quest 2/3 (via Link/Air Link)
- HTC Vive/Vive Pro
- Valve Index
- Any Monado-supported hardware

**🔄 Should Work:**
- Windows Mixed Reality headsets
- Pico 4/4 Enterprise
- Varjo Aero/VR-3
- Any OpenXR-compatible headset

## Quick Start

### 1. Install Prerequisites

**Ubuntu/Debian:**
```bash
# System packages
sudo apt update
sudo apt install build-essential git

# OpenXR and Vulkan
sudo apt install libopenxr-loader1 libopenxr-dev vulkan-tools libvulkan-dev

# Monado VR runtime
sudo apt install libopenxr1-monado monado-cli monado-gui

# Download Zig compiler
wget https://ziglang.org/download/0.15.0-dev.1147+69cf40da6/zig-linux-x86_64-0.15.0-dev.1147+69cf40da6.tar.xz
tar -xf zig-linux-*.tar.xz
sudo mv zig-linux-* /opt/zig
echo 'export PATH="/opt/zig:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Arch Linux:**
```bash
# System packages
sudo pacman -S base-devel git

# OpenXR and Vulkan
sudo pacman -S openxr vulkan-devel vulkan-tools

# Zig compiler
sudo pacman -S zig

# Monado (AUR)
yay -S monado-git
```

### 2. Download and Build

```bash
# Clone repository
git clone https://github.com/LuEklund/WallensteinVR.git
cd WallensteinVR

# Build project
zig build

# Start VR runtime (in another terminal)
monado-service --verbose --null  # Use --null for testing without VR hardware

# Run application
zig build run
```

### 3. Verify Installation

You should see output similar to:
```
OpenXR instance created successfully
Vulkan instance created with validation
Physical device selected: [Your GPU Name]
VR session established
Entering main loop...
Program started. Press Ctrl+C to quit, or send SIGTERM.
```

## Development Setup

### IDE Support

**Visual Studio Code:**
```bash
# Install Zig extension
code --install-extension ziglang.vscode-zig

# Open project
code WallensteinVR/
```

**Vim/Neovim:**
```bash
# Install zig.vim plugin
git clone https://github.com/ziglang/zig.vim ~/.vim/pack/plugins/start/zig.vim
```

### Debug Configuration

```bash
# Build with debug symbols
zig build -Doptimize=Debug

# Run with debugger
gdb ./zig-out/bin/WallensteinVr

# Enable verbose logging
zig build run 2>&1 | tee debug.log
```

## Troubleshooting Downloads

### Common Issues

**"Zig version too old"**
- Download latest Zig from [ziglang.org](https://ziglang.org/download/)
- Ensure PATH points to correct Zig installation

**"glslc not found"**
- Install complete Vulkan SDK, not just runtime
- Add Vulkan bin directory to PATH

**"No OpenXR runtime found"**
- Install and start VR runtime before building
- Check with `openxr_runtime_list`

**Build fails with linking errors**
- Install development packages: `libopenxr-dev`, `libvulkan-dev`
- Check library paths with `ldconfig -p | grep -E "(openxr|vulkan)"`

### Getting Help

- **Installation Issues:** [GitHub Issues](https://github.com/LuEklund/WallensteinVR/issues)
- **General Questions:** [GitHub Discussions](https://github.com/LuEklund/WallensteinVR/discussions)
- **Documentation:** [Installation Guide](../installation.md)
- **Troubleshooting:** [Troubleshooting Guide](../guides/troubleshooting.md)

## License

WallensteinVR is released under the **MIT License**, allowing:
- ✅ Commercial use
- ✅ Modification and distribution
- ✅ Private use
- ✅ Patent use

See [LICENSE](https://github.com/LuEklund/WallensteinVR/blob/master/LICENSE) for full terms.

---

**Ready to start VR development?** 🥽

Download WallensteinVR today and join the growing community of developers building the future of open-source virtual reality!