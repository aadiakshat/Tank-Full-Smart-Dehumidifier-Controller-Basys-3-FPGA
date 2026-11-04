
`timescale 1ns/1ps

module tb_top_controller;

    localparam [2:0] MODE_IDLE       = 3'd0;
    localparam [2:0] MODE_DEH        = 3'd1;
    localparam [2:0] MODE_DEFROST    = 3'd2;
    localparam [2:0] MODE_RECOVERY   = 3'd3;
    localparam [2:0] MODE_TANK_FULL  = 3'd4;
    localparam [2:0] MODE_FAULT      = 3'd5;

    reg clk;
    reg btnC, btnU, btnD, btnL, btnR;

    wire [14:0] led;
    wire [6:0] seg;
    wire [3:0] an;

    integer pass_count;
    integer fail_count;
    top_controller #(
        .DEBOUNCE_CYCLES(3),
        .MIN_OFF_CYCLES(35'd120),
        .RECOVERY_CYCLES(40),
        .DIGIT_REFRESH_CYCLES(2),
        .HUMIDITY_ON(60),
        .HUMIDITY_OFF(50)
    ) dut (
        .clk(clk),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .btnL(btnL),
        .btnR(btnR),
        .led(led),
        .seg(seg),
        .an(an)
    );

    // 100 MHz simulation clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_top_controller.vcd");
        $dumpvars(0, tb_top_controller);
    end

    // Global watchdog prevents an infinite simulation.
    initial begin
        #1000000;
        $display("ERROR: Global simulation timeout.");
        $display("Summary: %0d PASS, %0d FAIL",
                 pass_count, fail_count + 1);
        $finish;
    end

    task check;
        input condition;
        input [8*100-1:0] label;
        begin
            if (condition === 1'b1) begin
                pass_count = pass_count + 1;
                $display("PASS: %0s", label);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s", label);
            end
        end
    endtask

    task wait_cycles;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // Button mapping:
    // 0 = reset, 1 = humidity up, 2 = humidity down,
    // 3 = tank button, 4 = defrost button.
    task press_button;
        input integer which_button;
        begin
            // Set input away from the active clock edge.
            @(negedge clk);
            case (which_button)
                0: btnC = 1'b1;
                1: btnU = 1'b1;
                2: btnD = 1'b1;
                3: btnL = 1'b1;
                4: btnR = 1'b1;
                default: begin
                    $display("ERROR: Invalid button index %0d",
                             which_button);
                    fail_count = fail_count + 1;
                end
            endcase

            // Allow debounce and event detection.
            wait_cycles(8);

            @(negedge clk);
            case (which_button)
                0: btnC = 1'b0;
                1: btnU = 1'b0;
                2: btnD = 1'b0;
                3: btnL = 1'b0;
                4: btnR = 1'b0;
                default: ;
            endcase

            // Allow release debounce.
            wait_cycles(8);
        end
    endtask

    // Set humidity in 5-point increments using the public inputs.
    task set_humidity;
        input integer target;
        integer current;
        integer steps;
        integer k;
        begin
            current = dut.humidity;

            if ((target < 0) || (target > 100) ||
                ((target % 5) != 0)) begin
                $display("ERROR: Invalid humidity target %0d", target);
                fail_count = fail_count + 1;
            end else begin
                steps = (target > current) ?
                        ((target - current) / 5) :
                        ((current - target) / 5);

                if (target > current) begin
                    for (k = 0; k < steps; k = k + 1)
                        press_button(1);
                end else if (target < current) begin
                    for (k = 0; k < steps; k = k + 1)
                        press_button(2);
                end

                check(dut.humidity == target,
                      "set_humidity reaches requested target");
            end
        end
    endtask

    // Wait a bounded number of cycles for a tank state.
    task wait_for_tank;
        input [1:0] target;
        input integer timeout_cycles;
        integer k;
        reg found;
        begin
            found = 1'b0;

            for (k = 0; k < timeout_cycles; k = k + 1) begin
                if (dut.tank_status === target)
                    found = 1'b1;
                if (!found)
                    @(posedge clk);
            end

            #1;
            check(found && (dut.tank_status === target),
                  "tank status reached expected state");
        end
    endtask

    // Check a multiplexed seven-segment digit.
    task check_digit;
        input [3:0] target_an;
        input [6:0] expected_seg;
        input [8*100-1:0] label;
        integer k;
        reg found;
        begin
            found = 1'b0;

            for (k = 0; k < 30; k = k + 1) begin
                if (an === target_an)
                    found = 1'b1;
                if (!found)
                    @(negedge clk);
            end

            #1;
            check(found &&
                  (an === target_an) &&
                  (seg === expected_seg), label);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        btnC = 0;
        btnU = 0;
        btnD = 0;
        btnL = 0;
        btnR = 0;

        // -------------------------------------------------
        // 1. Startup and reset
        // -------------------------------------------------
        wait_cycles(5);

        check(dut.humidity == 0 &&
              dut.tank_status == 0 &&
              dut.mode == MODE_IDLE,
              "Power-up initializes safe state");

        press_button(0);

        check(dut.humidity == 0 &&
              dut.tank_status == 0 &&
              dut.mode == MODE_IDLE &&
              !dut.defrost_request &&
              !dut.fault_latched,
              "Reset restores safe initial state");

        // -------------------------------------------------
        // 2. Debounce and humidity input
        // -------------------------------------------------
        @(negedge clk);
        btnU = 1'b1;
        @(negedge clk);
        btnU = 1'b0;

        wait_cycles(10);

        check(dut.humidity == 0,
              "Short button pulse does not change humidity");

        @(negedge clk);
        btnU = 1'b1;
        wait_cycles(36);
        check(dut.humidity == 5,
              "Long button press increments humidity once");

        @(negedge clk);
        btnU = 1'b0;
        wait_cycles(10);

        press_button(1);
        check(dut.humidity == 10,
              "Second press increments humidity");

        press_button(2);
        check(dut.humidity == 5,
              "Down button decrements humidity");

        press_button(0);
        check(dut.humidity == 0,
              "Reset clears humidity");

        // -------------------------------------------------
        // 3. Humidity LED and seven-segment display
        // Assumes active-low anodes and active-low segments.
        // -------------------------------------------------
        set_humidity(5);

        check(led[6:0] == 7'd5,
              "Humidity LED output represents 5");

        check_digit(4'b1110, 7'b0010010,
                    "Display ones digit is 5");
        check_digit(4'b1101, 7'b1000000,
                    "Display tens digit is 0");
        check_digit(4'b1011, 7'b1000000,
                    "Display hundreds digit is 0");
        check_digit(4'b0111, 7'b1111111,
                    "Fourth digit is blank");

        set_humidity(50);
        check(led[6:0] == 7'd50,
              "Humidity LED output represents 50");

        check_digit(4'b1110, 7'b1000000,
                    "50 ones digit is 0");
        check_digit(4'b1101, 7'b0010010,
                    "50 tens digit is 5");

        set_humidity(75);
        check(led[6:0] == 7'd75,
              "Humidity LED output represents 75");

        check_digit(4'b1110, 7'b0010010,
                    "75 ones digit is 5");
        check_digit(4'b1101, 7'b1111000,
                    "75 tens digit is 7");

        set_humidity(100);
        check(led[6:0] == 7'd100,
              "Humidity LED output represents 100");

        check_digit(4'b1110, 7'b1000000,
                    "100 ones digit is 0");
        check_digit(4'b1101, 7'b1000000,
                    "100 tens digit is 0");
        check_digit(4'b1011, 7'b1111001,
                    "100 hundreds digit is 1");

        press_button(1);
        check(dut.humidity == 100,
              "Humidity saturates at 100");

        set_humidity(0);
        check(dut.humidity == 0 && led[6:0] == 7'd0,
              "Humidity returns to zero");

        press_button(2);
        check(dut.humidity == 0,
              "Humidity saturates at zero");

        // -------------------------------------------------
        // 4. Humidity thresholds and hysteresis
        // -------------------------------------------------
        set_humidity(55);
        wait_cycles(140);

        check(dut.mode == MODE_IDLE && !led[7],
              "Below activation threshold compressor stays off");

        press_button(1);
        wait_cycles(5);

        check(dut.mode == MODE_DEH &&
              led[7] && led[8] && led[9],
              "60 percent activates dehumidification");

        set_humidity(55);
        wait_cycles(5);

        check(dut.mode == MODE_DEH && led[7],
              "Hysteresis retains demand at 55 percent");

        press_button(2);
        wait_cycles(5);

        check(dut.mode == MODE_IDLE && !led[7],
              "50 percent turns compressor off");

        // -------------------------------------------------
        // 5. Minimum compressor off-time
        // -------------------------------------------------
        set_humidity(60);
        wait_cycles(5);

        check(dut.mode != MODE_DEH && led[14],
              "Compressor is locked out during minimum off-time");

        wait_cycles(160);

        check(dut.mode == MODE_DEH &&
              led[7] && !led[14],
              "Compressor starts after lockout expires");

        // -------------------------------------------------
        // 6. Tank warning and full-tank protection
        // -------------------------------------------------
        press_button(3);

        check(dut.tank_status == 1 &&
              led[13] && !led[11] && led[7],
              "Low tank warning does not stop compressor");

        // Request FULL and bound the wait to avoid hanging.
        @(negedge clk);
        btnL = 1'b1;

        wait_for_tank(2'b10, 50);

        check(!led[7] && !led[8],
              "Full tank gates compressor and fan");

        @(negedge clk);
        btnL = 1'b0;
        wait_cycles(16);

        check(dut.tank_status == 2 &&
              dut.mode == MODE_TANK_FULL &&
              !led[7] && led[11] && !led[8],
              "Full tank shuts down compressor and fan");

        // -------------------------------------------------
        // 7. Defrost priority and recovery
        // -------------------------------------------------
        press_button(4);
        wait_cycles(5);

        check(dut.defrost_request &&
              dut.mode == MODE_TANK_FULL &&
              !led[7],
              "Full tank safety overrides defrost demand");

        press_button(3);
        wait_cycles(5);

        check(dut.tank_status == 0 &&
              dut.mode == MODE_DEFROST &&
              !led[7] && led[8] && led[10],
              "Defrost begins after tank clears");

        press_button(4);
        wait_cycles(5);

        check(!dut.defrost_request &&
              dut.mode == MODE_RECOVERY &&
              !led[7],
              "Defrost exit enters recovery");

        wait_cycles(100);

        check(dut.mode == MODE_DEH && led[7],
              "Recovery completes and demand resumes");

        // -------------------------------------------------
        // 8. Invalid tank state and fault recovery
        // Hierarchy must match your RTL.
        // -------------------------------------------------
        force dut.u_tank_controller.tank_status = 2'b11;
        wait_cycles(5);

        check(dut.fault_latched &&
              dut.mode == MODE_FAULT &&
              !led[7] && !led[8] && led[12],
              "Invalid tank state latches fault and shuts down");

        release dut.u_tank_controller.tank_status;
        wait_cycles(3);

        press_button(0);

        check(!dut.fault_latched &&
              dut.mode == MODE_IDLE &&
              !led[7] &&
              dut.tank_status == 0,
              "Reset clears fault after invalid condition is removed");

        // -------------------------------------------------
        // 9. LED status map
        // -------------------------------------------------
        set_humidity(60);
        wait_cycles(160);

        check(led[6:0] == 7'd60 &&
              led[7] && led[8] && led[9] &&
              !led[10] && !led[11] &&
              !led[12] && !led[13],
              "LED map reports humidity and DEHUMIDIFY status");

        press_button(4);
        wait_cycles(5);

        check(led[10] && !led[7] && led[8],
              "LED map reports defrost with compressor off");

        // -------------------------------------------------
        // Final report
        // -------------------------------------------------
        $display("");
        $display("========================================");
        $display("SIMULATION SUMMARY");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("FINAL PASS");
        else
            $display("FINAL FAIL");

        $finish;
    end

endmodule
