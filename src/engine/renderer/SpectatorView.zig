const std = @import("std");
const loader = @import("loader");
const c = loader.c;
const sdl = @import("sdl3");
const SpectatorView = @This();
const renderer = @import("renderer.zig");
const VulkanSwapchain = @import("VulkanSwapchain.zig");

sdl_surface: c.VkSurfaceKHR = undefined,
sdl_window: sdl.video.Window = undefined,

pub fn init(vulkan_instance: c.VkInstance, hight: usize, width: usize) !@This() {
    const init_flags: sdl.InitFlags = .{ .video = true, .events = true };
    try sdl.init(init_flags);
    const window: sdl.video.Window = try .init("Hello SDL3", width, hight, .{ .vulkan = true, .resizable = true });
    const vk_exts = try sdl.vulkan.getInstanceExtensions();
    for (0..vk_exts.len) |i| {
        std.debug.print("EXT_SDL: {s}\n", .{vk_exts[i]});
    }
    const sdl_surface = sdl.vulkan.Surface.init(window, @ptrCast(vulkan_instance), null) catch |err| {
        std.debug.print("SDL Error: {s}\n", .{sdl.c.SDL_GetError()});
        return err;
    };
    return .{
        .sdl_surface = @ptrCast(sdl_surface.surface),
        .sdl_window = window,
    };
}
pub fn deinit() !void {}
pub fn update(
    self: @This(),
    ctx: *renderer.Context,
) !void {
    while (sdl.events.poll()) |sdl_event| {
        switch (sdl_event) {
            // .quit =>
            .window_resized => |wr| {
                try ctx.vk_swapchain.recreate(
                    self.sdl_surface,
                    ctx.vk_physical_device,
                    ctx.command_pool,
                    &ctx.image_index,
                    @intCast(wr.width),
                    @intCast(wr.height),
                );
            },
            // .key_down => |key| {
            //     if (key.key == .escape) {
            //         quit.store(true, .release);
            //     }
            // },
            else => {},
        }
    }
    const vkResult = c.vkAcquireNextImageKHR(
        ctx.vk_logical_device,
        ctx.vk_swapchain.swapchain,
        0,
        null,
        ctx.vk_fence,
        &ctx.image_index,
    );

    if (vkResult == c.VK_ERROR_OUT_OF_DATE_KHR or vkResult == c.VK_SUBOPTIMAL_KHR) {
        const win_size = try ctx.spectator_view.sdl_window.getSize();

        try ctx.vk_swapchain.recreate(
            ctx.spectator_view.sdl_surface,
            ctx.vk_physical_device,
            ctx.command_pool,
            &ctx.image_index,
            @intCast(win_size.width),
            @intCast(win_size.height),
        );
    } else if (vkResult == c.VK_SUCCESS) {
        try loader.vkCheck(c.vkWaitForFences(
            ctx.vk_logical_device,
            1,
            &ctx.vk_fence,
            1,
            std.math.maxInt(u8),
        ));
        try loader.vkCheck(c.vkResetFences(
            ctx.vk_logical_device,
            1,
            &ctx.vk_fence,
        ));

        const element: VulkanSwapchain.SwapchainImage = ctx.vk_swapchain.swapchain_images[ctx.image_index];
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
                .{ .x = @intCast(ctx.xr_swapchain.width), .y = @intCast(ctx.xr_swapchain.height), .z = 1 },
            },
            .dstSubresource = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .dstOffsets = .{
                .{ .x = 0, .y = 0, .z = 0 },
                .{ .x = @intCast(ctx.vk_swapchain.width), .y = @intCast(ctx.vk_swapchain.height), .z = 1 },
            },
        };

        c.vkCmdBlitImage(
            element.command_buffer,
            ctx.xr_swapchain.swapchain_images[ctx.last_rendered_image_index].vk_dup_image,
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

        try loader.vkCheck(c.vkQueueSubmit(ctx.vk_queue, 1, &submitInfo, null));

        var presentInfo: c.VkPresentInfoKHR = .{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &element.render_done_semaphore,
            .swapchainCount = 1,
            .pSwapchains = &ctx.vk_swapchain.swapchain,
            .pImageIndices = &ctx.image_index,
        };

        const vk_result: c.VkResult = c.vkQueuePresentKHR(ctx.vk_queue, &presentInfo);

        if (vk_result == c.VK_ERROR_OUT_OF_DATE_KHR or vk_result == c.VK_SUBOPTIMAL_KHR) {
            const win_size = try ctx.spectator_view.sdl_window.getSize();
            try ctx.vk_swapchain.recreate(
                ctx.spectator_view.sdl_surface,
                ctx.vk_physical_device,
                ctx.command_pool,
                &ctx.image_index,
                @intCast(win_size.width),
                @intCast(win_size.height),
            );
        } else if (vk_result > 0) {
            std.log.err("Failed to present Vulkan queue: {any}\n", .{vk_result});
        }
    } else if (vkResult != c.VK_TIMEOUT) {
        std.log.err("Failed to acquire next Vulkan swapchain image:{any}\n", .{vkResult});
    }
}
