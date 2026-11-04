`timescale 1ns/1ps

// Two-bit status encoding: NORMAL=0, LOW=1, FULL=2, INVALID=3 (reserved).
module tank_controller (
    input  wire      clk,
    input  wire      reset,
    input  wire      cycle_event,
    output reg [1:0] tank_status
);
    localparam [1:0] TANK_NORMAL = 2'd0;
    localparam [1:0] TANK_LOW    = 2'd1;
    localparam [1:0] TANK_FULL   = 2'd2;

    initial tank_status = TANK_NORMAL;

    always @(posedge clk) begin
        if (reset) begin
            tank_status <= TANK_NORMAL;
        end else if (cycle_event) begin
            case (tank_status)
                TANK_NORMAL: tank_status <= TANK_LOW;
                TANK_LOW:    tank_status <= TANK_FULL;
                default:     tank_status <= TANK_NORMAL;
            endcase
        end
    end
endmodule
