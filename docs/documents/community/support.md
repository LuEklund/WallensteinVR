# Support & Community

Get help, connect with other developers, and contribute to the WallensteinVR community.

## Getting Help

### 🐛 Bug Reports & Issues

**GitHub Issues** - For bugs, feature requests, and technical problems
- [Report a Bug](https://github.com/LuEklund/WallensteinVR/issues/new?template=bug_report.md)
- [Request a Feature](https://github.com/LuEklund/WallensteinVR/issues/new?template=feature_request.md)
- [Browse Existing Issues](https://github.com/LuEklund/WallensteinVR/issues)

**Before Creating an Issue:**
1. Search existing issues to avoid duplicates
2. Check the [Troubleshooting Guide](../guides/troubleshooting.md)
3. Include system information and error messages
4. Provide minimal reproduction steps

### 💬 Community Discussion

**GitHub Discussions** - For questions, ideas, and community interaction
- [Ask Questions](https://github.com/LuEklund/WallensteinVR/discussions/categories/q-a)
- [Share Ideas](https://github.com/LuEklund/WallensteinVR/discussions/categories/ideas)
- [Show Your Projects](https://github.com/LuEklund/WallensteinVR/discussions/categories/show-and-tell)
- [General Discussion](https://github.com/LuEklund/WallensteinVR/discussions/categories/general)

### 📚 Documentation

**Self-Help Resources:**
- [Installation Guide](../installation.md) - Setup and prerequisites
- [Quick Start](../quick-start.md) - Get running in 5 minutes
- [Troubleshooting](../guides/troubleshooting.md) - Common issues and solutions
- [API Reference](../api/overview.md) - Complete function documentation
- [Examples](../examples/basic-vr.md) - Code examples and tutorials

## Community Resources

### 🔗 Related Communities

**OpenXR Community**
- [OpenXR Specification](https://www.khronos.org/openxr/)
- [OpenXR Discord](https://discord.gg/openxr) - Official OpenXR community
- [Monado Project](https://monado.freedesktop.org/) - Open source OpenXR runtime

**Vulkan Community**
- [Vulkan Guide](https://vkguide.dev/) - Excellent Vulkan learning resource
- [Vulkan Discord](https://discord.gg/vulkan) - Official Vulkan community
- [Vulkan Samples](https://github.com/KhronosGroup/Vulkan-Samples) - Official examples

**Zig Community**
- [Zig Language](https://ziglang.org/) - Official Zig website
- [Zig Discord](https://discord.gg/zig) - Official Zig community
- [Zig Learn](https://ziglearn.org/) - Comprehensive Zig tutorial

### 🎓 Learning Resources

**VR Development**
- [OpenXR Tutorial Series](https://github.com/maluoi/openxr-tutorial) - Comprehensive OpenXR guide
- [VR Development Best Practices](https://developer.oculus.com/documentation/native/pc/dg-performance-guidelines/)
- [Vulkan VR Rendering](https://www.khronos.org/assets/uploads/developers/library/2016-vulkan-devday-uk/7-Vulkan-VR.pdf)

**Graphics Programming**
- [Learn OpenGL](https://learnopengl.com/) - Graphics fundamentals
- [Real-Time Rendering](http://www.realtimerendering.com/) - Advanced graphics techniques
- [GPU Gems](https://developer.nvidia.com/gpugems/gpugems/contributors) - GPU programming techniques

## Support Tiers

### 🆓 Community Support

**What's Included:**
- GitHub Issues and Discussions
- Community-driven help and answers
- Documentation and examples
- Best-effort response from maintainers

**Response Time:**
- Issues: 2-7 days (depending on complexity)
- Discussions: Community-driven, varies
- Pull Requests: 1-2 weeks for review

**Best For:**
- Learning and experimentation
- Open source projects
- Non-critical applications

### 🏢 Enterprise Support

**Coming Soon** - Professional support options for commercial projects:
- Priority issue resolution
- Direct communication channels
- Custom feature development
- Training and consultation

**Contact:** enterprise@wallensteinvr.dev (coming soon)

## Contributing Back

### 🤝 Ways to Help

**Code Contributions**
- Fix bugs and implement features
- Improve performance and optimization
- Add platform support (Windows, macOS)
- See [Contributing Guide](contributing.md)

**Documentation**
- Fix typos and improve clarity
- Add examples and tutorials
- Translate documentation
- Create video tutorials

**Community Support**
- Answer questions in Discussions
- Help newcomers get started
- Share your projects and experiences
- Report bugs and test new features

**Testing & Feedback**
- Test on different hardware configurations
- Report compatibility issues
- Provide performance feedback
- Suggest improvements

### 🏆 Recognition

Active contributors are recognized through:
- **Contributors list** in repository
- **Release notes** mentions
- **Community highlights** in discussions
- **Maintainer status** for long-term contributors

## Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/) to ensure a welcoming community:

### Our Pledge

We pledge to make participation in our community a harassment-free experience for everyone, regardless of:
- Age, body size, disability, ethnicity
- Gender identity and expression
- Level of experience, education, socio-economic status
- Nationality, personal appearance, race, religion
- Sexual identity and orientation

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what's best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**
- Harassment, trolling, or insulting comments
- Public or private harassment
- Publishing others' private information
- Other conduct inappropriate in a professional setting

### Enforcement

Report violations to: conduct@wallensteinvr.dev (coming soon)

## FAQ

### General Questions

**Q: Is WallensteinVR ready for production use?**
A: WallensteinVR is currently in early development. It's great for learning and experimentation, but not recommended for production applications yet.

**Q: What VR headsets are supported?**
A: Any headset with OpenXR runtime support, including:
- Meta Quest (via Link/Air Link)
- HTC Vive series
- Valve Index
- Windows Mixed Reality headsets
- Pico headsets

**Q: Can I use this for commercial projects?**
A: Yes! WallensteinVR is MIT licensed, allowing commercial use. See LICENSE file for details.

### Technical Questions

**Q: Why Zig instead of C++ or Rust?**
A: Zig provides memory safety without garbage collection, excellent C interop, and compile-time guarantees that make it ideal for VR applications where performance and reliability are critical.

**Q: Can I contribute if I'm new to VR development?**
A: Absolutely! We welcome contributors of all skill levels. Check out our "good first issue" labels and don't hesitate to ask questions.

**Q: How do I test without VR hardware?**
A: Use Monado's null driver: `monado-service --verbose --null`. This simulates a VR environment for development and testing.

### Platform Questions

**Q: When will Windows support be available?**
A: Windows support is a high priority. We're looking for contributors to help with native Windows OpenXR/Vulkan integration.

**Q: What about macOS support?**
A: macOS support via MoltenVK is planned but lower priority due to limited VR ecosystem on macOS.

**Q: Can I run this in WSL2?**
A: WSL2 with GPU passthrough may work but isn't officially supported. Native Windows support is preferred.

## Stay Connected

### 📢 Announcements

- **GitHub Releases** - New versions and features
- **GitHub Discussions** - Development updates
- **README.md** - Latest project status

### 🔄 Regular Updates

- **Monthly releases** with new features
- **Weekly development updates** in Discussions
- **Quarterly roadmap reviews**

### 📧 Contact

- **General inquiries:** hello@wallensteinvr.dev (coming soon)
- **Security issues:** security@wallensteinvr.dev (coming soon)
- **Enterprise support:** enterprise@wallensteinvr.dev (coming soon)

---

**Thank you for being part of the WallensteinVR community!** 🥽

Whether you're just getting started or you're a VR development veteran, we're excited to have you here. Don't hesitate to reach out with questions, ideas, or just to say hello!