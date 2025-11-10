module fpu (
    input [31:0] src1,
    input [31:0] src2,
    input sub,
    output logic [31:0] fpuOut
);


logic operation;
logic Comp_enable;
logic output_sign;

logic [31:0] operand_a, operand_b;
logic [23:0] significand_a,significand_b;
logic [7:0] exponent_diff;


logic [30:0] significand_a_shift, significand_b_shift;
logic [7:0] exponent_b_shift;

logic [31:0] significand_res;
logic [24:0] significand_round;

logic [4:0] shift;

//for operations always operand_a must not be less than b_operand
assign {Comp_enable,operand_a,operand_b} = (src1[30:0] < src2[30:0]) ? {1'b1, src2, src1} : {1'b0, src1, src2};

// sub: 1 for sub, 0 for add
assign fpuOut[31] = sub ? Comp_enable ? !operand_a[31] : operand_a[31] : operand_a[31] ;

// operation 1 for add, 0 for sub
assign operation = sub ? operand_a[31] ^ operand_b[31] : ~(operand_a[31] ^ operand_b[31]);

//Assigining significand values according to Hidden Bit.
//If exponent is equal to zero then hidden bit will be 0 for that respective significand else it will be 1
assign significand_a = (|operand_a[30:23]) ? {1'b1,operand_a[22:0]} : {1'b0,operand_a[22:0]};
assign significand_b = (|operand_b[30:23]) ? {1'b1,operand_b[22:0]} : {1'b0,operand_b[22:0]};

//Evaluating Exponent Difference
assign exponent_diff = operand_a[30:23] - operand_b[30:23];

//Shifting significand_b according to exponent_diff
assign significand_a_shift = {significand_a, 7'd0};
assign significand_b_shift = {significand_b, 7'd0} >> exponent_diff;

assign significand_res = (operation) ? ({1'b0, significand_a_shift} + {1'b0, significand_b_shift}) : ({1'b0, significand_a_shift} - {1'b0, significand_b_shift});

always_comb begin
    if (significand_res[6]) begin
        if(significand_res[7]) significand_round = significand_res[31:7] + 25'd1;
        else significand_round = significand_res[31:7] + {24'd0, (|significand_res[6:0])};
    end
    else significand_round = significand_res[31:7];
end


//Result will be equal to Most 23 bits if carry generates else it will be Least 22 bits.
always_comb begin
    if (operation) begin // 1 for add
        shift = 5'd0;
        if(significand_round[24]) begin
            fpuOut[22:0] = significand_round[23:1];
            fpuOut[30:23] = operand_a[30:23] + 8'd1;
        end
        else begin
            fpuOut[22:0] = significand_round[22:0];
            fpuOut[30:23] = operand_a[30:23];
        end

    end
    else begin // 0 for sub
        casez(significand_round)
            25'b0_1???_????_????_????_????_????: begin
                shift = 5'd0;
                fpuOut[22:0] = significand_round[22:0];
            end
            25'b0_01??_????_????_????_????_????: begin
                shift = 5'd1;
                fpuOut[22:0] = {significand_round[21:0], 1'd0};
            end
            25'b0_001z_????_????_????_????_????: begin
                shift = 5'd2;
                fpuOut[22:0] = {significand_round[20:0], 2'd0};
            end
            25'b0_0001_????_????_????_????_????: begin
                shift = 5'd3;
                fpuOut[22:0] = {significand_round[19:0], 3'd0};
            end
            25'b0_0000_1???_????_????_????_????: begin
                shift = 5'd4;
                fpuOut[22:0] = {significand_round[18:0], 4'd0};
            end
            25'b0_0000_01??_????_????_????_????: begin
                shift = 5'd5;
                fpuOut[22:0] = {significand_round[17:0], 5'd0};
            end
            25'b0_0000_001?_????_????_????_????: begin
                shift = 5'd6;
                fpuOut[22:0] = {significand_round[16:0], 6'd0};
            end
            25'b0_0000_0001_????_????_????_????: begin
                shift = 5'd7;
                fpuOut[22:0] = {significand_round[15:0], 7'd0};
            end
            25'b0_0000_0000_1???_????_????_????: begin
                shift = 5'd8;
                fpuOut[22:0] = {significand_round[14:0], 8'd0};
            end
            25'b0_0000_0000_01??_????_????_????: begin
                shift = 5'd9;
                fpuOut[22:0] = {significand_round[13:0], 9'd0};
            end
            25'b0_0000_0000_001?_????_????_????: begin
                shift = 5'd10;
                fpuOut[22:0] = {significand_round[12:0], 10'd0};
            end
            25'b0_0000_0000_0001_????_????_????: begin
                shift = 5'd11;
                fpuOut[22:0] = {significand_round[11:0], 11'd0};
            end
            25'b0_0000_0000_0000_1???_????_????: begin
                shift = 5'd12;
                fpuOut[22:0] = {significand_round[10:0], 12'd0};
            end
            25'b0_0000_0000_0000_01??_????_????: begin
                shift = 5'd13;
                fpuOut[22:0] = {significand_round[9:0], 13'd0};
            end
            25'b0_0000_0000_0000_001?_????_????: begin
                shift = 5'd14;
                fpuOut[22:0] = {significand_round[8:0], 14'd0};
            end
            25'b0_0000_0000_0000_0001_????_????: begin
                shift = 5'd15;
                fpuOut[22:0] = {significand_round[7:0], 15'd0};
            end
            25'b0_0000_0000_0000_0000_1???_????: begin
                shift = 5'd16;
                fpuOut[22:0] = {significand_round[6:0], 16'd0};
            end
            25'b0_0000_0000_0000_0000_01??_????: begin
                shift = 5'd17;
                fpuOut[22:0] = {significand_round[5:0], 17'd0};
            end
            25'b0_0000_0000_0000_0000_001?_????: begin
                shift = 5'd18;
                fpuOut[22:0] = {significand_round[4:0], 18'd0};
            end
            25'b0_0000_0000_0000_0000_0001_????: begin
                shift = 5'd19;
                fpuOut[22:0] = {significand_round[3:0], 19'd0};
            end
            25'b0_0000_0000_0000_0000_0000_1???: begin
                shift = 5'd20;
                fpuOut[22:0] = {significand_round[2:0], 20'd0};
            end
            25'b0_0000_0000_0000_0000_0000_01??: begin
                shift = 5'd21;
                fpuOut[22:0] = {significand_round[1:0], 21'd0};
            end
            25'b0_0000_0000_0000_0000_0000_001?: begin
                shift = 5'd22;
                fpuOut[22:0] = {significand_round[0], 22'd0};
            end
            25'b0_0000_0000_0000_0000_0000_0001: begin
                shift = 5'd23;
                fpuOut[22:0] = 23'd0;
            end
            default: begin
                shift = 5'd0;
                fpuOut[22:0] = 23'd0;
            end
        endcase
        fpuOut[30:23] = operand_a[30:23] - {3'd0, shift};
    end
end



endmodule