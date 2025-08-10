const std = @import("std");

pub const Tilemap = struct {
    const Self = @This();

    tiles: []u8,
    x: usize,
    y: usize,

    pub fn init(allocator: std.mem.Allocator, x: usize, y: usize) !Self {
        const tiles: []u8 = try allocator.alloc(u8, x * y);
        @memset(tiles, 1);

        return .{ .tiles = tiles, .x = x, .y = y };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.tiles);
    }

    pub fn get(self: Self, x: usize, y: usize) u8 {
        const index = (y * self.x) + x;
        return self.tiles[index];
    }

    pub fn set(self: Self, x: usize, y: usize, tile: u8) void {
        const index = (y * self.x) + x;
        self.tiles[index] = tile;
    }

    pub fn spawnWalker(self: Self, random: std.Random, iterations: ?usize) void {
        var x: usize = random.int(usize) % self.x;
        var y: usize = random.int(usize) % self.y;

        const start_x = x;
        const start_y = y;
        defer self.set(start_x, start_y, 254);

        const i = if (iterations) |i| i else std.math.clamp(random.int(usize), 200, 10000);
        std.debug.print("ITS {d}\n", .{i});
        for (0..i) |_| {
            const decision: u8 = random.int(u8) % 4;
            switch (decision) {
                0 => x += 1,
                1 => y += 1,
                2 => x -= 1,
                3 => y -= 1,
                else => unreachable,
            }

            x = std.math.clamp(x, 1, self.x - 2);
            y = std.math.clamp(y, 1, self.y - 2);

            self.set(x, y, 0);
        }

        self.set(x, y, 255);
    }

    pub fn gridSpawn(self: Self, distance: usize, offset: usize, tile: u8) void {
        for (0..@divFloor(self.x - offset, distance)) |x| {
            for (0..@divFloor(self.y - offset, distance)) |y| {
                if (self.get(x * distance + offset, y * distance + offset) == 0)
                    self.set(x * distance + offset, y * distance + offset, tile);
            }
        }
    }

    pub fn print(self: Self) void {
        for (self.tiles, 0..) |tile, i| {
            if (i > 0 and i % self.x == 0) {
                std.debug.print("\x1b[0m\n", .{});
            }

            const color: struct { u8, u8, u8 } = switch (tile) {
                0 => .{ 0, 0, 0 }, // Air
                1 => .{ 0, 100, 0 }, // Basic wall
                200 => .{ 255, 0, 0 }, // Enemy spawn
                254 => .{ 255, 255, 255 }, // Spawn
                255 => .{ 255, 215, 0 }, // Goal
                else => unreachable,
            };

            std.debug.print("\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m██", .{ color.@"0", color.@"1", color.@"2", color.@"0", color.@"1", color.@"2" });
        }

        std.debug.print("\x1b[0m\n", .{});
    }
};
