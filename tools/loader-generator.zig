const std = @import("std");

const c = @cImport({
    @cDefine("XR_USE_GRAPHICS_API_VULKAN", "1");
    @cDefine("XR_EXTENSION_PROTOTYPES", "1");
    @cInclude("vulkan/vulkan.h");
    @cInclude("openxr/openxr.h");
    @cInclude("openxr/openxr_platform.h");
});

const Pfn = struct {
    trimmed_name: []const u8,
    pfn: type,
};

const Mode = enum {
    xr,
    vk,
};

pub fn main() !void {
    @setEvalBranchQuota(1_000_000);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2)
        return error.@"missing output file arg";

    var output_file = try std.fs.cwd().createFile(args[1], .{});
    defer output_file.close();

    var buf_writer = std.io.bufferedWriter(output_file.writer());
    const writer = buf_writer.writer();

    try writer.writeAll(@embedFile("loader-generator-base.zig"));

    comptime var vk_pfns: []const Pfn = &.{};
    comptime var xr_pfns: []const Pfn = &.{};

    inline for (@typeInfo(c).@"struct".decls) |decl| {
        if (comptime checkDecl(decl, "PFN_vk")) |pfn| {
            vk_pfns = vk_pfns ++ pfn;
        }
        if (comptime checkDecl(decl, "PFN_xr")) |pfn| {
            xr_pfns = xr_pfns ++ pfn;
        }
    }

    inline for (vk_pfns) |vk_pfn|
        try addVkWrapper(writer, vk_pfn);
    inline for (xr_pfns) |xr_pfn|
        try addXrWrapper(writer, xr_pfn);

    try createDispatcherSpec(writer, vk_pfns, .vk);
    try createDispatcherSpec(writer, xr_pfns, .xr);

    try createDispatcher(writer, vk_pfns, .vk);
    try createDispatcher(writer, xr_pfns, .xr);

    try writer.writeAll("\n");
    try buf_writer.flush();
}

fn checkDecl(
    decl: std.builtin.Type.Declaration,
    needle: []const u8,
) ?[1]Pfn {
    if (!std.mem.startsWith(
        u8,
        decl.name[0..],
        needle,
    )) return null;

    return [1]Pfn{.{
        .trimmed_name = decl.name[6..],
        .pfn = @typeInfo(@field(c, decl.name)).optional.child,
    }};
}

fn addVkWrapper(
    writer: anytype,
    comptime pfn: Pfn,
) !void {
    try writer.print(
        \\
        \\pub const PfnVk{0s} = {1any};
        \\pub fn loadVk{0s}(instance_or_device: anytype) LoadError!PfnVk{0s} {{
        \\    var func: c.PFN_vkVoidFunction = null;
        \\    if (comptime @TypeOf(instance_or_device) == c.VkInstance) {{
        \\        func = c.vkGetInstanceProcAddr(instance_or_device, "vk{0s}");
        \\    }} else {{
        \\        func = c.vkGetDeviceProcAddr(instance_or_device, "vk{0s}");
        \\    }}
        \\    if (func == null) return error.LoadFailed;
        \\    return @ptrCast(func.?);
        \\}}
        \\
    , .{ pfn.trimmed_name, pfn.pfn });
}

fn addXrWrapper(
    writer: anytype,
    comptime pfn: Pfn,
) !void {
    try writer.print(
        \\
        \\pub const PfnXr{0s} = {1any};
        \\pub fn loadXr{0s}(instance: c.XrInstance) (LoadError || XrError)!PfnXr{0s} {{
        \\    var func: c.PFN_vkVoidFunction = null;
        \\    try xrCheck(c.xrGetInstanceProcAddr(instance, "xr{0s}", &func));
        \\    if (func == null) return LoadError.LoadFailed;
        \\    return @ptrCast(func.?);
        \\}}
        \\
    , .{ pfn.trimmed_name, pfn.pfn });
}

fn createDispatcherSpec(
    writer: anytype,
    comptime pfns: []const Pfn,
    comptime mode: Mode,
) !void {
    try writer.print(
        \\
        \\pub const {s}DispatcherSpec = struct {{
        \\
    , .{if (mode == .xr) "Xr" else "Vk"});

    inline for (pfns) |vk_pfn| {
        try writer.print(
            \\    {s}{s}: bool = false,
            \\
        , .{ if (mode == .xr) "xr" else "vk", vk_pfn.trimmed_name });
    }

    try writer.writeAll(
        \\};
        \\
    );
}

fn createDispatcher(
    writer: anytype,
    comptime pfns: []const Pfn,
    comptime mode: Mode,
) !void {
    try writer.print(
        \\
        \\pub fn {0s}Dispatcher(comptime spec: {0s}DispatcherSpec) type {{
        \\    @setEvalBranchQuota(10_000);
        \\    const loader = @This();
        \\    comptime var pfn_count: usize = 0;
        \\    inline for (@typeInfo(@TypeOf(spec)).@"struct".fields) |field| {{
        \\        if (comptime !@field(spec, field.name)) continue;
        \\        pfn_count += 1;
        \\    }}
        \\    comptime var pfn_fields: [pfn_count]std.builtin.Type.StructField = undefined;
        \\    pfn_count = 0;
        \\    inline for (@typeInfo(@TypeOf(spec)).@"struct".fields) |field| {{
        \\        if (comptime !@field(spec, field.name)) continue;
        \\        const Pfn = @field(loader, "Pfn{0s}" ++ field.name[2..]);
        \\        pfn_fields[pfn_count] = .{{
        \\            .name = field.name,
        \\            .type = Pfn,
        \\            .default_value_ptr = null,
        \\            .is_comptime = false,
        \\            .alignment = @alignOf(Pfn),
        \\        }};
        \\        pfn_count += 1;
        \\    }}
        \\    const PfnStore = @Type(.{{ .@"struct" = std.builtin.Type.Struct{{
        \\        .layout = .auto,
        \\        .fields = &pfn_fields,
        \\        .decls = &.{{}},
        \\        .is_tuple = false,
        \\    }}}});
        \\    return struct {{
        \\        store: PfnStore,
        \\
        \\        pub fn init({1s}: anytype) !@This() {{
        \\            var self: @This() = undefined;
        \\            inline for (@typeInfo(@TypeOf(spec)).@"struct".fields) |field| {{
        \\                if (comptime !@field(spec, field.name)) continue;
        \\                @field(self.store, field.name) = try @field(loader, "load{0s}" ++ field.name[2..])({1s});
        \\            }}
        \\            return self;
        \\        }}
        \\
    , if (mode == .xr) .{ "Xr", "instance" } else .{ "Vk", "instance_or_device" });

    inline for (pfns) |pfn| {
        const FnProto = @typeInfo(@typeInfo(pfn.pfn).pointer.child).@"fn";

        if (FnProto.return_type.? != c_int and FnProto.return_type.? != void)
            continue;

        try writer.print(
            \\
            \\    pub fn {0s}{1s}(
            \\        self: @This(),
            \\
        , .{ if (mode == .xr) "xr" else "vk", pfn.trimmed_name });

        inline for (FnProto.params, 0..) |pfn_param, i| {
            try writer.print(
                \\        _{}: {},
                \\
            , .{ i, pfn_param.type.? });
        }

        if (FnProto.return_type.? == c_int) {
            try writer.print(
                \\    ) {0s}Error!void {{
                \\        try {1s}Check(self.store.{1s}{2s}(
                \\
            , if (mode == .xr) .{ "Xr", "xr", pfn.trimmed_name } else .{ "Vk", "vk", pfn.trimmed_name });

            for (0..FnProto.params.len) |i| {
                try writer.print(
                    \\            _{},
                    \\
                , .{i});
            }

            try writer.writeAll(
                \\        ));
                \\    }
                \\
            );
        } else if (FnProto.return_type.? == void) {
            try writer.print(
                \\    ) void {{
                \\        self.store.{0s}{1s}(
                \\
            , if (mode == .xr) .{ "xr", pfn.trimmed_name } else .{ "vk", pfn.trimmed_name });

            for (0..FnProto.params.len) |i| {
                try writer.print(
                    \\            _{},
                    \\
                , .{i});
            }

            try writer.writeAll(
                \\        );
                \\    }
                \\
            );
        }
    }

    try writer.writeAll(
        \\    };
        \\}
        \\
    );
}
