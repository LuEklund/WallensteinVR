const std = @import("std");
const c = @import("sdl3").c;

pub fn sdlCheck(result: anytype) !void {
    if (!switch (@typeInfo(@TypeOf(result))) {
        .bool => !result,
        .optional => result == null,
        else => @compileError("unsupported type for sdl check"),
    }) return;

    std.log.err("sdl: {s}\n", .{c.SDL_GetError()});
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
    streams: []?*c.SDL_AudioStream,
    spec: c.SDL_AudioSpec,
    ptr: [*]u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, device: Device, file_path: [*:0]const u8) !@This() {
        var spec: c.SDL_AudioSpec = undefined;
        var ptr: [*]u8 = undefined;
        var len: u32 = undefined;
        try sdlCheck(c.SDL_LoadWAV(file_path, &spec, @ptrCast(&ptr), &len));

        const streams = try allocator.alloc(?*c.SDL_AudioStream, 16);
        @memset(streams, null);

        return .{
            .device = device,
            .streams = streams,
            .spec = spec,
            .ptr = ptr,
            .len = @intCast(len),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: @This()) void {
        for (self.streams) |stream| {
            if (stream != null) c.SDL_DestroyAudioStream(stream.?);
        }

        self.allocator.free(self.streams);
        c.SDL_free(@ptrCast(self.ptr));
    }

    pub fn play(self: @This(), volume: f32) !void {
        var free_stream: ?*c.SDL_AudioStream = null;

        for (self.streams) |*stream_ptr| {
            const current_stream = stream_ptr.*;
            if (current_stream == null) {
                const new_stream = c.SDL_CreateAudioStream(&self.spec, null);
                try sdlCheck(new_stream);
                try sdlCheck(c.SDL_BindAudioStream(self.device.id, new_stream));
                stream_ptr.* = new_stream;
                free_stream = new_stream;
                break;
            }
            if (c.SDL_GetAudioStreamAvailable(current_stream) == 0) {
                free_stream = current_stream;
                break;
            }
        }

        if (free_stream) |stream| {
            _ = c.SDL_SetAudioStreamGain(stream, volume);
            try sdlCheck(c.SDL_PutAudioStreamData(stream, @ptrCast(self.ptr), @intCast(self.len)));
        }
    }
};
