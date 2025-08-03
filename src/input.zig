const loader = @import("loader");
const std = @import("std");
const xr = @import("openxr.zig");
const c = loader.c;
// const f32max = std.math.floatMax(f32);
// const f32abs = std.math.

pub const Block = struct {
    orientation: c.XrQuaternionf = std.mem.zeroes(c.XrQuaternionf),
    position: c.XrVector3f = std.mem.zeroes(c.XrVector3f),
    scale: c.XrVector3f = std.mem.zeroes(c.XrVector3f),
    color: c.XrVector3f = std.mem.zeroes(c.XrVector3f),
};

pub fn pollAction(
    session: c.XrSession,
    actionSet: c.XrActionSet,
    roomSpace: c.XrSpace,
    predictedDisplayTime: c.XrTime,
    leftHandAction: c.XrAction,
    rightHandAction: c.XrAction,
    leftGrabAction: c.XrAction,
    rightGrabAction: c.XrAction,
    m_handPaths: [2]c.XrPath,
    hand_pose_space: [2]c.XrSpace,
    hand_pose_state: *[2]c.XrActionStatePose,
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

    var actionStateGetInfo: c.XrActionStateGetInfo = .{ .type = c.XR_TYPE_ACTION_STATE_GET_INFO };
    var pose_action_array: [2]c.XrAction = undefined;
    pose_action_array[0] = leftHandAction;
    pose_action_array[1] = rightHandAction;
    actionStateGetInfo.action = @ptrCast(&pose_action_array);
    for (0..2) |i| {
        // Specify the subAction Path.
        actionStateGetInfo.subactionPath = m_handPaths[i];
        try loader.xrCheck(c.xrGetActionStatePose(session, &actionStateGetInfo, @ptrCast(&hand_pose_state[i])));
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
    // const leftHand: c.XrPosef = try xr.getActionPose(session, leftHandAction, leftHandSpace, roomSpace, predictedDisplayTime);
    // const rightHand: c.XrPosef = try xr.getActionPose(session, rightHandAction, rightHandSpace, roomSpace, predictedDisplayTime);
    _ = try xr.getActionBoolean(
        session,
        leftGrabAction,
        m_handPaths[0],
    );
    _ = try xr.getActionBoolean(
        session,
        rightGrabAction,
        m_handPaths[1],
    );
    // std.debug.print("\n\n=========[RIGHT: {any}]===========\n\n", .{rightHand});
    // std.debug.print("\n\n=========[LEFT: {any}]===========\n\n", .{leftHand});

    return false;
}

pub fn blockInteraction(
    grabbed_block: [2]u32,
    grab_state: [2]c.XrActionStateBoolean,
    near_block: [2]u32,
    hand_pose: [2]c.XrSpace,
    handPoseState: [2]c.XrSpace,
    blocks: std.ArrayList(Block),
) void {
    for (0..2) |i| {
        var nearest: f32 = 1.0;
        if (grabbed_block[i] == -1) {
            near_block[i] = -1;
            if (handPoseState[i].isActive) {
                for (0..blocks.len) |j| {
                    const block: Block = blocks[j];
                    const diff: c.XrVector3f = block.pose.position - hand_pose[j].position;
                    const distance: f32 = @max(@abs(diff.x), @max(@abs(diff.y), @abs(diff.z)));
                    if (distance < 0.05 and distance < nearest) {
                        near_block[i] = j;
                        nearest = distance;
                    }
                }
            }
            if (near_block[i] != -1) {
                if (grab_state[i].isActive and grab_state[i].currentState == true) {
                    grabbed_block[i] = near_block[i];
                }
            }
        } else {
            near_block[i] = grabbed_block[i];
            if (handPoseState[i].isActive)
                blocks[grabbed_block[i]].pose.position = hand_pose[i].position;
            if (!grab_state[i].isActive || grab_state[i].currentState < 0.5) {
                grabbed_block[i] = -1;
            }
        }
    }
}
