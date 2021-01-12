const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

fn unwrapOptionalBool(optionalBool: ?bool) bool {
    if (optionalBool) |b| return b;
    return false;
}

pub fn build(b: *Builder) !void {
    const openssl = unwrapOptionalBool(b.option(bool, "openssl", "enable OpenSSL ssl backend"));
    //const wolfssl = unwrapOptionalBool(b.option(bool, "wolfssl", "enable WolfSSL ssl backend"));

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("ziget", "ziget-cmdline.zig");
    exe.setTarget(target);
    exe.single_threaded = true;
    exe.setBuildMode(mode);
    if (openssl) {
        exe.addPackage(Pkg { .name = "ssl", .path = "openssl/ssl.zig" });
        exe.linkSystemLibrary("c");
        if (std.builtin.os.tag == .windows) {
            exe.linkSystemLibrary("libcrypto");
            exe.linkSystemLibrary("libssl");
            try setupOpensslWindows(b, exe);
        } else {
            exe.linkSystemLibrary("crypto");
            exe.linkSystemLibrary("ssl");
        }
    } else {
        exe.addPackage(Pkg { .name = "ssl", .path = "nossl/ssl.zig" });
    }
    //if (wolfssl) {
    //    std.debug.print("Error: -Dwolfssl=true not implemented", .{});
    //    std.os.exit(1);
    //}
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn setupOpensslWindows(b: *Builder, exe: *std.build.LibExeObjStep) !void {
    const openssl_path = b.option([]const u8, "openssl-path", "path to openssl (for Windows)") orelse {
        std.debug.print("Error: -Dopenssl on windows requires -Dopenssl-path=DIR to be specified\n", .{});
        std.os.exit(1);
    };
    // NOTE: right now these files are hardcoded to the files expected when installing SSL via
    //       this web page: https://slproweb.com/products/Win32OpenSSL.html and installed using
    //       this exe installer: https://slproweb.com/download/Win64OpenSSL-1_1_1g.exe
    exe.addIncludeDir(try std.fs.path.join(b.allocator, &[_][]const u8 {openssl_path, "include"}));
    exe.addLibPath(try std.fs.path.join(b.allocator, &[_][]const u8 {openssl_path, "lib"}));
    // install dlls to the same directory as executable
    for ([_][]const u8 {"libcrypto-1_1-x64.dll", "libssl-1_1-x64.dll"}) |dll| {
        exe.step.dependOn(
            &b.addInstallFileWithDir(
                try std.fs.path.join(b.allocator, &[_][]const u8 {openssl_path, dll}),
                .Bin,
                dll,
            ).step
        );
    }
}
