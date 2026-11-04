`timescale 1ns/1ps

module dehumidifier_controller #(
    parameter integer HUMIDITY_ON = 60,
    parameter integer HUMIDITY_OFF = 50,
    parameter [34:0] MIN_OFF_CYCLES = 35'd18000000000,
    parameter integer RECOVERY_CYCLES = 500000000
) (
    input  wire       clk,
    input  wire       reset,
    input  wire [6:0] humidity,
    input  wire [1:0] tank_status,
    input  wire       defrost_request,
    output reg  [2:0] mode,
    output wire       fan_on,
    output wire       compressor_on,
    output reg        fault_latched,
    output reg        humidity_demand,
    output wire       anti_cycle_lockout
);
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] DEHUMIDIFY  = 3'd1;
    localparam [2:0] DEFROST     = 3'd2;
    localparam [2:0] RECOVERY    = 3'd3;
    localparam [2:0] TANK_FULL   = 3'd4;
    localparam [2:0] FAULT       = 3'd5;

    localparam [1:0] TANK_FULL_CODE = 2'd2;
    localparam [1:0] TANK_INVALID   = 2'd3;

    reg [34:0] compressor_off_count;
    reg [31:0] recovery_count;

    initial begin
        mode = IDLE;
        fault_latched = 1'b0;
        humidity_demand = 1'b0;
        compressor_off_count = 35'd0;
        recovery_count = 32'd0;
    end

    assign anti_cycle_lockout = (mode != DEHUMIDIFY) &&
                                (compressor_off_count < MIN_OFF_CYCLES);

    // Safety conditions gate the physical output immediately, even before the
    // registered FSM advances to its corresponding safe state.
    assign compressor_on = (mode == DEHUMIDIFY) &&
                           (tank_status != TANK_FULL_CODE) &&
                           (tank_status != TANK_INVALID) &&
                           !fault_latched && !defrost_request;

    assign fan_on = ((mode == DEHUMIDIFY) ||
                     (mode == DEFROST) ||
                     (mode == RECOVERY)) &&
                    (tank_status != TANK_FULL_CODE) &&
                    (tank_status != TANK_INVALID) && !fault_latched;

    always @(posedge clk) begin
        if (reset) begin
            mode <= IDLE;
            fault_latched <= 1'b0;
            humidity_demand <= 1'b0;
            compressor_off_count <= 35'd0;
            recovery_count <= 32'd0;
        end else begin
            // Hysteresis: demand sets at or above HUMIDITY_ON and clears at or
            // below HUMIDITY_OFF. Values between thresholds retain prior demand.
            if (humidity >= HUMIDITY_ON)
                humidity_demand <= 1'b1;
            else if (humidity <= HUMIDITY_OFF)
                humidity_demand <= 1'b0;

            // Count compressor off-time, saturating at the configured limit.
            if (mode == DEHUMIDIFY)
                compressor_off_count <= 35'd0;
            else if (compressor_off_count < MIN_OFF_CYCLES)
                compressor_off_count <= compressor_off_count + 1'b1;

            // Priority: reset, invalid-state safety fault, latched fault,
            // FULL tank, defrost, then humidity demand and anti-cycle timing.
            if (tank_status == TANK_INVALID) begin
                fault_latched <= 1'b1;
                mode <= FAULT;
                recovery_count <= 32'd0;
            end else if (fault_latched || mode == FAULT) begin
                mode <= FAULT;
            end else if (tank_status == TANK_FULL_CODE) begin
                mode <= TANK_FULL;
                recovery_count <= 32'd0;
            end else if (defrost_request) begin
                mode <= DEFROST;
                recovery_count <= 32'd0;
            end else begin
                case (mode)
                    IDLE: begin
                        if (humidity_demand && !anti_cycle_lockout)
                            mode <= DEHUMIDIFY;
                    end
                    DEHUMIDIFY: begin
                        if (!humidity_demand)
                            mode <= IDLE;
                    end
                    DEFROST: begin
                        mode <= RECOVERY;
                        recovery_count <= RECOVERY_CYCLES;
                    end
                    RECOVERY: begin
                        if (recovery_count != 0) begin
                            recovery_count <= recovery_count - 1'b1;
                        end else if (humidity_demand && !anti_cycle_lockout) begin
                            mode <= DEHUMIDIFY;
                        end else begin
                            mode <= IDLE;
                        end
                    end
                    TANK_FULL: begin
                        if (humidity_demand && !anti_cycle_lockout)
                            mode <= DEHUMIDIFY;
                        else
                            mode <= IDLE;
                    end
                    FAULT: mode <= FAULT;
                    default: begin
                        fault_latched <= 1'b1;
                        mode <= FAULT;
                    end
                endcase
            end
        end
    end
endmodule
