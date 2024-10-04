//`timescale 1ns/1ns
`define layer1 1'b0
`define layer2 1'b1
module bias_relu #(
    parameter pixel_bit = 36,
    parameter ker_bias_bit = 16
) (
    input clk,reset,
    input mode,
    input [5:0] input_offset,
    input signed [ker_bias_bit-1:0] bias,
    input signed [pixel_bit-1:0] pixel_read,pixel,
    output reg signed [pixel_bit-1:0] pixel_write
);

    wire signed [pixel_bit-1:0] pixel_temp0,pixel_temp1,pixel_bias;
    wire signed [pixel_bit-1:0] pixel_temp2;

    assign pixel_temp0 = pixel;
    assign pixel_temp1 = pixel_read + pixel;
    assign pixel_bias = pixel_temp1 + bias;
    assign pixel_temp2 = (pixel_bias > 0) ? pixel_bias : 36'd0;
    
    always @(posedge clk or posedge reset) begin
        if(reset) pixel_write <= 36'd0;
        else begin
            case(mode)
                `layer1: begin
                    if(input_offset == 6'd0) pixel_write <= pixel_temp0;
                    else if(input_offset == 6'd2) pixel_write <= pixel_temp2;
                    else pixel_write <= pixel_temp1;
                end
                `layer2: begin
                    if(input_offset == 6'd0) pixel_write <= pixel_temp0;
                    else if(input_offset == 6'd63) pixel_write <= pixel_temp2;
                    else pixel_write <= pixel_temp1;
                end
            endcase
        end
    end

endmodule