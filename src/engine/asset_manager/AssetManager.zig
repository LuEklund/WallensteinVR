const std = @import("std");
const c = @import("loader").c;
const World = @import("../../ecs.zig").World;
const Context = @import("../renderer/renderer.zig").Context;
const vk = @import("../renderer/vulkan.zig");

const Obj = @import("Obj.zig");

const Self = @This();

model_path_list: [][]const u8,
models: std.StringHashMapUnmanaged(Model),

pub const Model = struct {
    vertex_buffer: vk.VulkanBuffer,
    index_buffer: vk.VulkanBuffer,
    index_count: u32,
};

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const ctx = try world.getResource(Context);
    const model_dir_path = "../../assets/models"; // assets/models
    // const texture_paths = findAssetsFromDir(allocator, "assets/textures", ".png");
    // defer allocator.free(texture_paths);

    const model_paths = try findAssetsFromDir(allocator, model_dir_path, ".obj");
    // defer allocator.free(model_paths);

    const asset_manager = try allocator.create(Self);
    asset_manager.* = .{
        .models = .empty,
        .model_path_list = model_paths,
    };

    std.debug.print("PATHS :.{any}\n", .{model_paths});
    for (asset_manager.model_path_list) |path| {
        std.debug.print("PATH :.{any}\n", .{path});
        const local_path = try std.fs.path.join(allocator, &.{ model_dir_path, path });
        std.debug.print("LOCAL_PATH :.{s}\n", .{local_path});
        const obj = try Obj.init(allocator, local_path);
        defer obj.deinit(allocator);

        std.debug.print("\n\nOBJ len {any}\n\n", .{obj.vertices.len});
        const vertex_buffer = try vk.createBuffer(
            ctx.vk_physical_device,
            ctx.vk_logical_device,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            @intCast(obj.vertices.len),
            @sizeOf(f32),
            obj.vertices.ptr,
        );
        const index_buffer = try vk.createBuffer(
            ctx.vk_physical_device,
            ctx.vk_logical_device,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            @intCast(obj.indices.len),
            @sizeOf(u32),
            obj.indices.ptr,
        );

        const model: Model = .{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .index_count = @intCast(obj.indices.len),
        };
        try asset_manager.models.put(allocator, path, model);
    }

    try world.setResource(allocator, Self, asset_manager);
}

pub fn deinit(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const asset_manager = try world.getResource(Self);
    defer allocator.destroy(asset_manager);
}

pub fn findAssetsFromDir(
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
            // cheesecake saves the day again
            errdefer allocator.free(name);
            std.debug.print("APPEND :.{s}\n", .{name});
            try assets.append(allocator, name);
        }
    }
    // done
    const slice = try assets.toOwnedSlice(allocator);
    assets.items = &.{}; // to prevent double-free probably idk i am writing this blindly i have no idea what i am doing
    return slice;
}
