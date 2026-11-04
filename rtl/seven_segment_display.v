`timescale 1ns/1ps

// Basys 3 common-anode display. seg[0:6] map CA..CG and are active-low;
// an[0:3] are active-low digit enables. The leftmost digit is blank so the
// three rightmost digits show humidity as 000 through 100. DP is unused.
module seven_segment_display #(
    parameter integer DIGIT_REFRESH_CYCLES = 25000
) (
    input  wire       clk,
    input  wire       reset,
    input  wire [6:0] humidity,
    output reg  [6:0] seg,
    output reg  [3:0] an
);
    reg [31:0] refresh_count;
    reg [1:0] digit_index;
    reg [3:0] digit_value;
    reg       digit_blank;
    reg [6:0] hundreds;
    reg [6:0] tens;
    reg [6:0] ones;

    initial begin
        refresh_count = 32'd0;
        digit_index = 2'd0;
    end

    always @(posedge clk) begin
        if (reset) begin
            refresh_count <= 32'd0;
            digit_index <= 2'd0;
        end else if (refresh_count >= DIGIT_REFRESH_CYCLES - 1) begin
            refresh_count <= 32'd0;
            digit_index <= digit_index + 1'b1;
        end else begin
            refresh_count <= refresh_count + 1'b1;
        end
    end

    always @* begin
        hundreds = humidity / 7'd100;
        tens = (humidity / 7'd10) % 7'd10;
        ones = humidity % 7'd10;
        digit_value = 4'd0;
        digit_blank = 1'b0;
        an = 4'b1111;
        an[digit_index] = 1'b0;
        case (digit_index)
            2'd0: digit_value = ones[3:0];
            2'd1: digit_value = tens[3:0];
            2'd2: digit_value = hundreds[3:0];
            default: digit_blank = 1'b1;
        endcase

        if (digit_blank) begin
            seg = 7'b1111111;
        end else begin
            case (digit_value)
                4'd0: seg = 7'b1000000;
                4'd1: seg = 7'b1111001;
                4'd2: seg = 7'b0100100;
                4'd3: seg = 7'b0110000;
                4'd4: seg = 7'b0011001;
                4'd5: seg = 7'b0010010;
                4'd6: seg = 7'b0000010;
                4'd7: seg = 7'b1111000;
                4'd8: seg = 7'b0000000;
                4'd9: seg = 7'b0010000;
                default: seg = 7'b1111111;
            endcase
        end
    end
endmodule
