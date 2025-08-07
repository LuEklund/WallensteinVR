const std = @import("std");
const log = @import("std").log;
const builtin = @import("builtin");
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const input = @import("input.zig");
const VulkanSwapchain = @import("VulkanSwapchain.zig");
const XrSwapchain = @import("XrSwapchain.zig");
const loader = @import("loader");
const build_options = @import("build_options");
const nz = @import("numz");
const c = loader.c;
const sdl = @import("sdl3");
const SpectatorView = @import("SpectatorView.zig");
const World = @import("../../ecs.zig").World;
const root = @import("../root.zig");
const AssetManager = @import("../asset_manager/AssetManager.zig");
var quit: std.atomic.Value(bool) = .init(false);

const window_width: c_int = 1600;
const window_height: c_int = 900;

var grabbed_block: [2]i32 = .{ -1, -1 };
var near_block: [2]i32 = .{ -1, -1 };
var blocks: std.ArrayList(input.Block) = undefined;

var m_grabState: [2]c.XrActionStateFloat = .{ .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT }, .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT } };
var m_handPaths: [2]c.XrPath = .{ 0, 0 };
var hand_pose_space: [2]c.XrSpace = undefined;
var hand_pose: [2]c.XrPosef = .{
    .{
        .orientation = .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        .position = .{ .x = 0.0, .z = 0.0, .y = -100 },
    },
    .{
        .orientation = .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        .position = .{ .x = 0.0, .z = 0.0, .y = -100 },
    },
};
var m_palmPoseAction: c.XrAction = undefined;
var m_grabCubeAction: c.XrAction = undefined;
var m_handPoseState: [2]c.XrActionStatePose = .{
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
};

// var normals: [6]c.XrVector4f = .{
// .{ .x = 1.00, .y = 0.00, .z = 0.00, .w = 0 },
// .{ .x = -1.00, .y = 0.00, .z = 0.00, .w = 0 },
// .{ .x = 0.00, .y = 1.00, .z = 0.00, .w = 0 },
// .{ .x = 0.00, .y = -1.00, .z = 0.00, .w = 0 },
// .{ .x = 0.00, .y = 0.00, .z = 1.00, .w = 0 },
// .{ .x = 0.00, .y = 0.0, .z = -1.00, .w = 0 },
// };
//

var cube_vertecies: [8]c.XrVector3f = .{
    .{ .x = 0.5, .y = 0.5, .z = 0.5 }, // 0: Top-Front-Right
    .{ .x = 0.5, .y = 0.5, .z = -0.5 }, // 1: Top-Back-Right
    .{ .x = 0.5, .y = -0.5, .z = 0.5 }, // 2: Bottom-Front-Right
    .{ .x = 0.5, .y = -0.5, .z = -0.5 }, // 3: Bottom-Back-Right
    .{ .x = -0.5, .y = 0.5, .z = 0.5 }, // 4: Top-Front-Left
    .{ .x = -0.5, .y = 0.5, .z = -0.5 }, // 5: Top-Back-Left
    .{ .x = -0.5, .y = -0.5, .z = 0.5 }, // 6: Bottom-Front-Left
    .{ .x = -0.5, .y = -0.5, .z = -0.5 }, // 7: Bottom-Back-Left
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

pub const Context = struct {
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
    running: bool = false,
};

pub const Renderer = struct {
    pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
        const xr_extensions = &[_][*:0]const u8{
            loader.c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
            loader.c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
            loader.c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
        };
        const xr_layers = &[_][*:0]const u8{
            // "XR_APILAYER_LUNARG_core_validation",
            // "XR_APILAYER_LUNARG_api_dump",
        };

        const vk_layers = &[_][*:0]const u8{
            // "VK_LAYER_KHRONOS_validation",
        };

        try xr.validateExtensions(allocator, xr_extensions);
        try xr.validateLayers(allocator, xr_layers);

        const xr_instance: c.XrInstance = try xr.createInstance(xr_extensions, xr_layers);
        const xrd = try xr.Dispatcher.init(xr_instance);
        const xr_debug_messenger: c.XrDebugUtilsMessengerEXT = try xr.createDebugMessenger(xrd, xr_instance);
        const xr_system_id: c.XrSystemId = try xr.getSystem(xr_instance);

        const action_set: c.XrActionSet = try xr.createActionSet(xr_instance);
        var paths: std.ArrayListUnmanaged([*:0]const u8) = .empty;
        try paths.append(allocator, "/user/hand/left");
        try paths.append(allocator, "/user/hand/right");
        defer paths.deinit(allocator);
        m_grabCubeAction = try xr.createAction(xr_instance, action_set, "grab-cube", c.XR_ACTION_TYPE_FLOAT_INPUT, paths);
        m_palmPoseAction = try xr.createAction(xr_instance, action_set, "palm-pose", c.XR_ACTION_TYPE_POSE_INPUT, paths);

        m_handPaths[0] = try xr.createXrPath(xr_instance, "/user/hand/left".ptr);
        m_handPaths[1] = try xr.createXrPath(xr_instance, "/user/hand/right".ptr);

        const xr_graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, const xr_instance_extensions: []const [*:0]const u8 =
            try xr.getVulkanInstanceRequirements(xrd, allocator, xr_instance, xr_system_id);

        const vk_instance: c.VkInstance = try vk.createInstance(xr_graphics_requirements, xr_instance_extensions, vk_layers);
        const vkid = try vk.Dispatcher.init(vk_instance);
        const vk_debug_messenger: c.VkDebugUtilsMessengerEXT = try vk.createDebugMessenger(vkid, vk_instance);

        const spectator_view: SpectatorView = try .init(vk_instance, window_height, window_width);

        const vk_physical_device: c.VkPhysicalDevice, const vk_device_extensions: []const [*:0]const u8 = try xr.getVulkanDeviceRequirements(xrd, allocator, xr_instance, xr_system_id, vk_instance);
        const queue_family_index = try vk.findGraphicsQueueFamily(
            vk_physical_device,
            spectator_view.sdl_surface,
        );

        const vk_logical_device: c.VkDevice, const queue: c.VkQueue = try vk.createLogicalDevice(vk_physical_device, queue_family_index, vk_device_extensions);

        const xr_session: c.XrSession = try xr.createSession(xr_instance, xr_system_id, vk_instance, vk_physical_device, vk_logical_device, queue_family_index);

        try xr.suggestBindings(xr_instance, m_palmPoseAction, m_palmPoseAction, m_grabCubeAction, m_grabCubeAction);

        hand_pose_space[0] = try input.createActionPoses(xr_instance, xr_session, m_palmPoseAction, "/user/hand/left");
        hand_pose_space[1] = try input.createActionPoses(xr_instance, xr_session, m_palmPoseAction, "/user/hand/right");
        try xr.attachActionSet(xr_session, action_set);

        var vulkan_swapchain: VulkanSwapchain = try .init(vk_physical_device, vk_logical_device, spectator_view.sdl_surface, window_width, window_height);
        var xr_swapchain: XrSwapchain = try .init(2, vk_physical_device, xr_instance, xr_system_id, xr_session);
        const render_pass: c.VkRenderPass = try vk.createRenderPass(vk_logical_device, xr_swapchain.format, xr_swapchain.depth_format, xr_swapchain.sample_count);
        const command_pool: c.VkCommandPool = try vk.createCommandPool(vk_logical_device, queue_family_index);
        const descriptor_pool: c.VkDescriptorPool = try vk.createDescriptorPool(vk_logical_device);
        const descriptor_set_layout: c.VkDescriptorSetLayout = try vk.createDescriptorSetLayout(vk_logical_device);
        const vertex_shader: c.VkShaderModule = try vk.createShader(allocator, vk_logical_device, "shaders/vertex.vert.spv");
        const fragment_shader: c.VkShaderModule = try vk.createShader(allocator, vk_logical_device, "shaders/fragment.frag.spv");
        const pipeline_layout: c.VkPipelineLayout, const pipeline: c.VkPipeline = try vk.createPipeline(vk_logical_device, render_pass, descriptor_set_layout, vertex_shader, fragment_shader, xr_swapchain.sample_count);

        const acquire_fence: c.VkFence = try vk.createFence(vk_logical_device);

        try vulkan_swapchain.createSwapchainImages(command_pool);
        try xr_swapchain.createSwapchainImages(
            vk_physical_device,
            vk_logical_device,
            render_pass,
            command_pool,
            descriptor_pool,
            descriptor_set_layout,
        );

        const space: c.XrSpace = try xr.createSpace(xr_session);

        const context = try allocator.create(Context);
        context.* = .{
            .spectator_view = spectator_view,
            .command_pool = command_pool,
            .graphics_queue_family_index = queue_family_index,
            .render_pass = render_pass,
            .vk_fence = acquire_fence,
            .vk_debug_messenger = vk_debug_messenger,
            .vk_instance = vk_instance,
            .vk_logical_device = vk_logical_device,
            .vk_physical_device = vk_physical_device,
            .vk_queue = queue,
            .vk_swapchain = vulkan_swapchain,
            .pipeline = pipeline,
            .descriptor_pool = descriptor_pool,
            .descriptor_set_layout = descriptor_set_layout,
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
            .pipeline_layout = pipeline_layout,
            .vkid = vkid,
            .action_set = action_set,
            .xr_debug_messenger = xr_debug_messenger,
            .xr_instance = xr_instance,
            .xr_session = xr_session,
            .xr_system_id = xr_system_id,
            .xr_space = space,
            .xr_swapchain = xr_swapchain,
        };

        try world.setResource(allocator, Context, context);
    }

    // mashe dpotatoes

    pub fn deinit(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
        const ctx = try world.getResource(Context);
        defer allocator.destroy(ctx);
        std.debug.print("\n\n=========[EXITED while loop]===========\n\n", .{});
        try loader.xrCheck(c.vkDeviceWaitIdle(ctx.vk_logical_device));

        c.vkDestroyPipeline(ctx.vk_logical_device, ctx.pipeline, null);
        c.vkDestroyPipelineLayout(ctx.vk_logical_device, ctx.pipeline_layout, null);
        c.vkDestroyShaderModule(ctx.vk_logical_device, ctx.fragment_shader, null);
        c.vkDestroyShaderModule(ctx.vk_logical_device, ctx.vertex_shader, null);
        c.vkDestroyDescriptorSetLayout(ctx.vk_logical_device, ctx.descriptor_set_layout, null);
        c.vkDestroyDescriptorPool(ctx.vk_logical_device, ctx.descriptor_pool, null);
        c.vkDestroyCommandPool(ctx.vk_logical_device, ctx.command_pool, null);
        c.vkDestroyRenderPass(ctx.vk_logical_device, ctx.render_pass, null);
    }

    pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
        var ctx = try world.getResource(Context);
        std.debug.print("\n\n=========[ENTERED while loop]===========\n\n", .{});
        if (true) {
            try ctx.spectator_view.update(ctx);
        }

        var eventData = c.XrEventDataBuffer{
            .type = c.XR_TYPE_EVENT_DATA_BUFFER,
        };
        var result: c.XrResult = c.xrPollEvent(ctx.xr_instance, &eventData);

        switch (eventData.type) {
            c.XR_TYPE_EVENT_DATA_EVENTS_LOST => std.debug.print("Event queue overflowed and events were lost.\n", .{}),
            c.XR_TYPE_EVENT_DATA_INSTANCE_LOSS_PENDING => {
                std.debug.print("OpenXR instance is shutting down.\n", .{});
                quit.store(true, .release);
            },
            c.XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED => {
                try xr.recordCurrentBindings(ctx.xr_session, ctx.xr_instance);
                std.debug.print("The interaction profile has changed.\n", .{});
            },
            c.XR_TYPE_EVENT_DATA_REFERENCE_SPACE_CHANGE_PENDING => std.debug.print("The reference space is changing.\n", .{}),
            c.XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED => {
                const event: *c.XrEventDataSessionStateChanged = @ptrCast(&eventData);

                switch (event.state) {
                    c.XR_SESSION_STATE_UNKNOWN, c.XR_SESSION_STATE_MAX_ENUM => std.debug.print("Unknown session state entered: {any}\n", .{event.state}),
                    c.XR_SESSION_STATE_IDLE => ctx.running = false,
                    c.XR_SESSION_STATE_READY => {
                        const sessionBeginInfo = c.XrSessionBeginInfo{
                            .type = c.XR_TYPE_SESSION_BEGIN_INFO,
                            .primaryViewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
                        };
                        try loader.xrCheck(c.xrBeginSession(ctx.xr_session, &sessionBeginInfo));
                        ctx.running = true;
                    },
                    c.XR_SESSION_STATE_SYNCHRONIZED, c.XR_SESSION_STATE_VISIBLE, c.XR_SESSION_STATE_FOCUSED => ctx.running = true,
                    c.XR_SESSION_STATE_STOPPING => {
                        try loader.xrCheck(c.xrEndSession(ctx.xr_session));
                        ctx.running = false;
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
                        log.err("Unknown event STATE received: {any}", .{event.state});
                    },
                }
            },
            else => {
                log.err("Unknown event TYPE received: {any}", .{eventData.type});
            },
        }
        // if (result == c.XR_EVENT_UNAVAILABLE) {
        // mashed potatos
        if (ctx.running) {
            var frame_wait_info = c.XrFrameWaitInfo{ .type = c.XR_TYPE_FRAME_WAIT_INFO };
            var frame_state = c.XrFrameState{ .type = c.XR_TYPE_FRAME_STATE };
            result = c.xrWaitFrame(ctx.xr_session, &frame_wait_info, &frame_state);
            if (result != c.XR_SUCCESS) {
                std.debug.print("\n\n=========[OMG WE DIDED]===========\n\n", .{}); //TODO: QUITE APP
                return;
            }
            var begin_frame_info = c.XrFrameBeginInfo{
                .type = c.XR_TYPE_FRAME_BEGIN_INFO,
            };
            try loader.xrCheck(c.xrBeginFrame(ctx.xr_session, &begin_frame_info));
            var should_quit = input.pollAction(
                ctx.xr_session,
                ctx.action_set,
                ctx.xr_space,
                frame_state.predictedDisplayTime,
                m_palmPoseAction,
                m_grabCubeAction,
                m_handPaths,
                hand_pose_space,
                &m_handPoseState,
                &m_grabState,
                &hand_pose,
            ) catch true;
            // input.blockInteraction(
            //     &grabbed_block,
            //     m_grabState,
            //     &near_block,
            //     hand_pose,
            //     m_handPoseState,
            //     blocks,
            // );
            if (frame_state.shouldRender == c.VK_FALSE) {
                var end_frame_info = c.XrFrameEndInfo{
                    .type = c.XR_TYPE_FRAME_END_INFO,
                    .displayTime = frame_state.predictedDisplayTime,
                    .environmentBlendMode = c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
                    .layerCount = 0,
                    .layers = null,
                };
                try loader.xrCheck(c.xrEndFrame(ctx.xr_session, &end_frame_info));
            } else {
                should_quit, const active_index = render(
                    comps,
                    world,
                    ctx.xr_session,
                    ctx.xr_swapchain,
                    ctx.xr_space,
                    frame_state.predictedDisplayTime,
                    ctx.vk_logical_device,
                    ctx.vk_queue,
                    ctx.render_pass,
                    ctx.pipeline_layout,
                    ctx.pipeline,
                ) catch .{ true, 0 };
                if (should_quit)
                    quit.store(should_quit, .release);
                ctx.last_rendered_image_index = active_index;
            }
        }
        std.debug.print("\n\n=========[DONE while loop]===========\n\n", .{});
    }
};

// mashedpotatoe

pub fn render(
    comps: []const type,
    world: *World(comps),
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
        .next = null,
    };

    var view_state = c.XrViewState{
        .type = c.XR_TYPE_VIEW_STATE,
        .next = null,
    };

    var view_count: u32 = 2;
    var views: [2]c.XrView = .{ .{
        .type = c.XR_TYPE_VIEW,
        .next = null,
    }, .{
        .type = c.XR_TYPE_VIEW,
        .next = null,
    } };

    try loader.xrCheck(c.xrLocateViews(
        session,
        &view_locate_info,
        &view_state,
        view_count,
        &view_count,
        @ptrCast(&views[0]),
    ));

    const ok, const active_index = try renderEye(
        comps,
        world,
        swapchain,
        &views,
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
    comps: []const type,
    world: *World(comps),
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

    var it = world.query(&.{ root.Transform, root.Mesh });
    while (it.next()) |entity| {
        const transform = entity.get(root.Transform).?.*;
        const mesh = entity.get(root.Mesh).?.*;
        const asset_manager = try world.getResource(AssetManager);
        const model = asset_manager.getModel(mesh.name);
        renderMesh(transform, model, image.command_buffer, pipeline_layout);
    }

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
            .levelCount = 0,
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

pub fn renderMesh(transform: root.Transform, model: AssetManager.Model, command_buffer: c.VkCommandBuffer, layput: c.VkPipelineLayout) void {
    var scale: nz.Mat4(f32) = .identity(2);
    scale.d[0] = transform.scale[0];
    scale.d[5] = transform.scale[1];
    scale.d[10] = transform.scale[2];

    const rotation: nz.Mat4(f32) = .identity(1);

    var positon: nz.Mat4(f32) = .translate(transform.position);

    var push: vk.PushConstant = .{
        .matrix = (positon.mul(rotation).mul(scale)).d,
        .color = .{ 0.7, 0.0, 0.4, 0 },
    };

    c.vkCmdPushConstants(command_buffer, layput, c.VK_SHADER_STAGE_VERTEX_BIT, 0, @sizeOf(vk.PushConstant), &push);

    var offsets: [1]c.VkDeviceSize = .{0};
    var vertex_buffers: [1]c.VkBuffer = .{model.vertex_buffer.buffer};
    c.vkCmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers, @ptrCast(&offsets));
    c.vkCmdBindIndexBuffer(command_buffer, model.index_buffer.buffer, 0, c.VK_INDEX_TYPE_UINT32);
    c.vkCmdDrawIndexed(
        command_buffer,
        model.index_count,
        1,
        0,
        0,
        0,
    );
}
