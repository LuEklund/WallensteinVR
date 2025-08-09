const loader = @import("loader");
const std = @import("std");
const xr = @import("openxr.zig");
const c = loader.c;
const nz = @import("numz");
const GFX_Context = @import("Context.zig");

pub fn createActionPoses(xr_instance: c.XrInstance, xr_session: c.XrSession, action: c.XrAction, sub_path: [*:0]const u8) !c.XrSpace {
    var xrSpace: c.XrSpace = undefined;
    const xrPoseIdentity: c.XrPosef = .{
        .orientation = .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 },
        .position = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
    };
    // Create frame of reference for a pose action
    var actionSpaceCI: c.XrActionSpaceCreateInfo = .{
        .type = c.XR_TYPE_ACTION_SPACE_CREATE_INFO,
        .action = action,
        .poseInActionSpace = xrPoseIdentity,
        .subactionPath = try xr.createXrPath(xr_instance, sub_path),
    };
    try loader.xrCheck(c.xrCreateActionSpace(xr_session, &actionSpaceCI, &xrSpace));
    return xrSpace;
}

// pub fn blockInteraction(
//     grabbed_block: *[2]i32,
//     grab_state: [2]c.XrActionStateFloat,
//     near_block: *[2]i32,
//     hand_pose: [2]c.XrPosef,
//     handPoseState: [2]c.XrActionStatePose,
//     blocks: std.ArrayList(Block),
// ) void {
//     for (0..2) |i| {
//         const hand_pos: nz.Vec3(f32) = .{
//             hand_pose[i].position.x,
//             hand_pose[i].position.y,
//             hand_pose[i].position.z,
//         };
//         var nearest: f32 = 1.0;
//         if (grabbed_block[i] == -1) {
//             near_block[i] = -1;
//             if (handPoseState[i].isActive != 0) {
//                 for (0..blocks.items.len) |j| {
//                     const block: Block = blocks.items[j];

//                     const diff: nz.Vec3(f32) = block.position - hand_pos;
//                     const distance: f32 = @max(@abs(diff[0]), @max(@abs(diff[1]), @abs(diff[2])));
//                     if (distance < 0.05 and distance < nearest) {
//                         near_block[i] = @intCast(j);
//                         nearest = distance;
//                     }
//                 }
//             }
//             if (near_block[i] != -1) {
//                 if (grab_state[i].isActive != 0 and grab_state[i].currentState > 0.5) {
//                     grabbed_block[i] = near_block[i];
//                 }
//             }
//         } else {
//             near_block[i] = grabbed_block[i];
//             if (handPoseState[i].isActive != 0)
//                 blocks.items[@intCast(grabbed_block[i])].position = hand_pos;
//             if (grab_state[i].isActive == 0 or grab_state[i].currentState < 0.5) {
//                 grabbed_block[i] = -1;
//             }
//         }
//     }
// }
