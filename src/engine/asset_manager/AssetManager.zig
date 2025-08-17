const std = @import("std");
const c = @import("loader").c;
const World = @import("../../ecs.zig").World;
const Context = @import("../renderer/Context.zig");
const vk = @import("../renderer/vulkan.zig");
const audio = @import("audio.zig");

const Obj = @import("Obj.zig");

const Self = @This();

var replacement_model_vertices = [_]f32{
    // pos.x pos.y pos.z   u    v     nx   ny   nz
    // 0: Top-Front-Right
    0.5,  0.5,  0.5,  1.0, 0.0, 0.0, 0.0, 1.0,
    // 1: Top-Back-Right
    0.5,  0.5,  -0.5, 0.0, 0.0, 0.0, 0.0, -1.0,
    // 2: Bottom-Front-Right
    0.5,  -0.5, 0.5,  1.0, 1.0, 0.0, 0.0, 1.0,
    // 3: Bottom-Back-Right
    0.5,  -0.5, -0.5, 0.0, 1.0, 0.0, 0.0, -1.0,
    // 4: Top-Front-Left
    -0.5, 0.5,  0.5,  0.0, 0.0, 0.0, 0.0, 1.0,
    // 5: Top-Back-Left
    -0.5, 0.5,  -0.5, 1.0, 0.0, 0.0, 0.0, -1.0,
    // 6: Bottom-Front-Left
    -0.5, -0.5, 0.5,  0.0, 1.0, 0.0, 0.0, 1.0,
    // 7: Bottom-Back-Left
    -0.5, -0.5, -0.5, 1.0, 1.0, 0.0, 0.0, -1.0,
};

var replacement_model_indices = [_]u32{
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

var replacement_texture_pixels = [_]u32{
    0xFFFF00FF, 0xFF000000, 0xFF000000, 0xFFFF00FF, 0xFFFF00FF, 0xFF000000, 0xFF000000, 0xFFFF00FF,
    0xFF000000, 0xFFFF00FF, 0xFF000000, 0xFFFF00FF, 0xFFFF00FF, 0xFF000000, 0xFFFF00FF, 0xFF000000,
    0xFF000000, 0xFF000000, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFF000000, 0xFF000000,
    0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF,
    0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF,
    0xFF000000, 0xFF000000, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFFFF00FF, 0xFF000000, 0xFF000000,
    0xFF000000, 0xFFFF00FF, 0xFF000000, 0xFFFF00FF, 0xFFFF00FF, 0xFF000000, 0xFFFF00FF, 0xFF000000,
    0xFFFF00FF, 0xFF000000, 0xFF000000, 0xFFFF00FF, 0xFFFF00FF, 0xFF000000, 0xFF000000, 0xFFFF00FF,
};
ctx: *Context,
audio_device: audio.Device,

models: std.StringHashMapUnmanaged(Model),
textures: std.StringHashMapUnmanaged(Texture),
sounds: std.StringHashMapUnmanaged(audio.Sound),

replacement_model: Model,

pub const Model = struct {
    vertex_buffer: vk.VulkanBuffer,
    index_buffer: vk.VulkanBuffer,
    index_count: u32,
};

pub const Texture = struct {
    staging_buffer: vk.VulkanBuffer,
    image_buffer: vk.VulkanImageBuffer,
    texture_image_view: c.VkImageView,
    texture_sample: c.VkSampler,
};

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const ctx = try world.getResource(Context);

    const asset_manager = try allocator.create(Self);
    asset_manager.* = .{
        .ctx = ctx,
        .models = .empty,
        .textures = .empty,
        .sounds = .empty,
        .replacement_model = undefined,
        .audio_device = try .init(),
    };

    try asset_manager.loadModels(allocator, ctx);
    try asset_manager.loadTextures(allocator, ctx);
    try asset_manager.loadSounds(allocator);

    try world.setResource(allocator, Self, asset_manager);

    // @panic("\nLOL\n");
}

pub fn loadSounds(asset_manager: *Self, allocator: std.mem.Allocator) !void {
    const sound_files = try findAssetsFromDir(allocator, "../../assets/sounds", ".wav");
    defer allocator.free(sound_files);

    for (sound_files) |file| {
        const path = try std.fs.path.join(allocator, &.{ "../../assets/sounds", file });

        std.debug.print("PATH: {s}\n", .{path});
        try asset_manager.sounds.put(allocator, file, try .init(asset_manager.audio_device, @ptrCast(path)));
    }
}

pub fn deinit(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const asset_manager = try world.getResource(Self);
    defer allocator.destroy(asset_manager);
}

pub fn loadModels(asset_manager: *Self, allocator: std.mem.Allocator, ctx: *Context) !void {
    const dir_path = "../../assets/models"; // assets/models
    const paths = try findAssetsFromDir(allocator, "../../assets/models", ".obj");

    asset_manager.replacement_model = try createModelFromBuffers(
        ctx.vk_physical_device,
        ctx.vk_logical_device,
        &replacement_model_vertices,
        &replacement_model_indices,
    );

    for (paths) |path| {
        const local_path = try std.fs.path.join(allocator, &.{ dir_path, path });
        const obj = try Obj.init(allocator, local_path);
        defer obj.deinit(allocator);

        const model = try createModelFromBuffers(
            ctx.vk_physical_device,
            ctx.vk_logical_device,
            obj.vertices,
            obj.indices,
        );
        try asset_manager.models.put(allocator, path, model);
    }
}

pub fn createModelFromBuffers(physical_device: c.VkPhysicalDevice, logical_device: c.VkDevice, vertices: []f32, indices: []u32) !Model {
    const vertex_buffer = try vk.createBuffer(
        physical_device,
        logical_device,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        @intCast(vertices.len),
        @sizeOf(f32),
        vertices.ptr,
    );
    const index_buffer = try vk.createBuffer(
        physical_device,
        logical_device,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        @intCast(indices.len),
        @sizeOf(u32),
        indices.ptr,
    );
    return .{
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .index_count = @intCast(indices.len),
    };
}

pub fn loadTextures(asset_manager: *Self, allocator: std.mem.Allocator, ctx: *Context) !void {
    try asset_manager.textures.put(
        allocator,
        "default",
        try createTextureFromBuffer(ctx, @ptrCast(replacement_texture_pixels[0..].ptr), 8, 8),
    );
    const dir_path = "../../assets/textures"; // assets/textures
    const paths = try findAssetsFromDir(allocator, dir_path, ".jpg");
    for (paths) |path| {
        const local_path_z = try std.fs.path.joinZ(allocator, &.{ dir_path, path });
        defer allocator.free(local_path_z);
        const file = std.fs.cwd().openFile(local_path_z, .{}) catch |err| {
            if (err == error.FileNotFound) {
                std.log.err("Texture '{s}' not found", .{local_path_z});
                return;
            }
            return err;
        };
        file.close();

        const surface1: *c.SDL_Surface = c.IMG_Load(local_path_z.ptr) orelse {
            const err = c.SDL_GetError();
            std.debug.print("sdl error {s}\n", .{std.mem.span(err)});
            return error.FailedToLoadImage;
        };
        const surface: *c.SDL_Surface = c.SDL_ConvertSurface(surface1, c.SDL_PIXELFORMAT_ABGR8888);
        std.debug.print("\nLoad Texture: {s}, width: {d}, height: {d}, format: {d}\n", .{ local_path_z, surface.*.w, surface.*.h, surface.*.format });

        try asset_manager.textures.put(
            allocator,
            path,
            try createTextureFromBuffer(ctx, surface.pixels.?, @intCast(surface.w), @intCast(surface.h)),
        );
    }
    std.debug.print("\nASSETS: {any}\n", .{asset_manager.textures});
    // if (true) @panic("XDDDD");
}

fn createTextureFromBuffer(ctx: *Context, pixels: *anyopaque, width: u32, heigth: u32) !Texture {
    const texture_buffer = try vk.createBuffer(
        ctx.vk_physical_device,
        ctx.vk_logical_device,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        width * heigth,
        @sizeOf(u32),
        pixels,
    );
    const image_buffer = try vk.createImage(
        ctx.vk_physical_device,
        ctx.vk_logical_device,
        width,
        heigth,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | c.VK_IMAGE_USAGE_SAMPLED_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );

    try vk.transitionImageLayout(
        ctx.vk_logical_device,
        ctx.vk_queue,
        ctx.command_pool,
        image_buffer.texture_image,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    );
    try vk.copyBufferToImage(
        ctx.vk_logical_device,
        ctx.vk_queue,
        ctx.command_pool,
        texture_buffer.buffer,
        image_buffer.texture_image,
        width,
        heigth,
    );
    try vk.transitionImageLayout(
        ctx.vk_logical_device,
        ctx.vk_queue,
        ctx.command_pool,
        image_buffer.texture_image,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    );

    const texture_image_view = try vk.createImageView(
        ctx.vk_logical_device,
        image_buffer.texture_image,
        c.VK_IMAGE_VIEW_TYPE_2D,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_ASPECT_COLOR_BIT,
        1,
    );

    const texture_sample = try vk.createTextureSampler(
        ctx.vk_physical_device,
        ctx.vk_logical_device,
    );

    return .{
        .staging_buffer = texture_buffer,
        .image_buffer = image_buffer,
        .texture_image_view = texture_image_view,
        .texture_sample = texture_sample,
    };
}

pub fn getModel(self: Self, asset_name: []const u8) Model {
    return self.models.get(asset_name) orelse self.replacement_model;
}

pub fn putModel(self: *Self, allocator: std.mem.Allocator, key: []const u8, vertices: []f32, indices: []u32) !void {
    const model = try createModelFromBuffers(
        self.ctx.vk_physical_device,
        self.ctx.vk_logical_device,
        vertices,
        indices,
    );
    try self.models.put(allocator, key, model);
}

// lucas read this while i am trying to find the is https://zig.news/kristoff/dont-self-simple-structs-fj8

pub fn getTexture(self: Self, asset_name: []const u8) Texture {
    return self.textures.get(asset_name) orelse @panic("TEXTURE NOT FOUND");
}

pub fn getSound(self: Self, sound_name: []const u8) audio.Sound {
    return self.sounds.get(sound_name) orelse @panic("SOUND NOT FOUND");
}

fn findAssetsFromDir(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    /// Should be an extension like ".obj" for "model.obj"
    extension: []const u8,
) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var assets: std.ArrayListUnmanaged([]const u8) = .empty;

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .file and std.mem.eql(u8, std.fs.path.extension(entry.name), extension)) {
            const name = try allocator.dupe(u8, entry.name);
            errdefer allocator.free(name);
            try assets.append(allocator, name);
        }
    }
    const slice = try assets.toOwnedSlice(allocator);
    assets.items = &.{}; // to prevent double-free probably idk i am writing this blindly i have no idea what i am doing
    return slice;
}
