const std = @import("std");
const log = std.log;

const loader = @import("loader");
const c = loader.c;

// const XrSwapchain = @import("XrSwapchain.zig");

const xr = @import("openxr.zig");

pub const Dispatcher = loader.VkDispatcher(.{
    .vkCreateDebugUtilsMessengerEXT = true,
    .vkDestroyDebugUtilsMessengerEXT = true,
});

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

pub fn createRenderPass(device: c.VkDevice, format: c.VkFormat, sample_count: c.VkSampleCountFlagBits) !c.VkRenderPass {
    var attachment = c.VkAttachmentDescription{
        .format = format,
        .samples = sample_count,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    var attachment_reference = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    var subpass = c.VkSubpassDescription{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &attachment_reference,
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

    var create_info = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = &multiview,
        .flags = 0,
        .attachmentCount = 1,
        .pAttachments = &attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
    };

    var render_pass: c.VkRenderPass = undefined;
    try loader.vkCheck(c.vkCreateRenderPass(device, &create_info, null, &render_pass));

    return render_pass;
}

pub fn createDescriptorPool(device: c.VkDevice) !c.VkDescriptorPool {
    var descriptor_pool: c.VkDescriptorPool = undefined;

    var create_info = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = 32,
        .poolSizeCount = 1,
        .pPoolSizes = &.{
            .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 32,
        },
    };

    try loader.vkCheck(c.vkCreateDescriptorPool(device, &create_info, null, &descriptor_pool));

    return descriptor_pool;
}

pub fn createDescriptorSetLayout(device: c.VkDevice) !c.VkDescriptorSetLayout {
    var binding = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };
    var create_info = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &binding,
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

    var layout_create_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
    };

    var pipeline_layout: c.VkPipelineLayout = undefined;
    try loader.vkCheck(c.vkCreatePipelineLayout(device, &layout_create_info, null, &pipeline_layout));

    var vertex_binding: c.VkVertexInputBindingDescription = .{
        .binding = 0,
        .stride = @sizeOf(c.XrVector4f),
        .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
    };

    var vertex_input: c.VkVertexInputAttributeDescription = .{
        .binding = 0,
        .location = 0,
        .offset = 0,
        .format = c.VK_FORMAT_R32G32B32A32_SFLOAT,
    };

    var vertex_input_stage = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &vertex_binding,
        .vertexAttributeDescriptionCount = 1,
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
        .cullMode = c.VK_CULL_MODE_NONE,
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
    var buffer: c.VkBuffer = undefined;
    try loader.vkCheck(c.vkCreateBuffer(device, &buffer_create_info, null, &buffer));

    var memoryRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, buffer, &memoryRequirements);

    var properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &properties);
    const flags: c.VkMemoryPropertyFlags = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    var memory_type_index: u32 = 0;
    const shiftee: u32 = 1;

    for (0..properties.memoryTypeCount) |i| {
        if ((memoryRequirements.memoryTypeBits & (shiftee << @intCast(i)) == 0) or (properties.memoryTypes[i].propertyFlags & flags) != flags)
            continue;
        memory_type_index = @intCast(i);
        break;
    } else return error.MemoryRequirements;

    var allocate_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = memoryRequirements.size,
        .memoryTypeIndex = memory_type_index,
    };

    var memory: c.VkDeviceMemory = undefined;
    try loader.vkCheck(c.vkAllocateMemory(device, &allocate_info, null, &memory));
    try loader.vkCheck(c.vkBindBufferMemory(device, buffer, memory, 0));

    var mappedData: *anyopaque = undefined;
    try loader.vkCheck(c.vkMapMemory(device, memory, 0, buffer_create_info.size, 0, @ptrCast(&mappedData)));
    const dest_bytes: [*]u8 = @ptrCast(mappedData);
    const src_bytes: [*]const u8 = @ptrCast(data);
    const dest_slice = dest_bytes[0..buffer_create_info.size];
    const src_slice = src_bytes[0..buffer_create_info.size];
    @memcpy(dest_slice, src_slice);

    return .{
        .buffer = buffer,
        .memory = memory,
    };
}
