//`timescale 1ns/1ns

`define buffer_total_size 226*2+3,
`define convolution_times 226*224-2,
//FSM
`define reset_state         4'd0
`define padding_l1          4'd1
`define not_full            4'd2
`define full                4'd3
`define next_input          4'd4
`define next_kernel_bias    4'd5
`define next_bias           4'd6
`define next_layer          4'd7
`define padding_l2          4'd8
`define next_input_l2       4'd9
`define next_kernel_bias_l2 4'd10
`define finish_state        4'd11
//Mode
`define layer1 1'b0
`define layer2 1'b1

module control #(
    parameter buffer_total_size = 226*2+3,
    parameter convolution_times = 226*224-2
) (
    input clk,reset,
    input start,
    output reg [3:0]  state,
    output reg [3:0]  next_state,
    output reg        mode,
    output reg        input_en,
    output reg [15:0] input_addr,
    output reg [5:0]  input_offset,
    output reg        read_en,
    output reg [15:0] read_addr,
    output reg        write_en,
    output reg [15:0] write_addr,
    output reg [7:0]  kernel_addr,
    output reg [5:0]  bias_addr,
    output reg        write_l1_picture_en,
    output reg [7:0]  write_picture_counter,
    output reg [15:0] write_picture_total_counter,
    output reg        finish
);


//====================================================================================\\
//    FSM                                                                              ||
//====================================================================================//

    always @(*) begin
        case(state)
            `reset_state: begin
                if(start) next_state = `padding_l1;
                else next_state = `reset_state; 
            end
            `padding_l1: begin
                next_state = `not_full;
            end
            `not_full: begin
                if(input_addr >= buffer_total_size-1) next_state = `full;
                else next_state = `not_full;
            end
            `full: begin
                if(write_addr >= convolution_times-2) begin
                    case(mode)
                        `layer1: begin
                            if(kernel_addr >= 8'd7 && input_offset >= 6'd2) next_state = `next_layer;
                            else if(input_offset >= 6'd2) next_state = `next_kernel_bias;
                            else next_state = `next_input;
                        end
                        `layer2: begin
                            if(kernel_addr >= 8'd7 && input_offset >= 6'd63) next_state = `finish_state;
                            else if(kernel_addr >= 8'd7) next_state = `next_input_l2;
                            else next_state = `next_kernel_bias_l2;
                        end
                    endcase
                end
                else next_state = `full;
            end
            `next_input: begin
                next_state = `not_full;
            end
            `next_kernel_bias: begin
                next_state = `not_full;
            end
            `next_layer: begin
                next_state = `padding_l2;
            end
            `padding_l2: begin
                next_state = `not_full;
            end
            `next_input_l2: begin
                next_state = `not_full;
            end
            `next_kernel_bias_l2: begin
                next_state = `not_full;
            end
            `finish_state: begin
                next_state = `reset_state; 
            end
            default: next_state = `reset_state;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if(reset) state <= `reset_state;
        else state <= next_state;	
    end


//	operation state display
/*
	initial begin
	//start
		$display("start");
	//later1
		wait(state == `full) begin		
			$display("---------------------");
			$display();
			$display("layer1");
			$display();
			$display("---------------------");
			//$stop;
			//$finish;
		end
		$display("layer1 start");
	//later2		
		wait(mode)begin
			$display("---------------------");
			$display();
			$display("layer2");
			$display();
			$display("---------------------");
			//$stop;
			//$finish;			
		end
		$display("layer2 start");
	//finish
		wait(state == `finish_state) begin
			$display("finish");
			//$stop;
		end
	end
*/	

//====================================================================================\\
//  Mode                                                                               ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) mode <= `layer1;
        else if(state == `next_layer) mode <= `layer2;
        else mode <= mode;
    end

//====================================================================================\\
//  Input Enable                                                                       ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) input_en <= 1'b0;
        else begin
            if(input_addr >= 16'd51075) input_en <= 1'b0;
            else if(next_state == `not_full || next_state == `full) input_en <= 1'b1;
            else input_en <= 1'b0;
        end
    end

//====================================================================================\\
//  Input Address                                                                      ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) input_addr <= 16'd0;
        else begin
            if (input_en) begin
                if (input_addr >= 16'd51075) input_addr <= 16'd0;
                else input_addr <= input_addr + 16'd1;
            end
            else input_addr <= 16'd0;
        end
    end

//====================================================================================\\
//  Input Offset                                                                       ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) input_offset <= 6'd0;
        else begin
            case(mode)
                `layer1: begin
                    if(state == `next_input || state == `next_kernel_bias || state == `next_layer) begin
                        if(input_offset >= 6'd2) input_offset <= 6'd0;
                        else input_offset <= input_offset + 16'd1;
                    end
                    else input_offset <= input_offset;
                end
                `layer2: begin
                     if(state == `next_input_l2) begin
                        if(input_offset >= 6'd63) input_offset <= 6'd0;
                        else input_offset <= input_offset + 16'd1;
                    end
                    else input_offset <= input_offset;
                end
            endcase
        end
    end

//====================================================================================\\
//  Read Enable                                                                        ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) read_en <= 16'd0;
        else begin
            if(read_addr == 16'd50621) read_en <= 1'b0;
            else if (next_state == `full) read_en <= 1'b1;
            else read_en <= 1'b0;
        end
    end

//====================================================================================\\
//  Read Address                                                                       ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) read_addr <= 16'd0;
        else begin
            if(read_en) begin
                if(read_addr >= 16'd50621) read_addr <= 16'd0; 
                else read_addr <= read_addr + 16'd1;
            end
            else read_addr <= 16'd0;   
        end
    end

//====================================================================================\\
//  Write Enable                                                                       ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) write_en <= 16'd0;
        else begin
            if(write_addr == 16'd50621) write_en <= 1'b0;
            else if (read_en) write_en <= 1'b1;
            else write_en <= 1'b0;
        end
    end

//====================================================================================\\
//  Write Address                                                                      ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) write_addr <= 16'd0;
        else begin
            if(write_en) begin
                if(write_addr >= 16'd50621) write_addr <= 16'd0;
                else write_addr <= write_addr + 16'd1;
            end
            else write_addr <= 16'd0;
        end
    end

//====================================================================================\\
//  Kernel Address                                                                     ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) kernel_addr <= 8'd0;
        else begin
            case(mode)
                `layer1: begin
                    if(state == `next_kernel_bias || state == `next_layer) begin
                        if(kernel_addr >= 8'd7) kernel_addr <= 8'd0;
                        else kernel_addr <= kernel_addr + 8'd1;
                    end
                    else kernel_addr <= kernel_addr;
                end
                `layer2: begin
                    if(state == `next_kernel_bias_l2 || state == `next_input_l2) begin
                        if(kernel_addr >= 8'd7) kernel_addr <= 8'd0;
                        else kernel_addr <= kernel_addr + 8'd1;
                    end
                    else kernel_addr <= kernel_addr;
                end
            endcase
        end
    end

//====================================================================================\\
//  Bias Address                                                                       ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) bias_addr <= 6'd0;
        else begin
            case(mode)
                `layer1: begin
                    if(state == `next_kernel_bias || state == `next_layer) begin
                        if(bias_addr >= 6'd7) bias_addr <= 6'd0; 
                        else bias_addr <= bias_addr + 6'd1;
                    end
                    else bias_addr <= bias_addr;
                end
                `layer2: begin
                    if(state == `next_kernel_bias_l2 || state == `next_input_l2) begin
                        if(bias_addr >= 6'd7) bias_addr <= 6'd0; 
                        else bias_addr <= bias_addr + 6'd1;
                    end
                    else bias_addr <= bias_addr;
                end
            endcase
        end
    end

//====================================================================================\\
//  Write L1 Picture Enable                                                            ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) write_l1_picture_en <= 16'd0;
        else begin
            case(mode)
                `layer1: begin
                    if (input_offset >= 6'd2 && state == `full) begin
                        if(write_picture_counter == 8'd224 || write_picture_counter == 8'd225) write_l1_picture_en <= 1'b0;
                        else write_l1_picture_en <= 1'b1;
                    end
                    else write_l1_picture_en <= 1'b0;
                end
                `layer2: begin
                    if (input_offset >= 6'd63 && state == `full) begin
                        if(write_picture_counter == 8'd224 || write_picture_counter == 8'd225) write_l1_picture_en <= 1'b0;
                        else write_l1_picture_en <= 1'b1;
                    end
                    else write_l1_picture_en <= 1'b0;
                end
            endcase
        end
    end

//====================================================================================\\
//  Write Picture Counter                                                              ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) write_picture_counter <= 8'd0;
        else begin
            if(write_en) begin
                if(write_picture_counter >= 8'd225) write_picture_counter <= 8'd0;
                else write_picture_counter <= write_picture_counter + 8'd1;
            end
            else write_picture_counter <= 8'd0;
        end
    end

//====================================================================================\\
//  Write Picture Total Counter                                                        ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) write_picture_total_counter <= 16'd0;
        else begin
            if(write_en) begin
                if(write_picture_counter == 8'd224 || write_picture_counter == 8'd225) write_picture_total_counter <= write_picture_total_counter;
                else if(write_picture_total_counter >= 16'd50175) write_picture_total_counter <= 16'd0;
                else write_picture_total_counter <= write_picture_total_counter + 16'd1;
            end
            else write_picture_total_counter <= 16'd0;
        end
    end

//====================================================================================\\
//  Finish                                                                             ||
//====================================================================================//

    always @(posedge clk or posedge reset) begin
        if(reset) finish <= 1'b0;
        else begin
            if (state == `finish_state) finish <= 1'b1;
            else finish <= 1'b0;
        end
    end

endmodule