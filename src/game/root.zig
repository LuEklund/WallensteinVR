const nz = @import("numz");
pub const map = @import("map.zig");

pub const Hand = struct {
    side: enum(usize) { left = 0, right = 1 },
};
