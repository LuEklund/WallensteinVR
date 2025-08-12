const std = @import("std");
const log = std.log;

const loader = @import("loader");
const c = loader.c;
const vk = @import("vulkan.zig");

const VulkanSwapchain = @This();

device: c.VkDevice,
swapchain: c.VkSwapchainKHR,
swapchain_images: [16]SwapchainImage,
vk_image_views: [16]c.VkImageView,
vk_images: [16]c.VkImage,
image_count: u32,
format: c.VkFormat,
width: u32,
height: u32,

pub fn init(physical_device: c.VkPhysicalDevice, device: c.VkDevice, surface: c.VkSurfaceKHR, width: u32, height: u32) !@This() {
    var swapchain: c.VkSwapchainKHR = undefined;

    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    loader.vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &capabilities)) catch {
        std.log.err("\n\nMEGA ERR\n\n", .{});
        return error.aaa;
    };

    var formatCount: u32 = 0;
    try loader.vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &formatCount, null));

    var formats: [16]c.VkSurfaceFormatKHR = undefined;
    try loader.vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &formatCount, &formats[0]));

    var chosenFormat: c.VkSurfaceFormatKHR = formats[0];
    for (0..formatCount) |i| {
        if (formats[i].format == c.VK_FORMAT_R8G8B8A8_SRGB) {
            chosenFormat = formats[i];
            break;
        }
    }

    var createInfo: c.VkSwapchainCreateInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = capabilities.minImageCount,
        .imageFormat = chosenFormat.format,
        .imageColorSpace = chosenFormat.colorSpace,
        .imageExtent = .{ .width = width, .height = height },
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = c.VK_PRESENT_MODE_IMMEDIATE_KHR, //TODO: MAILBOX
        .clipped = 1,
    };

    try loader.vkCheck(c.vkCreateSwapchainKHR(device, &createInfo, null, &swapchain));

    return .{
        .device = device,
        .swapchain = swapchain,
        .swapchain_images = undefined,
        .vk_image_views = undefined,
        .vk_images = undefined,
        .image_count = undefined,
        .format = chosenFormat.format,
        .width = width,
        .height = height,
    };
}

pub fn deinit(
    self: @This(),
) void {
    c.vkDestroySwapchainKHR(self.device, self.swapchain, null);
}

pub fn createSwapchainImages(
    self: *@This(),
    command_pool: c.VkCommandPool,
) !void {
    try loader.vkCheck(c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &self.image_count, null));
    if (self.image_count > 16) @panic("More than 16 VkImages\n");

    try loader.vkCheck(c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &self.image_count, &self.vk_images[0]));

    for (0..self.image_count) |i| {
        var view_create_info: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = self.vk_images[i],
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = self.format,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        try loader.vkCheck(c.vkCreateImageView(self.device, &view_create_info, null, &self.vk_image_views[i]));
        self.swapchain_images[i] = try .init(self.device, command_pool, self.vk_images[i]);
    }
}

pub fn recreate(
    self: *@This(),
    surface: c.VkSurfaceKHR,
    physical_device: c.VkPhysicalDevice,
    command_pool: c.VkCommandPool,
    image_index: *u32,
    width: u32,
    height: u32,
) !void {
    try loader.vkCheck(c.vkDeviceWaitIdle(self.device));

    for (0..self.image_count) |i| {
        self.swapchain_images[i].deinit(self.device, command_pool);
    }

    self.deinit();
    self.* = try init(physical_device, self.device, surface, width, height);

    try self.createSwapchainImages(command_pool);

    image_index.* = 0;
}

pub const SwapchainImage = struct {
    image: c.VkImage,
    command_buffer: c.VkCommandBuffer,
    render_done_semaphore: c.VkSemaphore,

    pub fn init(device: c.VkDevice, command_pool: c.VkCommandPool, image: c.VkImage) !@This() {
        var command_buffer: c.VkCommandBuffer = undefined;
        try vk.createCommandBuffers(device, command_pool, 1, &command_buffer);

        var semaphoreCreateInfo: c.VkSemaphoreCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };

        var render_done_semaphore: c.VkSemaphore = undefined;
        try loader.vkCheck(c.vkCreateSemaphore(device, &semaphoreCreateInfo, null, &render_done_semaphore));

        return .{
            .image = image,
            .command_buffer = command_buffer,
            .render_done_semaphore = render_done_semaphore,
        };
    }

    pub fn deinit(self: @This(), device: c.VkDevice, command_pool: c.VkCommandPool) void {
        c.vkDestroySemaphore(device, self.render_done_semaphore, null);
        c.vkFreeCommandBuffers(device, command_pool, 1, &self.command_buffer);
    }
};
