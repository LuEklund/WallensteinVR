const std = @import("std");
const loader = @import("loader");
const c = loader.c;
const sdl = @import("sdl3");
const GFX_Context = @import("../renderer/Context.zig");
const World = @import("../../ecs.zig").World;

// pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.allocator) !void {}
pub fn pollEvents(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var ctx = try world.getResource(GFX_Context);

    std.debug.print("\n\n=========[Polling Events]===========\n\n", .{});

    while (sdl.events.poll()) |sdl_event| {
        switch (sdl_event) {
            // .quit =>
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
                if (key.key == .escape) {
                    ctx.should_quit = true;
                }
            },
            else => {},
        }
    }

    _ = try pollAction(ctx); //TODO  QUit app
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
    ctx: *GFX_Context,
) !bool {
    var activeActionSet = c.XrActiveActionSet{
        .actionSet = ctx.action_set,
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
    actionStateGetInfo.action = @ptrCast(ctx.palm_pose_action);
    for (0..2) |i| {
        // Specify the subAction Path.
        actionStateGetInfo.subactionPath = ctx.hand_paths[i];
        try loader.xrCheck(c.xrGetActionStatePose(ctx.xr_session, &actionStateGetInfo, @ptrCast(&ctx.hand_pose_state[i])));
        if (ctx.hand_pose_state[i].isActive != 0) {
            var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
            const res: c.XrResult = c.xrLocateSpace(ctx.hand_pose_space[i], ctx.xr_space, ctx.predicted_time_frame, &spaceLocation);
            if (c.XR_UNQUALIFIED_SUCCESS(res) and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                ctx.hand_pose[i] = spaceLocation.pose;
            } else {
                ctx.hand_pose_state[i].isActive = 0;
            }
        }
    }

    for (0..2) |i| {
        actionStateGetInfo.action = ctx.grab_cube_action;
        actionStateGetInfo.subactionPath = ctx.hand_paths[i];
        try loader.xrCheck(c.xrGetActionStateFloat(ctx.xr_session, &actionStateGetInfo, &ctx.grab_state[i]));
    }

    return false;
}
