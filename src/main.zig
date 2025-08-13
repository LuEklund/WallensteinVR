const std = @import("std");
const World = @import("ecs.zig").World;
const eng = @import("engine/root.zig");
const game = @import("game/root.zig");
const GfxContext = @import("engine/renderer/Context.zig");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .verbose_log = true }) = .init;
    const smp_allocator = std.heap.smp_allocator;

    const allocator = if (@import("builtin").mode == .Debug)
        debug_allocator.allocator()
    else
        smp_allocator;

    var world: World(
        &[_]type{ eng.RigidBody, eng.Transform, eng.Mesh, game.Hand, eng.Player },
    ) = .init();
    defer world.deinit(allocator);
    //Engine Init
    try world.runSystems(allocator, .{
        eng.Renderer.init,
        eng.Input.init,
        eng.AssetManager.init,
        eng.Renderer.initSwapchains,
    });
    const map = try game.map.initLevel(allocator, 19);
    defer map.deinit(allocator);
    const verices: []f32, const indices: []u32 = try map.toModel(allocator);
    defer allocator.free(verices);
    defer allocator.free(indices);
    const asset_manager = try world.getResource(eng.AssetManager);
    try asset_manager.putModel(
        allocator,
        "world",
        verices,
        indices,
    );
    //Game Init
    try world.runSystems(allocator, .{
        someInitSystem,
        ininitPlayer,
    });

    const io_ctx: *eng.IoCtx = try world.getResource(eng.IoCtx);
    io_ctx.*.player_pos[0] = @floatFromInt(map.start_x);
    io_ctx.*.player_pos[2] = @floatFromInt(map.start_y);
    const ctx: *GfxContext = try world.getResource(GfxContext);
    while (!ctx.should_quit) {
        try world.runSystems(allocator, .{
            eng.Renderer.beginFrame,
            eng.Input.pollEvents,
            playerUpdateSystem,
            someUpdateSystem,
            eng.Renderer.update,
        });
    }
    try world.runSystems(allocator, .{ eng.AssetManager.deinit, eng.Renderer.deinit });
}

pub fn ininitPlayer(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    //PLAYER
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 1, 0 },
            .scale = .{ 1, 1, 1 },
        },
        eng.Player{},
    });
    //HANDS
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, 0 },
            .scale = .{ 0.1, 0.1, 0.1 },
        },
        eng.Mesh{ .name = "basket.obj" },
        game.Hand{ .side = .left },
    });
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, 0 },
            .scale = .{ 0.1, 0.1, 0.1 },
        },
        eng.Mesh{ .name = "cube.obj" },
        game.Hand{ .side = .right },
    });
}

pub fn someInitSystem(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    // for (0..4) |i| {
    //     var fx: f32 = @floatFromInt(i);
    //     fx = fx / 5;
    //     for (0..4) |j| {
    //         var fy: f32 = @floatFromInt(j);
    //         fy = fy / 5;
    //         for (0..4) |k| {
    //             var fz: f32 = @floatFromInt(k);
    //             fz = fz / 5 - 2;
    //             _ = try world.spawn(allocator, .{
    //                 eng.RigidBody{ .force = .{ std.math.sin(fx) / 1000, std.math.cos(fy) / 1000, std.math.tan(fz) / 1000 } },
    //                 eng.Transform{ .position = .{ fx, fy, fz } },
    //                 eng.Mesh{ .name = "basket.obj" },
    //             });
    //         }
    //     }
    // }

    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, -0.5, 0 },
            .scale = .{ 1, 1, 1 },
        },
        eng.Mesh{ .name = "world" },
    });
}

pub fn playerUpdateSystem(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const io_ctx = try world.getResource(eng.IoCtx);
    var query_player = world.query(&.{ eng.Player, eng.Transform });
    while (query_player.next()) |entity| {
        var transform = entity.get(eng.Transform).?;
        if (io_ctx.keyboard.isActive(.w)) transform.position[2] -= 0.016;
        if (io_ctx.keyboard.isActive(.s)) transform.position[2] += 0.016;
        if (io_ctx.keyboard.isActive(.a)) transform.position[0] -= 0.016;
        if (io_ctx.keyboard.isActive(.d)) transform.position[0] += 0.016;
        if (io_ctx.keyboard.isActive(.q)) transform.position[1] -= 0.016;
        if (io_ctx.keyboard.isActive(.e)) transform.position[1] += 0.016;
        if (io_ctx.keyboard.isActive(.left)) transform.rotation[1] -= 0.016;
        if (io_ctx.keyboard.isActive(.right)) transform.rotation[1] += 0.016;
    }

    var query = world.query(&.{ game.Hand, eng.Transform });

    // if (io_ctx.keyboard.isActive(.left)) io_ctx.p += 0.016;
    // if (io_ctx.keyboard.isActive(.right)) io_ctx.player_pos[1] += 0.016;
    // io_ctx.player_pos[0] += io_ctx.trackpad_state[0].currentState.x / 100;
    // io_ctx.player_pos[2] += io_ctx.trackpad_state[0].currentState.y / 100;
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        var transform = entity.get(eng.Transform).?;
        transform.position = @bitCast(io_ctx.hand_pose[@intFromEnum(hand.side)].position);
    }
}

pub fn someUpdateSystem(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var query = world.query(&.{ eng.RigidBody, eng.Transform });
    // _ = query;

    while (query.next()) |entity| {
        const rigid_body = entity.get(eng.RigidBody).?;
        const transform = entity.get(eng.Transform).?;

        // std.debug.print("ID: {d} ", .{entity.id});

        // std.debug.print("Pos! {d} {d} ", .{ p.x, p.y });
        transform.position[0] += rigid_body.force[0] * std.math.sin(transform.position[0]);
        transform.position[1] += rigid_body.force[1] * std.math.sin(transform.position[1]);

        // std.debug.print("Vel! {d} {d}\n", .{ velocity.x, velocity.y });
    }
}
