//`timescale 1ns/1ns
module cnn #(
    parameter data_bit = 9,
    parameter ker_bias_bit = 16,
    parameter pixel_out_bit = 36,
    parameter matrix_num = 9,
    parameter matrix_in_bit = 9
) (
    input signed [matrix_in_bit*9-1:0] matrix_in,
    input signed [ker_bias_bit*9-1:0] kernel,
    output reg signed [pixel_out_bit-1:0] pixel
);

    integer i;
    reg signed [pixel_out_bit-1:0] matrix_temp [matrix_num-1:0];
    reg signed [pixel_out_bit-1:0] temp [5:0];


	
//============================
//	cnn/PE
//============================

    always @(*) begin
        for(i = 0; i < matrix_num; i = i + 1) begin
            matrix_temp[i] = {{27{matrix_in[i * matrix_in_bit + 8]}},matrix_in[i * matrix_in_bit +: matrix_in_bit]} *
                     {{20{kernel[i * ker_bias_bit + 15]}},kernel[i * ker_bias_bit +: ker_bias_bit]};
        end
    end

//============================
//	adder tree
//============================

    always @(*) begin
        temp[0] = matrix_temp[0] + matrix_temp[1];
        temp[1] = matrix_temp[2] + matrix_temp[3];
        temp[2] = matrix_temp[4] + matrix_temp[5];
        temp[3] = matrix_temp[6] + matrix_temp[7];
        temp[4] = temp[0] + temp[1];
        temp[5] = temp[2] + temp[3];
        pixel = temp[4] + temp[5] + matrix_temp[8];
    end
    
endmodule