
const std = @import("std");


pub fn createPhysicalDevice(instance: c.VkInstance) !c.VkPhysicalDevice {    
    var num_devices: u32 = 0;

    c.vkEnumeratePhysicalDevices(instance, &num_devices, null);

    if (num_devices == 0) {
        std.debug.print("Num physical devices in 0\n");
        return error.InvalidDeviceCount;
    }

    var physical_devices: [8]c.VkPhysicalDevice = undefined;
    c.vkEnumeratePhysicalDevices(instance, &num_devices, @ptrCast(&physical_devices));
    
    // debug 
    std.debug.print("Found {d} num of GPUs!\n", .{num_devices});
    
    
    return physical_devices[0];
}


