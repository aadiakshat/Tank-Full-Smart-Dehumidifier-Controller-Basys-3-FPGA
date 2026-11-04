`timescale 1ns/1ps

module humidity_controller (
    input  wire       clk,
    input  wire       reset,
    input  wire       increase_event,
    input  wire       decrease_event,
    output reg  [6:0] humidity
);
    initial humidity = 7'd0;

    always @(posedge clk) begin
        if (reset) begin
            humidity <= 7'd0;
        end else if (increase_event && !decrease_event) begin
            if (humidity >= 7'd95)
                humidity <= 7'd100;
            else
                humidity <= humidity + 7'd5;
        end else if (decrease_event && !increase_event) begin
            if (humidity <= 7'd5)
                humidity <= 7'd0;
            else
                humidity <= humidity - 7'd5;
        end
    end
endmodule
