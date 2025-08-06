const loader = @import("loader");
const std = @import("std");
const xr = @import("openxr.zig");
const c = loader.c;
const nz = @import("numz");
// const f32max = std.math.floatMax(f32);
// const f32abs = std.math.

pub const Block = struct {
    orientation: nz.Vec4(f32) = @splat(0),
    position: nz.Vec3(f32) = @splat(0),
    scale: nz.Vec3(f32) = @splat(0),
    color: nz.Vec4(f32) = @splat(0),
};

// pub fn createActionSpace(session: c.XrSession, action: c.XrAction) !c.XrSpace {
//     var space: c.XrSpace = undefined;

//     var actionSpaceCreateInfo = c.XrActionSpaceCreateInfo{
//         .type = c.XR_TYPE_ACTION_SPACE_CREATE_INFO,
//         .poseInActionSpace = .{
//             .position = .{ .x = 0, .y = 0, .z = 0 },
//             .orientation = .{ .x = 1, .y = 0, .z = 0, .w = 0 },
//         },
//         .action = action,
//     };

//     try loader.xrCheck(c.xrCreateActionSpace(session, &actionSpaceCreateInfo, &space));

//     return space;
// }

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

pub fn pollAction(
    session: c.XrSession,
    actionSet: c.XrActionSet,
    roomSpace: c.XrSpace,
    predictedDisplayTime: c.XrTime,
    m_handPoseAction: c.XrAction,
    m_handGrabAction: c.XrAction,
    m_handPaths: [2]c.XrPath,
    hand_pose_space: [2]c.XrSpace,
    hand_pose_state: *[2]c.XrActionStatePose,
    m_grabState: *[2]c.XrActionStateFloat,
    hand_pose: *[2]c.XrPosef,
) !bool {
    var activeActionSet = c.XrActiveActionSet{
        .actionSet = actionSet,
        .subactionPath = c.XR_NULL_PATH,
    };

    var syncInfo = c.XrActionsSyncInfo{
        .type = c.XR_TYPE_ACTIONS_SYNC_INFO,
        .countActiveActionSets = 1,
        .activeActionSets = &activeActionSet,
    };

    const result: c.XrResult = (c.xrSyncActions(session, &syncInfo));

    if (result == c.XR_SESSION_NOT_FOCUSED) {
        return false;
    } else if (result != c.XR_SUCCESS) {
        std.log.err("Failed to synchronize actions: {any}\n", .{result});
        return true;
    }

    // _ = roomSpace;
    // _ = predictedDisplayTime;
    // _ = leftHandAction;
    // _ = rightHandAction;
    // _ = hand_pose;
    // _ = hand_pose_space;
    // _ = hand_pose_state;
    var actionStateGetInfo: c.XrActionStateGetInfo = .{ .type = c.XR_TYPE_ACTION_STATE_GET_INFO };
    actionStateGetInfo.action = @ptrCast(m_handPoseAction);
    for (0..2) |i| {
        // Specify the subAction Path.
        actionStateGetInfo.subactionPath = m_handPaths[i];
        try loader.xrCheck(c.xrGetActionStatePose(session, &actionStateGetInfo, @ptrCast(&hand_pose_state.*[i])));
        if (hand_pose_state[i].isActive != 0) {
            var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
            const res: c.XrResult = c.xrLocateSpace(hand_pose_space[i], roomSpace, predictedDisplayTime, &spaceLocation);
            if (c.XR_UNQUALIFIED_SUCCESS(res) and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                hand_pose[i] = spaceLocation.pose;
            } else {
                hand_pose_state[i].isActive = 0;
            }
        }
    }

    for (0..2) |i| {
        actionStateGetInfo.action = m_handGrabAction;
        actionStateGetInfo.subactionPath = m_handPaths[i];
        try loader.xrCheck(c.xrGetActionStateFloat(session, &actionStateGetInfo, &m_grabState[i]));
    }

    return false;
}

pub fn blockInteraction(
    grabbed_block: *[2]i32,
    grab_state: [2]c.XrActionStateFloat,
    near_block: *[2]i32,
    hand_pose: [2]c.XrPosef,
    handPoseState: [2]c.XrActionStatePose,
    blocks: std.ArrayList(Block),
) void {
    for (0..2) |i| {
        const hand_pos: nz.Vec3(f32) = .{
            hand_pose[i].position.x,
            hand_pose[i].position.y,
            hand_pose[i].position.z,
        };
        var nearest: f32 = 1.0;
        if (grabbed_block[i] == -1) {
            near_block[i] = -1;
            if (handPoseState[i].isActive != 0) {
                for (0..blocks.items.len) |j| {
                    const block: Block = blocks.items[j];

                    const diff: nz.Vec3(f32) = block.position - hand_pos;
                    const distance: f32 = @max(@abs(diff[0]), @max(@abs(diff[1]), @abs(diff[2])));
                    if (distance < 0.05 and distance < nearest) {
                        near_block[i] = @intCast(j);
                        nearest = distance;
                    }
                }
            }
            if (near_block[i] != -1) {
                if (grab_state[i].isActive != 0 and grab_state[i].currentState > 0.5) {
                    grabbed_block[i] = near_block[i];
                }
            }
        } else {
            near_block[i] = grabbed_block[i];
            if (handPoseState[i].isActive != 0)
                blocks.items[@intCast(grabbed_block[i])].position = hand_pos;
            if (grab_state[i].isActive == 0 or grab_state[i].currentState < 0.5) {
                grabbed_block[i] = -1;
            }
        }
    }
}
