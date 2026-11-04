`timescale 1ns/1ps

module led_status_display (
    input  wire [6:0] humidity,
    input  wire       compressor_on,
    input  wire       fan_on,
    input  wire       dehumidify_active,
    input  wire       defrost_active,
    input  wire       tank_full,
    input  wire       fault_latched,
    input  wire       tank_low,
    input  wire       anti_cycle_lockout,
    output wire [14:0] led
);
    assign led[6:0] = humidity;
    assign led[7] = compressor_on;
    assign led[8] = fan_on;
    assign led[9] = dehumidify_active;
    assign led[10] = defrost_active;
    assign led[11] = tank_full;
    assign led[12] = fault_latched;
    assign led[13] = tank_low;
    assign led[14] = anti_cycle_lockout;
endmodule
