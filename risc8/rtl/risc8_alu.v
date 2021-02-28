//-----------------------------------------------------------------------------
//          (C) COPYRIGHT 2000 S.Aravindhan 
//
// This program is free software; you can redistribute it and/or
// modify it provided this header is preserved on all copies. 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
//
// Author   : S.Aravindhan
// File     : risc8_alu.v
// Version  : 1.0
// Abstract : ALU module, also this module generates the next cycle flags.
//
// History:
// ============================================================================
// 02/06/20000  arvind   1.0      Initial Release
// ============================================================================

module risc8_alu (/*AUTOARG*/
  // Outputs
  next_psw, alu_out, divide_by_0, 
  // Inputs
  clk, rst_n, a_src, b_src, carry_src, alu_cmd, invert_b, lu_op, 
  flag_op, muldiv_op, queue_out, a_data, b_data, psw, scan_mode
  ); 
 
  output [7:0]  next_psw;     // next psw
  output [7:0]  alu_out;      // alu output 
  output        divide_by_0;  // divide by zero
 
  input         clk;          // clock 
  input         rst_n;        // reset 
  input [1:0]   a_src;        // alu a-bus source: 
  input [1:0]   b_src;        // alu b-bus source 
  input [2:0]   carry_src;    // carry source 
  input [3:0]   alu_cmd;      // alu command 
  input         invert_b;     // invert b-bus
  input         lu_op;        // Logic Unit Operation
  input [2:0]   flag_op;      // flag operation 
  input [5:0]   muldiv_op;    // mulitier/divider operation 
  input [7:0]   queue_out;    // immediate data 
  input [7:0]   a_data;       // registerbank a data 
  input [7:0]   b_data;       // registerbank b data 
  input [7:0]   psw;          // psw 
  input         scan_mode;    // test scan mode pin

  reg [7:0]     lu_out;
  reg [8:0]     p_reg;
  reg [7:0]     a_reg;
  reg [7:0]     a_alu;
  reg [7:0]     b_alu_tmp;
  reg [7:0]     a_lu;
  reg [7:0]     b_lu;
  reg [7:0]     a_adder;
  reg [7:0]     b_adder;
  reg           carry_in;
  reg           save_carry;
  reg           save_a7;
 
  wire [7:0]    adder_out;
  wire [7:0]    b_alu;
  wire          next_zflag;
  wire          next_nflag;
  wire          next_vflag;
  wire          next_cflag;
  wire          carry_in_tmp;
  wire          carry_out;
  wire          sel_imm_a;
  wire          mul;
  wire          div;
  wire          muldiv_init;
  wire          muldiv_save0;
  wire          muldiv_save1;
  wire          div_restore;
  wire          word_zero;      // Word Operation

  assign mul          = muldiv_op[0];
  assign div          = muldiv_op[1];
  assign muldiv_init  = muldiv_op[2];
  assign muldiv_save0 = muldiv_op[3];
  assign muldiv_save1 = muldiv_op[4];
  assign div_restore  = muldiv_op[5];
  assign divide_by_0  = (b_data == 8'h0) & (alu_cmd == `ALUthb) & muldiv_init;

  assign sel_imm_a    = a_src[0];
  assign word_zero    = flag_op == 3'b110;
  assign next_zflag   = (alu_out == 8'h0) & (word_zero? psw[0] : 1'b1);
  assign next_cflag   = (alu_cmd == `ALUadd)? carry_out: (
                        (alu_cmd == `ALUshl)? a_lu[7]  : a_lu[0]);
  assign next_nflag   = alu_out[7];
  assign next_vflag   = ( a_alu[7] & b_alu_tmp[7]  & ~alu_out[7]) |
                        (~a_alu[7] & ~b_alu_tmp[7] &  alu_out[7]);
 
  assign next_psw[7:4]= {psw[7:5], ((flag_op == 3'b100)? 1'b0 : psw[4])}; 
  assign next_psw[3:0]= (flag_op[1:0] == 2'b00)? psw[3:0] : ( 
                        (flag_op[1:0] == 2'b01)? {psw[3], next_nflag, psw[1], 
                                                  next_zflag} : (
                        (flag_op[1:0] == 2'b10)? {psw[3], next_nflag, 
                                                  next_cflag, next_zflag} : 
                        {next_vflag, next_nflag, next_cflag, next_zflag}));

  assign b_alu        = (invert_b | (div & ~p_reg[8]))? ~b_alu_tmp : b_alu_tmp;

  assign carry_in_tmp = (div & ~p_reg[8])     ? 1'b1   : (
                        (carry_src == 3'b000) ? 1'b0   : (
                        (carry_src == 3'b001) ? 1'b1   : (
                        (carry_src == 3'b010) ? ~psw[1]: (
                        (carry_src == 3'b011) ? save_carry : psw[1]))));

  // ALU A_Data Selector
  always @ (/*AUTOSENSE*/a_data or a_reg or div or div_restore or mul
            or muldiv_save0 or muldiv_save1 or p_reg or queue_out
            or sel_imm_a)
    begin
      if(sel_imm_a)
        a_alu = queue_out;
      else if(mul | div_restore | muldiv_save1)
        a_alu = p_reg[7:0];
      else if(div)
        a_alu = {p_reg[6:0], a_reg[7]};
      else if(muldiv_save0)
        a_alu = a_reg;
      else
        a_alu = a_data;
    end

  // ALU B_Data Selector
  always @ (/*AUTOSENSE*/a_reg or b_data or b_src or div_restore
            or mul or p_reg or save_a7)
    begin
      if(b_src == 2'b10)
        b_alu_tmp = {8{save_a7}}; // change to previous sign extension
      else if(mul & a_reg[0])
        b_alu_tmp = b_data; 
      else if((mul & ~a_reg[0]) | (div_restore & ~p_reg[8]) |
              (b_src == 2'b01))
        b_alu_tmp = 8'b0; 
      else
        b_alu_tmp = b_data; 
    end

  // a_data and b_data to Logic unit and the adder unit.

  // When ADD_ALU_LATCHES = 1'b1, to redeuce the switching in the Adder and 
  // the Logic-Unit 33 latches are introduced.  For test coverage these latches 
  // are bypassed when the scan mode signal (scan_mode) is high.
  always @ (a_alu or b_alu or carry_in_tmp or scan_mode or lu_op)
    begin
      if(`ADD_ALU_LATCHES == 1'b0)
        begin 
          a_lu     = a_alu;
          b_lu     = b_alu;
          a_adder  = a_alu;
          b_adder  = b_alu;
          carry_in = carry_in_tmp;
        end
      else // For Power Optimization
        begin
          if(lu_op | scan_mode)
            begin
              a_lu = a_alu;
              b_lu = b_alu;
            end
          if(!lu_op | scan_mode)
            begin
              a_adder  = a_alu;
              b_adder  = b_alu; 
              carry_in = carry_in_tmp;
            end
        end
    end

  // Logic unit 
  always @ (a_lu or b_lu or alu_cmd or psw) 
    begin 
      case(alu_cmd) 
      `ALUand:   lu_out = a_lu & b_lu; 
      `ALUor :   lu_out = a_lu | b_lu; 
      `ALUxor:   lu_out = a_lu ^ b_lu; 
      `ALUnot:   lu_out = ~a_lu; 
      `ALUshl:   lu_out = {a_lu[6:0], 1'b0}; 
      `ALUshr:   lu_out = {1'b0, a_lu[7:1]}; 
      `ALUasr:   lu_out = {a_lu[7], a_lu[7:1]}; 
      `ALUror:   lu_out = {a_lu[0], a_lu[7:1]}; 
      `ALUrorc:  lu_out = {psw[1], a_lu[7:1]}; 
      `ALUtha:   lu_out = a_lu; 
      `ALUthb:   lu_out = b_lu; 
      default:   lu_out = 8'bx; 
      endcase 
    end 

   // adder
   DW01_add #(8) U0 (a_adder, b_adder, carry_in, adder_out, carry_out);

   // If you don't have DesignWare, then you can use the faster 'rbcla_adder', 
   // carry look-ahead adder or the slower ripple adder in the sim directory.
   // rbcla_adder #(8,4) U0 (a_adder, b_adder, carry_in, adder_out, carry_out);

   assign alu_out = (alu_cmd == `ALUadd)? adder_out : lu_out;

  // multiplier/divider p_reg and a_reg
  always @ (posedge clk or negedge rst_n)
    begin
      if(!rst_n)
        begin
          p_reg      <= 9'h0;
          a_reg      <= 8'h0;
          save_carry <= 1'b0;
          save_a7    <= 1'b0;
        end
      else
        begin
          save_carry <= carry_out;
          save_a7    <= a_alu[7];
          if(muldiv_init)
            begin
              p_reg <= 9'h0;
              a_reg <= a_data;
            end
          else if(mul)
            begin
              p_reg <= {1'b0, carry_out, adder_out[7:1]};  
              a_reg <= {adder_out[0], a_reg[7:1]};  
            end
          else if(div)
            begin
              p_reg <={(p_reg[7] ^ carry_out ^ carry_in), adder_out};  
              a_reg <= {a_reg[6:0], ~(p_reg[7] ^ carry_out ^ carry_in)};  
            end
          else if(div_restore)
            p_reg <= {(p_reg[7] ^ carry_out ^ carry_in), adder_out};  
        end
    end

endmodule 
 
