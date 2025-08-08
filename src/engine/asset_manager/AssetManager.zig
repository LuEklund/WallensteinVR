const std = @import("std");
const c = @import("loader").c;
const World = @import("../../ecs.zig").World;
const Context = @import("../renderer/Context.zig");
const vk = @import("../renderer/vulkan.zig");

const Obj = @import("Obj.zig");

const Self = @This();

var replacement_model_vertices = [_]f32{
    0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 0: Top-Front-Right
    0.5, 0.5, -0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 1: Top-Back-Right
    0.5, -0.5, 0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 2: Bottom-Front-Right
    0.5, -0.5, -0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 3: Bottom-Back-Right
    -0.5, 0.5, 0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 4: Top-Front-Left
    -0.5, 0.5, -0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 5: Top-Back-Left
    -0.5, -0.5, 0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 6: Bottom-Front-Left
    -0.5, -0.5, -0.5, 1.0, 0.0, 0.0, 1.0, 0.0, // 7: Bottom-Back-Left
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

model_path_list: [][]const u8,
models: std.StringHashMapUnmanaged(Model),
replacement_model: Model,

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
        .replacement_model = undefined,
    };

    asset_manager.replacement_model.vertex_buffer = try vk.createBuffer(
        ctx.vk_physical_device,
        ctx.vk_logical_device,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        @intCast(replacement_model_vertices.len),
        @sizeOf(f32),
        @ptrCast(&replacement_model_vertices),
    );
    asset_manager.replacement_model.index_buffer = try vk.createBuffer(
        ctx.vk_physical_device,
        ctx.vk_logical_device,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        replacement_model_indices.len,
        @sizeOf(u32),
        @ptrCast(&replacement_model_indices),
    );
    asset_manager.replacement_model.index_count = replacement_model_indices.len;

    for (asset_manager.model_path_list) |path| {
        const local_path = try std.fs.path.join(allocator, &.{ model_dir_path, path });
        const obj = try Obj.init(allocator, local_path);
        defer obj.deinit(allocator);

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

pub fn getModel(self: Self, asset_name: []const u8) Model {
    return self.models.get(asset_name) orelse self.replacement_model;
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
