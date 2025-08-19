const std = @import("std");
const loader = @import("loader");
const c = loader.c;
const sdl = @import("sdl3");
const GfxContext = @import("../renderer/Context.zig");
const IoCtx = @import("Context.zig");
const World = @import("../../ecs.zig").World;
const xr = @import("../renderer/openxr.zig");

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const gfx_ctx = try world.getResource(GfxContext);

    const action_set: c.XrActionSet = try xr.createActionSet(gfx_ctx.xr_instance);
    var paths: std.ArrayListUnmanaged([*:0]const u8) = .empty;
    try paths.append(allocator, "/user/hand/left");
    try paths.append(allocator, "/user/hand/right");
    defer paths.deinit(allocator);
    const palm_pose_action = try xr.createAction(gfx_ctx.xr_instance, action_set, "palm-pose", c.XR_ACTION_TYPE_POSE_INPUT, paths);
    const grab_cube_action = try xr.createAction(gfx_ctx.xr_instance, action_set, "grab-cube", c.XR_ACTION_TYPE_FLOAT_INPUT, paths);
    const trackpad_action = try xr.createAction(gfx_ctx.xr_instance, action_set, "trackpad-2d", c.XR_ACTION_TYPE_VECTOR2F_INPUT, paths);

    const hand_paths_l = try xr.createXrPath(gfx_ctx.xr_instance, "/user/hand/left".ptr);
    const hand_paths_r = try xr.createXrPath(gfx_ctx.xr_instance, "/user/hand/right".ptr);

    const suggested_bindings = [_]c.XrActionSuggestedBinding{
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, palm_pose_action, "/user/hand/left/input/grip/pose"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, palm_pose_action, "/user/hand/right/input/grip/pose"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, grab_cube_action, "/user/hand/left/input/select/click"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, grab_cube_action, "/user/hand/right/input/select/click"),
    };
    try xr.suggestBindings(
        gfx_ctx.xr_instance,
        try xr.getPath(gfx_ctx.xr_instance, "/interaction_profiles/khr/simple_controller"),
        &suggested_bindings,
    );
    const suggested_bindings_vive = [_]c.XrActionSuggestedBinding{
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, palm_pose_action, "/user/hand/left/input/grip/pose"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, palm_pose_action, "/user/hand/right/input/grip/pose"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, grab_cube_action, "/user/hand/left/input/trigger/click"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, grab_cube_action, "/user/hand/right/input/trigger/click"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, trackpad_action, "/user/hand/left/input/trackpad"),
        try xr.createSuggestedBinding(gfx_ctx.xr_instance, trackpad_action, "/user/hand/right/input/trackpad"),
    };
    try xr.suggestBindings(
        gfx_ctx.xr_instance,
        try xr.getPath(gfx_ctx.xr_instance, "/interaction_profiles/htc/vive_controller"),
        &suggested_bindings_vive,
    );
    const hand_pose_space_l = try xr.createActionPoses(gfx_ctx.xr_instance, gfx_ctx.xr_session, palm_pose_action, "/user/hand/left");
    const hand_pose_space_r = try xr.createActionPoses(gfx_ctx.xr_instance, gfx_ctx.xr_session, palm_pose_action, "/user/hand/right");
    try xr.attachActionSet(gfx_ctx.xr_session, action_set);
    const space: c.XrSpace = try xr.createSpace(gfx_ctx.xr_session);

    const context = try allocator.create(IoCtx);
    context.* = .{
        .action_set = action_set,
        .grab_cube_action = grab_cube_action,
        .palm_pose_action = palm_pose_action,
        .hand_paths = .{
            hand_paths_l,
            hand_paths_r,
        },
        .hand_pose_space = .{
            hand_pose_space_l,
            hand_pose_space_r,
        },
        .trackpad_action = trackpad_action,
        .xr_views = undefined,
        .xr_space = space,
    };
    try world.setResource(allocator, IoCtx, context);
}
pub fn pollEvents(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var ctx = try world.getResource(GfxContext);
    var io_ctx = try world.getResource(IoCtx);

    // std.debug.print("\n\n=========[Polling Events]===========\n\n", .{});

    while (sdl.events.poll()) |sdl_event| {
        switch (sdl_event) {
            .quit, .terminating => if (@import("builtin").mode == .Debug) @panic("debug force close"), // This is a bad solution but god damn i want to close the stuff
            .window_resized => |wr| {
                try ctx.vk_swapchain.recreate(
                    ctx.spectator_view.sdl_surface,
                    ctx.vk_physical_device,
                    ctx.command_pool,
                    &ctx.image_index,
                    @intCast(wr.width),
                    @intCast(wr.height),
                );
            },
            .key_down => |key| {
                switch (key.key.?) {
                    .escape => ctx.should_quit = true,
                    else => {},
                }
            },
            else => {},
        }
    }

    io_ctx.keyboard.active = sdl.keyboard.getState();

    _ = try pollAction(ctx, io_ctx); //TODO  QUit app
}

// pub fn deint() !void {}
pub fn recordCurrentBindings(xr_session: c.XrSession, xr_instance: c.XrInstance) !void {
    var hand_paths: [2]c.XrPath = .{ 0, 0 };
    try loader.xrCheck(c.xrStringToPath(
        xr_instance,
        "/user/hand/left",
        @ptrCast(&hand_paths[0]),
    ));
    try loader.xrCheck(c.xrStringToPath(
        xr_instance,
        "/user/hand/right",
        @ptrCast(&hand_paths[1]),
    ));

    std.debug.print("\nstr: {d}\n", .{hand_paths[0]});
    std.debug.print("\nstr: {d}\n", .{hand_paths[1]});

    var strl: u32 = 0;
    var text: [c.XR_MAX_PATH_LENGTH]u8 = undefined;
    var interactionProfile: c.XrInteractionProfileState = .{
        .type = c.XR_TYPE_INTERACTION_PROFILE_STATE,
        .interactionProfile = 0,
        .next = null,
    };

    try loader.xrCheck(
        c.xrGetCurrentInteractionProfile(
            xr_session,
            hand_paths[0],
            &interactionProfile,
        ),
    );
    if (interactionProfile.interactionProfile != c.XR_NULL_HANDLE) {
        try loader.xrCheck(c.xrPathToString(
            xr_instance,
            interactionProfile.interactionProfile,
            text.len,
            &strl,
            &text[0],
        ));
        std.debug.print("\n\n====[LEFT]]=====\n\n", .{});
        std.debug.print("user/hand/left ActiveProfile : {any}", .{text});
    } else std.debug.print("\noh shit\n", .{});
    try loader.xrCheck(
        c.xrGetCurrentInteractionProfile(
            xr_session,
            hand_paths[1],
            &interactionProfile,
        ),
    );
    if (interactionProfile.interactionProfile != c.XR_NULL_HANDLE) {
        try loader.xrCheck(c.xrPathToString(
            xr_instance,
            interactionProfile.interactionProfile,
            text.len,
            &strl,
            &text[0],
        ));
        std.debug.print("\n\n====[RIGHT]=====\n\n", .{});
        std.debug.print("user/hand/right ActiveProfile : {any}", .{text});
    } else std.debug.print("\noh shit\n", .{});
}

pub fn pollAction(
    ctx: *GfxContext,
    io_ctx: *IoCtx,
) !bool {
    var activeActionSet = c.XrActiveActionSet{
        .actionSet = io_ctx.action_set,
        .subactionPath = c.XR_NULL_PATH,
    };

    var syncInfo = c.XrActionsSyncInfo{
        .type = c.XR_TYPE_ACTIONS_SYNC_INFO,
        .countActiveActionSets = 1,
        .activeActionSets = &activeActionSet,
    };

    const result: c.XrResult = (c.xrSyncActions(ctx.xr_session, &syncInfo));

    if (result == c.XR_SESSION_NOT_FOCUSED) {
        return false;
    } else if (result != c.XR_SUCCESS) {
        std.log.err("Failed to synchronize actions: {any}\n", .{result});
        return true;
    }

    var actionStateGetInfo: c.XrActionStateGetInfo = .{ .type = c.XR_TYPE_ACTION_STATE_GET_INFO };
    actionStateGetInfo.action = @ptrCast(io_ctx.palm_pose_action);
    for (0..2) |i| {
        // Specify the subAction Path.
        actionStateGetInfo.subactionPath = io_ctx.hand_paths[i];
        try loader.xrCheck(c.xrGetActionStatePose(ctx.xr_session, &actionStateGetInfo, @ptrCast(&io_ctx.hand_pose_state[i])));
        if (io_ctx.hand_pose_state[i].isActive != 0) {
            var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
            const res: c.XrResult = c.xrLocateSpace(io_ctx.hand_pose_space[i], io_ctx.xr_space, ctx.predicted_time_frame, &spaceLocation);
            if (c.XR_UNQUALIFIED_SUCCESS(res) and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                io_ctx.hand_pose[i] = spaceLocation.pose;
            } else {
                io_ctx.hand_pose_state[i].isActive = 0;
            }
        }
    }

    for (0..2) |i| {
        actionStateGetInfo.action = io_ctx.grab_cube_action;
        actionStateGetInfo.subactionPath = io_ctx.hand_paths[i];
        try loader.xrCheck(c.xrGetActionStateFloat(ctx.xr_session, &actionStateGetInfo, &io_ctx.trigger_state[i]));
        // if (io_ctx.grab_state[i].isActive != 0) {
        //     std.debug.print("\ngrab : {any}\n", .{io_ctx.grab_state[i].currentState});
        // }
    }

    for (0..2) |i| {
        actionStateGetInfo.action = io_ctx.trackpad_action;
        actionStateGetInfo.subactionPath = io_ctx.hand_paths[i];
        try loader.xrCheck(c.xrGetActionStateVector2f(ctx.xr_session, &actionStateGetInfo, &io_ctx.trackpad_state[i]));
        // if (io_ctx.trackpad_state[i].isActive != 0) {
        // std.debug.print("\nTrackpad pos: {d}, {d}\n", .{
        //     io_ctx.trackpad_state[i].currentState.x,
        //     io_ctx.trackpad_state[i].currentState.y,
        // });
        // }
    }

    var view_locate_info = c.XrViewLocateInfo{
        .type = c.XR_TYPE_VIEW_LOCATE_INFO,
        .viewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
        .displayTime = ctx.predicted_time_frame,
        .space = io_ctx.xr_space,
        .next = null,
    };

    var view_state = c.XrViewState{
        .type = c.XR_TYPE_VIEW_STATE,
        .next = null,
    };

    var view_count: u32 = 2;
    var views: [2]c.XrView = .{ .{
        .type = c.XR_TYPE_VIEW,
        .next = null,
    }, .{
        .type = c.XR_TYPE_VIEW,
        .next = null,
    } };

    try loader.xrCheck(c.xrLocateViews(
        ctx.xr_session,
        &view_locate_info,
        &view_state,
        view_count,
        &view_count,
        @ptrCast(&views[0]),
    ));
    io_ctx.xr_views = views;

    return false;
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
