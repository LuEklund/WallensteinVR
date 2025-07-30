const std = @import("std");
const log = std.log;

const loader = @import("loader");
const c = loader.c;

const XrSwapchain = @This();

swapchain: c.XrSwapchain,
depth_swapchain: c.XrSwapchain,
format: c.VkFormat,
sample_count: u32,
width: u32,
height: u32,

// Same as createSwapchains
pub fn init(eye_count: comptime_int, instance: c.XrInstance, system_id: c.XrSystemId, session: c.XrSession) !@This() {
    var config_views = [_]c.XrViewConfigurationView{
        .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW },
    } ** eye_count;

    var config_view_count: u32 = eye_count;
    try loader.xrCheck(c.xrEnumerateViewConfigurationViews(instance, system_id, c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO, config_view_count, &config_view_count, &config_views[0]));

    var format_count: u32 = 0;
    try loader.xrCheck(c.xrEnumerateSwapchainFormats(session, 0, &format_count, null));
    if (format_count > 16) @panic("More than 16 VkFormats\n");

    var formats: [16]i64 = undefined;
    try loader.xrCheck(c.xrEnumerateSwapchainFormats(session, format_count, &format_count, &formats[0]));

    var color_fotmat: i64 = undefined;
    for (formats) |fmt| {
        if (fmt == c.VK_FORMAT_R8G8B8A8_SRGB) {
            color_fotmat = fmt;
            break;
        }
    } else {
        @panic("Did not find supported color format\n");
    }

    var depth_fotmat: i64 = undefined;
    for (formats) |fmt| {
        if (fmt == c.VK_FORMAT_D32_SFLOAT) {
            depth_fotmat = fmt;
            break;
        }
    } else {
        @panic("Did not find supported Depth format\n");
    }

    var swapchain_create_info = c.XrSwapchainCreateInfo{
        .type = c.XR_TYPE_SWAPCHAIN_CREATE_INFO,
        .usageFlags = c.XR_SWAPCHAIN_USAGE_SAMPLED_BIT | c.XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT,
        .format = color_fotmat,
        .sampleCount = config_views[0].recommendedSwapchainSampleCount,
        .width = config_views[0].recommendedImageRectWidth,
        .height = config_views[0].recommendedImageRectHeight,
        .faceCount = 1,
        .arraySize = eye_count,
        .mipCount = 1,
    };
    var swapchain: c.XrSwapchain = undefined;
    try loader.xrCheck(c.xrCreateSwapchain(session, &swapchain_create_info, &swapchain));

    swapchain_create_info = c.XrSwapchainCreateInfo{
        .type = c.XR_TYPE_SWAPCHAIN_CREATE_INFO,
        .usageFlags = c.XR_SWAPCHAIN_USAGE_SAMPLED_BIT | c.XR_SWAPCHAIN_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
        .format = depth_fotmat,
        .sampleCount = config_views[0].recommendedSwapchainSampleCount,
        .width = config_views[0].recommendedImageRectWidth,
        .height = config_views[0].recommendedImageRectHeight,
        .faceCount = 1,
        .arraySize = eye_count,
        .mipCount = 1,
    };
    var depth_swapchain: c.XrSwapchain = undefined;
    try loader.xrCheck(c.xrCreateSwapchain(session, &swapchain_create_info, &depth_swapchain));

    return .{
        .swapchain = swapchain,
        .depth_swapchain = depth_swapchain,
        .format = @intCast(color_fotmat),
        .sample_count = config_views[0].recommendedSwapchainSampleCount,
        .width = config_views[0].recommendedImageRectWidth,
        .height = config_views[0].recommendedImageRectHeight,
    };
}

pub fn createSwapchainImages(self: @This(), allocator: std.mem.Allocator) ![]c.XrSwapchainImageVulkanKHR {
    var image_count: u32 = undefined;
    try loader.xrCheck(c.xrEnumerateSwapchainImages(self.swapchain, 0, &image_count, null));

    var images = try allocator.alloc(c.XrSwapchainImageVulkanKHR, image_count);
    @memset(images, .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_VULKAN_KHR });

    try loader.xrCheck(c.xrEnumerateSwapchainImages(self.swapchain, image_count, &image_count, @ptrCast(&images[0])));

    return images;
}

// NOTE: Named SwapchainImage in the toutorial
pub const SwapchainImage = struct {
    const Self = @This();

    device: c.VkDevice,
    command_pool: c.VkCommandPool,
    descriptor_pool: c.VkDescriptorPool,

    image: c.XrSwapchainImageVulkanKHR,
    vk_dup_image: c.VkImage,
    vk_image_memory: c.VkDeviceMemory,
    image_view: c.VkImageView,
    framebuffer: c.VkFramebuffer,
    memory: c.VkDeviceMemory,
    buffer: c.VkBuffer,
    command_buffer: c.VkCommandBuffer,
    descriptor_set: c.VkDescriptorSet,

    pub fn init(
        physical_device: c.VkPhysicalDevice,
        device: c.VkDevice,
        render_pass: c.VkRenderPass,
        command_pool: c.VkCommandPool,
        descriptor_pool: c.VkDescriptorPool,
        descriptor_set_layout: c.VkDescriptorSetLayout,
        swapchain: XrSwapchain,
        image: c.XrSwapchainImageVulkanKHR,
    ) !Self {
        var image_view_create_info = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = image.image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D_ARRAY,
            .format = swapchain.format,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 2, //<-- eye count
            },
        };

        var image_view: c.VkImageView = undefined;
        try loader.vkCheck(c.vkCreateImageView(device, &image_view_create_info, null, &image_view));

        var framebuffer_create_info = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = render_pass,
            .attachmentCount = 1,
            .pAttachments = &image_view,
            .width = swapchain.width,
            .height = swapchain.height,
            .layers = 1,
        };

        var framebuffer: c.VkFramebuffer = undefined;
        try loader.vkCheck(c.vkCreateFramebuffer(device, &framebuffer_create_info, null, &framebuffer));

        var create_info = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = @sizeOf(f32) * 4 * 4 * 5, // :NOTE Matrix(f32)[4][4] * 5
            .usage = c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        };

        var buffer: c.VkBuffer = undefined;
        try loader.vkCheck(c.vkCreateBuffer(device, &create_info, null, &buffer));

        var requirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(device, buffer, &requirements);

        const flags: c.VkMemoryPropertyFlags = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;

        var properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(physical_device, &properties);

        var memory_type_index: u32 = 0;
        const shiftee: u32 = 1;

        for (0..properties.memoryTypeCount) |i| {
            if ((requirements.memoryTypeBits & (shiftee << @intCast(i)) == 0)) {
                continue;
            }
            if ((properties.memoryTypes[i].propertyFlags & flags) != flags) {
                continue;
            }
            memory_type_index = @intCast(i);
            break;
        }

        var allocate_info = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: c.VkDeviceMemory = undefined;
        try loader.vkCheck(c.vkAllocateMemory(device, &allocate_info, null, &memory));

        try loader.vkCheck(c.vkBindBufferMemory(device, buffer, memory, 0));

        var command_buffer_allocate_info = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };

        var command_buffer: c.VkCommandBuffer = undefined;
        try loader.vkCheck(c.vkAllocateCommandBuffers(device, &command_buffer_allocate_info, &command_buffer));

        var descriptor_set_allocate_info = c.VkDescriptorSetAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = descriptor_pool,
            .descriptorSetCount = 1,
            .pSetLayouts = &descriptor_set_layout,
        };

        var descriptor_set: c.VkDescriptorSet = undefined;
        try loader.vkCheck(c.vkAllocateDescriptorSets(device, &descriptor_set_allocate_info, &descriptor_set));

        var descriptor_buffer_info = c.VkDescriptorBufferInfo{
            .buffer = buffer,
            .offset = 0,
            .range = c.VK_WHOLE_SIZE,
        };

        var descriptor_write = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptor_set,
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorCount = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .pBufferInfo = &descriptor_buffer_info,
        };

        c.vkUpdateDescriptorSets(device, 1, &descriptor_write, 0, null);

        var imageCreateInfo: c.VkImageCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .imageType = c.VK_IMAGE_TYPE_2D,
            .extent = .{ .width = swapchain.width, .height = swapchain.height, .depth = 1 },
            .mipLevels = 1,
            .arrayLayers = 1,
            .format = swapchain.format,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .tiling = c.VK_IMAGE_TILING_OPTIMAL,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
            .usage = c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        };

        var vk_image: c.VkImage = undefined;
        try loader.vkCheck(c.vkCreateImage(device, &imageCreateInfo, null, &vk_image));
        var image_requirements: c.VkMemoryRequirements = undefined;
        c.vkGetImageMemoryRequirements(device, vk_image, &image_requirements);

        const image_memory_properties_flags: c.VkMemoryPropertyFlags = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

        var image_memory_type_index: u32 = 0;
        c.vkGetPhysicalDeviceMemoryProperties(physical_device, &properties);

        var found_image_memory_type = false;
        for (0..properties.memoryTypeCount) |i| {
            if ((image_requirements.memoryTypeBits & (shiftee << @intCast(i))) == 0) {
                continue;
            }
            if ((properties.memoryTypes[i].propertyFlags & image_memory_properties_flags) != image_memory_properties_flags) {
                continue;
            }
            image_memory_type_index = @intCast(i);
            found_image_memory_type = true;
            break;
        }
        if (!found_image_memory_type) {
            std.log.err("Failed to find suitable memory type for vk_dup_image!", .{});
            return error.NoSuitableImageMemory;
        }
        var image_allocate_info = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = image_requirements.size,
            .memoryTypeIndex = image_memory_type_index,
        };

        var image_memory: c.VkDeviceMemory = undefined;
        try loader.vkCheck(c.vkAllocateMemory(device, &image_allocate_info, null, &image_memory));

        try loader.vkCheck(c.vkBindImageMemory(device, vk_image, image_memory, 0));
        return .{
            .device = device,
            .command_pool = command_pool,
            .descriptor_pool = descriptor_pool,
            .image = image,
            .vk_dup_image = vk_image,
            .vk_image_memory = image_memory,
            .image_view = image_view,
            .framebuffer = framebuffer,
            .memory = memory,
            .buffer = buffer,
            .command_buffer = command_buffer,
            .descriptor_set = descriptor_set,
        };
    }

    pub fn deinit(self: Self) void {
        std.debug.print("Destroyed SwapChainImage\n", .{});
        _ = c.vkFreeDescriptorSets(self.device, self.descriptor_pool, 1, &self.descriptor_set);
        std.debug.print("INFO : {any}\n", .{self.command_buffer});
        c.vkFreeCommandBuffers(self.device, self.command_pool, 1, &self.command_buffer);
        c.vkDestroyBuffer(self.device, self.buffer, null);
        c.vkFreeMemory(self.device, self.memory, null);
        c.vkDestroyFramebuffer(self.device, self.framebuffer, null);
        c.vkDestroyImageView(self.device, self.image_view, null);
        c.vkDestroyImage(self.device, self.vk_dup_image, null);
    }
};
