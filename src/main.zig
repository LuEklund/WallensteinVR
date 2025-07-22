const std = @import("std");
const log = @import("std").log;
const builtin = @import("builtin");
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const loader = @import("loader");
const build_options = @import("build_options");
const nz = @import("numz");
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
        try xr.validateExtensions(allocator, config.xr_extensions);
        try xr.validateLayers(allocator, config.xr_layers);

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

        const xr_session: c.XrSession = try xr.createSession(xr_instance, xr_system_id, vk_instance, physical_device, logical_device, queue_family_index.?);

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
        self.xrd.xrDestroyDebugUtilsMessengerEXT(self.xr_debug_messenger) catch {};

        _ = c.xrDestroySession(self.xr_session);
        _ = c.xrDestroyInstance(self.xr_instance);

        _ = c.vkDestroyDevice(self.vk_logical_device, null);
        _ = c.vkDestroyInstance(self.vk_instance, null);
    }

    pub fn start(self: Self) !void {
        const eye_count = build_options.eye_count;
        const swapchains = try xr.Swapchain.init(eye_count, self.allocator, self.xr_instance, self.xr_system_id, self.xr_session);
        defer self.allocator.free(swapchains);
        const render_pass: c.VkRenderPass = try vk.createRenderPass(self.vk_logical_device, swapchains[0].format);
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
        const pipeline_layout: c.VkPipelineLayout, const pipeline: c.VkPipeline = try vk.createPipeline(self.vk_logical_device, render_pass, descriptor_set_layout, vertex_shader, fragment_shader);
        defer c.vkDestroyPipelineLayout(self.vk_logical_device, pipeline_layout, null);
        defer c.vkDestroyPipeline(self.vk_logical_device, pipeline, null);

        var swapchains_images: [eye_count][]c.XrSwapchainImageVulkanKHR = undefined;
        for (0..eye_count) |i| {
            swapchains_images[i] = try swapchains[i].getImages(self.allocator);
        }
        defer {
            for (0..eye_count) |i| {
                self.allocator.free(swapchains_images[i]);
            }
        }

        var wrapped_swapchain_images: [eye_count]std.ArrayList(vk.SwapchainImage) = undefined;

        for (0..eye_count) |i| {
            wrapped_swapchain_images[i] = .init(self.allocator);

            for (0..swapchains_images.len) |j| {
                try wrapped_swapchain_images[i].append(
                    try vk.SwapchainImage.init(
                        self.vk_physical_device,
                        self.vk_logical_device,
                        render_pass,
                        command_pool,
                        descriptor_pool,
                        descriptor_set_layout,
                        &swapchains[i],
                        swapchains_images[i][j],
                    ),
                );
            }
        }
        defer {
            std.debug.print("\n\n=========[FREEING THE IMAGES]===========\n\n", .{});
            for (0..eye_count) |i| {
                for (wrapped_swapchain_images[i].items) |swapchain_image| {
                    swapchain_image.deinit();
                }
                wrapped_swapchain_images[i].deinit();
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

        const space: c.XrSpace = try xr.createSpace(self.xr_session);

        var running: bool = true;
        while (!quit.load(.acquire)) {
            std.debug.print("\n\n=========[entered while loop]===========\n\n", .{});

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
                    std.debug.print("\n\n=========[entered rendering]===========\n\n", .{});
                    const should_quit = try render(
                        self.allocator,
                        self.xr_session,
                        swapchains,
                        &wrapped_swapchain_images,
                        space,
                        frame_state.predictedDisplayTime,
                        self.vk_logical_device,
                        self.vk_queue,
                        render_pass,
                        pipeline_layout,
                        pipeline,
                    );
                    std.debug.print("\n\n=========[quite == {}]===========\n\n", .{should_quit});
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
        std.debug.print("\n\n=========[EXITED while loop]===========\n\n", .{});
        try loader.xrCheck(c.vkDeviceWaitIdle(self.vk_logical_device));
    }
    fn render(
        allocator: std.mem.Allocator,
        session: c.XrSession,
        swapchains: []const xr.Swapchain,
        swapchain_images: []std.ArrayList(vk.SwapchainImage),
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

        try loader.xrCheck(c.xrBeginFrame(session, &begin_frame_info));

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
            @ptrCast(&view_count),
            views.ptr,
        ));

        for (0..build_options.eye_count) |i| {
            const ok = try renderEye(
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
                return true;
            }
        }

        var projected_views: [build_options.eye_count]c.XrCompositionLayerProjectionView = undefined;

        for (0..build_options.eye_count) |i| {
            projected_views[i].type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW;
            projected_views[i].pose = views[i].pose;
            projected_views[i].fov = views[i].fov;
            projected_views[i].subImage = .{
                .swapchain = swapchains[i].swapchain,
                .imageRect = .{
                    // .{ 0, 0 },
                    .extent = .{
                        .width = @intCast(swapchains[i].width),
                        .height = @intCast(swapchains[i].height),
                    },
                },
                .imageArrayIndex = 0,
            };
        }

        // var layer = c.XrCompositionLayerProjection{
        //     .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION,
        //     .space = space,
        //     .viewCount = build_options.eye_count,
        //     .views = &projected_views[0],
        // };

        // // const layers = [_]c.XrCompositionLayerBaseHeader{@bitCast(layer)};
        // var pLayer: *const c.XrCompositionLayerBaseHeader = @ptrCast(&layer);

        // var end_frame_info = c.XrFrameEndInfo{
        //     .type = c.XR_TYPE_FRAME_END_INFO,
        //     .displayTime = predicted_display_time,
        //     .environmentBlendMode = c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
        //     .layerCount = 1,
        //     .layers = &pLayer,
        // };

        // try loader.xrCheck(c.xrEndFrame(session, &end_frame_info));

        return false;
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

        try loader.xrCheck(c.xrWaitSwapchainImage(swapchain.swapchain, &wait_image_info));
        const image: vk.SwapchainImage = images.items[active_index];

        var data: ?[*]f32 = null;
        try loader.xrCheck(c.vkMapMemory(device, image.memory, 0, c.VK_WHOLE_SIZE, 0, @ptrCast(@alignCast(&data))));

        const angle_width: f32 = std.math.tan(view.fov.angleRight) - std.math.tan(view.fov.angleLeft);
        const angle_height: f32 = std.math.tan(view.fov.angleDown) - std.math.tan(view.fov.angleUp);

        var projection_matrix = nz.Mat4(f32).identity(0);

        //NOTE make defines?
        const far_distance: f32 = 1;
        const near_distance: f32 = 0.01;

        projection_matrix.d[0] = 2.0 / angle_width;
        projection_matrix.d[8] = (std.math.tan(view.fov.angleRight) + std.math.tan(view.fov.angleLeft)) / angle_width;
        projection_matrix.d[5] = 2.0 / angle_height;
        projection_matrix.d[9] = (std.math.tan(view.fov.angleUp) + std.math.tan(view.fov.angleDown)) / angle_height;
        projection_matrix.d[10] = -far_distance / (far_distance - near_distance);
        projection_matrix.d[14] = -(far_distance * near_distance) / (far_distance - near_distance);
        projection_matrix.d[11] = -1;

        const view_matrix: nz.Mat4(f32) = .mul(
            .translate(.{ view.pose.position.x, view.pose.position.y, view.pose.position.z }),
            .fromQuaternion(.{ view.pose.orientation.w, view.pose.orientation.x, view.pose.orientation.y, view.pose.orientation.z }),
        );

        const model_matrix = nz.Mat4(f32).identity(1);

        @memcpy(data.?[0..16], projection_matrix.d[0..]);
        @memcpy(data.?[16..32], view_matrix.d[0..]);
        @memcpy(data.?[32..48], model_matrix.d[0..]);

        c.vkUnmapMemory(device, image.memory);

        const begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        try loader.xrCheck(c.vkBeginCommandBuffer(image.command_buffer, &begin_info));

        const clearValue = c.VkClearValue{
            .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } },
        };

        const begin_render_pass_info = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = render_pass,
            .framebuffer = image.framebuffer,
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = swapchain.width, .height = swapchain.height },
            },
            .clearValueCount = 1,
            .pClearValues = &clearValue,
        };

        c.vkCmdBeginRenderPass(image.command_buffer, &begin_render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);

        const viewport = c.VkViewport{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(swapchain.width),
            .height = @floatFromInt(swapchain.height),
            .minDepth = 0,
            .maxDepth = 1,
        };

        c.vkCmdSetViewport(image.command_buffer, 0, 1, &viewport);

        const scissor = c.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = swapchain.width, .height = swapchain.height },
        };

        c.vkCmdSetScissor(image.command_buffer, 0, 1, &scissor);
        c.vkCmdBindPipeline(image.command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
        c.vkCmdBindDescriptorSets(image.command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout, 0, 1, &image.descriptor_set, 0, null);
        c.vkCmdDraw(image.command_buffer, 3, 1, 0, 0);
        c.vkCmdEndRenderPass(image.command_buffer);

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

        try loader.xrCheck(c.xrReleaseSwapchainImage(swapchain.swapchain, &release_image_info));

        return true;
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

    const engine = try Engine.init(allocator, .{
        .xr_extensions = xr_extensions,
        .xr_layers = xr_layers,
        .vk_layers = vk_layers,
    });
    defer engine.deinit();
    try engine.start();
}
