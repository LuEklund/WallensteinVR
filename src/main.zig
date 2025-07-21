const std = @import("std");
const log = @import("std").log;
const builtin = @import("builtin");
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const loader = @import("loader");
const build_options = @import("builds_options");
const c = loader.c;
var quit: std.atomic.Value(bool) = .init(false);

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
    vkid: vk.Dispatcher,

    pub const Config = struct {
        xr_extensions: []const [*:0]const u8,
        xr_layers: []const [*:0]const u8,
        vk_layers: []const [*:0]const u8,
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        const xr_instance: c.XrInstance = try xr.createInstance(config.xr_extensions, config.xr_layers);
        const xrd = try xr.Dispatcher.init(xr_instance);
        const xr_debug_messenger: c.XrDebugUtilsMessengerEXT = try xr.createDebugMessenger(xrd, xr_instance);
        const xr_system_id: c.XrSystemId = try xr.getSystem(xr_instance);
        const xr_graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, const xr_instance_extensions: []const [*:0]const u8 =
            try xr.getVulkanInstanceRequirements(xrd, allocator, xr_instance, xr_system_id);

        const vk_instance: c.VkInstance = try vk.createInstance(xr_graphics_requirements, xr_instance_extensions, config.vk_layers);
        const vkid = try vk.Dispatcher.init(vk_instance);
        const vk_debug_messenger: c.VkDebugUtilsMessengerEXT = try vk.createDebugMessenger(vkid, vk_instance);

        const physical_device: c.VkPhysicalDevice, const vk_device_extensions: []const [*:0]const u8 = try xr.getVulkanDeviceRequirements(xrd, allocator, xr_instance, xr_system_id, vk_instance);
        const queue_family_index = vk.findGraphicsQueueFamily(physical_device);
        const logical_device: c.VkDevice, const queue: c.VkQueue = try vk.createLogicalDevice(physical_device, queue_family_index.?, vk_device_extensions);

        std.debug.print("\n1: {*}\n", .{physical_device});
        std.debug.print("\n2: {*}\n", .{logical_device});
        const xr_session: c.XrSession = try xr.createSession(xr_instance, xr_system_id, vk_instance, physical_device, logical_device, queue_family_index.?);

        std.debug.print("\nHELLO2\n", .{});
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
            .graphics_queue_family_index = queue_family_index.?,
            .vk_logical_device = logical_device,
            .vk_queue = queue,
            .vkid = vkid,
        };
    }

    pub fn deinit(self: Self) void {
        self.vkid.vkDestroyDebugUtilsMessengerEXT(self.vk_instance, self.vk_debug_messenger, null);
        // self.xrd.xrDestroyDebugUtilsMessengerEXT(self.xr_debug_messenger) catch {};

        // _ = c.vkDestroyDevice(self.vk_logical_device, null);

        // _ = c.xrDestroySession(self.xr_session);

        // _ = c.vkDestroyInstance(self.vk_instance, null);
        // _ = c.xrDestroyInstance(self.xr_instance);
    }

    pub fn start(self: Self) !void {
        const eye_count = build_options.eye_count;
        const swapchains = try xr.Swapchain.init(eye_count, self.allocator, self.xr_instance, self.xr_system_id, self.xr_session);
        const render_pass: c.VkRenderPass = try vk.createRenderPass(self.vk_logical_device, swapchains[0].format);
        const command_pool: c.VkCommandPool = try vk.createCommandPool(self.vk_logical_device, self.graphics_queue_family_index);
        const descriptor_pool: c.VkDescriptorPool = try vk.createDescriptorPool(self.vk_logical_device);
        const descriptor_set_layout: c.VkDescriptorSetLayout = try vk.createDescriptorSetLayout(self.vk_logical_device);
        const vertex_shader: c.VkShaderModule = try vk.createShader(self.allocator, self.vk_logical_device, "shaders/vertex.vert.spv");
        const fragment_shader: c.VkShaderModule = try vk.createShader(self.allocator, self.vk_logical_device, "shaders/fragment.frag.spv");
        const pipeline_layout: c.VkPipelineLayout, const pipeline: c.VkPipeline = try vk.createPipeline(self.vk_logical_device, render_pass, descriptor_set_layout, vertex_shader, fragment_shader);

        var swapchains_images: [eye_count][]c.XrSwapchainImageVulkanKHR = undefined;
        for (0..eye_count) |i| {
            swapchains_images[i] = try swapchains[i].getImages(self.allocator);
        }

        var wrapped_swapchain_images: [eye_count]std.ArrayList(vk.SwapchainImage) = undefined;

        for (0..eye_count) |i| {
            wrapped_swapchain_images[i] = .init(self.allocator);

            for (0..swapchains_images.len) |j| {
                try wrapped_swapchain_images[i].append(try vk.SwapchainImage.init(self.vk_physical_device, self.vk_logical_device, render_pass, command_pool, descriptor_pool, descriptor_set_layout, &swapchains[i], swapchains_images[i][j]));
            }
        }

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

        var running: bool = true;
        while (!quit.load(.acquire)) {
            var eventData = c.XrEventDataBuffer{
                .type = c.XR_TYPE_EVENT_DATA_BUFFER,
            };
            const result: c.XrResult = c.xrPollEvent(self.xr_instance, &eventData);
            if (result == c.XR_EVENT_UNAVAILABLE) {
                if (running) {
                    var frame_wait_info = c.XrFrameWaitInfo{ .type = c.XR_TYPE_FRAME_WAIT_INFO };
                    var frame_state = c.XrFrameState{ .type = c.XR_TYPE_FRAME_STATE };
                    try loader.xrCheck(c.xrWaitFrame(self.xr_session, &frame_wait_info, &frame_state));
                    if (frame_state.shouldRender != 0) {
                        continue;
                    }
                    const should_quit = render(
                        self.allocator,
                        self.xr_session,
                        swapchains,
                        wrapped_swapchain_images,
                        // TODO : ADD space!
                        null,
                        frame_state.predictedDisplayTime,
                        self.vk_logical_device,
                        self.vk_queue,
                        render_pass,
                        pipeline_layout,
                        pipeline,
                    );
                    quit.store(should_quit, .release);
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
                    c.XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED => std.debug.print("The interaction profile has changed.\n", .{}),
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
                            c.XR_SESSION_STATE_STOPPING => try loader.xrCheck(c.xrEndSession(self.xr_session)),
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
    }
    fn render(
        allocator: std.mem.Allocator,
        session: c.XrSession,
        swapchains: [2]xr.Swapchain,
        swapchain_images: [2]std.ArrayList(vk.SwapchainImage),
        space: c.XrSpace,
        predicted_display_time: c.XrTime,
        device: c.VkDevice,
        queue: c.VkQueue,
        render_pass: c.VkRenderPass,
        pipeline_layout: c.VkPipelineLayout,
        pipeline: c.VkPipeline,
    ) !bool {
        var begin_frame_info = c.XrFrameBeginInfo{
            .type = c.XR_TYPE_FRAME_BEGIN_INFO,
        };

        loader.xrCheck(c.xrBeginFrame(session, &begin_frame_info));

        var view_locate_info = c.XrViewLocateInfo{
            .type = c.XR_TYPE_VIEW_LOCATE_INFO,
            .viewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
            .displayTime = predicted_display_time,
            .space = space,
        };

        var view_state = c.XrViewState{
            .type = c.XR_TYPE_VIEW_STATE,
        };

        const view_count: u32 = build_options.eye_count;
        var views = allocator.alloc(c.XrView, view_count);
        defer allocator.free(views);
        @memset(views, .{ .type = c.Xr_TYPE_VIEW });

        loader.xrCheck(c.xrLocateViews(
            session,
            &view_locate_info,
            &view_state,
            view_count,
            &view_count,
            views.data(),
        ));

        for (0..build_options.eye_count) |i| {
            const ok = renderEye(
                swapchains[i],
                swapchain_images[i],
                views[i],
                device,
                queue,
                render_pass,
                pipeline_layout,
                pipeline,
            );

            if (!ok) {
                return false;
            }
        }
    }
    fn renderEye(
        swapchain: xr.Swapchain,
        images: std.ArrayList(vk.SwapchainImage),
        view: c.XrView,
        device: c.VkDevice,
        queue: c.VkQueue,
        render_pass: c.VkRenderPass,
        pipeline_layout: c.VkPipelineLayout,
        pipeline: c.VkPipeline,
    ) !bool {
        var acquire_image_info = c.XrSwapchainImageAcquireInfo{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO,
        };

        var active_index: u32 = 0;

        try loader.xrCheck(c.xrAcquireSwapchainImage(swapchain.swapchain, &acquire_image_info, &active_index));

        var wait_image_info = c.XrSwapchainImageWaitInfo{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO,
            .timeout = std.math.maxInt(i64),
        };

        loader.xrCheck(c.xrWaitSwapchainImage(swapchain.swapchain, &wait_image_info));
        const image: c.SwapchainImage = images[active_index];

        const data: f32 = 0;
        loader.xrCheck(c.vkMapMemory(device, image.memory, 0, c.VK_WHOLE_SIZE, 0, @ptrCast(data)));

        const angle_width: f32 = std.math.tan(view.fov.angleRight) - std.math.tan(view.fov.angleLeft);
        const angle_height: f32 = std.math.tan(view.fov.angleDown) - std.math.tan(view.fov.angleUp);

        const projection_matrix: [4][4]f32 = 0;

        //NOTE make defines?
        const far_distance: f32 = 1;
        const near_distance: f32 = 0.01;

        projection_matrix[0][0] = 2.0 / angle_width;
        projection_matrix[2][0] = (std.math.tan(view.fov.angleRight) + std.math.tan(view.fov.angleLeft)) / angle_width;
        projection_matrix[1][1] = 2.0 / angle_height;
        projection_matrix[2][1] = (std.math.tan(view.fov.angleUp) + std.math.tan(view.fov.angleDown)) / angle_height;
        projection_matrix[2][2] = -far_distance / (far_distance - near_distance);
        projection_matrix[3][2] = -(far_distance * near_distance) / (far_distance - near_distance);
        projection_matrix[2][3] = -1;

        // TODO : math library
        // glm::mat4 viewMatrix = glm::inverse(
        //     glm::translate(glm::mat4(1.0f), glm::vec3(view.pose.position.x, view.pose.position.y, view.pose.position.z))
        //     * glm::mat4_cast(glm::quat(view.pose.orientation.w, view.pose.orientation.x, view.pose.orientation.y, view.pose.orientation.z))
        // );

        const model_matrix = [4][4]f32{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        };

        @memcpy(data, projection_matrix);
        //TODO . math library
        // @memcpy(data + (4 * 4), glm::value_ptr(viewMatrix), sizeof(float) * 4 * 4);
        @memcpy(data + (4 * 4) * 2, model_matrix);

        c.vkUnmapMemory(device, image.memory);

        const begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        loader.xrCheck(c.vkBeginCommandBuffer(image.commandBuffer, &begin_info));

        const clearValue = c.VkClearValue{
            .color = .{.{ 0.0, 0.0, 0.0, 1.0 }},
        };

        const begin_render_pass_info = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = render_pass,
            .framebuffer = image.framebuffer,
            .renderArea = .{
                .{ 0, 0 },
                .{ swapchain.width, swapchain.height },
            },
            .clearValueCount = 1,
            .pClearValues = &clearValue,
        };

        c.vkCmdBeginRenderPass(image.commandBuffer, &begin_render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);

        const viewport = c.VkViewport{ 0, 0, swapchain.width, swapchain.height, 0, 1 };

        c.vkCmdSetViewport(image.commandBuffer, 0, 1, &viewport);

        const scissor = c.VkRect2D{ .{ 0, 0 }, .{ swapchain.width, swapchain.height } };

        c.vkCmdSetScissor(image.commandBuffer, 0, 1, &scissor);
        c.vkCmdBindPipeline(image.commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
        c.vkCmdBindDescriptorSets(image.commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout, 0, 1, &image.descriptorSet, 0, null);
        c.vkCmdDraw(image.commandBuffer, 3, 1, 0, 0);
        c.vkCmdEndRenderPass(image.commandBuffer);

        loader.xrCheck(c.vkEndCommandBuffer(image.command_buffer));

        const stage_mask: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        const submit_info = c.VkSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pWaitDstStageMask = &stage_mask,
            .commandBufferCount = 1,
            .pCommandBuffers = &image.commandBuffer,
        };

        loader.xrCheck(c.vkQueueSubmit(queue, 1, &submit_info, null));
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

    const engine = try Engine.init(allocator, .{
        .xr_extensions = xr_extensions,
        .xr_layers = xr_layers,
        .vk_layers = vk_layers,
    });
    defer engine.deinit();
    try engine.start();
}
