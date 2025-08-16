const std = @import("std");
const c = @import("sdl3").c; // TODO: Replace all the C stuff into the sdl bindings stuff

pub fn sdlCheck(result: anytype) !void {
    if (!switch (@typeInfo(@TypeOf(result))) {
        .bool => !result,
        .optional => result == null,
        else => @compileError("unsupported type for sdl check"),
    }) return;

    std.log.err("sdl: {s}\n", .{c.SDL_GetError()});
    return error.Sdl;
}

pub const Sound = struct {
    ptr: [*]u8,
    len: u32,
    stream: ?*c.SDL_AudioStream,
    spec: c.SDL_AudioSpec,
};

pub const AudioPlayer = struct {
    device_id: c.SDL_AudioDeviceID,
    sounds: []Sound,

    pub fn init(allocator: std.mem.Allocator, file_paths: []const [*:0]const u8) !@This() {
        const audio_device = c.SDL_OpenAudioDevice(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, null);
        try sdlCheck(audio_device != 0);

        const sounds = try allocator.alloc(Sound, file_paths.len);

        for (file_paths, sounds) |file_path, *sound| {
            try sdlCheck(c.SDL_LoadWAV(file_path, &sound.spec, @ptrCast(&sound.ptr), &sound.len));

            sound.stream = c.SDL_CreateAudioStream(&sound.spec, null);
            try sdlCheck(sound.stream);

            try sdlCheck(c.SDL_BindAudioStream(audio_device, sound.stream));
        }

        return .{ .device_id = audio_device, .sounds = sounds };
    }

    pub fn playSound(self: *@This(), index: usize, volume: f32) !void {
        const sound = self.sounds[index];
        var buffer: [1028 * 10 * 10 * 10]u8 = undefined;
        @memcpy(buffer[0..@intCast(sound.len)], sound.ptr[0..@intCast(sound.len)]);

        for (0..@intCast(sound.len / 2)) |i| {
            const bytes = buffer[i * 2 .. (i * 2 + 2)][0..2];

            var sample = std.mem.readInt(i16, bytes, .little);

            sample = if (volume <= 1)
                @intFromFloat(std.math.round(@as(f32, @floatFromInt(sample)) * (volume)))
            else
                @intFromFloat(std.math.round(std.math.tanh(@as(f32, @floatFromInt(sample)) / 32768.0 * volume) * 32767.0));

            std.mem.writeInt(i16, bytes, sample, .little);
        }

        const queue_size = c.SDL_GetAudioStreamAvailable(sound.stream);
        if (queue_size < sound.len * 8) try sdlCheck(c.SDL_PutAudioStreamData(sound.stream, &buffer, @intCast(sound.len)));
    }

    pub fn deinit(self: *@This()) void {
        for (self.sounds) |sound| {
            if (sound.stream) |s| {
                c.SDL_DestroyAudioStream(s);
            }
            c.SDL_free(@ptrCast(sound.ptr));
        }
        c.SDL_CloseAudioDevice(self.device_id);
    }
};
