`timescale 1ns/1ps

module top_controller #(
    parameter integer DEBOUNCE_CYCLES = 1000000,
    parameter [34:0] MIN_OFF_CYCLES = 35'd18000000000,
    parameter integer RECOVERY_CYCLES = 500000000,
    parameter integer DIGIT_REFRESH_CYCLES = 25000,
    parameter integer HUMIDITY_ON = 60,
    parameter integer HUMIDITY_OFF = 50
) (
    input  wire        clk,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        btnD,
    input  wire        btnL,
    input  wire        btnR,
    output wire [14:0] led,
    output wire [6:0]  seg,
    output wire [3:0]  an
);
    localparam [2:0] MODE_DEHUMIDIFY = 3'd1;
    localparam [2:0] MODE_DEFROST = 3'd2;
    localparam [1:0] TANK_LOW = 2'd1;
    localparam [1:0] TANK_FULL = 2'd2;

    wire reset_event;
    wire increase_event;
    wire decrease_event;
    wire tank_cycle_event;
    wire defrost_toggle_event;
    wire [6:0] humidity;
    wire [1:0] tank_status;
    wire defrost_request;
    wire [2:0] mode;
    wire fan_on;
    wire compressor_on;
    wire fault_latched;
    wire humidity_demand;
    wire anti_cycle_lockout;

    button_debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btnc (
        .clk(clk), .button_async(btnC), .press_pulse(reset_event)
    );
    button_debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btnu (
        .clk(clk), .button_async(btnU), .press_pulse(increase_event)
    );
    button_debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btnd (
        .clk(clk), .button_async(btnD), .press_pulse(decrease_event)
    );
    button_debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btnl (
        .clk(clk), .button_async(btnL), .press_pulse(tank_cycle_event)
    );
    button_debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btnr (
        .clk(clk), .button_async(btnR), .press_pulse(defrost_toggle_event)
    );

    humidity_controller u_humidity_controller (
        .clk(clk), .reset(reset_event),
        .increase_event(increase_event), .decrease_event(decrease_event),
        .humidity(humidity)
    );

    tank_controller u_tank_controller (
        .clk(clk), .reset(reset_event), .cycle_event(tank_cycle_event),
        .tank_status(tank_status)
    );

    reg defrost_request_reg;
    initial defrost_request_reg = 1'b0;
    always @(posedge clk) begin
        if (reset_event)
            defrost_request_reg <= 1'b0;
        else if (defrost_toggle_event)
            defrost_request_reg <= ~defrost_request_reg;
    end
    assign defrost_request = defrost_request_reg;

    dehumidifier_controller #(
        .HUMIDITY_ON(HUMIDITY_ON),
        .HUMIDITY_OFF(HUMIDITY_OFF),
        .MIN_OFF_CYCLES(MIN_OFF_CYCLES),
        .RECOVERY_CYCLES(RECOVERY_CYCLES)
    ) u_dehumidifier_controller (
        .clk(clk), .reset(reset_event), .humidity(humidity),
        .tank_status(tank_status), .defrost_request(defrost_request),
        .mode(mode), .fan_on(fan_on), .compressor_on(compressor_on),
        .fault_latched(fault_latched), .humidity_demand(humidity_demand),
        .anti_cycle_lockout(anti_cycle_lockout)
    );

    seven_segment_display #(
        .DIGIT_REFRESH_CYCLES(DIGIT_REFRESH_CYCLES)
    ) u_seven_segment_display (
        .clk(clk), .reset(reset_event), .humidity(humidity),
        .seg(seg), .an(an)
    );

    led_status_display u_led_status_display (
        .humidity(humidity),
        .compressor_on(compressor_on), .fan_on(fan_on),
        .dehumidify_active(mode == MODE_DEHUMIDIFY),
        .defrost_active(mode == MODE_DEFROST),
        .tank_full(tank_status == TANK_FULL),
        .fault_latched(fault_latched), .tank_low(tank_status == TANK_LOW),
        .anti_cycle_lockout(anti_cycle_lockout), .led(led)
    );

endmodule
