const std = @import("std");

const Self = @This();

vertices: []f32,
indices: []u32,

pub fn init(
    allocator: std.mem.Allocator,
    path: []const u8,
) !Self {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const tok_buffer = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    var lines = std.mem.tokenizeAny(u8, tok_buffer, "\n");

    var positions: std.ArrayListUnmanaged(f32) = .empty;
    defer positions.deinit(allocator);
    var uvs: std.ArrayListUnmanaged(f32) = .empty;
    defer uvs.deinit(allocator);
    var normals: std.ArrayListUnmanaged(f32) = .empty;
    defer normals.deinit(allocator);

    var vertices: std.ArrayListUnmanaged(f32) = .empty;
    var indices: std.ArrayListUnmanaged(u32) = .empty;

    var vertex_count: u32 = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        switch (line[0]) {
            'v' => {
                if (line.len < 2) continue;

                var array: *std.ArrayListUnmanaged(f32) = switch (line[1]) {
                    ' ' => &positions,
                    't' => &uvs,
                    'n' => &normals,
                    else => continue,
                };

                var parts = std.mem.splitAny(u8, line[2..], " ");
                while (parts.next()) |part| {
                    const trimmed = std.mem.trim(u8, part, "\n\r\t ");
                    if (trimmed.len == 0) continue;
                    try array.append(allocator, try std.fmt.parseFloat(f32, trimmed));
                }
            },

            'f' => {
                var face_vertices: std.ArrayListUnmanaged(u32) = .empty;
                defer face_vertices.deinit(allocator);

                var faces = std.mem.splitAny(u8, line[2..], " ");
                while (faces.next()) |face| {
                    if (face.len == 0) continue;

                    var it = std.mem.splitAny(u8, face, "/");

                    const position_idx = try std.fmt.parseInt(usize, std.mem.trim(u8, it.next().?, " \n\r\t"), 10) - 1;
                    if (position_idx * 3 + 2 >= positions.items.len) return error.InvalidIndex;

                    try vertices.appendSlice(allocator, &.{
                        positions.items[position_idx * 3 + 0],
                        positions.items[position_idx * 3 + 1],
                        positions.items[position_idx * 3 + 2],
                    });

                    if (it.next()) |uv| {
                        const trimmed_uv = std.mem.trim(u8, uv, " \n\r\t");
                        if (trimmed_uv.len > 0) {
                            const uv_idx = try std.fmt.parseInt(usize, trimmed_uv, 10) - 1;
                            if (uv_idx * 2 + 1 >= uvs.items.len) return error.InvalidIndex;

                            try vertices.appendSlice(allocator, &.{
                                uvs.items[uv_idx * 2 + 0],
                                uvs.items[uv_idx * 2 + 1],
                            });
                        } else try vertices.appendSlice(allocator, &.{ 0, 0 });
                    } else try vertices.appendSlice(allocator, &.{ 0, 0 });

                    if (it.next()) |normal| {
                        const normal_idx = try std.fmt.parseInt(usize, std.mem.trim(u8, normal, " \n\r\t"), 10) - 1;
                        if (normal_idx * 3 + 2 >= normals.items.len) return error.InvalidIndex;

                        try vertices.appendSlice(allocator, &.{
                            normals.items[normal_idx * 3 + 0],
                            normals.items[normal_idx * 3 + 1],
                            normals.items[normal_idx * 3 + 2],
                        });
                    } else try vertices.appendSlice(allocator, &.{ 0, 1, 0 });

                    try face_vertices.append(allocator, vertex_count);
                    vertex_count += 1;
                }

                if (face_vertices.items.len >= 3) {
                    for (1..face_vertices.items.len - 1) |i| {
                        try indices.appendSlice(allocator, &.{
                            face_vertices.items[0],
                            face_vertices.items[i],
                            face_vertices.items[i + 1],
                        });
                    }
                }
            },

            else => {},
        }
    }

    return .{
        .vertices = try vertices.toOwnedSlice(allocator),
        .indices = try indices.toOwnedSlice(allocator),
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self.indices);
    allocator.free(self.vertices);
}
