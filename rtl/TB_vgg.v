`timescale 10ns/10ps
`define period 				10
`define img_max_size 		224 * 224 * 3 + 54
`define img_size 			224 * 224
`define padding_all_size 	226 * 226 * 3
`define pixel_1_size 		(226*224-2) * 8
`define pixel_2_size 		(226*224-2) * 64
`define l1_kernel_num 		1728
`define l2_kernel_num 		36864
`define l1_bias_num 		64
`define l2_bias_num 		64
`define picture_num 		64
`define path_img_in         	"/home/2023_HDL_32/work/hw5/pre/input_file/cat224.bmp"
`define path_l1_kernel      	"/home/2023_HDL_32/work/hw5/pre/input_file/conv1_kernel_hex.txt"
`define path_l1_bias        	"/home/2023_HDL_32/work/hw5/pre/input_file/conv1_bias_hex.txt"
`define path_l2_kernel      	"/home/2023_HDL_32/work/hw5/pre/input_file/conv2_kernel_hex.txt"
`define path_l2_bias        	"/home/2023_HDL_32/work/hw5/pre/input_file/conv2_bias_hex.txt"
`define path_check_data_in  	"/home/2023_HDL_32/work/hw5/pre/result/PE_result/data_in.txt"
`define path_check_data_in_2  	"/home/2023_HDL_32/work/hw5/pre/result/PE_result/data_in_2.txt"
`define path_result_ly1 		"/home/2023_HDL_32/work/hw5/pre/result/ly1"
`define path_result_ly2 		"/home/2023_HDL_32/work/hw5/pre/result/ly2"
`define path_result_PE 			"/home/2023_HDL_32/work/hw5/pre/result/PE_result"


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
`define next_picture_l2     4'd10
`define finish_state        4'd11

//Mode
`define layer1 1'b0
`define layer2 1'b1
module TB_vgg ();

    parameter img_bit 		= 8;
    parameter data_bit 		= 9;
    parameter ker_bia_bit 	= 16;
    parameter pixel_bit 	= 36;
    parameter matrix_num 	= 9;
    parameter picture_num 	= 64;
    parameter parallelism 	= 8;

    reg clk,reset;
    reg start;
    reg [data_bit-1:0] data_in;
    reg [ker_bia_bit*matrix_num*parallelism-1:0] kernel;
    reg [ker_bia_bit*parallelism-1:0] bias;
    reg [pixel_bit*parallelism-1:0] pixel_read;
    wire [3:0]  state;
    wire [3:0]  next_state;
    wire        mode;
    wire        input_en;
    wire [15:0] input_addr;
    wire [5:0]  input_offset;
    wire        read_en;
    wire [15:0] read_addr;
    wire        write_en;
    wire [15:0] write_addr;
    wire [7:0]  kernel_addr;
    wire [5:0]  bias_addr;
    wire        write_l1_picture_en;
    wire [7:0]  write_picture_counter;
    wire [15:0] write_picture_total_counter;
    wire        finish;
    wire [pixel_bit*parallelism-1:0] pixel_write;

    always begin
		#(`period/2.0) clk = ~clk;
	end

    initial begin
        clk = 1'b0;
        start = 1'b0;
        reset = 1'b1;
        #(`period);
        reset = 1'b0;
    end

    initial begin
        @(negedge reset);
        start = 1'b1;
    end



    vgg vgg
    (
        .clk(clk),.reset(reset),
        .start(start),
        .data_in(data_in),
        .kernel(kernel),
        .bias(bias),
        .pixel_read(pixel_read),
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
        .finish(finish),
        .pixel_write(pixel_write)
    );



//======================================================================\\
//  Open Picture                                                         ||
//======================================================================// 

    //Open Picture
    reg [img_bit-1:0] img_data [0 : `img_max_size - 1];

    integer img_in;
    integer img_w;
    integer img_h;
    integer offset;
    integer header;
    integer read_data;
    integer i_picture;
    integer l1_picture [0 : 63];
    integer l1_check [0 : 63];
    integer l2_picture [0 : 63];

    initial begin
        img_in  = $fopen(`path_img_in, "rb");
        for(i_picture = 0; i_picture < `picture_num; i_picture = i_picture + 1) begin
                l1_picture[i_picture] = $fopen($sformatf("%s/l1_p%0d.bmp",`path_result_ly1, i_picture), "wb");
                //l1_check[i_picture] =   $fopen($sformatf("%s/l1_p%0d.txt",`path_result_ly1, i_picture), "wb");
                l2_picture[i_picture] = $fopen($sformatf("%s/l2_p%0d.bmp",`path_result_ly2, i_picture), "wb");
        end
        read_data = $fread(img_data, img_in);

        img_w   = {img_data[21],img_data[20],img_data[19],img_data[18]};
        img_h   = {img_data[25],img_data[24],img_data[23],img_data[22]};
        offset  = {img_data[13],img_data[12],img_data[11],img_data[10]};

        for(header = 0; header < 54; header = header + 1) begin
            for(i_picture = 0; i_picture < `picture_num; i_picture = i_picture + 1) begin
                $fwrite(l1_picture[i_picture], "%c", img_data[header]);
                $fwrite(l2_picture[i_picture], "%c", img_data[header]);
            end
        end
    end

//======================================================================\\
//  Padding L1 Ram                                                       ||
//======================================================================// 

    //Padding Layer1
    reg [data_bit-1:0] padding_layer1 [0 : `padding_all_size - 1];
    integer i,j,k;

    always @(posedge clk) begin
        if(state==`padding_l1) begin
            for(j = 0; j < 226; j = j + 1) begin
                for(k = 0; k < 226; k = k + 1) begin
                    for(i = 0; i < 3; i = i + 1) begin
                        if((j==0) || (j==225) || (k==0) || (k==225)) begin
                            padding_layer1[j * 226 + k + (2-i) * 51076] <= 9'd0;
                        end
                        else begin
                            padding_layer1[j * 226 + k + (2-i) * 51076] <= {1'b0,img_data[((j - 1) * 224 + (k - 1)) * 3 + offset + i]};
                        end
                    end
                end
            end
        end
    end

//======================================================================\\
//  Kernel Ram                                                           ||
//======================================================================// 

    integer kernel_num;
    integer kernel_offset;
    integer check_kernel;
    integer check_kernel_open;
    reg [ker_bia_bit-1:0] l1_kernel [0 :  `l1_kernel_num-1];
    reg [ker_bia_bit-1:0] l2_kernel [0 :  `l2_kernel_num-1];

    initial begin
        $readmemh(`path_l1_kernel, l1_kernel);
        $readmemh(`path_l2_kernel, l2_kernel);
        check_kernel_open = $fopen($sformatf("%s/check_kernel.txt",`path_result_PE),"w");
        for(check_kernel=0;check_kernel<`l2_kernel_num;check_kernel=check_kernel+1) begin
            $fdisplay(check_kernel_open,"%h",l2_kernel [check_kernel]);
        end
        $fclose(check_kernel_open);
    end

    //read ram
    always @(negedge clk) begin
        if(state==`not_full) begin
            case(mode)
            `layer1: begin
                for(kernel_offset=0; kernel_offset<parallelism; kernel_offset = kernel_offset + 1) begin
                    for(kernel_num=0; kernel_num<9; kernel_num=kernel_num+1)begin
                        kernel[kernel_offset*144+ker_bia_bit*kernel_num +: ker_bia_bit] <= l1_kernel[kernel_offset*27+kernel_addr*216+input_offset*9+kernel_num];
                    end
                end
            end
            `layer2: begin
                for(kernel_offset=0; kernel_offset<parallelism; kernel_offset = kernel_offset + 1) begin
                    for(kernel_num=0; kernel_num<9; kernel_num=kernel_num+1)begin
                        kernel[kernel_offset*144+ker_bia_bit*kernel_num +: ker_bia_bit] <= l2_kernel[kernel_offset*64*9+kernel_addr*512*9+input_offset*9+kernel_num];
                    end
                end
            end
            endcase
        end
    end

    //test
    // reg [15:0] kernel_all_addr0,kernel_all_addr1;

    // always @(*) begin
        // kernel_all_addr0 = kernel_addr*512*9+input_offset*9;
        // kernel_all_addr1 = kernel_addr*512*9+input_offset*9+576;
    // end

//======================================================================\\
//  Bias Ram                                                             ||
//======================================================================// 
    integer bias_offset;
    reg [ker_bia_bit-1:0] l1_bias [0 : `l1_bias_num-1];
    reg [ker_bia_bit-1:0] l2_bias [0 : `l2_bias_num-1];

    initial begin
        $readmemh(`path_l1_bias, l1_bias);
        $readmemh(`path_l2_bias, l2_bias);
    end

    //read bias
    always @(negedge clk) begin
        if(state==`not_full) begin
            case(mode)
                `layer1: begin
                    for(bias_offset=0; bias_offset<parallelism; bias_offset = bias_offset + 1) begin
                        bias[ker_bia_bit*bias_offset +: ker_bia_bit] <= l1_bias[bias_addr*8+bias_offset];
                    end
                end
                `layer2: begin
                    for(bias_offset=0; bias_offset<parallelism; bias_offset = bias_offset + 1) begin
                        bias[ker_bia_bit*bias_offset +: ker_bia_bit] <= l2_bias[bias_addr*8+bias_offset];
                    end
                end
            endcase
        end
    end

    //test
    // reg [15:0] bias_all_addr0,bias_all_addr1;

    // always @(*) begin
        // bias_all_addr0 = bias_addr*8;
        // bias_all_addr1 = bias_addr*8+1; 
    // end

//======================================================================\\
//  Pixel Ram                                                            ||
//======================================================================//   

    //Read Pixel
    integer i_pixel_1;
    integer i_pixel_2;
    integer read_offset;
    integer write_offset;
    reg [pixel_bit-1:0] l1_pixel [0 : `pixel_1_size - 1];
    reg [pixel_bit-1:0] l2_pixel [0 : `pixel_2_size - 1];

    initial begin
        for(i_pixel_1=0; i_pixel_1<`pixel_1_size; i_pixel_1=i_pixel_1+1) begin
            l1_pixel [i_pixel_1] = 36'd0;
        end
        for(i_pixel_2=0; i_pixel_2<`pixel_2_size; i_pixel_2=i_pixel_2+1) begin
            l2_pixel [i_pixel_2] = 36'd0;
        end
    end

    //test
    // reg signed [35:0] test_read;

    //Read Pixel
    always @(negedge clk) begin
        if(read_en) begin
            case(mode)
                `layer1: begin
                    for(read_offset=0; read_offset<parallelism; read_offset=read_offset+1)begin
                        pixel_read[read_offset*pixel_bit +: pixel_bit] <= l1_pixel[read_addr + read_offset*50622];   
                    end
                end
                `layer2: begin
                    for(read_offset=0; read_offset<parallelism; read_offset=read_offset+1)begin
                        pixel_read[read_offset*pixel_bit +: pixel_bit] <= l2_pixel[read_addr + read_offset*50622 + kernel_addr * 8 * 50622];   
                    end
                end
            endcase
        end
    end


    //test
    // reg [19:0] read_all_addr0,read_all_addr1;

    // always @(*) begin
         //test
        // test_read = l1_pixel[0];
        // read_all_addr0 = read_addr + kernel_addr * 8 * 50622;
        // read_all_addr1 = read_addr + kernel_addr * 8 * 50622 + 50622;
    // end

    //test
    // reg signed [35:0] test_write;

    //Write Pixel
    always @(posedge clk) begin
        if(write_en) begin
            case(mode)
                `layer1: begin
                    for(write_offset=0; write_offset<parallelism; write_offset=write_offset+1)begin
                        l1_pixel[write_addr + write_offset*50622] <= pixel_write[write_offset*pixel_bit +: pixel_bit];   
                    end
                end
                `layer2: begin
                    for(write_offset=0; write_offset<parallelism; write_offset=write_offset+1)begin
                        l2_pixel[write_addr + write_offset*50622 + kernel_addr * 8 * 50622] <= pixel_write[write_offset*pixel_bit +: pixel_bit];   
                    end
                end
            endcase
        end
    end

    //test
    // always @(*) begin
        // test_write = pixel_write[35:0];
    // end
    
//======================================================================\\
//  Write Picture                                                        ||
//======================================================================//
    integer write_picture_offset;
    reg [7:0] picture_l1 [`img_size * 64 - 1:0];

    //test
    // reg [35:0] test3;
    // reg [7:0] test4;

    always @(posedge clk) begin
        if(write_l1_picture_en) begin
            case(mode)
                `layer1: begin
                    for(write_picture_offset=0; write_picture_offset<parallelism; write_picture_offset=write_picture_offset+1)begin
                        picture_l1[write_picture_total_counter + write_picture_offset*224*224 + kernel_addr*224*224*8] <= pixel_write[write_picture_offset*pixel_bit+4 +: 8];   
                        $fwrite(l1_picture[write_picture_offset+kernel_addr*8], "%c%c%c", pixel_write[write_picture_offset*pixel_bit+4 +: 8], pixel_write[write_picture_offset*pixel_bit+4 +: 8],pixel_write[write_picture_offset*pixel_bit+4 +: 8]);
                        $fdisplay(l1_check[write_picture_offset+kernel_addr*8], "%d", pixel_write[write_picture_offset*pixel_bit+4 +: 8]);
                        //test
                        // test3 <= picture_l1[0];
                        // test4 <= pixel_write[11:4];
                    end
                end
                `layer2: begin
                    for(write_picture_offset=0; write_picture_offset<parallelism; write_picture_offset=write_picture_offset+1)begin
                        $fwrite(l2_picture[write_picture_offset+kernel_addr*8], "%c%c%c", pixel_write[write_picture_offset*pixel_bit+7 +: 8], pixel_write[write_picture_offset*pixel_bit+7 +: 8],pixel_write[write_picture_offset*pixel_bit+7 +: 8]);
                    end
                end
            endcase   
        end
    end

//======================================================================\\
//  Padding L2 Ram                                                       ||
//======================================================================// 

    //Padding Layer2
    reg [data_bit-1:0] padding_layer2 [0 : 3268864 - 1];
    integer i_l2,j_l2,k_l2,l2_header;
    integer test_padding_l2 [0:63];

    always @(posedge clk) begin
        if(state==`padding_l2) begin
            for(j_l2 = 0; j_l2 < 226; j_l2 = j_l2 + 1) begin
                for(k_l2 = 0; k_l2 < 226; k_l2 = k_l2 + 1) begin
                    for(i_l2 = 0; i_l2 < 64; i_l2 = i_l2 + 1) begin
                        if(( j_l2==0) || ( j_l2==225) || (k_l2==0) || (k_l2==225)) begin
                            padding_layer2[ j_l2 * 226 + k_l2 + i_l2 * 51076] <= 9'd0;
                        end
                        else begin
                            padding_layer2[ j_l2 * 226 + k_l2 + i_l2 * 51076] <= {1'b0,picture_l1[((j_l2 - 1) * 224 + (k_l2 - 1)) + i_l2 * 50176]};
                        end
                    end
                end
            end
        end
    end

    initial begin
        for(i_l2 = 0; i_l2 < `picture_num; i_l2 = i_l2 + 1) begin
                test_padding_l2[i_l2] = $fopen($sformatf("%s/padding_l2/p%0d.bmp",`path_result_PE,i_l2), "wb");		
        end
        for(l2_header = 0; l2_header < 54; l2_header = l2_header + 1) begin
            for(i_l2 = 0; i_l2 < `picture_num; i_l2 = i_l2 + 1) begin
                $fwrite(test_padding_l2[i_l2], "%c", img_data[l2_header]);
            end
        end
        wait(state==`padding_l2);
        #(`period);
        #3;
        for(j_l2 = 0; j_l2 < 226; j_l2 = j_l2 + 1) begin
            for(k_l2 = 0; k_l2 < 226; k_l2 = k_l2 + 1) begin
                for(i_l2 = 0; i_l2 < 64; i_l2 = i_l2 + 1) begin
                    if(!(( j_l2==0) || ( j_l2==225) || (k_l2==0) || (k_l2==225))) begin
                        $fwrite(test_padding_l2[i_l2], "%c%c%c", padding_layer2[ j_l2 * 226 + k_l2 + i_l2 * 51076], padding_layer2[ j_l2 * 226 + k_l2 + i_l2 * 51076], padding_layer2[ j_l2 * 226 + k_l2 + i_l2 * 51076]);
                    end
                end
            end
        end
    end

//======================================================================\\
//  Input                                                                ||
//======================================================================//
    integer check_data_in;
    integer check_data_in_2;

    initial begin
        check_data_in = $fopen(`path_check_data_in,"w");
        check_data_in_2 = $fopen(`path_check_data_in_2,"w");
    end

    always @(negedge clk) begin
        if(input_en)begin
            case(mode)
                `layer1: begin
                    data_in <= padding_layer1[input_addr + input_offset*51076];
                    $fdisplay(check_data_in,"%d",padding_layer1[input_addr + input_offset*51076]);
                end
                `layer2: begin
                    data_in <= padding_layer2[input_addr + input_offset*51076];
                    $fdisplay(check_data_in_2,"%d",padding_layer2[input_addr + input_offset*51076]);
                end
            endcase
        end
    end

    //test
    // reg [21:0] test_input_addr;
    // always @(*) begin
        // test_input_addr = input_addr + input_offset*51076;
    // end


//======================================================================\\
//  Finish                                                               ||
//======================================================================//  

    //Finish
    initial begin
        wait(finish==1'b1);
        #(`period);
        #(`period);
        $fclose(img_in);
        $fclose(check_data_in);
        $fclose(check_data_in_2);
        for(i_picture = 0; i_picture < `picture_num; i_picture = i_picture + 1) begin
            $fclose(l1_picture[i_picture]);
            $fclose(l1_check[i_picture]);
            $fclose(l2_picture[i_picture]);
        end
        //$stop;
		$finish;
    end
    
endmodule

