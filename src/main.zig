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

        &[_]type{
            eng.RigidBody,
            eng.Transform,
            eng.Mesh,
            game.Hand,
            eng.Player,
            eng.Enemy,
            eng.Texture,
            eng.BBAA,
            game.Bullet,
            game.collectable,
            game.Door,
        },
    ) = .init();
    defer world.deinit(allocator);

    try world.runSystems(allocator, .{
        eng.init,
        game.init,
    });

    var map = try game.map.init(allocator, null);
    defer map.deinit(allocator);
    try world.setResource(allocator, game.map.Tilemap, &map);
    const verices: []f32, const indices: []u32 = try map.toModel(allocator);
    defer allocator.free(verices);
    defer allocator.free(indices);
    const asset_manager = try world.getResource(eng.AssetManager);

    var player_query = world.query(&.{ eng.Player, eng.Transform });
    const player = player_query.next().?;
    var player_transform = player.get(eng.Transform).?;
    player_transform.position[0] = @floatFromInt(map.start_x);
    player_transform.position[2] = @floatFromInt(map.start_y);

    _ = try world.spawn(allocator, &.{
        eng.Transform{ .position = .{
            @floatFromInt(map.end_x),
            1,
            @floatFromInt(map.end_y),
        }, .scale = @splat(0.5) },
        eng.Mesh{},
        eng.Texture{},
        game.collectable{},
    });

    try asset_manager.putModel(
        allocator,
        "world",
        verices,
        indices,
    );

    const ctx: *GfxContext = try world.getResource(GfxContext);
    try asset_manager.getSound("windows-xp-startup.wav").play(0.1);
    while (!ctx.should_quit) {
        try world.runSystems(allocator, .{
            eng.update,
            game.update,
        });
    }
    try world.runSystems(allocator, .{
        eng.deinit,
        game.deinit,
    });
}
