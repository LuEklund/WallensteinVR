const SpectatorView = @import("SpectatorView.zig");
const VulkanSwapchain = @import("VulkanSwapchain.zig");
const XrSwapchain = @import("XrSwapchain.zig");
const loader = @import("loader");
const c = loader.c;
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");

spectator_view: SpectatorView,
xr_instance: c.XrInstance,
xr_session: c.XrSession,
xr_debug_messenger: c.XrDebugUtilsMessengerEXT,
xr_system_id: c.XrSystemId,
xr_space: c.XrSpace,
xr_swapchain: XrSwapchain,
vk_debug_messenger: c.VkDebugUtilsMessengerEXT,
vk_instance: c.VkInstance,
vk_physical_device: c.VkPhysicalDevice,
vk_logical_device: c.VkDevice,
vkid: vk.Dispatcher,
vk_queue: c.VkQueue,
vk_fence: c.VkFence,
vk_swapchain: VulkanSwapchain,
render_pass: c.VkRenderPass,
command_pool: c.VkCommandPool,
descriptor_pool: c.VkDescriptorPool,
descriptor_set_layout: c.VkDescriptorSetLayout,
vertex_shader: c.VkShaderModule,
fragment_shader: c.VkShaderModule,
pipeline: c.VkPipeline,
pipeline_layout: c.VkPipelineLayout,
graphics_queue_family_index: u32,
image_index: u32 = 0,
last_rendered_image_index: u32 = 0,
predicted_time_frame: c.XrTime,
running: bool = false,
should_quit: bool = false,
should_render: c.VkBool32 = c.VK_FALSE,
