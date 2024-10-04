//`timescale 1ns/1ns
module vgg #(
    parameter data_bit = 9,
    parameter pixel_bit = 36,
    parameter ker_bias_bit = 16,
    parameter matrix_num = 9,
    parameter parallelism = 8
) (
    input clk,reset,
    input start,
    input [data_bit-1:0] data_in,
    input signed [ker_bias_bit*matrix_num*parallelism-1:0] kernel,
    input signed [ker_bias_bit*parallelism-1:0] bias,
    input signed [pixel_bit*parallelism-1:0] pixel_read,
    output [3:0]  state,
    output [3:0]  next_state,
    output        mode,
    output        input_en,
    output [15:0] input_addr,
    output [5:0]  input_offset,
    output        read_en,
    output [15:0] read_addr,
    output        write_en,
    output [15:0] write_addr,
    output [7:0]  kernel_addr,
    output [5:0]  bias_addr,
    output        write_l1_picture_en,
    output [7:0]  write_picture_counter,
    output [15:0] write_picture_total_counter,
    output        finish,
    output signed [pixel_bit*parallelism-1:0] pixel_write
);

    wire [data_bit*matrix_num-1:0] matrix;
    wire signed [pixel_bit*parallelism-1:0] pixel;


    control control
    (
        .clk(clk),.reset(reset),
        .start(start),
        .state(state),
        .next_state(next_state),
        .mode(mode),
        .input_en(input_en),
        .input_addr(input_addr),
        .input_offset(input_offset),
        .read_en(read_en),
        .read_addr(read_addr),
        .write_en(write_en),
        .write_addr(write_addr),
        .kernel_addr(kernel_addr),
        .bias_addr(bias_addr),
        .write_l1_picture_en(write_l1_picture_en),
        .write_picture_counter(write_picture_counter),
        .write_picture_total_counter(write_picture_total_counter),
        .finish(finish)
    );

    line_buffer line_buffer
    (
        .clk(clk),.reset(reset),
        .data_in(data_in),
        .matrix(matrix)
    );

    genvar i;
    generate
        for(i=0; i<parallelism; i=i+1) begin
            cnn cnn //PE
            (
                .matrix_in(matrix),
                .kernel(kernel[i*ker_bias_bit*matrix_num +: ker_bias_bit*matrix_num]),
                .pixel(pixel[i*pixel_bit +: pixel_bit])
            );
            bias_relu bias_relu
            (
                .clk(clk),.reset(reset),
                .mode(mode),
                .input_offset(input_offset),
                .bias(bias[i*ker_bias_bit +: ker_bias_bit]),
                .pixel_read(pixel_read[i*pixel_bit +: pixel_bit]),
                .pixel(pixel[i*pixel_bit +: pixel_bit]),
                .pixel_write(pixel_write[i*pixel_bit +: pixel_bit])
            );
        end
    endgenerate
    
endmodule