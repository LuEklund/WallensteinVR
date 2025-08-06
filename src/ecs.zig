const std = @import("std");

pub fn World(comps: []const type) type {
    const fields: [comps.len]std.builtin.Type.StructField = comptime blk: {
        var result: [comps.len]std.builtin.Type.StructField = undefined;
        for (comps, 0..) |T, i| {
            const Type = std.AutoHashMapUnmanaged(u32, T);
            result[i] = std.builtin.Type.StructField{
                .name = @typeName(T),
                .type = Type,
                .default_value_ptr = null,
                .alignment = @alignOf(Type),
                .is_comptime = false,
            };
        }
        break :blk result;
    };

    const ComponentsLayout = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });

    return struct {
        const Self = @This();

        layout: ComponentsLayout,
        resources: std.StringHashMapUnmanaged(*anyopaque),

        next_id: u32 = 0,

        pub fn init() Self {
            var comps_layout: ComponentsLayout = undefined;

            inline for (comps) |T| {
                const field_name = @typeName(T);
                const field_ptr = &@field(comps_layout, field_name);
                field_ptr.* = .empty;
            }

            return .{ .layout = comps_layout, .resources = .empty };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            inline for (comps) |T| {
                @field(self.layout, @typeName(T)).deinit(allocator);
            }
        }

        pub fn runSystems(self: *Self, allocator: std.mem.Allocator, systems: anytype) !void {
            const SystemsType = @TypeOf(systems);
            const systems_type_info = @typeInfo(SystemsType);
            if (systems_type_info != .@"struct") {
                @compileError("expected tuple or struct argument, found " ++ @typeName(SystemsType));
            }
            inline for (systems_type_info.@"struct".fields) |field| {
                try @call(.auto, @as(*const fn ([]const type, *Self, std.mem.Allocator) anyerror!void, @ptrCast(field.default_value_ptr.?)), .{ comps, self, allocator });
            }
        }

        pub fn spawn(self: *Self, allocator: std.mem.Allocator, data: anytype) !u32 {
            const entity_id: u32 = self.next_id;
            self.next_id += 1;

            inline for (data) |entry| {
                const T = @TypeOf(entry);
                const map = &@field(self.layout, @typeName(T));
                try map.put(allocator, entity_id, entry);
            }

            return entity_id;
        }

        pub fn query(self: *Self, search: []const type) Query(search) {
            return .init(self);
        }

        pub fn Query(search: []const type) type {
            return struct {
                world: *World(comps),
                iter: std.AutoHashMapUnmanaged(u32, search[0]).Iterator,

                pub fn init(world: *World(comps)) @This() {
                    return .{
                        .world = world,
                        .iter = @field(world.layout, @typeName(search[0])).iterator(),
                    };
                }

                pub fn next(self: *@This()) ?Entry {
                    blk: while (self.iter.next()) |entry| {
                        const id = entry.key_ptr.*;

                        var components: [search.len]*anyopaque = undefined;
                        inline for (search, 0..) |T, i| {
                            const map: std.AutoHashMapUnmanaged(u32, T) = @field(self.world.layout, @typeName(T));
                            const ptr = map.getPtr(id) orelse continue :blk;
                            components[i] = ptr;
                        }

                        return .{ .id = id, .components = components };
                    }
                    return null;
                }

                pub const Entry = struct {
                    id: u32,
                    components: [search.len]*anyopaque,

                    pub fn get(self: Entry, comptime T: type) ?*T {
                        return inline for (search, 0..) |ST, i| {
                            if (ST == T) break @ptrCast(@alignCast(self.components[i]));
                        } else null;
                    }
                };
            };
        } // bro how deeply is this nested 💔💔

        pub inline fn setResource(self: *Self, allocator: std.mem.Allocator, comptime Key: type, val: *Key) !void {
            try self.resources.put(allocator, @typeName(Key), @ptrCast(val));
        }

        pub inline fn getResource(self: *Self, comptime Key: type) !*Key {
            const ctx = self.resources.get(@typeName(Key));
            if (ctx != null) return @ptrCast(@alignCast(ctx)) else return error.ResourceNotFound;
        } // We get seg faults when we store an opaque like c.VkInstance u32 and other primitives work fine so idk
    };
}
