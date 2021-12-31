extern const __etext: usize;
extern var __data_start__: usize;
extern const __data_size: usize;
extern var __bss_start__: usize;
extern const __bss_size: usize;

export fn Reset_Handler() noreturn {
    // Set up memory
    const data_src = @ptrCast([*]const u32, &__etext);
    var data = @ptrCast([*]u32, &__data_start__);
    const data_size = @ptrToInt(&__data_size);

    for (data_src[0..data_size]) |val, idx| data[idx] = val; // Copy values from the .text to .data

    var bss = @ptrCast([*]u32, &__bss_start__);
    const bss_size = @ptrToInt(&__bss_size);

    for (bss[0..bss_size]) |*b| b.* = 0; // Zero .bss

    main() catch {}; // Jump to main
    while (true) {} // If main ever returns, busy-loop
}

const ExceptionHandler = fn () callconv(.C) void;
export fn default_handler() void {
    while (true) {}
}

export fn nop_handler() void {}

const VectorTable = struct {
    reset: fn () callconv(.C) noreturn,
    nmi: ExceptionHandler = default_handler,
    hard_fault: ExceptionHandler = default_handler,
    _reserved1: u32 = 0,
    _reserved2: u32 = 0,
    _reserved3: u32 = 0,
    _reserved4: u32 = 0,
    _reserved5: u32 = 0,
    _reserved6: u32 = 0,
    _reserved7: u32 = 0,
    sv_call: ExceptionHandler = default_handler,
    pend_sv: ExceptionHandler = default_handler,
    sys_tick: ExceptionHandler = default_handler,
    power_clock: ExceptionHandler = default_handler,
    radio: ExceptionHandler = default_handler,
    uart0: ExceptionHandler = default_handler,
    spi0_twi0: ExceptionHandler = default_handler,
    spi1_twi1: ExceptionHandler = default_handler,
    gpiote: ExceptionHandler = default_handler,
    adc: ExceptionHandler = default_handler,
    timer0: ExceptionHandler = default_handler,
    timer1: ExceptionHandler = default_handler,
    timer2: ExceptionHandler = default_handler,
    rtc0: ExceptionHandler = default_handler,
    temp: ExceptionHandler = default_handler,
    rng: ExceptionHandler = default_handler,
    ecb: ExceptionHandler = default_handler,
    ccm_aar: ExceptionHandler = default_handler,
    wdt: ExceptionHandler = default_handler,
    rtc1: ExceptionHandler = default_handler,
    qdec: ExceptionHandler = default_handler,
    lpcomp: ExceptionHandler = default_handler,
    swi0: ExceptionHandler = default_handler,
    swi1: ExceptionHandler = default_handler,
    swi2: ExceptionHandler = default_handler,
    swi3: ExceptionHandler = default_handler,
    swi4: ExceptionHandler = default_handler,
    swi5: ExceptionHandler = default_handler,
};

export const vector_table linksection(".isr_vector") = VectorTable{
    .reset = Reset_Handler,
};

// END BOOT

const std = @import("std");
const gpio = @import("nrf51/gpio.zig");

const PinType = enum { en_high, en_low };

const Pin = union(PinType) { en_high: usize, en_low: usize };

fn enablePin(pin: Pin) void {
    switch (pin) {
        .en_high => |i| gpio.writeOutset(@as(u32, 1) <<| i),
        .en_low => |i| gpio.writeOutclr(@as(u32, 1) <<| i),
    }
}

fn disablePin(pin: Pin) void {
    switch (pin) {
        .en_high => |i| gpio.writeOutclr(@as(u32, 1) <<| i),
        .en_low => |i| gpio.writeOutset(@as(u32, 1) <<| i),
    }
}

pub fn main() anyerror!void {
    const clock = @import("nrf51/clock.zig");

    //// Start the external HF crystal
    clock.writeTasksHfclkstart(1); // Request clock start
    while (clock.readEventsHfclkstarted() != 1) {} // Wait for clock
    clock.writeEventsHfclkstarted(0); // Reset the event

    //// Start the internal LF oscillator
    clock.writeTasksLfclkstart(1); // Request clock start
    while (clock.readEventsLfclkstarted() != 1) {} // Wait for clock
    clock.writeEventsLfclkstarted(0); // Reset the event

    //// Calibrate the internal LF oscillator
    clock.writeTasksCal(1); // Request calibration
    while (clock.readEventsDone() != 1) {} // Wait for calibration
    clock.writeEventsDone(0); // Reset the event

    gpio.writeDirsetPin24(1); // Set to output
    gpio.writeDirclrPin25(1); // Set to input

    gpio.writeDirset(1 << 13 | 1 << 14 | 1 << 15);
    gpio.writeDirset(1 << 4 | 1 << 5 | 1 << 6 | 1 << 7 | 1 << 8 | 1 << 9 | 1 << 10 | 1 << 11 | 1 << 12);
    gpio.writeOutset(0);

    const matrix = @import("hla").drivers.matrix;
    

    var raw_matrix = matrix.RawMatrix(Pin, 3, 9){ .rows = .{ Pin{ .en_high = 13 }, Pin{ .en_high = 14 }, Pin{ .en_high = 15 } }, .cols = .{ Pin{ .en_low = 4 }, Pin{ .en_low = 5 }, Pin{ .en_low = 6 }, Pin{ .en_low = 7 }, Pin{ .en_low = 8 }, Pin{ .en_low = 9 }, Pin{ .en_low = 10 }, Pin{ .en_low = 11 }, Pin{ .en_low = 12 } }, .enabler = enablePin, .disabler = disablePin };
    var display = matrix.TransformedMatrix(Pin, 5, 5, 3, 9){ .map = .{ .{ .{ 0, 0 }, .{ 2, 3 }, .{ 1, 1 }, .{ 0, 7 }, .{ 2, 2 } }, .{ .{ 1, 3 }, .{ 2, 4 }, .{ 0, 8 }, .{ 0, 6 }, .{ 1, 6 } }, .{ .{ 0, 1 }, .{ 2, 5 }, .{ 1, 2 }, .{ 0, 5 }, .{ 2, 0 } }, .{ .{ 1, 4 }, .{ 2, 6 }, .{ 2, 8 }, .{ 0, 4 }, .{ 1, 5 } }, .{ .{ 0, 2 }, .{ 2, 7 }, .{ 1, 0 }, .{ 0, 3 }, .{ 2, 1 } } }, .raw_mat = raw_matrix };

    var filling: bool = true;
    var x: usize = 0;
    var y: usize = 0;
    while (true) {
        if (filling) {
            display.enable(x, y);
        } else {
            display.disable(x, y);
        }

        var i: usize = 0;

        while (i < 1000) {
            display.raw_mat.disable_all();
            i += 1;
        }

        if (y == 4 and x == 4) {
            if (filling) {
                display.raw_mat.enable_all();
                i = 0;
                while (i < 1000) {
                    display.raw_mat.display_next_row();
                    i += 1;
                }
                display.raw_mat.disable_all();
                i = 0;
                while (i < 1000) {
                    display.raw_mat.display_next_row();
                    i += 1;
                }
                display.raw_mat.enable_all();
                i = 0;
                while (i < 1000) {
                    display.raw_mat.display_next_row();
                    i += 1;
                }
                display.raw_mat.disable_all();
            } else {
                display.raw_mat.disable_all();
                i = 0;
                while (i < 1000) {
                    display.raw_mat.display_next_row();
                    i += 1;
                }
                display.raw_mat.enable_all();
                i = 0;
                while (i < 1000) {
                    display.raw_mat.display_next_row();
                    i += 1;
                }
                display.raw_mat.disable_all();
                i = 0;
                while (i < 1000) {
                    display.raw_mat.display_next_row();
                    i += 1;
                }
                display.raw_mat.enable_all();
            }

            filling = !filling;
            x = 0;
            y = 0;
        } else if (x == 4) {
            x = 0;
            y += 1;
        } else {
            x += 1;
        }
    }
}
