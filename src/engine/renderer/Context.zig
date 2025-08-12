const SpectatorView = @import("SpectatorView.zig");
const VulkanSwapchain = @import("VulkanSwapchain.zig");
const XrSwapchain = @import("XrSwapchain.zig");
const loader = @import("loader");
const c = loader.c;
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const ImGui = @import("ImGui.zig");

imgui: ImGui,
spectator_view: SpectatorView,
xr_instance: c.XrInstance,
xr_session: c.XrSession,
xr_debug_messenger: c.XrDebugUtilsMessengerEXT,
xr_system_id: c.XrSystemId,
xr_space: c.XrSpace,
xr_swapchain: XrSwapchain,
action_set: c.XrActionSet,
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

//XR INPUT POSE CONTEXT
grabbed_block: [2]i32 = .{ -1, -1 },
near_block: [2]i32 = .{ -1, -1 },

grab_state: [2]c.XrActionStateFloat = .{ .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT }, .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT } },
hand_paths: [2]c.XrPath = .{ 0, 0 },
hand_pose_space: [2]c.XrSpace = undefined,
hand_pose: [2]c.XrPosef = .{
    .{
        .orientation = .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        .position = .{ .x = 0.0, .z = 0.0, .y = -100 },
    },
    .{
        .orientation = .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        .position = .{ .x = 0.0, .z = 0.0, .y = -100 },
    },
},
palm_pose_action: c.XrAction = undefined,
grab_cube_action: c.XrAction = undefined,
hand_pose_state: [2]c.XrActionStatePose = .{
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
},

player_pos_x: f32 = 0,
player_pos_y: f32 = 0,
player_pos_z: f32 = 0,
