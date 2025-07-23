# Contributing to WallensteinVR

We welcome contributions from the community! This guide will help you get started with contributing to WallensteinVR.

## Getting Started

### Development Environment

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/WallensteinVR.git
   cd WallensteinVR
   ```

3. **Set up development environment:**
   ```bash
   # Install prerequisites (see Installation guide)
   # Start VR runtime
   monado-service --verbose --null
   
   # Build and test
   zig build
   zig build test
   zig build run
   ```

### Development Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards
3. **Test thoroughly:**
   ```bash
   zig build test
   zig build run
   ```

4. **Commit with clear messages:**
   ```bash
   git commit -m "Add feature: brief description
   
   Detailed explanation of what this commit does and why."
   ```

5. **Push and create a Pull Request**

## Areas for Contribution

### 🚀 High Priority

- **Windows Support** - Native Windows OpenXR/Vulkan integration
- **macOS Support** - MoltenVK integration for macOS
- **Performance Optimization** - VR-specific rendering optimizations
- **Documentation** - API docs, tutorials, examples
- **Testing** - Unit tests, integration tests, CI improvements

### 🎯 Medium Priority

- **VR Runtime Support** - Additional OpenXR runtime integrations
- **Shader Examples** - More complex shader demonstrations
- **Build System** - Cross-platform build improvements
- **Error Handling** - Better error messages and recovery
- **Logging** - Structured logging and debugging tools

### 💡 Good First Issues

- **Documentation fixes** - Typos, clarity improvements
- **Code comments** - Adding explanatory comments
- **Example applications** - Simple VR demos
- **Build scripts** - Platform-specific build helpers
- **Shader validation** - Additional shader error checking

## Coding Standards

### Zig Style Guide

Follow the [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide):

```zig
// Good: snake_case for variables and functions
const my_variable = 42;
pub fn myFunction() void {}

// Good: PascalCase for types
pub const MyStruct = struct {
    field_name: u32,
};

// Good: Clear, descriptive names
pub fn createVulkanInstance() !c.VkInstance {}

// Avoid: Abbreviations and unclear names
pub fn createVkInst() !c.VkInstance {}  // Bad
```

### Error Handling

Use Zig's error handling consistently:

```zig
// Good: Proper error propagation
pub fn initializeVR() !void {
    const instance = try xr.createInstance(extensions, layers);
    const session = try xr.createSession(instance);
}

// Good: Specific error handling when needed
pub fn loadShader(path: []const u8) !c.VkShaderModule {
    const file_content = std.fs.cwd().readFileAlloc(allocator, path, max_size) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("Shader file not found: {s}", .{path});
            return error.ShaderNotFound;
        },
        else => return err,
    };
    // ... rest of function
}
```

### Documentation

Document public APIs with doc comments:

```zig
/// Creates a new OpenXR instance with the specified extensions and layers.
/// 
/// This function initializes the OpenXR runtime and validates that all
/// requested extensions are available.
///
/// Parameters:
/// - extensions: Array of extension names to enable
/// - layers: Array of API layer names to enable
///
/// Returns:
/// - XrInstance handle on success
/// - XrError on failure (see error codes for details)
///
/// Example:
/// ```zig
/// const instance = try createInstance(
///     &[_][*:0]const u8{c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME},
///     &[_][*:0]const u8{"XR_APILAYER_LUNARG_core_validation"}
/// );
/// ```
pub fn createInstance(extensions: []const [*:0]const u8, layers: []const [*:0]const u8) !c.XrInstance {
    // Implementation...
}
```

## Testing Guidelines

### Unit Tests

Write tests for new functionality:

```zig
test "createInstance with valid extensions" {
    const testing = std.testing;
    
    const extensions = &[_][*:0]const u8{
        c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
    };
    const layers = &[_][*:0]const u8{};
    
    const instance = try createInstance(extensions, layers);
    defer c.xrDestroyInstance(instance);
    
    try testing.expect(instance != null);
}

test "createInstance with invalid extension fails" {
    const testing = std.testing;
    
    const extensions = &[_][*:0]const u8{"XR_INVALID_EXTENSION"};
    const layers = &[_][*:0]const u8{};
    
    try testing.expectError(error.XrErrorExtensionNotPresent, createInstance(extensions, layers));
}
```

### Integration Tests

Test complete workflows:

```zig
test "full VR initialization sequence" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const config = Engine.Config{
        .xr_extensions = &[_][*:0]const u8{c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME},
        .xr_layers = &[_][*:0]const u8{},
        .vk_layers = &[_][*:0]const u8{},
    };
    
    const engine = try Engine.init(gpa.allocator(), config);
    defer engine.deinit();
    
    // Test that engine initialized successfully
    try testing.expect(engine.xr_instance != null);
    try testing.expect(engine.vk_instance != null);
}
```

## Pull Request Guidelines

### Before Submitting

- [ ] Code follows Zig style guidelines
- [ ] All tests pass (`zig build test`)
- [ ] Application builds and runs (`zig build run`)
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear and descriptive

### PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings introduced
```

## Code Review Process

### What We Look For

1. **Correctness** - Does the code work as intended?
2. **Safety** - Proper error handling and resource management
3. **Performance** - VR-appropriate performance characteristics
4. **Maintainability** - Clear, readable, well-documented code
5. **Testing** - Adequate test coverage

### Review Timeline

- **Initial response**: Within 2-3 days
- **Full review**: Within 1 week
- **Follow-up**: Within 2-3 days of updates

## Community Guidelines

### Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/):

- **Be respectful** and inclusive
- **Be collaborative** and constructive
- **Focus on the code**, not the person
- **Help newcomers** learn and contribute

### Communication Channels

- **GitHub Issues** - Bug reports, feature requests
- **GitHub Discussions** - Questions, ideas, general discussion
- **Pull Requests** - Code review and collaboration

## Recognition

Contributors are recognized in:
- **CONTRIBUTORS.md** file
- **Release notes** for significant contributions
- **Documentation** for major features

## Getting Help

### For Contributors

- **Documentation questions** - Check existing docs first, then ask in Discussions
- **Technical issues** - Create an issue with detailed reproduction steps
- **Design decisions** - Start a Discussion to gather community input

### Mentorship

New contributors can request mentorship:
- Comment on "good first issue" tickets
- Ask questions in GitHub Discussions
- Join our community chat (coming soon)

## Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR** - Breaking changes
- **MINOR** - New features, backward compatible
- **PATCH** - Bug fixes, backward compatible

### Release Cycle

- **Regular releases** - Monthly minor releases
- **Patch releases** - As needed for critical fixes
- **Major releases** - When significant breaking changes accumulate

Thank you for contributing to WallensteinVR! 🥽