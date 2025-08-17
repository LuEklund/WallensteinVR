const std = @import("std");
const log = std.log;

const loader = @import("loader");
const c = loader.c;

const nz = @import("numz");
// const XrSwapchain = @import("XrSwapchain.zig");

const xr = @import("openxr.zig");

pub const Dispatcher = loader.VkDispatcher(.{
    .vkCreateDebugUtilsMessengerEXT = true,
    .vkDestroyDebugUtilsMessengerEXT = true,
});

pub const PushConstant = extern struct {
    matrix: [16]f32,
    color: [4]f32,
};

export fn debugCallback(
    message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.c) c.VkBool32 {
    const prefix: []const u8 = switch (message_severity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warn", // ← fix typo from "wanr"
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        else => "unknown",
    };

    log.info("[Vulkan {s}]: {s}\n", .{ prefix, std.mem.sliceTo(callback_data.*.pMessage, 0) });
    return c.VK_FALSE;
}

pub fn createInstance(graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, extensions: []const [*:0]const u8, layers: []const [*:0]const u8) !c.VkInstance {
    _ = graphics_requirements;
    var create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .ppEnabledExtensionNames = if (extensions.len > 0) extensions.ptr else null,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledLayerNames = if (layers.len > 0) layers.ptr else null,
        .enabledLayerCount = @intCast(layers.len),

        .pApplicationInfo = &.{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "WallensteinVR",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "WallensteinVR_Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            // .apiVersion = c.VK_VERSION_1_4,
            .apiVersion = c.VK_MAKE_API_VERSION(
                0,
                1,
                4,
                0,
            ),
        },
    };

    var instance: c.VkInstance = undefined;
    try loader.vkCheck(c.vkCreateInstance(&create_info, null, &instance));
    return instance;
}

pub fn createDebugMessenger(
    dispatcher: Dispatcher,
    instance: c.VkInstance,
) !c.VkDebugUtilsMessengerEXT {
    var debug_messenger_create_info = c.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = debugCallback,
    };

    var debug_messenger: c.VkDebugUtilsMessengerEXT = undefined;
    try dispatcher.vkCreateDebugUtilsMessengerEXT(
        instance,
        &debug_messenger_create_info,
        null,
        &debug_messenger,
    );

    return debug_messenger;
}

pub fn createLogicalDevice(physical_device: c.VkPhysicalDevice, graphics_queue_family_index: u32, extensions: []const [*:0]const u8) !struct { c.VkDevice, c.VkQueue } {
    var queue_priority: f32 = 1.0;
    const queue_info = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .queueFamilyIndex = graphics_queue_family_index,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
        .flags = 0,
    };

    const features = c.VkPhysicalDeviceFeatures{};

    var multiview_features = c.VkPhysicalDeviceMultiviewFeatures{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MULTIVIEW_FEATURES,
        .multiview = 1,
    };

    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &multiview_features,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
        .pEnabledFeatures = &features,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .flags = 0,
    };

    var logical_device: c.VkDevice = undefined;
    try loader.vkCheck(c.vkCreateDevice(physical_device, &device_info, null, &logical_device));
    var queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(logical_device, graphics_queue_family_index, 0, &queue);

    return .{ logical_device, queue };
}

pub fn findGraphicsQueueFamily(physical: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !u32 {
    var count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical, &count, null);

    var props: [16]c.VkQueueFamilyProperties = undefined;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical, &count, &props);
    for (props[0..count], 0..) |qf, i| {
        var present: c.VkBool32 = 0;
        const result: c.VkResult = c.vkGetPhysicalDeviceSurfaceSupportKHR(physical, @intCast(i), surface, &present);
        if (result != c.VK_SUCCESS) {
            std.log.err("Failed to get Vulkan physical device surface support: {d}", .{result});
            return error.findGraphicsQueueFamily;
        }
        if (present != 0 and qf.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            return @intCast(i);
        }
    }

    return error.NoQueueFamily;
}

pub fn createCommandPool(device: c.VkDevice, graphicsQueueFamilyIndex: u32) !c.VkCommandPool {
    var commandPool: c.VkCommandPool = undefined;

    var createInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = graphicsQueueFamilyIndex,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
    };
    try loader.vkCheck(c.vkCreateCommandPool(device, &createInfo, null, &commandPool));
    return commandPool;
}

pub fn createRenderPass(device: c.VkDevice, color_format: c.VkFormat, depth_format: c.VkFormat, sample_count: c.VkSampleCountFlagBits) !c.VkRenderPass {
    const color_attachment = c.VkAttachmentDescription{
        .format = color_format,
        .samples = sample_count,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    var color_attachment_reference = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const depth_attachment = c.VkAttachmentDescription{
        .format = depth_format,
        .samples = sample_count,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    var depth_attachment_reference = c.VkAttachmentReference{
        .attachment = 1,
        .layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    var subpass = c.VkSubpassDescription{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_reference,
        .pDepthStencilAttachment = &depth_attachment_reference,
    };

    const viewMask: c_int = 0b11;
    const correlationMask: c_int = 0b11;

    var multiview = c.VkRenderPassMultiviewCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_MULTIVIEW_CREATE_INFO,
        .subpassCount = 1,
        .pViewMasks = @ptrCast(&viewMask),
        .correlationMaskCount = 1,
        .pCorrelationMasks = @ptrCast(&correlationMask),
    };

    var attachments: [2]c.VkAttachmentDescription = .{
        color_attachment,
        depth_attachment,
    };

    var dependency: c.VkSubpassDependency = .{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        .srcAccessMask = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
    };

    var create_info = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = &multiview,
        .flags = 0,
        .attachmentCount = attachments.len,
        .pAttachments = &attachments,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
    };

    var render_pass: c.VkRenderPass = undefined;
    try loader.vkCheck(c.vkCreateRenderPass(device, &create_info, null, &render_pass));

    return render_pass;
}

pub fn createDescriptorPool(device: c.VkDevice) !c.VkDescriptorPool {
    var descriptor_pool: c.VkDescriptorPool = undefined;

    //TODO: Frames in flight instead of 32!
    var pool_sizes = [_]c.VkDescriptorPoolSize{
        .{
            .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 32,
        },
        .{
            .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 32,
        },
    };

    var create_info = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = 32,
        .poolSizeCount = pool_sizes.len,
        .pPoolSizes = &pool_sizes,
    };

    try loader.vkCheck(c.vkCreateDescriptorPool(device, &create_info, null, &descriptor_pool));

    return descriptor_pool;
}

pub fn createDescriptorSetLayout(device: c.VkDevice) !c.VkDescriptorSetLayout {
    const view_projection_binding = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };
    const texture_sampler_binding = c.VkDescriptorSetLayoutBinding{
        .binding = 1,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    };
    var bindings = [_]c.VkDescriptorSetLayoutBinding{ view_projection_binding, texture_sampler_binding };
    var create_info = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = bindings.len,
        .pBindings = &bindings,
    };

    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
    try loader.vkCheck(c.vkCreateDescriptorSetLayout(device, &create_info, null, &descriptor_set_layout));

    return descriptor_set_layout;
}

pub fn createShader(allocator: std.mem.Allocator, device: c.VkDevice, file_path: []const u8) !c.VkShaderModule {
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));

    var shader_create_info = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = source.len,
        .pCode = @ptrCast(@alignCast(source.ptr)),
    };

    var shader: c.VkShaderModule = undefined;
    try loader.vkCheck(c.vkCreateShaderModule(device, &shader_create_info, null, &shader));
    allocator.free(source);
    return shader;
}

pub fn createPipeline(
    device: c.VkDevice,
    render_pass: c.VkRenderPass,
    descriptor_set_layout: c.VkDescriptorSetLayout,
    vertex_shader: c.VkShaderModule,
    fragment_shader: c.VkShaderModule,
    sample_count: c.VkSampleCountFlagBits,
) !struct { c.VkPipelineLayout, c.VkPipeline } {
    var pipeline: c.VkPipeline = undefined;

    var push_constant_range: c.VkPushConstantRange = .{
        .offset = 0,
        .size = @sizeOf(PushConstant),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };
    var layout_create_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &push_constant_range,
    };

    var pipeline_layout: c.VkPipelineLayout = undefined;
    try loader.vkCheck(c.vkCreatePipelineLayout(device, &layout_create_info, null, &pipeline_layout));

    var vertex_binding: c.VkVertexInputBindingDescription = .{
        .binding = 0,
        .stride = @sizeOf(f32) * 8,
        .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
    };

    var vertex_input: [3]c.VkVertexInputAttributeDescription = .{ .{
        .binding = 0,
        .location = 0,
        .offset = 0,
        .format = c.VK_FORMAT_R32G32B32_SFLOAT,
    }, .{
        .binding = 0,
        .location = 1,
        .offset = @sizeOf(f32) * 3,
        .format = c.VK_FORMAT_R32G32_SFLOAT,
    }, .{
        .binding = 0,
        .location = 2,
        .offset = @sizeOf(f32) * 5,
        .format = c.VK_FORMAT_R32G32B32_SFLOAT,
    } };

    var vertex_input_stage = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &vertex_binding,
        .vertexAttributeDescriptionCount = vertex_input.len,
        .pVertexAttributeDescriptions = &vertex_input,
    };

    var input_assembly_stage = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    };

    const vertex_shader_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertex_shader,
        .pName = "main",
    };

    var viewport = c.VkViewport{ .x = 0, .y = 0, .width = 1024, .height = 1024, .minDepth = 0, .maxDepth = 1 };
    var scissor = c.VkRect2D{ .offset = .{ .x = 0, .y = 0 }, .extent = .{ .width = 1024, .height = 1024 } };

    var viewport_stage = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    };

    var rasterization_stage = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0,
        .depthBiasClamp = 0,
        .depthBiasSlopeFactor = 0,
    };

    var multisample_stage = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = sample_count,
        .sampleShadingEnable = c.VK_FALSE,
        .minSampleShading = 0.25,
    };

    var depth_stencil_stage = c.VkPipelineDepthStencilStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_TRUE,
        .depthWriteEnable = c.VK_TRUE,
        .depthCompareOp = c.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = c.VK_FALSE,
        .minDepthBounds = 0,
        .maxDepthBounds = 1,
        .stencilTestEnable = c.VK_FALSE,
    };

    const fragment_shader_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragment_shader,
        .pName = "main",
    };

    var color_blend_attachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_TRUE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    var color_blend_stage = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
        .blendConstants = [4]f32{ 0, 0, 0, 0 },
    };

    const dynamic_states = [_]c.VkDynamicState{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR };

    var dynamic_state = c.VkPipelineDynamicStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = 2,
        .pDynamicStates = &dynamic_states,
    };

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{ vertex_shader_stage, fragment_shader_stage };

    var create_info = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shader_stages,
        .pVertexInputState = &vertex_input_stage,
        .pInputAssemblyState = &input_assembly_stage,
        .pTessellationState = null,
        .pViewportState = &viewport_stage,
        .pRasterizationState = &rasterization_stage,
        .pMultisampleState = &multisample_stage,
        .pDepthStencilState = &depth_stencil_stage,
        .pColorBlendState = &color_blend_stage,
        .pDynamicState = &dynamic_state,
        .layout = pipeline_layout,
        .renderPass = render_pass,
        .subpass = 0,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    try loader.vkCheck(c.vkCreateGraphicsPipelines(device, null, 1, &create_info, null, &pipeline));

    return .{ pipeline_layout, pipeline };
}

pub fn createFence(device: c.VkDevice) !c.VkFence {
    var createInfo: c.VkFenceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    };

    var fence: c.VkFence = undefined;

    try loader.vkCheck(c.vkCreateFence(device, &createInfo, null, &fence));

    return fence;
}

pub fn findMemoryType(
    properties: c.VkPhysicalDeviceMemoryProperties,
    memory_requirements: c.VkMemoryRequirements,
    flags: c.VkMemoryPropertyFlags,
) !u32 {
    const shiftee: u32 = 1;

    for (0..properties.memoryTypeCount) |i| {
        if ((memory_requirements.memoryTypeBits & (shiftee << @intCast(i)) == 0) or (properties.memoryTypes[i].propertyFlags & flags) != flags)
            continue;
        return @intCast(i);
    } else return error.MemoryRequirements;
}

pub const VulkanBuffer = struct {
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
};

pub fn createBuffer(
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    usage_type: u32,
    len: u32,
    type_size: u32,
    data: *anyopaque,
) !VulkanBuffer {
    //(bufferCI.type == BufferCreateInfo::Type::VERTEX ? VK_BUFFER_USAGE_VERTEX_BUFFER_BIT : 0) | (bufferCI.type == BufferCreateInfo::Type::INDEX ? VK_BUFFER_USAGE_INDEX_BUFFER_BIT : 0) | (bufferCI.type == BufferCreateInfo::Type::UNIFORM ? VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT : 0),
    var buffer_create_info: c.VkBufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .size = len * type_size,
        .usage = usage_type,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
    };
    std.debug.print("Creating VulkanBuffer with the following parameters:\n", .{});
    std.debug.print("  - physical_device: {any}\n", .{physical_device});
    std.debug.print("  - device: {any}\n", .{device});
    std.debug.print("  - usage_type: {d}\n", .{usage_type});
    std.debug.print("  - len: {d}\n", .{len});
    std.debug.print("  - type_size: {d}\n", .{type_size});
    std.debug.print("  - data: {any}\n", .{data});
    var buffer: c.VkBuffer = undefined;
    try loader.vkCheck(c.vkCreateBuffer(device, &buffer_create_info, null, &buffer));

    var memory_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, buffer, &memory_requirements);

    var properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &properties);
    const flags: c.VkMemoryPropertyFlags = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;

    var allocate_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = memory_requirements.size,
        .memoryTypeIndex = try findMemoryType(properties, memory_requirements, flags),
    };

    var memory: c.VkDeviceMemory = undefined;
    try loader.vkCheck(c.vkAllocateMemory(device, &allocate_info, null, &memory));
    try loader.vkCheck(c.vkBindBufferMemory(device, buffer, memory, 0));

    var mapped_data: *anyopaque = undefined;
    try loader.vkCheck(c.vkMapMemory(device, memory, 0, buffer_create_info.size, 0, @ptrCast(&mapped_data)));
    const dest_bytes: [*]u8 = @ptrCast(mapped_data);
    const src_bytes: [*]const u8 = @ptrCast(data);
    const dest_slice = dest_bytes[0..buffer_create_info.size];
    const src_slice = src_bytes[0..buffer_create_info.size];
    std.debug.print("{d} -=- {d}\n", .{ dest_slice.len, src_slice.len });
    @memcpy(dest_slice, src_slice);

    return .{
        .buffer = buffer,
        .memory = memory,
    };
}
pub const VulkanImageBuffer = struct {
    texture_image: c.VkImage,
    texture_image_memory: c.VkDeviceMemory,
};

pub fn createImage(
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    width: u32,
    height: u32,
    format: c.VkFormat,
    tiling: c.VkImageTiling,
    usage: c.VkImageUsageFlags,
    properties: c.VkMemoryPropertyFlags,
) !VulkanImageBuffer {
    var image_info: c.VkImageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = c.VK_IMAGE_TYPE_2D,
        .extent = .{
            .width = width,
            .height = height,
            .depth = 1,
        },
        .mipLevels = 1,
        .arrayLayers = 1,
        .format = format,
        .tiling = tiling,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .flags = 0,
    };

    var image: c.VkImage = undefined;
    try loader.vkCheck(c.vkCreateImage(
        device,
        &image_info,
        null,
        &image,
    ));

    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetImageMemoryRequirements(device, image, &mem_requirements);
    var device_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &device_properties);

    var allocInfo: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
    };
    allocInfo.memoryTypeIndex = try findMemoryType(device_properties, mem_requirements, properties);
    var image_memory: c.VkDeviceMemory = undefined;
    try loader.vkCheck(c.vkAllocateMemory(device, &allocInfo, null, &image_memory));

    try loader.vkCheck(c.vkBindImageMemory(device, image, image_memory, 0));
    return .{
        .texture_image = image,
        .texture_image_memory = image_memory,
    };
}

pub fn beginSingleTimeCommands(device: c.VkDevice, command_pool: c.VkCommandPool) !c.VkCommandBuffer {
    var alloc_info: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = command_pool,
        .commandBufferCount = 1,
    };

    var command_buffer: c.VkCommandBuffer = undefined;
    try loader.vkCheck(c.vkAllocateCommandBuffers(device, &alloc_info, &command_buffer));

    var begin_info: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    try loader.vkCheck(c.vkBeginCommandBuffer(command_buffer, &begin_info));
    return command_buffer;
}

pub fn endSingleTimeCommands(device: c.VkDevice, queue: c.VkQueue, command_pool: c.VkCommandPool, command_buffer: c.VkCommandBuffer) !void {
    try loader.vkCheck(c.vkEndCommandBuffer(command_buffer));

    var submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
    };

    try loader.vkCheck(c.vkQueueSubmit(queue, 1, &submit_info, null));
    try loader.vkCheck(c.vkQueueWaitIdle(queue));

    c.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
}

pub fn transitionImageLayout(
    device: c.VkDevice,
    queue: c.VkQueue,
    command_pool: c.VkCommandPool,
    image: c.VkImage,
    format: c.VkFormat,
    oldLayout: c.VkImageLayout,
    newLayout: c.VkImageLayout,
) !void {
    _ = format;
    const command_buffer: c.VkCommandBuffer = try beginSingleTimeCommands(
        device,
        command_pool,
    );
    var barrier: c.VkImageMemoryBarrier = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .srcAccessMask = 0,
        .dstAccessMask = 0,
    };

    var source_stage: c.VkPipelineStageFlags = undefined;
    var destination_stage: c.VkPipelineStageFlags = undefined;
    if (oldLayout == c.VK_IMAGE_LAYOUT_UNDEFINED and newLayout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;

        source_stage = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destination_stage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (oldLayout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = c.VK_ACCESS_SHADER_READ_BIT;

        source_stage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
        destination_stage = c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else {
        @panic("\nunsupported layout transition!\n");
    }

    c.vkCmdPipelineBarrier(command_buffer, source_stage, destination_stage, 0, 0, null, 0, null, 1, &barrier);

    try endSingleTimeCommands(
        device,
        queue,
        command_pool,
        command_buffer,
    );
}

pub fn copyBufferToImage(
    device: c.VkDevice,
    queue: c.VkQueue,
    command_pool: c.VkCommandPool,
    buffer: c.VkBuffer,
    image: c.VkImage,
    width: u32,
    height: u32,
) !void {
    const command_buffer: c.VkCommandBuffer = try beginSingleTimeCommands(
        device,
        command_pool,
    );
    var region: c.VkBufferImageCopy = .{
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,

        .imageSubresource = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
        .imageExtent = .{ .width = width, .height = height, .depth = 1 },
    };
    c.vkCmdCopyBufferToImage(
        command_buffer,
        buffer,
        image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &region,
    );

    try endSingleTimeCommands(
        device,
        queue,
        command_pool,
        command_buffer,
    );
}

pub fn createImageView(
    device: c.VkDevice,
    image: c.VkImage,
    view_type: c.VkImageViewType,
    format: c.VkFormat,
    aspect_mask: c.VkImageAspectFlags,
    layer_count: u32,
) !c.VkImageView {
    var view_info: c.VkImageViewCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = view_type,
        .format = format,
        .subresourceRange = .{
            .aspectMask = aspect_mask,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = layer_count,
        },
    };

    var image_view: c.VkImageView = undefined;
    try loader.vkCheck(c.vkCreateImageView(device, &view_info, null, &image_view));

    return image_view;
}

pub fn createTextureSampler(
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
) !c.VkSampler {
    _ = physical_device;
    // var properties: c.VkPhysicalDeviceProperties = undefined;
    // c.vkGetPhysicalDeviceProperties(physical_device, &properties);

    var samplerInfo: c.VkSamplerCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = c.VK_FILTER_NEAREST,
        .minFilter = c.VK_FILTER_NEAREST,
        .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = c.VK_FALSE,
        .maxAnisotropy = 1.0,
        .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = c.VK_FALSE,
        .compareEnable = c.VK_FALSE,
        .compareOp = c.VK_COMPARE_OP_ALWAYS,
        .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
    };
    var texture_sampler: c.VkSampler = undefined;
    try loader.vkCheck(c.vkCreateSampler(device, &samplerInfo, null, &texture_sampler));
    return texture_sampler;
}
