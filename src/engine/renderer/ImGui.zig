const std = @import("std");
const loader = @import("loader");
const c = loader.c;
const Context = @import("Context.zig");
const imgui = @import("imgui").c;
const vk = @import("vulkan.zig");

frame_buffer_width: u32 = 0,
frame_buffer_height: u32 = 0,
descriptor_pool: c.VkDescriptorPool = null,
cmd_buffers: []c.VkCommandBuffer = undefined,
f: f32 = 0.0,
m_clearColor: [4]f32 = [_]f32{ 0.45, 0.55, 0.60, 1.00 },
m_position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
m_rotation: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
m_scale: f32 = 1.0,
counter: c_int = 0,

// The 3D gizmo variables. Note that you may need a separate Zig binding for this
// as ImGuizmo is not part of the core ImGui library.
// For now, we represent them as arrays of floats.
qRot1: [4]f32 = [_]f32{ 1.0, 0.0, 0.0, 0.0 },
qRot2: [4]f32 = [_]f32{ 1.0, 0.0, 0.0, 0.0 },
dir: [4]f32 = [_]f32{ 1.0, 0.0, 0.0, 0.0 },

pub fn init(allocator: std.mem.Allocator, gfx_ctx: *Context) !@This() {
    const frame_buffer_width = gfx_ctx.vk_swapchain.width;
    const frame_buffer_height = gfx_ctx.vk_swapchain.height;

    var pool_size = [_]c.VkDescriptorPoolSize{
        .{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, .descriptorCount = 1000 },
    };

    var pool_create_info: c.VkDescriptorPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = 1000 * pool_size.len,
        .pPoolSizes = &pool_size,
    };

    var descriptor_pool: c.VkDescriptorPool = null;
    try loader.vkCheck(c.vkCreateDescriptorPool(
        gfx_ctx.vk_logical_device,
        &pool_create_info,
        null,
        &descriptor_pool,
    ));

    //Imgui
    const context = imgui.ImGui_CreateContext(null);
    if (context == null) {
        @panic("Failed to create ImGui context!");
    }
    const io = imgui.ImGui_GetIO();
    io.*.ConfigFlags |= imgui.ImGuiConfigFlags_NavEnableKeyboard;
    io.*.ConfigFlags |= imgui.ImGuiConfigFlags_NavEnableSetMousePos;
    io.*.DisplaySize.x = @floatFromInt(frame_buffer_width);
    io.*.DisplaySize.y = @floatFromInt(frame_buffer_height);

    imgui.ImGui_GetStyle().*.FontScaleMain = 1.5;
    // imgui.ImGui_StyleColorsDark();

    _ = imgui.cImGui_ImplSDL3_InitForVulkan(@ptrCast(&gfx_ctx.spectator_view.sdl_window));

    // const color_format: c.VkFormat = gfx_ctx.vk_swapchain.format;

    var imgui_vulkan_info: imgui.ImGui_ImplVulkan_InitInfo = .{
        //init_info.ApiVersion = VK_API_VERSION_1_3;              // Pass in your value of VkApplicationInfo::apiVersion, otherwise will default to header version.
        .Instance = @ptrCast(gfx_ctx.vk_instance),
        .PhysicalDevice = @ptrCast(gfx_ctx.vk_physical_device),
        .Device = @ptrCast(gfx_ctx.vk_logical_device),
        .QueueFamily = gfx_ctx.graphics_queue_family_index,
        .Queue = @ptrCast(gfx_ctx.vk_queue),
        .PipelineCache = null,
        .DescriptorPool = @ptrCast(descriptor_pool),
        .RenderPass = @ptrCast(gfx_ctx.render_pass),
        .Subpass = 0,
        .MinImageCount = 3,
        .ImageCount = gfx_ctx.vk_swapchain.image_count,
        .MSAASamples = loader.c.VK_SAMPLE_COUNT_1_BIT,
        .UseDynamicRendering = false,
        .Allocator = null,
        .CheckVkResultFn = checkVKResult,
    };

    _ = imgui.cImGui_ImplVulkan_Init(&imgui_vulkan_info);

    var cmd_buffers = try allocator.alloc(c.VkCommandBuffer, gfx_ctx.vk_swapchain.image_count);
    try vk.createCommandBuffers(
        gfx_ctx.vk_logical_device,
        gfx_ctx.command_pool,
        gfx_ctx.vk_swapchain.image_count,
        &cmd_buffers[0],
    );

    std.debug.print("cmd  buff: .{any}\n", .{cmd_buffers});
    // if (true) @panic("LOL");
    return .{
        .frame_buffer_height = frame_buffer_height,
        .frame_buffer_width = frame_buffer_width,
        .descriptor_pool = descriptor_pool,
        .cmd_buffers = cmd_buffers,
    };
}

pub fn checkVKResult(err: c_int) callconv(.c) void {
    if (err == 0) {
        return;
    }
    std.log.err("[vulkan] Error: VkResult = .{any}\n", .{err});

    if (err < 0) {
        @panic("ERROR IMGUI");
    }
}

pub fn deinit() !void {
    // defer imgui.ImGui_DestroyContext(context);

}

pub fn prepareCommandBuffer(self: *@This(), cmd_buffer: c.VkCommandBuffer, image: u32, gfx_ctx: *Context) !c.VkCommandBuffer {
    // _ = self;
    std.debug.print("Image num : .{any}\n", .{image});
    std.debug.print("cmd  buff: .{any}\n", .{cmd_buffer});
    var color_attachment_info: c.VkRenderingAttachmentInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
        .imageView = gfx_ctx.vk_swapchain.vk_image_views[image],
        .imageLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .resolveMode = c.VK_RESOLVE_MODE_NONE,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_LOAD,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
    };
    var rendering_info: c.VkRenderingInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDERING_INFO,
        .renderArea = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = gfx_ctx.vk_swapchain.width, .height = gfx_ctx.vk_swapchain.height },
        },
        .layerCount = 1,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_info,
    };
    // c.vkCmdBeginRendering(cmd_buffer, &rendering_info);
    c.vkCmdBeginRendering(self.cmd_buffers[image], &rendering_info);

    const draw_data = imgui.ImGui_GetDrawData();
    if (draw_data.*.Valid) {
        // imgui.cImGui_ImplVulkan_RenderDrawData(draw_data, @ptrCast(cmd_buffer));
        imgui.cImGui_ImplVulkan_RenderDrawData(draw_data, @ptrCast(self.cmd_buffers[image]));
    } else {
        @panic("AAAAAAAAAAAAAAAAAAAAAAAAAAAA\n");
    }

    // try loader.vkCheck(c.vkEndCommandBuffer(cmd_buffer));
    return self.cmd_buffers[image];
}

pub fn updateGUI(self: *@This(), ctx: *Context) !void {
    const io = imgui.ImGui_GetIO();

    const win_size = try ctx.spectator_view.sdl_window.getSize();
    io.*.DisplaySize = .{ .x = @floatFromInt(win_size.width), .y = @floatFromInt(win_size.height) };

    std.debug.print("DIMENTION\n width: {any}, Heigth .{any}", .{ win_size.width, win_size.height });

    // Add validation
    const width = @max(1, win_size.width);
    const height = @max(1, win_size.height);
    io.*.DisplaySize = .{ .x = @floatFromInt(width), .y = @floatFromInt(height) };
    // Get the window size from your context
    // const win_size = try ctx.spectator_view.sdl_window.getSize();

    // // Set the DisplaySize and DisplayFramebufferScale
    // io.*.DisplaySize = .{ .x = @floatFromInt(win_size.width), .y = @floatFromInt(win_size.height) };
    // io.*.DisplayFramebufferScale = .{ .x = 1.0, .y = 1.0 }; // Assumes a 1:1 scale for now

    // The C++ `ImGuiIO& io = ImGui::GetIO()` is not explicitly needed here
    // as the ImGui functions are bound differently in Zig.
    imgui.cImGui_ImplVulkan_NewFrame();
    imgui.cImGui_ImplSDL3_NewFrame(); // Using SDL3 as per your setup
    imgui.ImGui_NewFrame();

    // The main "Hello, world!" window
    _ = imgui.ImGui_Begin("Hello, world!", null, imgui.ImGuiWindowFlags_AlwaysAutoResize);
    imgui.ImGui_Text("This is some useful text.");

    // Slider for a float variable
    _ = imgui.ImGui_SliderFloat("float", &self.f, 0.0, 1.0);
    // Color editor
    _ = imgui.ImGui_ColorEdit3("Clear color", &self.m_clearColor, 0);

    // The "Transform" window
    _ = imgui.ImGui_Begin("Transform", null, 0);

    // Position section with a collapsing header
    if (imgui.ImGui_CollapsingHeader("Position", imgui.ImGuiTreeNodeFlags_None)) {
        _ = imgui.ImGui_DragFloat3("##Position", &self.m_position);
        imgui.ImGui_SameLine();
        if (imgui.ImGui_Button("Reset##Pos")) {
            self.m_position[0] = 0.0;
            self.m_position[1] = 0.0;
            self.m_position[2] = 0.0;
        }
    }

    // // Rotation section
    if (imgui.ImGui_CollapsingHeader("Rotation", imgui.ImGuiTreeNodeFlags_None)) {
        _ = imgui.ImGui_DragFloat3("##Rotation", &self.m_rotation);
        imgui.ImGui_SameLine();
        if (imgui.ImGui_Button("Reset##Rot")) {
            self.m_rotation[0] = 0.0;
            self.m_rotation[1] = 0.0;
            self.m_rotation[2] = 0.0;
        }
    }

    // // Scale section
    if (imgui.ImGui_CollapsingHeader("Scale", imgui.ImGuiTreeNodeFlags_None)) {
        _ = imgui.ImGui_DragFloat("##Scale", &self.m_scale);
        imgui.ImGui_SameLine();
        if (imgui.ImGui_Button("Reset##Scale")) {
            self.m_scale = 1.0;
        }
    }

    // Gizmo rendering, assuming a binding exists
    // imgui.gizmo3D("##gizmo1", &qRot1, 200.0, c.imguiGizmo_modeRotation);
    // imgui.gizmo3D("##Dir1", &dir, 200.0, c.imguiGizmo_modeDirection);

    // Button and counter
    if (imgui.ImGui_Button("Button")) {
        self.counter += 1;
    }
    imgui.ImGui_SameLine();
    imgui.ImGui_Text("counter = %d", @as(u8, @intCast(self.counter)));

    // Frame rate text
    imgui.ImGui_Text(
        "Application average %.3f ms/frame (%.1f FPS)",
        1000.0 / io.*.Framerate,
        io.*.Framerate,
    );

    imgui.ImGui_End(); // End "Transform"
    imgui.ImGui_End(); // End "Hello, world!"

    imgui.ImGui_Render();
}
