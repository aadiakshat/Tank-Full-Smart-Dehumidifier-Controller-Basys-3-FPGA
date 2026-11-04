`timescale 1ns/1ps

// Two-flop synchronizer followed by a stable-level debounce filter.
// press_pulse is asserted for one clk cycle on each debounced low-to-high edge.
module button_debouncer #(
    parameter integer DEBOUNCE_CYCLES = 1000000
) (
    input  wire clk,
    input  wire button_async,
    output reg  press_pulse
);
    reg sync_ff1;
    reg sync_ff2;
    reg debounced_level;
    reg [31:0] stable_count;

    // Basys 3 FPGA registers support power-up initialization in Vivado.
    initial begin
        sync_ff1 = 1'b0;
        sync_ff2 = 1'b0;
        debounced_level = 1'b0;
        stable_count = 32'd0;
        press_pulse = 1'b0;
    end

    always @(posedge clk) begin
        sync_ff1 <= button_async;
        sync_ff2 <= sync_ff1;
        press_pulse <= 1'b0;

        if (sync_ff2 == debounced_level) begin
            stable_count <= 32'd0;
        end else if (stable_count >= DEBOUNCE_CYCLES - 1) begin
            debounced_level <= sync_ff2;
            stable_count <= 32'd0;
            if (sync_ff2)
                press_pulse <= 1'b1;
        end else begin
            stable_count <= stable_count + 1'b1;
        end
    end
endmodule
