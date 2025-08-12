const loader = @import("loader");
const c = loader.c;

grabbed_block: [2]i32 = .{ -1, -1 },
near_block: [2]i32 = .{ -1, -1 },
grab_state: [2]c.XrActionStateFloat = .{ .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT }, .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT } },
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
hand_pose_state: [2]c.XrActionStatePose = .{
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
    .{ .type = c.XR_TYPE_ACTION_STATE_POSE },
},
