const std = @import("std");
const c = @import("sdl3").c;

pub fn sdlCheck(result: anytype) !void {
    if (!switch (@typeInfo(@TypeOf(result))) {
        .bool => !result,
        .optional => result == null,
        else => @compileError("unsupported type for sdl check"),
    }) return;

    @import("std").log.err("sdl: {s}\n", .{c.SDL_GetError()});
    return error.Sdl;
}

pub const Device = struct {
    id: c.SDL_AudioDeviceID,

    pub fn init() !@This() {
        const device_id = c.SDL_OpenAudioDevice(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, null);
        try sdlCheck(device_id != 0);
        return .{ .id = device_id };
    }

    pub fn deinit(self: @This()) void {
        c.SDL_CloseAudioDevice(self.id);
    }
};

pub const Sound = struct {
    device: Device,
    spec: c.SDL_AudioSpec,
    stream: *c.SDL_AudioStream,
    ptr: [*]u8,
    len: usize,

    pub fn init(device: Device, file_path: [*:0]const u8) !@This() {
        var spec: c.SDL_AudioSpec = undefined;
        var ptr: [*]u8 = undefined;
        var len: u32 = undefined;
        try sdlCheck(c.SDL_LoadWAV(file_path, &spec, @ptrCast(&ptr), &len));

        const stream = c.SDL_CreateAudioStream(&spec, null);
        try sdlCheck(stream);

        try sdlCheck(c.SDL_BindAudioStream(device.id, stream));

        return .{
            .device = device,
            .spec = spec,
            .stream = stream.?,
            .ptr = ptr,
            .len = @intCast(len),
        };
    }

    pub fn deinit(self: @This()) void {
        c.SDL_DestroyAudioStream(self.stream);
        c.SDL_free(@ptrCast(self.ptr));
    }

    pub fn play(self: @This(), volume: f32) !void {
        var buffer: [1028 * 10 * 10 * 10]u8 = undefined;
        @memcpy(buffer[0..self.len], self.ptr[0..self.len]);

        for (0..@intCast(self.len / 2)) |i| {
            const bytes = buffer[i * 2 .. (i * 2 + 2)][0..2];

            var sample = std.mem.readInt(i16, bytes, .little);

            sample = if (volume <= 1)
                @intFromFloat(std.math.round(@as(f32, @floatFromInt(sample)) * (volume)))
            else
                @intFromFloat(std.math.round(std.math.tanh(@as(f32, @floatFromInt(sample)) / std.math.maxInt(i16) * volume) * std.math.maxInt(i16)));

            std.mem.writeInt(i16, bytes, sample, .little);
        }

        const queue_size: usize = @intCast(c.SDL_GetAudioStreamAvailable(self.stream));
        if (queue_size < self.len * 8) try sdlCheck(c.SDL_PutAudioStreamData(self.stream, &buffer, @intCast(self.len)));
    }
};
