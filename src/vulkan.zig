const std = @import("std");
const log = std.log;

const c = @import("c.zig");

export fn debugCallback(
    message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.C) c.VkBool32 {
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

fn createInstance(graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, extensions: []const [:0]const u8) !c.VkInstance {
    const validation_layers = &[_][:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    const debug_info = c.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = debugCallback,
        .pUserData = null,
    };

    var create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = &debug_info,
        .ppEnabledExtensionNames = @ptrCast(&extensions),
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledLayerNames = @ptrCast(&validation_layers),
        .enabledLayerCount = @intCast(validation_layers.len),

        .pApplicationInfo = &.{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "WallensteinVR",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "WallensteinVR_Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_MAKE_API_VERSION(
                0,
                c.XR_VERSION_MAJOR(graphics_requirements.minApiVersionSupported),
                c.XR_VERSION_MINOR(graphics_requirements.minApiVersionSupported),
                0,
            ),
        },
    };

    var instance: c.VkInstance = undefined;
    try c.check(
        c.vkCreateInstance(&create_info, null, &instance),
        error.CreateInstance,
    );
    return instance;
}

pub fn createLogicalDevice(physical_device: c.VkPhysicalDevice) !c.VkDevice {
    const indices = findGraphicsQueueFamily(physical_device);
    if (indices == null) return error.MissingGraphicsQueue;

    var queue_priority: f32 = 1.0;
    const queue_info = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .queueFamilyIndex = indices.?,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
        .flags = 0,
    };

    const features = c.VkPhysicalDeviceFeatures{};

    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
        .pEnabledFeatures = &features,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .flags = 0,
    };

    var logical_device: c.VkDevice = undefined;
    try c.check(
        c.vkCreateDevice(physical_device, &device_info, null, &logical_device),
        error.CreateDevice,
    );

    return logical_device;
}

// NOTE: Not needed since physical device is supplied from OpenXR
// fn selectPhysicalDevice(instance: c.VkInstance) !c.VkPhysicalDevice {
//     var device_count: u32 = 0;
//     try c.check(
//         c.vkEnumeratePhysicalDevices(instance, &device_count, null),
//         error.EnumeratePhysicalDevicesCount,
//     );
//     if (device_count == 0) return error.NoPhysicalDevicesFound;

//     var devices: [8]c.VkPhysicalDevice = undefined;
//     try c.check(
//         c.vkEnumeratePhysicalDevices(instance, &device_count, &devices),
//         error.EnumeratePhysicalDevices,
//     );

//     for (devices[0..device_count], 0..) |device, i| {
//         var props: c.VkPhysicalDeviceProperties = undefined;
//         var feats: c.VkPhysicalDeviceFeatures = undefined;

//         c.vkGetPhysicalDeviceProperties(device, &props);
//         c.vkGetPhysicalDeviceFeatures(device, &feats);

//         log.info("Device {}: {s}", .{ i, props.deviceName });

//         if (props.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU and
//             feats.geometryShader == c.VK_TRUE)
//         {
//             log.info("Selected GPU: {s}", .{props.deviceName});
//             return device;
//         }
//     }

//     return error.NoSuitablePhysicalDevice;
// }

fn findGraphicsQueueFamily(physical: c.VkPhysicalDevice) ?u32 {
    var count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical, &count, null);

    var props: [16]c.VkQueueFamilyProperties = undefined;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical, &count, &props);

    for (props[0..count], 0..) |qf, i| {
        if (qf.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0)
            return @intCast(i);
    }

    return null;
}

pub fn createRenderPass(device: c.VkDevice, format: c.VkFormat) !c.VkRenderPass {
    var attachment = c.VkAttachmentDescription{
        .format = format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
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

    var create_info = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .flags = 0,
        .attachmentCount = 1,
        .pAttachments = &attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
    };

    var render_pass: c.VkRenderPass = undefined;
    try c.vkCheck(
        c.vkCreateRenderPass(device, &create_info, null, &render_pass),
        error.CreateRenderPass,
    );

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

    try c.vkCheck(
        c.vkCreateDescriptorPool(device, &create_info, null, &descriptor_pool),
        error.CreateDescriptorPool,
    );

    return descriptor_pool;
}

pub fn createDescriptorSetLayout(device: c.VkDevice) c.VkDescriptorSetLayout {
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
    try c.vkCheck(
        c.vkCreateDescriptorSetLayout(device, &create_info, null, &descriptor_set_layout),
        error.CreateDescriptorSetLayout,
    );

    return descriptor_set_layout;
}

pub fn createShader(allocator: std.mem.Allocator, device: c.VkDevice, file_path: []const u8) !c.VkShaderModule {
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));

    var shader_create_info = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = source,
        .pCode = source,
    };

    var shader: c.VkShaderModule = undefined;
    try c.vkCheck(
        c.vkCreateShaderModule(device, &shader_create_info, null, &shader),
        error.CreateShaderModule,
    );

    return shader;
}

pub fn createPipeline(device: c.VkDevice, render_pass: c.VkRenderPass, descriptor_set_layout: c.VkDescriptorSetLayout, vertex_shader: c.VkShaderModule, fragment_shader: c.VkShaderModule) struct { c.VkPipelineLayout, c.VkPipeline } {
    var pipeline: c.VkPipeline = undefined;

    var layout_create_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
    };

    var pipeline_layout: c.VkPipelineLayout = undefined;
    try c.vkCheck(
        c.vkCreatePipelineLayout(device, &layout_create_info, null, &pipeline_layout),
        error.CreatePipelineLayout,
    );

    var vertex_input_stage = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
    };

    var input_assembly_stage = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = false,
    };

    const vertex_shader_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertex_shader,
        .pName = "main",
    };

    var viewport = c.VkViewport{ 0, 0, 1024, 1024, 0, 1 };

    var scissor = c.VkRect2D{ .{ 0, 0 }, .{ 1024, 1024 } };

    var viewport_stage = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    };

    var rasterization_stage = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = false,
        .rasterizerDiscardEnable = false,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1,
        .cullMode = c.VK_CULL_MODE_NONE,
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        .depthBiasEnable = false,
        .depthBiasConstantFactor = 0,
        .depthBiasClamp = 0,
        .depthBiasSlopeFactor = 0,
    };

    var multisample_stage = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .sampleShadingEnable = false,
        .minSampleShading = 0.25,
    };

    var depth_stencil_stage = c.VkPipelineDepthStencilStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = true,
        .depthWriteEnable = true,
        .depthCompareOp = c.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = false,
        .minDepthBounds = 0,
        .maxDepthBounds = 1,
        .stencilTestEnable = false,
    };

    const fragment_shader_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragment_shader,
        .pName = "main",
    };

    var color_blend_attachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = true,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    var color_blend_stage = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = false,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
        .blendConstants = [4]f32{ 0, 0, 0, 0 },
    };

    const dynamic_states = [_]c.VkDynamicState{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR };

    var dynamic_state = c.VkPipelineDynamicStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = 2,
        .pDynamicStates = dynamic_states,
    };

    const shader_stages = []c.VkPipelineShaderStageCreateInfo{ vertex_shader_stage, fragment_shader_stage };

    var create_info = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = shader_stages,
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
        .basePipelineHandle = c.VK_NULL_HANDLE,
        .basePipelineIndex = -1,
    };

    try c.vkCheck(
        c.vkCreateGraphicsPipelines(device, null, 1, &create_info, null, &pipeline),
        error.CreateGraphicsPipelines,
    );

    return .{ pipeline_layout, pipeline };
}
