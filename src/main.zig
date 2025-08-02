const std = @import("std");
const log = @import("std").log;
const builtin = @import("builtin");
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const VulkanSwapchain = @import("VulkanSwapchain.zig");
const XrSwapchain = @import("XrSwapchain.zig");
const loader = @import("loader");
const build_options = @import("build_options");
const nz = @import("numz");
const c = loader.c;
const sdl = @import("sdl3");
var quit: std.atomic.Value(bool) = .init(false);

var object_grabbed: u32 = 0;
var object_pos = c.XrVector3f{ .x = 0, .y = 0, .z = 0 };
var grab_distance: f32 = 1;
const windowWidth: c_int = 1600;
const windowHeight: c_int = 900;

// var normals: [6]c.XrVector4f = .{
// .{ .x = 1.00, .y = 0.00, .z = 0.00, .w = 0 },
// .{ .x = -1.00, .y = 0.00, .z = 0.00, .w = 0 },
// .{ .x = 0.00, .y = 1.00, .z = 0.00, .w = 0 },
// .{ .x = 0.00, .y = -1.00, .z = 0.00, .w = 0 },
// .{ .x = 0.00, .y = 0.00, .z = 1.00, .w = 0 },
// .{ .x = 0.00, .y = 0.0, .z = -1.00, .w = 0 },
// };
//
var cube_vertecies: [8]c.XrVector4f = .{
    .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 1.0 }, // 0: Top-Front-Right
    .{ .x = 0.5, .y = 0.5, .z = -0.5, .w = 1.0 }, // 1: Top-Back-Right
    .{ .x = 0.5, .y = -0.5, .z = 0.5, .w = 1.0 }, // 2: Bottom-Front-Right
    .{ .x = 0.5, .y = -0.5, .z = -0.5, .w = 1.0 }, // 3: Bottom-Back-Right
    .{ .x = -0.5, .y = 0.5, .z = 0.5, .w = 1.0 }, // 4: Top-Front-Left
    .{ .x = -0.5, .y = 0.5, .z = -0.5, .w = 1.0 }, // 5: Top-Back-Left
    .{ .x = -0.5, .y = -0.5, .z = 0.5, .w = 1.0 }, // 6: Bottom-Front-Left
    .{ .x = -0.5, .y = -0.5, .z = -0.5, .w = 1.0 }, // 7: Bottom-Back-Left
};

var cube_indecies: [36]u32 = .{
    // Front face
    4, 6, 0,
    0, 6, 2,
    // Back face
    1, 3, 5,
    5, 3, 7,
    // Right face
    0, 2, 1,
    1, 2, 3,
    // Left face
    5, 7, 4,
    4, 7, 6,
    // Top face
    4, 0, 5,
    5, 0, 1,
    // Bottom face
    6, 7, 2,
    2, 7, 3,
};

var index_buffer: vk.VulkanBuffer = undefined;
var index_buffer2: vk.VulkanBuffer = undefined;
var vertex_buffer: vk.VulkanBuffer = undefined;
var vertex_buffer2: vk.VulkanBuffer = undefined;
// var normal_buffer: vk.VulkanBuffer = undefined;

pub const Engine = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    xr_instance: c.XrInstance,
    xr_session: c.XrSession,
    xrd: xr.Dispatcher,
    xr_instance_extensions: []const [*:0]const u8,
    xr_debug_messenger: c.XrDebugUtilsMessengerEXT,
    xr_system_id: c.XrSystemId,
    vk_instance: c.VkInstance,
    vk_debug_messenger: c.VkDebugUtilsMessengerEXT,
    vk_physical_device: c.VkPhysicalDevice,
    graphics_queue_family_index: u32,
    vk_logical_device: c.VkDevice,
    vk_queue: c.VkQueue,
    action_set: c.XrActionSet,
    l_action: c.XrAction,
    r_action: c.XrAction,
    l_action_g: c.XrAction,
    r_action_g: c.XrAction,
    hand_poses_space: [2]c.XrSpace,
    vkid: vk.Dispatcher,
    sdl_window: sdl.video.Window,
    sdl_surface: c.VkSurfaceKHR,

    //TODO: Move OUT!

    pub const Config = struct {
        xr_extensions: []const [*:0]const u8,
        xr_layers: []const [*:0]const u8,
        vk_layers: []const [*:0]const u8,
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        try xr.validateExtensions(allocator, config.xr_extensions);
        try xr.validateLayers(allocator, config.xr_layers);

        //SDL
        const init_flags: sdl.InitFlags = .{ .video = true };
        try sdl.init(init_flags);
        // defer sdl.quit(init_flags);
        const window: sdl.video.Window = try .init("Hello SDL3", windowWidth, windowHeight, .{ .vulkan = true, .resizable = true });
        try window.show();
        const vk_exts = try sdl.vulkan.getInstanceExtensions();
        for (0..vk_exts.len) |i| {
            std.debug.print("EXT_SDL: {s}\n", .{vk_exts[i]});
        }

        const xr_instance: c.XrInstance = try xr.createInstance(config.xr_extensions, config.xr_layers);
        const xrd = try xr.Dispatcher.init(xr_instance);
        const xr_debug_messenger: c.XrDebugUtilsMessengerEXT = try xr.createDebugMessenger(xrd, xr_instance);
        const xr_system_id: c.XrSystemId = try xr.getSystem(xr_instance);

        const action_set: c.XrActionSet = try xr.createActionSet(xr_instance);
        defer _ = c.xrDestroyActionSet(action_set);
        const leftHandAction: c.XrAction = try xr.createAction(action_set, "left-hand", c.XR_ACTION_TYPE_POSE_INPUT);
        defer _ = c.xrDestroyAction(leftHandAction);
        const rightHandAction: c.XrAction = try xr.createAction(action_set, "right-hand", c.XR_ACTION_TYPE_POSE_INPUT);
        defer _ = c.xrDestroyAction(leftHandAction);
        // const hand_poses: [2]c.XrPosef = .{
        //     .{
        //         .orientation = .{ 1.0, 0.0, 0.0, 0.0 },
        //         .position = .{ 0.0, 0.0, -100 },
        //     },
        //     .{
        //         .orientation = .{ 1.0, 0.0, 0.0, 0.0 },
        //         .position = .{ 0.0, 0.0, -100 },
        //     },
        // };
        // _ = hand_poses;
        const leftGrabAction: c.XrAction = try xr.createAction(action_set, "left-grab", c.XR_ACTION_TYPE_BOOLEAN_INPUT);
        defer _ = c.xrDestroyAction(leftGrabAction);
        const right_grab_action: c.XrAction = try xr.createAction(action_set, "right-grab", c.XR_ACTION_TYPE_BOOLEAN_INPUT);
        defer _ = c.xrDestroyAction(right_grab_action);

        const xr_graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, const xr_instance_extensions: []const [*:0]const u8 =
            try xr.getVulkanInstanceRequirements(xrd, allocator, xr_instance, xr_system_id);

        const vk_instance: c.VkInstance = try vk.createInstance(xr_graphics_requirements, xr_instance_extensions, config.vk_layers);
        const vkid = try vk.Dispatcher.init(vk_instance);
        const vk_debug_messenger: c.VkDebugUtilsMessengerEXT = try vk.createDebugMessenger(vkid, vk_instance);

        const surface = sdl.vulkan.Surface.init(window, @ptrCast(vk_instance), null) catch |err| {
            std.debug.print("SDL Error: {s}\n", .{sdl.c.SDL_GetError()});
            return err;
        };

        const physical_device: c.VkPhysicalDevice, const vk_device_extensions: []const [*:0]const u8 = try xr.getVulkanDeviceRequirements(xrd, allocator, xr_instance, xr_system_id, vk_instance);
        const queue_family_index = try vk.findGraphicsQueueFamily(physical_device, @ptrCast(surface.surface));

        const logical_device: c.VkDevice, const queue: c.VkQueue = try vk.createLogicalDevice(physical_device, queue_family_index, vk_device_extensions);

        const xr_session: c.XrSession = try xr.createSession(xr_instance, xr_system_id, vk_instance, physical_device, logical_device, queue_family_index);
        const leftHandSpace: c.XrSpace = try xr.createActionSpace(xr_session, leftHandAction);
        defer _ = c.xrDestroySpace(leftHandSpace);
        const rightHandSpace: c.XrSpace = try xr.createActionSpace(xr_session, rightHandAction);
        defer _ = c.xrDestroySpace(rightHandSpace);

        try xr.suggestBindings(xr_instance, leftHandAction, rightHandAction, leftGrabAction, right_grab_action);

        try xr.attachActionSet(xr_session, action_set);

        //TODO: MOVE OUT!
        vertex_buffer = try vk.createBuffer(
            physical_device,
            logical_device,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            cube_vertecies.len,
            @sizeOf(c.XrVector4f),
            @ptrCast(&cube_vertecies),
        );
        index_buffer = try vk.createBuffer(
            physical_device,
            logical_device,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            cube_indecies.len,
            @sizeOf(c.XrVector4f),
            @ptrCast(&cube_indecies),
        );
        vertex_buffer2 = try vk.createBuffer(
            physical_device,
            logical_device,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            cube_vertecies.len,
            @sizeOf(c.XrVector4f),
            @ptrCast(&cube_vertecies),
        );
        index_buffer2 = try vk.createBuffer(
            physical_device,
            logical_device,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            cube_indecies.len,
            @sizeOf(c.XrVector4f),
            @ptrCast(&cube_indecies),
        );
        // normal_buffer = try vk.createBuffer(
        //     physical_device,
        //     logical_device,
        //     c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        //     normals.len,
        //     @sizeOf(c.XrVector4f),
        //     @ptrCast(&normals),
        // );
        return .{
            .allocator = allocator,
            .xr_instance = xr_instance,
            .xr_session = xr_session,
            .xr_instance_extensions = xr_instance_extensions,
            .xrd = xrd,
            .xr_debug_messenger = xr_debug_messenger,
            .xr_system_id = xr_system_id,
            .vk_instance = vk_instance,
            .vk_debug_messenger = vk_debug_messenger,
            .vk_physical_device = physical_device,
            .graphics_queue_family_index = queue_family_index,
            .vk_logical_device = logical_device,
            .vk_queue = queue,
            .action_set = action_set,
            .l_action = leftHandAction,
            .l_action_g = leftGrabAction,
            .r_action_g = right_grab_action,
            .r_action = rightHandAction,
            .hand_poses_space = .{ leftHandSpace, rightHandSpace },
            .vkid = vkid,
            .sdl_window = window,
            .sdl_surface = @ptrCast(surface.surface),
        };
    }

    pub fn deinit(self: Self) void {
        self.vkid.vkDestroyDebugUtilsMessengerEXT(self.vk_instance, self.vk_debug_messenger, null);
        self.xrd.xrDestroyDebugUtilsMessengerEXT(self.xr_debug_messenger) catch {};

        _ = c.xrDestroySession(self.xr_session);
        _ = c.xrDestroyInstance(self.xr_instance);

        _ = c.vkDestroyBuffer(self.vk_logical_device, vertex_buffer.buffer, null);
        _ = c.vkDestroyBuffer(self.vk_logical_device, index_buffer.buffer, null);
        // _ = c.vkDestroyBuffer(self.vk_logical_device, normal_buffer.buffer, null);

        _ = c.vkFreeMemory(self.vk_logical_device, vertex_buffer.memory, null);
        _ = c.vkFreeMemory(self.vk_logical_device, index_buffer.memory, null);
        // _ = c.vkFreeMemory(self.vk_logical_device, normal_buffer.memory, null);

        _ = c.vkDestroyDevice(self.vk_logical_device, null);
        _ = c.vkDestroyInstance(self.vk_instance, null);
        self.sdl_window.deinit();
    }

    pub fn start(self: Self) !void {
        const eye_count = build_options.eye_count;
        var vulkan_swapchain: VulkanSwapchain = try .init(self.vk_physical_device, self.vk_logical_device, self.sdl_surface, windowWidth, windowHeight);
        var xr_swapchain: XrSwapchain = try .init(eye_count, self.vk_physical_device, self.xr_instance, self.xr_system_id, self.xr_session);
        const render_pass: c.VkRenderPass = try vk.createRenderPass(self.vk_logical_device, xr_swapchain.format, xr_swapchain.depth_format, xr_swapchain.sample_count);
        defer c.vkDestroyRenderPass(self.vk_logical_device, render_pass, null);
        const command_pool: c.VkCommandPool = try vk.createCommandPool(self.vk_logical_device, self.graphics_queue_family_index);
        defer c.vkDestroyCommandPool(self.vk_logical_device, command_pool, null);
        const descriptor_pool: c.VkDescriptorPool = try vk.createDescriptorPool(self.vk_logical_device);
        defer c.vkDestroyDescriptorPool(self.vk_logical_device, descriptor_pool, null);
        const descriptor_set_layout: c.VkDescriptorSetLayout = try vk.createDescriptorSetLayout(self.vk_logical_device);
        defer c.vkDestroyDescriptorSetLayout(self.vk_logical_device, descriptor_set_layout, null);
        const vertex_shader: c.VkShaderModule = try vk.createShader(self.allocator, self.vk_logical_device, "shaders/vertex.vert.spv");
        defer c.vkDestroyShaderModule(self.vk_logical_device, vertex_shader, null);
        const fragment_shader: c.VkShaderModule = try vk.createShader(self.allocator, self.vk_logical_device, "shaders/fragment.frag.spv");
        defer c.vkDestroyShaderModule(self.vk_logical_device, fragment_shader, null);
        const pipeline_layout: c.VkPipelineLayout, const pipeline: c.VkPipeline = try vk.createPipeline(self.vk_logical_device, render_pass, descriptor_set_layout, vertex_shader, fragment_shader, xr_swapchain.sample_count);
        defer c.vkDestroyPipelineLayout(self.vk_logical_device, pipeline_layout, null);
        defer c.vkDestroyPipeline(self.vk_logical_device, pipeline, null);

        const acquireFence: c.VkFence = try vk.createFence(self.vk_logical_device);

        try vulkan_swapchain.createSwapchainImages(command_pool);
        try xr_swapchain.createSwapchainImages(
            self.vk_physical_device,
            self.vk_logical_device,
            render_pass,
            command_pool,
            descriptor_pool,
            descriptor_set_layout,
        );

        const isPosix: bool = switch (builtin.os.tag) {
            .linux,
            .plan9,
            .solaris,
            .netbsd,
            .openbsd,
            .haiku,
            .macos,
            .ios,
            .watchos,
            .tvos,
            .visionos,
            .dragonfly,
            .freebsd,
            => true,

            else => false,
        };
        if (isPosix) {
            std.posix.sigaction(std.posix.SIG.INT, &.{
                .handler = .{ .handler = onInterrupt },
                .mask = std.posix.sigemptyset(),
                .flags = 0,
            }, null);
            std.debug.print("Program started. Press Ctrl+C to quit, or send SIGTERM.\n", .{});
        } else if (builtin.os.tag == .windows) {
            // --- Windows-specific graceful shutdown (Console Control Handler) ---
            // const windows = std.os.windows;

            // const HandlerFunc = fn(event_type: windows.DWORD) callconv(.Winapi) windows.BOOL;

            // const win_handler = struct {
            //     fn handle(event_type: windows.DWORD) callconv(.Winapi) windows.BOOL {
            //         switch (event_type) {
            //             windows.CTRL_C_EVENT,
            //             windows.CTRL_BREAK_EVENT,
            //             windows.CTRL_CLOSE_EVENT,
            //             windows.CTRL_LOGOFF_EVENT,
            //             windows.CTRL_SHUTDOWN_EVENT,
            //             => {
            //                 std.debug.print("Windows console event received ({}). Initiating graceful shutdown...\n", .{event_type});
            //                 quit_requested.store(true, .Release);
            //                 return 1; // TRUE, indicating handled
            //             },
            //             else => return 0, // FALSE, let default handler take over
            //         }
            //     }
            // }.handle;

            // _ = try windows.SetConsoleCtrlHandler(@ptrCast(HandlerFunc, win_handler), 1);
            @compileError("YOU ARE USING WINDOWS!");
        } else {
            @compileError("WTF ARE YOU USING? Not Posix or Windows OS");
        }

        const space: c.XrSpace = try xr.createSpace(self.xr_session);

        var imageIndex: u32 = 0;
        var lastRenderedImageIndex: u32 = 0;

        var running: bool = true;

        // var times: u8 = 0;
        // while (times < 8 and !quit.load(.acquire)) {
        while (!quit.load(.acquire)) {
            // times += 1;
            std.debug.print("\n\n=========[ENTERED while loop]===========\n\n", .{});
            while (sdl.events.poll()) |sdl_event| {
                switch (sdl_event) {
                    .quit => quit.store(true, .release),
                    .window_resized => |wr| {
                        try vulkan_swapchain.recreate(
                            self.sdl_surface,
                            self.vk_physical_device,
                            command_pool,
                            &imageIndex,
                            @intCast(wr.width),
                            @intCast(wr.height),
                        );
                    },
                    else => {},
                }
            }
            const vkResult = c.vkAcquireNextImageKHR(
                self.vk_logical_device,
                vulkan_swapchain.swapchain,
                0,
                null,
                acquireFence,
                &imageIndex,
            );

            if (vkResult == c.VK_ERROR_OUT_OF_DATE_KHR or vkResult == c.VK_SUBOPTIMAL_KHR) {
                const win_size = try self.sdl_window.getSize();

                try vulkan_swapchain.recreate(
                    self.sdl_surface,
                    self.vk_physical_device,
                    command_pool,
                    &imageIndex,
                    @intCast(win_size.width),
                    @intCast(win_size.height),
                );
            } else if (vkResult == c.VK_SUCCESS) {
                try loader.vkCheck(c.vkWaitForFences(
                    self.vk_logical_device,
                    1,
                    &acquireFence,
                    1,
                    std.math.maxInt(u64),
                ));
                try loader.vkCheck(c.vkResetFences(
                    self.vk_logical_device,
                    1,
                    &acquireFence,
                ));

                const element: VulkanSwapchain.SwapchainImage = vulkan_swapchain.swapchain_images[imageIndex];
                var beginInfo: c.VkCommandBufferBeginInfo = .{
                    .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
                    .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
                };
                try loader.vkCheck(c.vkBeginCommandBuffer(element.command_buffer, &beginInfo));

                const beforeDstBarrier: c.VkImageMemoryBarrier = .{
                    .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                    .srcAccessMask = c.VK_ACCESS_NONE,
                    .dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT,
                    .oldLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
                    .newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    .image = element.image,
                    .subresourceRange = .{
                        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                        .baseMipLevel = 0,
                        .levelCount = 1,
                        .baseArrayLayer = 0,
                        .layerCount = 1,
                    },
                };

                const beforeBarriers: [1]c.VkImageMemoryBarrier = .{beforeDstBarrier};

                c.vkCmdPipelineBarrier(
                    element.command_buffer,
                    c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                    c.VK_PIPELINE_STAGE_TRANSFER_BIT,
                    0,
                    0,
                    null,
                    0,
                    null,
                    beforeBarriers.len,
                    &beforeBarriers,
                );

                var region: c.VkImageBlit = .{
                    .srcSubresource = .{
                        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                        .mipLevel = 0,
                        .baseArrayLayer = 0,
                        .layerCount = 1,
                    },
                    .srcOffsets = .{
                        .{ .x = 0, .y = 0, .z = 0 },
                        .{ .x = @intCast(xr_swapchain.width), .y = @intCast(xr_swapchain.height), .z = 1 },
                    },
                    .dstSubresource = .{
                        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                        .mipLevel = 0,
                        .baseArrayLayer = 0,
                        .layerCount = 1,
                    },
                    .dstOffsets = .{
                        .{ .x = 0, .y = 0, .z = 0 },
                        .{ .x = @intCast(vulkan_swapchain.width), .y = @intCast(vulkan_swapchain.height), .z = 1 },
                    },
                };

                c.vkCmdBlitImage(
                    element.command_buffer,
                    xr_swapchain.swapchain_images[lastRenderedImageIndex].vk_dup_image,
                    c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                    element.image,
                    c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    1,
                    &region,
                    c.VK_FILTER_LINEAR,
                );

                const afterDstBarrier: c.VkImageMemoryBarrier = .{
                    .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                    .srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT,
                    .dstAccessMask = c.VK_ACCESS_NONE,
                    .oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    .newLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                    .image = element.image,
                    .subresourceRange = .{
                        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                        .baseMipLevel = 0,
                        .levelCount = 1,
                        .baseArrayLayer = 0,
                        .layerCount = 1,
                    },
                };

                const afterBarriers: [1]c.VkImageMemoryBarrier = .{afterDstBarrier};

                c.vkCmdPipelineBarrier(
                    element.command_buffer,
                    c.VK_PIPELINE_STAGE_TRANSFER_BIT,
                    c.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                    0,
                    0,
                    null,
                    0,
                    null,
                    afterBarriers.len,
                    &afterBarriers,
                );

                try loader.vkCheck(c.vkEndCommandBuffer(element.command_buffer));

                var waitStage: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_TRANSFER_BIT;

                var submitInfo: c.VkSubmitInfo = .{
                    .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
                    .pWaitDstStageMask = &waitStage,
                    .commandBufferCount = 1,
                    .pCommandBuffers = &element.command_buffer,
                    .signalSemaphoreCount = 1,
                    .pSignalSemaphores = &element.render_done_semaphore,
                };

                try loader.vkCheck(c.vkQueueSubmit(self.vk_queue, 1, &submitInfo, null));

                var presentInfo: c.VkPresentInfoKHR = .{
                    .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
                    .waitSemaphoreCount = 1,
                    .pWaitSemaphores = &element.render_done_semaphore,
                    .swapchainCount = 1,
                    .pSwapchains = &vulkan_swapchain.swapchain,
                    .pImageIndices = &imageIndex,
                };

                const vk_result: c.VkResult = c.vkQueuePresentKHR(self.vk_queue, &presentInfo);

                if (vk_result == c.VK_ERROR_OUT_OF_DATE_KHR or vk_result == c.VK_SUBOPTIMAL_KHR) {
                    const win_size = try self.sdl_window.getSize();
                    try vulkan_swapchain.recreate(
                        self.sdl_surface,
                        self.vk_physical_device,
                        command_pool,
                        &imageIndex,
                        @intCast(win_size.width),
                        @intCast(win_size.height),
                    );
                } else if (vk_result < 0) {
                    std.log.err("Failed to present Vulkan queue: {any}\n", .{vk_result});
                }
            } else if (vkResult != c.VK_TIMEOUT) {
                std.log.err("Failed to acquire next Vulkan swapchain image:{any}\n", .{vkResult});
            }

            var eventData = c.XrEventDataBuffer{
                .type = c.XR_TYPE_EVENT_DATA_BUFFER,
            };
            var result: c.XrResult = c.xrPollEvent(self.xr_instance, &eventData);
            if (result == c.XR_EVENT_UNAVAILABLE) {
                if (running) {
                    var frame_wait_info = c.XrFrameWaitInfo{ .type = c.XR_TYPE_FRAME_WAIT_INFO };
                    var frame_state = c.XrFrameState{ .type = c.XR_TYPE_FRAME_STATE };
                    result = c.xrWaitFrame(self.xr_session, &frame_wait_info, &frame_state);
                    if (result != c.XR_SUCCESS) {
                        std.debug.print("\n\n=========[OMG WE DIDED]===========\n\n", .{});
                        break;
                    }
                    var begin_frame_info = c.XrFrameBeginInfo{
                        .type = c.XR_TYPE_FRAME_BEGIN_INFO,
                    };
                    try loader.xrCheck(c.xrBeginFrame(self.xr_session, &begin_frame_info));
                    var should_quit = input(
                        self.xr_session,
                        self.action_set,
                        space,
                        frame_state.predictedDisplayTime,
                        self.l_action,
                        self.r_action,
                        self.l_action_g,
                        self.r_action_g,
                        self.hand_poses_space[0],
                        self.hand_poses_space[1],
                    ) catch true;
                    if (frame_state.shouldRender == c.VK_FALSE) {
                        var end_frame_info = c.XrFrameEndInfo{
                            .type = c.XR_TYPE_FRAME_END_INFO,
                            .displayTime = frame_state.predictedDisplayTime,
                            .environmentBlendMode = c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
                            .layerCount = 0,
                            .layers = null,
                        };
                        try loader.xrCheck(c.xrEndFrame(self.xr_session, &end_frame_info));

                        continue;
                    } else {
                        should_quit, const active_index = render(
                            self.allocator,
                            self.xr_session,
                            xr_swapchain,
                            space,
                            frame_state.predictedDisplayTime,
                            self.vk_logical_device,
                            self.vk_queue,
                            render_pass,
                            pipeline_layout,
                            pipeline,
                        ) catch .{ true, 0 };
                        quit.store(should_quit, .release);
                        lastRenderedImageIndex = active_index;

                        std.debug.print("\n\n\n\n\n\n\n", .{});
                        try xr.recordCurrentBindings(self.xr_session, self.xr_instance);
                        std.debug.print("\n\n\n\n\n\n\n", .{});
                    }
                }
            } else if (result != c.XR_SUCCESS) {
                try loader.xrCheck(result);
            } else {
                switch (eventData.type) {
                    c.XR_TYPE_EVENT_DATA_EVENTS_LOST => std.debug.print("Event queue overflowed and events were lost.\n", .{}),
                    c.XR_TYPE_EVENT_DATA_INSTANCE_LOSS_PENDING => {
                        std.debug.print("OpenXR instance is shutting down.\n", .{});
                        quit.store(true, .release);
                    },
                    c.XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED => {
                        try xr.recordCurrentBindings(self.xr_session, self.xr_instance);
                        std.debug.print("The interaction profile has changed.\n", .{});
                    },
                    c.XR_TYPE_EVENT_DATA_REFERENCE_SPACE_CHANGE_PENDING => std.debug.print("The reference space is changing.\n", .{}),
                    c.XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED => {
                        const event: *c.XrEventDataSessionStateChanged = @ptrCast(&eventData);

                        switch (event.state) {
                            c.XR_SESSION_STATE_UNKNOWN, c.XR_SESSION_STATE_MAX_ENUM => std.debug.print("Unknown session state entered: {any}\n", .{event.state}),
                            c.XR_SESSION_STATE_IDLE => running = false,
                            c.XR_SESSION_STATE_READY => {
                                const sessionBeginInfo = c.XrSessionBeginInfo{
                                    .type = c.XR_TYPE_SESSION_BEGIN_INFO,
                                    .primaryViewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
                                };
                                try loader.xrCheck(c.xrBeginSession(self.xr_session, &sessionBeginInfo));
                                running = true;
                            },
                            c.XR_SESSION_STATE_SYNCHRONIZED, c.XR_SESSION_STATE_VISIBLE, c.XR_SESSION_STATE_FOCUSED => running = true,
                            c.XR_SESSION_STATE_STOPPING => {
                                try loader.xrCheck(c.xrEndSession(self.xr_session));
                                running = false;
                            },
                            c.XR_SESSION_STATE_LOSS_PENDING => {
                                std.debug.print("OpenXR session is shutting down.\n", .{});
                                quit.store(true, .release);
                            },
                            c.XR_SESSION_STATE_EXITING => {
                                std.debug.print("OpenXR runtime requested shutdown.\n", .{});
                                quit.store(true, .release);
                            },
                            else => {
                                log.err("Unknown event STATE type received: {any}", .{eventData.type});
                            },
                        }
                    },
                    else => {
                        log.err("Unknown event type received: {any}", .{eventData.type});
                    },
                }
            }
        }

        std.debug.print("\n\n=========[EXITED while loop]===========\n\n", .{});
        try loader.xrCheck(c.vkDeviceWaitIdle(self.vk_logical_device));
    }

    fn input(
        session: c.XrSession,
        actionSet: c.XrActionSet,
        roomSpace: c.XrSpace,
        predictedDisplayTime: c.XrTime,
        leftHandAction: c.XrAction,
        rightHandAction: c.XrAction,
        leftGrabAction: c.XrAction,
        rightGrabAction: c.XrAction,
        leftHandSpace: c.XrSpace,
        rightHandSpace: c.XrSpace,
    ) !bool {
        var activeActionSet = c.XrActiveActionSet{
            .actionSet = actionSet,
            .subactionPath = c.XR_NULL_PATH,
        };

        var syncInfo = c.XrActionsSyncInfo{
            .type = c.XR_TYPE_ACTIONS_SYNC_INFO,
            .countActiveActionSets = 1,
            .activeActionSets = &activeActionSet,
        };

        const result: c.XrResult = (c.xrSyncActions(session, &syncInfo));

        if (result == c.XR_SESSION_NOT_FOCUSED) {
            return false;
        } else if (result != c.XR_SUCCESS) {
            std.log.err("Failed to synchronize actions: {any}\n", .{result});
            return true;
        }

        const leftHand: c.XrPosef = try xr.getActionPose(session, leftHandAction, leftHandSpace, roomSpace, predictedDisplayTime);
        const rightHand: c.XrPosef = try xr.getActionPose(session, rightHandAction, rightHandSpace, roomSpace, predictedDisplayTime);
        const leftGrab: c.XrBool32 = try xr.getActionBoolean(session, leftGrabAction);
        const rightGrab: c.XrBool32 = try xr.getActionBoolean(session, rightGrabAction);

        std.debug.print("\n\n=========[RIGHT: {any}]===========\n\n", .{rightHand});
        std.debug.print("\n\n=========[LEFT: {any}]===========\n\n", .{leftHand});

        if (leftGrab != 0 and object_grabbed != 0 and std.math.sqrt(std.math.pow(f32, object_pos.x - leftHand.position.x, 2) + std.math.pow(f32, object_pos.y - leftHand.position.y, 2) + std.math.pow(f32, object_pos.z - leftHand.position.z, 2)) < grab_distance) {
            object_grabbed = 1;
        } else if (leftGrab != 0 and object_grabbed == 1) {
            object_grabbed = 0;
        }

        if (rightGrab != 0 and object_grabbed != 0 and std.math.sqrt(std.math.pow(f32, object_pos.x - rightHand.position.x, 2) + std.math.pow(f32, object_pos.y - rightHand.position.y, 2) + std.math.pow(f32, object_pos.z - leftHand.position.z, 2)) < grab_distance) {
            object_grabbed = 2;
        } else if (rightGrab != 0 and object_grabbed == 2) {
            object_grabbed = 0;
        }

        switch (object_grabbed) {
            1 => object_pos = leftHand.position,
            2 => object_pos = rightHand.position,
            else => return false,
        }

        return false;
    }
    fn render(
        allocator: std.mem.Allocator,
        session: c.XrSession,
        swapchain: XrSwapchain,
        space: c.XrSpace,
        predicted_display_time: c.XrTime,
        device: c.VkDevice,
        queue: c.VkQueue,
        render_pass: c.VkRenderPass,
        pipeline_layout: c.VkPipelineLayout,
        pipeline: c.VkPipeline,
    ) !struct { bool, u32 } {
        var view_locate_info = c.XrViewLocateInfo{
            .type = c.XR_TYPE_VIEW_LOCATE_INFO,
            .viewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
            .displayTime = predicted_display_time,
            .space = space,
        };

        var view_state = c.XrViewState{
            .type = c.XR_TYPE_VIEW_STATE,
        };

        var view_count: u32 = build_options.eye_count;
        const views = try allocator.alloc(c.XrView, view_count);
        defer allocator.free(views);
        @memset(views, .{ .type = c.XR_TYPE_VIEW });

        try loader.xrCheck(c.xrLocateViews(
            session,
            &view_locate_info,
            &view_state,
            view_count,
            &view_count,
            views.ptr,
        ));

        const ok, const active_index = try renderEye(
            swapchain,
            views,
            device,
            queue,
            render_pass,
            pipeline_layout,
            pipeline,
        );
        if (!ok) {
            return .{ true, active_index };
        }

        var projected_views: [build_options.eye_count]c.XrCompositionLayerProjectionView = undefined;

        for (0..build_options.eye_count) |i| {
            projected_views[i].type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW;
            projected_views[i].pose = views[i].pose;
            projected_views[i].fov = views[i].fov;
            projected_views[i].subImage = .{
                .swapchain = swapchain.color_swapchain,
                .imageRect = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{
                        .width = @intCast(swapchain.width),
                        .height = @intCast(swapchain.height),
                    },
                },
                .imageArrayIndex = @intCast(i),
            };
            projected_views[i].next = null;
        }

        var layer = c.XrCompositionLayerProjection{
            .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION,
            .space = space,
            .viewCount = build_options.eye_count,
            .views = &projected_views[0],
            .next = null,
        };

        const layers_array: [1]*const c.XrCompositionLayerBaseHeader = .{@ptrCast(&layer)};

        var end_frame_info = c.XrFrameEndInfo{
            .type = c.XR_TYPE_FRAME_END_INFO,
            .displayTime = predicted_display_time,
            .environmentBlendMode = c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
            .layerCount = 1,
            .layers = &layers_array[0],
        };
        try loader.xrCheck(c.xrEndFrame(session, &end_frame_info));

        return .{ false, active_index };
    }

    fn renderEye(
        xr_swapchain: XrSwapchain,
        view: []c.XrView,
        device: c.VkDevice,
        queue: c.VkQueue,
        render_pass: c.VkRenderPass,
        pipeline_layout: c.VkPipelineLayout,
        pipeline: c.VkPipeline,
    ) !struct { bool, u32 } {
        var acquire_image_info = c.XrSwapchainImageAcquireInfo{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO,
        };

        var color_active_index: u32 = 0;
        var depth_active_index: u32 = 0;
        try loader.xrCheck(c.xrAcquireSwapchainImage(xr_swapchain.color_swapchain, &acquire_image_info, &color_active_index));
        try loader.xrCheck(c.xrAcquireSwapchainImage(xr_swapchain.depth_swapchain, &acquire_image_info, &depth_active_index));

        var wait_image_info = c.XrSwapchainImageWaitInfo{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO,
            .timeout = std.math.maxInt(i64),
        };

        try loader.xrCheck(c.xrWaitSwapchainImage(xr_swapchain.color_swapchain, &wait_image_info));
        try loader.xrCheck(c.xrWaitSwapchainImage(xr_swapchain.depth_swapchain, &wait_image_info));
        const image: XrSwapchain.SwapchainImage = xr_swapchain.swapchain_images[color_active_index];

        var data: ?[*]f32 = null;
        try loader.xrCheck(c.vkMapMemory(device, image.memory, 0, c.VK_WHOLE_SIZE, 0, @ptrCast(@alignCast(&data))));

        var ptr_start: u32 = 0;
        for (0..2) |i| {
            const angle_width: f32 = std.math.tan(view[i].fov.angleRight) - std.math.tan(view[i].fov.angleLeft);
            const angle_height: f32 = std.math.tan(view[i].fov.angleDown) - std.math.tan(view[i].fov.angleUp);

            var projection_matrix = nz.Mat4(f32).identity(0);

            //TODO: defines?
            const far_distance: f32 = 100;
            const near_distance: f32 = 0.01;

            projection_matrix.d[0] = 2.0 / angle_width;
            projection_matrix.d[8] = (std.math.tan(view[i].fov.angleRight) + std.math.tan(view[i].fov.angleLeft)) / angle_width;
            projection_matrix.d[5] = 2.0 / angle_height;
            projection_matrix.d[9] = (std.math.tan(view[i].fov.angleUp) + std.math.tan(view[i].fov.angleDown)) / angle_height;
            projection_matrix.d[10] = -far_distance / (far_distance - near_distance);
            projection_matrix.d[14] = -(far_distance * near_distance) / (far_distance - near_distance);
            projection_matrix.d[11] = -1;

            // projection_matrix = nz.Mat4(f32).perspective(angle_height, angle_width, near_distance, far_distance);

            @memcpy(data.?[ptr_start .. ptr_start + 16], projection_matrix.d[0..]);
            ptr_start += 16;
        }

        for (0..2) |i| {
            const view_matrix: nz.Mat4(f32) = .inverse(.mul(
                .translate(.{ view[i].pose.position.x, view[i].pose.position.y, view[i].pose.position.z }),
                .fromQuaternion(.{ view[i].pose.orientation.x, view[i].pose.orientation.y, view[i].pose.orientation.z, view[i].pose.orientation.w }),
            ));
            @memcpy(data.?[ptr_start .. ptr_start + 16], view_matrix.d[0..]);
            ptr_start += 16;
        }

        var model_matrix = nz.Mat4(f32).identity(1);
        // model.scale(scale).rotate(pose.orientation).translate(pose.position);

        // renderCuboid(model_matrix, )
        @memcpy(data.?[ptr_start .. ptr_start + 16], model_matrix.d[0..]);

        c.vkUnmapMemory(device, image.memory);

        const begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        try loader.xrCheck(c.vkBeginCommandBuffer(image.command_buffer, &begin_info));

        var clear_values: [2]c.VkClearValue = undefined;
        clear_values[0].color.float32 = .{ 0.0, 0.0, 0.0, 1.0 };
        clear_values[1].depthStencil = .{ .depth = 1.0, .stencil = 0 };
        const begin_render_pass_info = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = render_pass,
            .framebuffer = image.framebuffer,
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = xr_swapchain.width, .height = xr_swapchain.height },
            },
            .clearValueCount = clear_values.len,
            .pClearValues = &clear_values[0],
        };

        c.vkCmdBeginRenderPass(image.command_buffer, &begin_render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);

        const viewport = c.VkViewport{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(xr_swapchain.width),
            .height = @floatFromInt(xr_swapchain.height),
            .minDepth = 0,
            .maxDepth = 1,
        };

        c.vkCmdSetViewport(image.command_buffer, 0, 1, &viewport);

        const scissor = c.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = xr_swapchain.width, .height = xr_swapchain.height },
        };

        c.vkCmdSetScissor(image.command_buffer, 0, 1, &scissor);

        c.vkCmdBindPipeline(image.command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
        c.vkCmdBindDescriptorSets(image.command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout, 0, 1, &image.descriptor_set, 0, null);

        var offsets: [1]c.VkDeviceSize = .{0};
        var vertex_buffers: [1]c.VkBuffer = .{vertex_buffer.buffer};
        c.vkCmdBindVertexBuffers(image.command_buffer, 0, 1, &vertex_buffers, @ptrCast(&offsets));
        c.vkCmdBindIndexBuffer(image.command_buffer, index_buffer.buffer, 0, c.VK_INDEX_TYPE_UINT32);
        c.vkCmdDrawIndexed(
            image.command_buffer,
            cube_indecies.len,
            1,
            0,
            0,
            0,
        );

        c.vkCmdEndRenderPass(image.command_buffer);

        const beforeSrcBarrier: c.VkImageMemoryBarrier = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .srcAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            .dstAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT,
            .oldLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            .newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            .image = image.image.image,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        const beforeDstBarrier: c.VkImageMemoryBarrier = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .srcAccessMask = c.VK_ACCESS_NONE,
            .dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT,
            .oldLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
            .newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            .image = image.vk_dup_image,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        const beforeBarriers = [_]c.VkImageMemoryBarrier{
            beforeSrcBarrier,
            beforeDstBarrier,
        };

        c.vkCmdPipelineBarrier(
            image.command_buffer,
            c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            c.VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0,
            null,
            0,
            null,
            beforeBarriers.len,
            &beforeBarriers,
        );

        var region: c.VkImageCopy = .{
            .srcSubresource = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .mipLevel = 0,
                .layerCount = 1,
            },
            .srcOffset = .{},
            .dstSubresource = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .mipLevel = 0,
                .layerCount = 1,
            },
            .dstOffset = .{},
            .extent = .{ .width = xr_swapchain.width, .height = xr_swapchain.height, .depth = 1 },
        };

        c.vkCmdCopyImage(
            image.command_buffer,
            image.image.image,
            c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            image.vk_dup_image,
            c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region,
        );

        const afterSrcBarrier: c.VkImageMemoryBarrier = .{ .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, .srcAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT, .dstAccessMask = c.VK_ACCESS_NONE, .oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, .newLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, .image = image.image.image, .subresourceRange = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        } };

        const afterDstBarrier: c.VkImageMemoryBarrier = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT,
            .dstAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT,
            .oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            .newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            .image = image.vk_dup_image,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        const afterBarriers = [_]c.VkImageMemoryBarrier{
            afterSrcBarrier,
            afterDstBarrier,
        };

        c.vkCmdPipelineBarrier(
            image.command_buffer,
            c.VK_PIPELINE_STAGE_TRANSFER_BIT,
            c.VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0,
            null,
            0,
            null,
            afterBarriers.len,
            &afterBarriers,
        );

        try loader.xrCheck(c.vkEndCommandBuffer(image.command_buffer));

        const stage_mask: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        const submit_info = c.VkSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pWaitDstStageMask = &stage_mask,
            .commandBufferCount = 1,
            .pCommandBuffers = &image.command_buffer,
        };
        try loader.xrCheck(c.vkQueueSubmit(queue, 1, &submit_info, null));

        const release_image_info = c.XrSwapchainImageReleaseInfo{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO,
        };

        try loader.xrCheck(c.xrReleaseSwapchainImage(xr_swapchain.color_swapchain, &release_image_info));
        try loader.xrCheck(c.xrReleaseSwapchainImage(xr_swapchain.depth_swapchain, &release_image_info));

        return .{ true, color_active_index };
    }

    fn onInterrupt(signum: c_int) callconv(.c) void {
        _ = signum;
        std.debug.print("SIGINT received. Initiating graceful shutdown...\n", .{});
        quit.store(true, .release); // Set quit_requested to true
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // const allocator = std.heap.page_allocator;

    const xr_extensions = &[_][*:0]const u8{
        loader.c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        loader.c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
        loader.c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };
    const xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
        "XR_APILAYER_LUNARG_api_dump",
    };

    const vk_layers = &[_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    defer sdl.shutdown();

    const engine = try Engine.init(allocator, .{
        .xr_extensions = xr_extensions,
        .xr_layers = xr_layers,
        .vk_layers = vk_layers,
    });
    defer engine.deinit();
    try engine.start();
}
