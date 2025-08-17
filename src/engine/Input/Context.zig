const loader = @import("loader");
const nz = @import("numz");
const c = loader.c;
const sdl = @import("sdl3");

grabbed_block: [2]i32 = .{ -1, -1 },
near_block: [2]i32 = .{ -1, -1 },
trigger_state: [2]c.XrActionStateFloat = .{ .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT }, .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT } },
trackpad_state: [2]c.XrActionStateVector2f = .{ .{ .type = c.XR_TYPE_ACTION_STATE_VECTOR2F }, .{ .type = c.XR_TYPE_ACTION_STATE_VECTOR2F } },
hand_paths: [2]c.XrPath = .{ 0, 0 },
hand_pose_space: [2]c.XrSpace = undefined,
hand_pose: [2]c.XrPosef = .{
    .{
        .orientation = .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        .position = .{ .x = 0.0, .z = 0.0, .y = -100 },
    },
    .{
        .orientation = .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        .position = .{ .x = 0.0, .z = 0.0, .y = -100 },
    },
},
action_set: c.XrActionSet,
palm_pose_action: c.XrAction = undefined,
grab_cube_action: c.XrAction = undefined,
trackpad_action: c.XrAction = undefined,
hand_pose_state: [2]c.XrActionStatePose = .{
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
},
xr_space: c.XrSpace,
xr_views: [2]c.XrView,

keyboard: Keyboard = undefined,

pub const Keyboard = struct {
    active: []const bool = undefined,
    pressed: [512]bool = [_]bool{false} ** 512,
    pub fn isActive(self: *@This(), key: sdl.Scancode) bool {
        return self.active[@intFromEnum(key)];
    }
    pub fn isPressed(self: *@This(), key: sdl.Scancode) bool {
        if (self.pressed[@intFromEnum(key)] == false and self.active[@intFromEnum(key)] == true) {
            self.pressed[@intFromEnum(key)] = true;
            return true;
        } else if (self.pressed[@intFromEnum(key)] == true and self.active[@intFromEnum(key)] == false) {
            self.pressed[@intFromEnum(key)] = false;
        }
        return false;
    }
};
