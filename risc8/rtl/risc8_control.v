//-----------------------------------------------------------------------------
//          (C) COPYRIGHT 2000 S.Aravindhan
//
// This program is free software; you can redistribute it and/or
// modify it  provided this header is preserved on all copies. 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
//
// Author   : S.Aravindhan
// File     : risc8_control.v
// Abstract : Control Unit and Instruction Decoder.
//            Please use 160 column window to view this file 
//          
// History:
// ============================================================================
// 02/06/2000  arvind   1.0      Initial Release
// ============================================================================

module risc8_control (/*AUTOARG*/
  // Outputs
  alu_cmd, carry_src, a_addr, b_addr, w_addr, wr_reg, a_src, b_src, 
  muldiv_op, flag_op, data_op, addr_op, invert_b, lu_op, inc_pc, 
  opcode_op, int_type, 
  // Inputs
  clk, rst_n, nmi, int, queue_out, psw, data_ready, queue_count, 
  divide_by_0
  ); 

  output [3:0]  alu_cmd;       // alu command
  output [2:0]  carry_src;     // carry source
  output [3:0]  a_addr;        // a-bus read reg. address
  output [3:0]  b_addr;        // b-bus read reg. address
  output [3:0]  w_addr;        // write-back reg. address
  output        wr_reg;        // write register
  output [1:0]  a_src;         // alu a-bus source
  output [1:0]  b_src;         // alu b-bus source
  output [5:0]  muldiv_op;     // mulitier/divider operation
  output [2:0]  flag_op;       // flag operation
  output [2:0]  data_op;       // data cycle operation     
  output [3:0]  addr_op;       // address register operation
  output        invert_b;      // invert b-bus 
  output        lu_op;         // Logic Unit Operation
  output [1:0]  inc_pc;        // increment pc
  output [4:0]  opcode_op;     // opcode fetch operations
  output [1:0]  int_type;      // interrupt type
 
  input         clk;           // clock
  input         rst_n;         // reset
  input         nmi;           // non-maskable interrupt
  input         int;           // maskable interrupt
  input  [7:0]  queue_out;     // instruction queue fifo output
  input  [7:0]  psw;           // psw
  input         data_ready;    // data ready
  input  [2:0]  queue_count;   // instruction queue count
  input         divide_by_0;   // divide by zero

  reg    [3:0]  state;
  reg    [3:0]  alu_cmd;
  reg    [2:0]  carry_src;
  reg           invert_b; 
  reg    [3:0]  a_addr;
  reg    [3:0]  b_addr;
  reg    [3:0]  w_addr;
  reg           wr_reg;
  reg    [1:0]  a_src;
  reg    [1:0]  b_src;
  reg    [7:0]  opcode_tmp;
  reg    [1:0]  inc_pc;
  reg    [4:0]  opcode_op_d;
  reg           lu_op;
  reg    [2:0]  flag_op;
  reg    [5:0]  muldiv_op;
  reg    [2:0]  data_op;
  reg    [3:0]  addr_op;

  reg           condition;
  reg    [51:0] decode;

  reg           nmi_reg;
  reg           int_reg;
  reg           div_reg;
  reg           int_processing;
  reg           next_int_processing;
  reg    [1:0]  int_type;
  reg    [1:0]  next_int_type;

  wire   [3:0]  operan;
  wire   [3:0]  operan1;
  wire   [3:0]  operan2;
  wire          opcode_valid;
  wire          sel_opcode_tmp;
  wire          clear_opcode;
  wire          load_opcode_tmp;
  wire   [7:0]  opcode;

  wire          queue_count_gt0;
  wire          queue_count_gt1;
  wire          lda_sta_opcode;
  wire          int_pending;
 
  assign opcode_op       = decode[11:7];
  assign sel_opcode_tmp  = opcode_op_d[2];
  assign clear_opcode    = opcode_op_d[3];
  assign load_opcode_tmp = opcode_op[1];
  assign operan          = {1'b0, opcode[2:0]};
  assign operan1         = {1'b0, opcode[1:0], 1'b0};
  assign operan2         = {1'b0, opcode[1:0], 1'b1};
  assign int_pending     = ((state == `ST0) &  (nmi_reg | 
                            (int_reg & psw[4]) | div_reg));
  assign lda_sta_opcode  = (opcode[7:4] == 4'b1111); // load/store only
  assign queue_count_gt0 = ~(queue_count == 3'b000);
  assign queue_count_gt1 = (queue_count > 3'b001);
  assign opcode_valid    = sel_opcode_tmp | 
                           (~lda_sta_opcode & queue_count_gt0 & ~clear_opcode) |
                           (lda_sta_opcode & queue_count_gt1 & ~clear_opcode);
  assign opcode          = (sel_opcode_tmp)? opcode_tmp : queue_out;

  // store the interrupt/nmi/divide_by_zero till they are serviced
  always @ (posedge clk or negedge rst_n)
    begin
      if(!rst_n)
        begin
          nmi_reg <= 1'b0;
          int_reg <= 1'b0;
          div_reg <= 1'b0;
        end
      else
        begin
          if(int_type == 2'b01)
            nmi_reg <= 1'b0;
          else if(nmi_reg)
            nmi_reg <= 1'b1;
          else
            nmi_reg <= nmi;
 
          if(int_type == 2'b10)
            div_reg <= 1'b0;
          else if(div_reg)
            div_reg <= 1'b1;
          else
            div_reg <= divide_by_0;
 
          if(int_type == 2'b11)
            int_reg <= 1'b0;
          else if(int_reg)
            int_reg <= 1'b1;
          else
            int_reg <= (int); // psw[4] = ie
        end
    end

  // moving controls from DECODE stage to EXECUTE stage.
  always @ (posedge clk or negedge rst_n)
    begin
      if(!rst_n)
        begin 
          int_processing <= 0;
          int_type       <= 2'b00; 
          opcode_tmp     <= 8'h00;
          lu_op          <= 1'b1;
          {state, alu_cmd, carry_src, invert_b, a_addr, b_addr, 
           w_addr, wr_reg, a_src, b_src, flag_op, muldiv_op, inc_pc, 
           opcode_op_d, data_op, addr_op} <= 0;
        end
      else
        begin
          if(load_opcode_tmp)
            opcode_tmp  <= queue_out;
            lu_op       <= ~(decode[47:44] == `ALUadd);

          if(data_ready) 
            begin
              int_processing <= next_int_processing;
              int_type       <= next_int_type; 
              {state, alu_cmd, carry_src, invert_b, a_addr, b_addr, 
               w_addr, wr_reg, a_src, b_src, flag_op, muldiv_op, inc_pc, 
               opcode_op_d, data_op, addr_op} <= decode;
            end
        end
    end

  // branch condition check; Flags Mapping: {V, N, C, Z} = psw[3:0]
  always @ (opcode or psw)
    begin
      case(opcode[2:0])
        3'b000: condition = (psw[0]);                       // EQ       
        3'b001: condition = (~psw[0]);                      // NE       
        3'b010: condition = (~(psw[3] ^ psw[2]) & ~psw[0]); // GT      
        3'b011: condition = (psw[3] ^ psw[2]);              // LT     
        3'b100: condition = (psw[1]);                       // CS    
        3'b101: condition = (psw[2]);                       // CC 
        3'b110: condition = (psw[3]);                       // NS      
        3'b111: condition = 1'b1;                           // AL      
        endcase
    end
 
  // INSTRUCTION DECODE: One BIG case statement!!
  // outputs
  // state, alu_cmd, carry_src, invert_b, a_addr, b_addr, w_addr, wr_reg,   
  // a_src, b_src, flag_op, muldiv_op, inc_pc, opcode_op, data_op, addr_opp
  

  always @ (opcode or state or opcode_valid or operan or operan1 or operan2 or
            a_addr or b_addr or w_addr or alu_cmd or invert_b or a_src or b_src
            or queue_count_gt0 or queue_count_gt1 or condition or carry_src or
            divide_by_0 or int_pending or int_processing or nmi_reg or div_reg 
            or int_type) 
    begin
    decode = {`ST0, `ALUpre, `CRYc, `PIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRCp, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPnul };
    next_int_type = 2'b00; next_int_processing = 0;
    if(int_pending | int_processing) 
     begin
     next_int_processing = 1;
     case(state[2:0])  
     3'b000: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRr0,  `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC11000, `DAOPwr, `ADOPrsp};
     3'b001: decode = {`ST2, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRpsw, `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10000, `DAOPwr, `ADOPinc};
     3'b010: decode = {`ST3, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRpcl, `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10000, `DAOPwr, `ADOPinc};
     3'b011: decode = {`ST4, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10000, `DAOPwr, `ADOPinc};
     3'b100: begin
     if(nmi_reg) 
      begin
      next_int_type = 2'b01;
      decode = {`ST5, `ALUtha, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRpcl, `Nrg, `ASRC1, `BSRCp, `FLclie, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPint};
      end
     else if(div_reg) 
      begin
      next_int_type = 2'b10;
      decode = {`ST5, `ALUtha, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRpcl, `Nrg, `ASRC1, `BSRCp, `FLclie, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPint};
      end
     else 
      begin
      next_int_type = 2'b11;
      decode = {`ST5, `ALUtha, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRpcl, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPack, `ADOPint};
      end
     end
     3'b101: begin
     next_int_processing = 0; 
      next_int_type = int_type;
     decode = {`ST0, `ALUtha, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRpch, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC11001, `DAOPno, `ADOPnul};
     end
     endcase
     end

    else if(opcode_valid)
     begin 
     case(opcode[7:3]) 
     `OPadd:  decode = {`ST0, `ALUadd, `CRY0, `NIb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPadc:  decode = {`ST0, `ALUadd, `CRYc, `NIb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul}; 
     `OPsub:  decode = {`ST0, `ALUadd, `CRY1, `INb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPsbc:  decode = {`ST0, `ALUadd, `CRYn, `INb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPinc:  decode = {`ST0, `ALUadd, `CRY1, `NIb, operan,  `ADRpvb, operan, `Wrg, `ASRC0, `BSRC1, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPdec:  decode = {`ST0, `ALUadd, `CRY0, `INb, operan,  `ADRpvb, operan, `Wrg, `ASRC0, `BSRC1, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPcmp:  decode = {`ST0, `ALUadd, `CRY1, `INb, `ADRr0,  operan, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPsbr:  decode = {`ST0, `ALUadd, `CRY1, `INb, operan,  `ADRr0, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzcnv, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPand:  decode = {`ST0, `ALUand, `CRYc, `NIb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzn,   `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPor:   decode = {`ST0, `ALUor , `CRYc, `NIb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzn,   `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul}; 
     `OPxor:  decode = {`ST0, `ALUxor, `CRYc, `NIb, `ADRr0,  operan, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLzn,   `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPnot:  decode = {`ST0, `ALUnot, `CRYc, `NIb, operan,  `ADRpvb, operan, `Wrg, `ASRC0, `BSRCp, `FLzn,   `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPshl:  decode = {`ST0, `ALUshl, `CRYc, `NIb, operan,  `ADRpvb, operan, `Wrg, `ASRC0, `BSRCp, `FLzcn,  `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPshr:  decode = {`ST0, `ALUshr, `CRYc, `NIb, operan,  `ADRpvb, operan, `Wrg, `ASRC0, `BSRCp, `FLzcn,  `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPspecial0:  // wrps, rdps, nop1, nop2
      casex(opcode[2:0])
      3'b000: decode = {`ST0, `ALUtha, `CRYc, `PIb, `ADRr0,  `ADRpvb, `ADRpsw, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      3'b001: decode = {`ST0, `ALUtha, `CRYc, `PIb, `ADRpsw, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      3'b01?: decode = {`ST0, `ALUpre, `CRYc, `PIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRCp, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      3'b1??: decode = {`ST0, `ALUpre, `CRYc, `PIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRCp, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      endcase
     `OPspecial1: begin // jmp,  ret, ror, rorc, asr
      if(!opcode[2])
       begin
        case(state[0]) // jmp an
        1'b0: decode = {`ST1, `ALUtha, `CRYc, `NIb, operan1, `ADRpvb, `ADRpcl, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10000, `DAOPno, `ADOPldl};
        1'b1: decode = {`ST0, `ALUtha, `CRYc, `NIb, operan2, `ADRpvb, `ADRpch, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC11000, `DAOPno, `ADOPldh};
        endcase
        end
      if(opcode[2])
       begin
        case(opcode[1:0]) // ret, ror, rorc, asr
        2'b00: 
         case({state[2:0]}) // ret
         3'b000: decode = {`ST1, `ALUadd, `CRY0, `INb, `ADRspl, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC10110, `DAOPno, `ADOPldl};
         3'b001: decode = {`ST2, `ALUadd, `CRYs, `INb, `ADRsph, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPrd, `ADOPldh};
         3'b010: decode = {`ST3, `ALUpre, `CRYp, `NIb, `ADRsph, `ADRpvb, `ADRpch, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPrd, `ADOPdec};
         3'b011: decode = {`ST4, `ALUpre, `CRYp, `NIb, `ADRsph, `ADRpvb, `ADRpcl, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPrd, `ADOPdec};
         3'b100: decode = {`ST5, `ALUpre, `CRYp, `NIb, `ADRsph, `ADRpvb, `ADRpsw, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPrd, `ADOPdec};
         3'b101: decode = {`ST6, `ALUtha, `CRYp, `NIb, `ADRpcl, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPldlssp};
         3'b110: decode = {`ST0, `ALUtha, `CRYp, `NIb, `ADRpch, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC11001, `DAOPno, `ADOPldh};
         endcase
       2'b01: decode = {`ST0, `ALUror,  `CRYc, `PIb, `ADRr0, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLzcn, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
       2'b10: decode = {`ST0, `ALUrorc, `CRYc, `PIb, `ADRr0, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLzcn, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
       2'b11: decode = {`ST0, `ALUasr,  `CRYc, `PIb, `ADRr0, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLzcn, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
       endcase
       end
       end
     `OPjmpr:  // jmpr #8-bit
      casex({condition, queue_count_gt0, state[1:0]})  
      4'b??00: decode = {`ST1, `ALUpre, `CRY0, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDnul, `PC1, `OPC00111, `DAOPno, `ADOPnul};
      4'b0001: decode = {`ST1, `ALUpre, `CRY0, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      4'b0101: decode = {`ST0, `ALUpre, `CRY0, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      4'b1001: decode = {`ST1, `ALUpre, `CRY0, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPnul};
      4'b1101: decode = {`ST2, `ALUadd, `CRY0, `NIb, `ADRpva, `ADRpcl, `ADRpcl, `Wrg, `ASRC1, `BSRC0, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPldl};
      4'b??10: decode = {`ST0, `ALUadd, `CRYs, `NIb, `ADRpch, `ADRpvb, `ADRpch, `Wrg, `ASRC0, `BSRC2, `FLnul, `MDnul, `PC0, `OPC11001, `DAOPno, `ADOPldh};
      endcase
     `OPjmpa:  // jmpa #16-bit
      casex({condition, queue_count_gt1, queue_count_gt0, state[1:0]})  
      5'b???00: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC3, `OPC00111, `DAOPno, `ADOPnul};
      5'b00001: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      5'b0?101,
      5'b01?01: decode = {`ST2, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00101, `DAOPno, `ADOPnul};
      5'b00010: decode = {`ST2, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      5'b01?10,
      5'b0?110: decode = {`ST0, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPnul};
      5'b10001: decode = {`ST1, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpcl, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      5'b10101: decode = {`ST1, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpcl, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPnul};
      5'b11?01: decode = {`ST2, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpcl, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPldl};
      5'b1??10: decode = {`ST0, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpch, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC11001, `DAOPno, `ADOPldh};
      endcase
     `OPjmps: // jmps #16-bit
      casex({condition, queue_count_gt1, queue_count_gt0, state[2:0]})  
      6'b???000: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC3, `OPC00111, `DAOPno, `ADOPnul};
      6'b000001: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      6'b0?1001, 
      6'b01?001: decode = {`ST2, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00101, `DAOPno, `ADOPnul};
      6'b000010: decode = {`ST2, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      6'b0?1010,
      6'b01?010: decode = {`ST0, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPnul};
      6'b100001: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      6'b101001: decode = {`ST1, `ALUpre, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPnul};
      6'b11?001: decode = {`ST2, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRr0,  `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPwr, `ADOPrsp};
      6'b1??010: decode = {`ST3, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRpsw, `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPwr, `ADOPinc};
      6'b???011: decode = {`ST4, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRpcl, `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPwr, `ADOPinc};
      6'b???100: decode = {`ST5, `ALUpre, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRspl, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPwr, `ADOPinc};
      6'b???101: decode = {`ST6, `ALUtha, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRpcl, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC10100, `DAOPno, `ADOPldlisp};
      6'b???110: decode = {`ST0, `ALUtha, `CRYp, `NIb, `ADRspl, `ADRpch, `ADRpch, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC11001, `DAOPno, `ADOPldh};
      endcase
     `OPwrr0:  decode = {`ST0, `ALUtha, `CRYc, `PIb, operan, `ADRpvb, `ADRr0, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPrdr0:  decode = {`ST0, `ALUtha, `CRYc, `PIb, `ADRr0, `ADRpvb, operan, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
     `OPmovsp:  // mov SP An & mov An SP; move to/from sp
      case({opcode[2], state[0]})
      2'b00: decode = {`ST1, `ALUtha, `CRYc, `PIb, operan1, `ADRpvb, `ADRspl, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      2'b01: decode = {`ST0, `ALUtha, `CRYc, `PIb, operan2, `ADRpvb, `ADRsph, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul}; 
      2'b10: decode = {`ST1, `ALUtha, `CRYc, `PIb, `ADRspl, `ADRpvb, operan1, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPnul}; 
      2'b11: decode = {`ST0, `ALUtha, `CRYc, `PIb, `ADRsph, `ADRpvb, operan2, `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul}; 
      endcase 
     `OPincdec16: // 16 bit inc/ dec
      case({opcode[2], state[0]})
      2'b00: decode = {`ST1, `ALUadd, `CRY1, `NIb, operan1, `ADRpvb, operan1, `Wrg, `ASRC0, `BSRC1, `FLzcn,  `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      2'b01: decode = {`ST0, `ALUadd, `CRYc, `NIb, operan2, `ADRpvb, operan2, `Wrg, `ASRC0, `BSRC1, `FLwzcn, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul}; 
      2'b10: decode = {`ST1, `ALUadd, `CRY0, `INb, operan1, `ADRpvb, operan1, `Wrg, `ASRC0, `BSRC1, `FLzcn,  `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPnul}; 
      2'b11: decode = {`ST0, `ALUadd, `CRYc, `INb, operan2, `ADRpvb, operan2, `Wrg, `ASRC0, `BSRC1, `FLwzcn, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul}; 
      endcase
     `OPldi: // 16 bit inc/ dec
      casex({queue_count_gt0, state[0]})
      2'b?0: decode = {`ST1, `ALUtha, `CRYc, `PIb, `ADRpva, `ADRpvb, operan, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00111, `DAOPno, `ADOPnul};
      2'b01: decode = {`ST1, `ALUtha, `CRYc, `PIb, `ADRpva, `ADRpvb, operan, `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPnul};
      2'b11: decode = {`ST0, `ALUtha, `CRYc, `PIb, `ADRpva, `ADRpvb, operan, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      endcase
     `OPmul: 
      case(state)
      `ST0: decode = {`ST1, `ALUtha, `CRY0, `NIb, `ADRr0,  `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDini, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST1: decode = {`ST2, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST2: decode = {`ST3, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST3: decode = {`ST4, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST4: decode = {`ST5, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST5: decode = {`ST6, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST6: decode = {`ST7, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST7: decode = {`ST8, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST8: decode = {`ST9, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDmul, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST9: decode = {`STa, `ALUtha, `CRY0, `NIb, `ADRpva, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLnul, `MDsv0, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `STa: decode = {`ST0, `ALUtha, `CRY0, `NIb, `ADRpva, `ADRpvb, operan,  `Wrg, `ASRC0, `BSRC0, `FLnul, `MDsv1, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      endcase
     `OPdiv: begin
      case(state)
      `ST0: decode = {`ST1, `ALUthb, `CRY0, `NIb, `ADRr0,  operan, `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDini, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST1: begin
       if(divide_by_0)
        decode = {`ST0, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC1, `OPC00001, `DAOPno, `ADOPnul};
       else
        decode = {`ST2, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
       end
      `ST2: decode = {`ST3, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST3: decode = {`ST4, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST4: decode = {`ST5, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST5: decode = {`ST6, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST6: decode = {`ST7, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST7: decode = {`ST8, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST8: decode = {`ST9, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDdiv, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `ST9: decode = {`STa, `ALUadd, `CRY0, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC0, `BSRC0, `FLnul, `MDres, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `STa: decode = {`STb, `ALUtha, `CRY0, `NIb, `ADRpva, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRC0, `FLnul, `MDsv0, `PC0, `OPC00000, `DAOPno, `ADOPnul};
      `STb: decode = {`ST0, `ALUtha, `CRY0, `NIb, `ADRpva, `ADRpvb, operan,  `Wrg, `ASRC0, `BSRC0, `FLnul, `MDsv1, `PC1, `OPC00001, `DAOPno, `ADOPnul};
      endcase
      end
     `OPldstr:  // ldr (An)/ Str (An)
      case({opcode[2],state[1:0]})
      3'b000: decode = {`ST1, `ALUtha, `CRYc, `NIb, operan1, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPldlsv};
      3'b001: decode = {`ST2, `ALUtha, `CRYc, `NIb, operan2, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPrd, `ADOPldh};
      3'b010: decode = {`ST0, `ALUtha, `CRYc, `NIb, `ADRpva, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPrec};
      3'b100: decode = {`ST1, `ALUtha, `CRYc, `NIb, operan1, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPno, `ADOPldlsv};
      3'b101: decode = {`ST2, `ALUtha, `CRYc, `NIb, operan2, `ADRr0,  `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPwr, `ADOPldh};
      3'b110: decode = {`ST0, `ALUtha, `CRYc, `NIb, operan2, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC1, `OPC00001, `DAOPno, `ADOPrec};
      endcase
     `OPpsh:  // psh
      case({state[0]})
      1'b0: decode = {`ST1, `ALUadd, `CRY1, `NIb, `ADRspl, operan,  `ADRspl, `Wrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC1, `OPC00000, `DAOPwr, `ADOPrsp};
      1'b1: decode = {`ST0, `ALUadd, `CRYs, `NIb, `ADRsph, `ADRpvb, `ADRsph, `Wrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPrec};
      endcase
     `OPpop: // pop
      case({state[1:0]})
      2'b00: decode = {`ST1, `ALUadd, `CRY0, `INb, `ADRspl, `ADRpvb, `ADRspl, `Wrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC1, `OPC00000, `DAOPno, `ADOPldlsv};
      2'b01: decode = {`ST2, `ALUadd, `CRYs, `INb, `ADRsph, `ADRpvb, `ADRsph, `Wrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC00000, `DAOPrd, `ADOPldh};
      2'b10: decode = {`ST0, `ALUadd, `CRYs, `NIb, `ADRsph, `ADRpvb, operan,  `Wrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPrec};
      endcase
     `OPldsto:  // ldo (An + 8-bit offset)/ Sto (An + 8-bit offset)
      case({opcode[2], queue_count_gt0, state[1:0]})
      4'b0000,
      4'b0100: decode = {`ST1, `ALUadd, `CRY0, `NIb, `ADRpva, operan1, `ADRpvw, `Nrg, `ASRC1, `BSRC0, `FLnul, `MDnul, `PC1, `OPC00111, `DAOPno, `ADOPldlsv};
      4'b0001: decode = {`ST1, `ALUadd, `CRY0, `NIb, `ADRpva, operan1, `ADRpvw, `Nrg, `ASRC1, `BSRC0, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPldl};
      4'b0101: decode = {`ST2, `ALUadd, `CRYs, `NIb, operan2, `ADRpvb, `ADRpvw, `Nrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPrd, `ADOPldh};
      4'b0010,
      4'b0110: decode = {`ST0, `ALUadd, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRr0,  `Wrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPrec};
      4'b1000,
      4'b1100: decode = {`ST1, `ALUadd, `CRY0, `NIb, `ADRpva, operan1, `ADRpvw, `Nrg, `ASRC1, `BSRC0, `FLnul, `MDnul, `PC1, `OPC00111, `DAOPno, `ADOPldlsv};
      4'b1001: decode = {`ST1, `ALUadd, `CRY0, `NIb, `ADRpva, operan1, `ADRpvw, `Nrg, `ASRC1, `BSRC0, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPldl};
      4'b1101: decode = {`ST2, `ALUadd, `CRYs, `NIb, operan2, `ADRr0,  `ADRpvw, `Nrg, `ASRC0, `BSRC1, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPwr, `ADOPldh};
      4'b1010,
      4'b1110: decode = {`ST0, `ALUadd, `CRYp, `NIb, operan2, `ADRr0,  `ADRpvw, `Nrg, `ASRC0, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPrec};
      endcase
     `OPlda:  // lda (16-bit absolute)
      casex({queue_count_gt1, state[1:0]})
      3'b?00: decode = {`ST1, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC3, `OPC00111, `DAOPno, `ADOPldlsv};
      3'b001: decode = {`ST1, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPldl};
      3'b101: decode = {`ST2, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00101, `DAOPrd, `ADOPldh};
      3'b?10: decode = {`ST0, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, operan,  `Wrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPrec};
      endcase
     `OPsta: // Sta ( + 16-bit absolute)
      casex({queue_count_gt1, state[1:0]})
      3'b?00: decode = {`ST1, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC3, `OPC00111, `DAOPno, `ADOPldlsv};
      3'b001: decode = {`ST1, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00100, `DAOPno, `ADOPldl};
      3'b101: decode = {`ST2, `ALUtha, `CRYp, `NIb, `ADRpva, operan,  `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00101, `DAOPwr, `ADOPldh};
      3'b?10: decode = {`ST0, `ALUtha, `CRYp, `NIb, `ADRpva, `ADRpvb, `ADRpvw, `Nrg, `ASRC1, `BSRCp, `FLnul, `MDnul, `PC0, `OPC00001, `DAOPno, `ADOPrec};
      endcase
     endcase 
     end
    end 

endmodule 
 
