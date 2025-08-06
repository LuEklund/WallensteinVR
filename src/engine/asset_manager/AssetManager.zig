const std = @import("std");
const c = @import("loader").c;
const World = @import("../../ecs.zig").World;
const Context = @import("../renderer/renderer.zig").Context;
const vk = @import("../renderer/vulkan.zig");

const Obj = @import("Obj.zig");

const Self = @This();

// models: std.StringHashMapUnmanaged(Model) = .empty,
model: Model, //TODO : REMOVE

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
    defer allocator.free(model_paths);

    const asset_manager = try allocator.create(Self);

    for (model_paths) |path| {
        var buffer: [64]u8 = undefined;
        const local_path = try std.fmt.bufPrint(&buffer, model_dir_path ++ "/{s}", .{path});
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

        // try asset_manager.models.put(
        //     allocator,
        //     path,
        //     .{
        //         .vertex_buffer = vertex_buffer,
        //         .index_buffer = index_buffer,
        //         .index_count = @intCast(obj.indices.len),
        //     },
        // );
        asset_manager.model = .{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .index_count = @intCast(obj.indices.len),
        };
        break; // TODO: REMOVE DO ALL
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
            try assets.append(allocator, entry.name);
        }
    }

    return assets.toOwnedSlice(allocator);
}
