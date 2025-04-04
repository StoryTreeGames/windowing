const win32 = @import("win32");
const wgpu = @import("wgpu");
const core = @import("storytree-core");

const Renderer = @This();

surface: *wgpu.Surface,
device: *wgpu.Device,
queue: *wgpu.Queue,
surface_config: wgpu.SurfaceConfiguration,
pipeline: *wgpu.RenderPipeline,

pub fn create(window: *core.Window) !Renderer {
    var self: Renderer = undefined;

    const instance = wgpu.Instance.create(null) orelse return error.CouldNotCreateInstance;
    defer instance.release();

    self.surface = instance.createSurface(&switch (@import("builtin").os.tag) {
        // On windows, the inner value of the window is the windows only data type that
        // contains the HINSTANCE and HWND types that are to be used here.
        .windows => wgpu.surfaceDescriptorFromWindowsHWND(.{
            .label = "HWND_surface",
            .hinstance = window.inner.instance.?,
            .hwnd = window.inner.handle,
        }),
        else => @compileError("platform not supported")
    }) orelse return error.CouldNotCreateSurface;

    const adapter_request = instance.requestAdapterSync(&wgpu.RequestAdapterOptions{
        .compatible_surface = self.surface,
    });
    const adapter = switch (adapter_request.status) {
        .success => adapter_request.adapter.?,
        else => return error.AdapterRequestFailed
    };
    defer adapter.release();

    const device_request = adapter.requestDeviceSync(&wgpu.DeviceDescriptor {
        .required_limits = null,
    });
    self.device = switch(device_request.status) {
        .success => device_request.device.?,
        else => return error.DeviceRequestFailed,
    };

    self.queue = self.device.getQueue() orelse return error.CouldNotGetQueue;

    var surface_capabilities: wgpu.SurfaceCapabilities = undefined;
    self.surface.getCapabilities(adapter, &surface_capabilities);

    const rect = window.getRect();
    self.surface_config = wgpu.SurfaceConfiguration {
        .width = rect.width,
        .height = rect.height,
        .format = surface_capabilities.formats[0],
        .device = self.device,
    };

    self.surface.configure(&self.surface_config);

    // Render pipeline stuff
    // -------------------------------------------------------------------------
    const shader_module = self.device.createShaderModule(&wgpu.shaderModuleWGSLDescriptor(.{
        .code = @embedFile("./shader.wgsl"),
    })) orelse return error.CouldNotCreateShader;
    defer shader_module.release();

    const color_targets = &[_]wgpu.ColorTargetState {
        wgpu.ColorTargetState {
            .format = self.surface_config.format,
            .blend = &wgpu.BlendState {
                .color = wgpu.BlendComponent {
                    .operation = wgpu.BlendOperation.add,
                    .src_factor = wgpu.BlendFactor.src_alpha,
                    .dst_factor = wgpu.BlendFactor.one_minus_src_alpha,
                },
                .alpha = wgpu.BlendComponent {
                    .operation = wgpu.BlendOperation.add,
                    .src_factor = wgpu.BlendFactor.zero,
                    .dst_factor = wgpu.BlendFactor.one,
                },
            },
        },
    };

    self.pipeline = self.device.createRenderPipeline(&wgpu.RenderPipelineDescriptor {
        .vertex = wgpu.VertexState {
            .module = shader_module,
            .entry_point = "vs_main",
        },
        .primitive = wgpu.PrimitiveState {},
        .multisample = wgpu.MultisampleState {},
        .fragment = &wgpu.FragmentState {
            .module = shader_module,
            .entry_point = "fs_main",
            .target_count = color_targets.len,
            .targets = color_targets.ptr,
        },
    }) orelse return error.CouldNotCreateRenderPipeline;

    return self;
}

pub fn resize(self: *Renderer, width: u32, height: u32) void {
    self.surface_config.width = @max(width, 1);
    self.surface_config.height = @max(height, 1);
    self.surface.configure(&self.surface_config);
}

pub fn render(self: *Renderer) !void {
    var surface_texture: wgpu.SurfaceTexture = undefined;
    self.surface.getCurrentTexture(&surface_texture);
    if (surface_texture.status != wgpu.GetCurrentTextureStatus.success) {
        return error.SurfaceTextureNotSuccessfulStatus; // TODO: find a better name for that
    }

    const target_view = surface_texture.texture.createView(&wgpu.TextureViewDescriptor {
        .label = "surface texture view",
        .format = surface_texture.texture.getFormat(),
        .dimension = wgpu.ViewDimension.@"2d",
        .mip_level_count = 1,
        .array_layer_count = 1,
    }) orelse return error.CouldNotCreateTextureView;

    const encoder = self.device.createCommandEncoder(&wgpu.CommandEncoderDescriptor {
        .label = "render command encoder"
    }) orelse return error.CouldNotCreateCommandEncoder;

    const render_pass_color_attachments = &[_]wgpu.ColorAttachment {
        wgpu.ColorAttachment {
            .view = target_view,
            .clear_value = wgpu.Color { .r = 0.9, .g = 0.1, .b = 0.2, .a = 0.0 },
        },
    };

    const render_pass = encoder.beginRenderPass(&wgpu.RenderPassDescriptor {
        .color_attachment_count = render_pass_color_attachments.len,
        .color_attachments = render_pass_color_attachments.ptr,
    }) orelse return error.CouldNotBeginRenderPass;

    render_pass.setPipeline(self.pipeline);
    render_pass.draw(3, 1, 0, 0);
    render_pass.end();
    render_pass.release();

    const command_buffer = encoder.finish(&wgpu.CommandBufferDescriptor {
        .label = "render command buffer",
    }) orelse return error.CouldNotFinishCommandEncoder;
    const commands = [_] *const wgpu.CommandBuffer {
        command_buffer,
    };
    encoder.release();

    self.queue.submit(&commands);

    command_buffer.release();
    target_view.release();

    self.surface.present();

    _ = self.device.poll(false, null);
}

pub fn release(self: *Renderer) void {
    self.pipeline.release();
    self.surface.unconfigure();
    self.queue.release();
    self.surface.release();
    self.device.release();
}
