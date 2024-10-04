//`timescale 1ns/1ns
module line_buffer #(
    parameter line_buffer_size = 226,
    parameter buffer_bit = 9
) (
    input clk,reset,
    input [buffer_bit-1:0] data_in,
    output reg [buffer_bit*9-1:0] matrix
);

    integer i,j;

    reg [buffer_bit-1:0] line_buffer_0 [0:line_buffer_size-1];
    reg [buffer_bit-1:0] line_buffer_1 [0:line_buffer_size-1];
    reg [buffer_bit-1:0] line_buffer_2 [0:2];


    always @(*) begin
        matrix = {line_buffer_2[2],line_buffer_2[1],line_buffer_2[0],
                  line_buffer_1[2],line_buffer_1[1],line_buffer_1[0],
                  line_buffer_0[2],line_buffer_0[1],line_buffer_0[0]};
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0;i<line_buffer_size;i=i+1)begin
                line_buffer_0[i] <= 9'd0;
                line_buffer_1[i] <= 9'd0;
                line_buffer_2[i] <= 9'd0;
            end
        end
        else begin
            for (i=0;i<line_buffer_size-1;i=i+1)begin
                line_buffer_0[i] <= line_buffer_0[i+1];
                line_buffer_1[i] <= line_buffer_1[i+1];
            end
            for (j=0;j<2;j=j+1)begin
                line_buffer_2[j] <= line_buffer_2[j+1];
            end
            line_buffer_0[line_buffer_size-1] <= line_buffer_1[0];
            line_buffer_1[line_buffer_size-1] <= line_buffer_2[0];
            line_buffer_2[2] <= data_in;
        end
    end
endmodule