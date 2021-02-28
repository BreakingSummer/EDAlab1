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
// File     : risc8.v
// Abstract : This is the risc8 top-level module. The lower level modules are
//            instantiated in this.
//
// History:
// ============================================================================
// 02/06/2000  arvind   1.0      Initial Release
// ============================================================================

module risc8 (/*AUTOARG*/
  // Outputs
  cycle, write, ifetch, iack, ie, address, data_out, scan_out, 
  // Inputs
  clk, rst_n, nmi, int, ready, data_in, scan_in, scan_en, scan_mode
  ); 

  output        cycle;      // bus cycle
  output        write;      // write cycle
  output        ifetch;     // instruction fetch
  output        iack;       // interrupt ack. cycle
  output        ie;         // interrupt enabled
  output [15:0] address;    // address bus
  output [7:0]  data_out;   // write data output
  output        scan_out;   // scan-test output
 
  input         clk;        // system clock
  input         rst_n;      // active low system reset
  input         nmi;        // non-maskable interrupt
  input         int;        // maskable interrupt
  input         ready;      // data ready
  input [7:0]   data_in;    // read data input
  input         scan_in;    // scan-test input
  input         scan_en;    // scan-test enable
  input         scan_mode;  // scan-test mode pin

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [3:0]            a_addr;         // From U_control of risc8_control.v
  wire [7:0]            a_data;         // From U_regb_biu of risc8_regb_biu.v
  wire [1:0]            a_src;          // From U_control of risc8_control.v
  wire [3:0]            addr_op;        // From U_control of risc8_control.v
  wire [3:0]            alu_cmd;        // From U_control of risc8_control.v
  wire [7:0]            alu_out;        // From U_alu of risc8_alu.v
  wire [3:0]            b_addr;         // From U_control of risc8_control.v
  wire [7:0]            b_data;         // From U_regb_biu of risc8_regb_biu.v
  wire [1:0]            b_src;          // From U_control of risc8_control.v
  wire [2:0]            carry_src;      // From U_control of risc8_control.v
  wire [2:0]            data_op;        // From U_control of risc8_control.v
  wire                  data_ready;     // From U_regb_biu of risc8_regb_biu.v
  wire                  divide_by_0;    // From U_alu of risc8_alu.v
  wire [2:0]            flag_op;        // From U_control of risc8_control.v
  wire [1:0]            inc_pc;         // From U_control of risc8_control.v
  wire [1:0]            int_type;       // From U_control of risc8_control.v
  wire                  invert_b;       // From U_control of risc8_control.v
  wire                  lu_op;          // From U_control of risc8_control.v
  wire [5:0]            muldiv_op;      // From U_control of risc8_control.v
  wire [7:0]            next_psw;       // From U_alu of risc8_alu.v
  wire [4:0]            opcode_op;      // From U_control of risc8_control.v
  wire [7:0]            psw;            // From U_regb_biu of risc8_regb_biu.v
  wire [2:0]            queue_count;    // From U_regb_biu of risc8_regb_biu.v
  wire [7:0]            queue_out;      // From U_regb_biu of risc8_regb_biu.v
  wire [3:0]            w_addr;         // From U_control of risc8_control.v
  wire                  wr_reg;         // From U_control of risc8_control.v
  // End of automatics

  risc8_alu U_alu 
    (/*AUTOINST*/
     // Outputs
     .next_psw                          (next_psw[7:0]),
     .alu_out                           (alu_out[7:0]),
     .divide_by_0                       (divide_by_0),
     // Inputs
     .clk                               (clk),
     .rst_n                             (rst_n),
     .a_src                             (a_src[1:0]),
     .b_src                             (b_src[1:0]),
     .carry_src                         (carry_src[2:0]),
     .alu_cmd                           (alu_cmd[3:0]),
     .invert_b                          (invert_b),
     .lu_op                             (lu_op),
     .flag_op                           (flag_op[2:0]),
     .muldiv_op                         (muldiv_op[5:0]),
     .queue_out                         (queue_out[7:0]),
     .a_data                            (a_data[7:0]),
     .b_data                            (b_data[7:0]),
     .psw                               (psw[7:0]),
     .scan_mode                         (scan_mode));
 
  risc8_regb_biu U_regb_biu
    (/*AUTOINST*/
     // Outputs
     .cycle                             (cycle),
     .write                             (write),
     .ifetch                            (ifetch),
     .iack                              (iack),
     .ie                                (ie),
     .address                           (address[15:0]),
     .data_out                          (data_out[7:0]),
     .psw                               (psw[7:0]),
     .a_data                            (a_data[7:0]),
     .b_data                            (b_data[7:0]),
     .queue_out                         (queue_out[7:0]),
     .queue_count                       (queue_count[2:0]),
     .data_ready                        (data_ready),
     // Inputs
     .clk                               (clk),
     .rst_n                             (rst_n),
     .a_addr                            (a_addr[3:0]),
     .b_addr                            (b_addr[3:0]),
     .w_addr                            (w_addr[3:0]),
     .wr_reg                            (wr_reg),
     .int_type                          (int_type[1:0]),
     .alu_out                           (alu_out[7:0]),
     .data_op                           (data_op[2:0]),
     .addr_op                           (addr_op[3:0]),
     .opcode_op                         (opcode_op[4:0]),
     .inc_pc                            (inc_pc[1:0]),
     .next_psw                          (next_psw[7:0]),
     .data_in                           (data_in[7:0]),
     .ready                             (ready));
 
  risc8_control U_control 
    (/*AUTOINST*/
     // Outputs
     .alu_cmd                           (alu_cmd[3:0]),
     .carry_src                         (carry_src[2:0]),
     .a_addr                            (a_addr[3:0]),
     .b_addr                            (b_addr[3:0]),
     .w_addr                            (w_addr[3:0]),
     .wr_reg                            (wr_reg),
     .a_src                             (a_src[1:0]),
     .b_src                             (b_src[1:0]),
     .muldiv_op                         (muldiv_op[5:0]),
     .flag_op                           (flag_op[2:0]),
     .data_op                           (data_op[2:0]),
     .addr_op                           (addr_op[3:0]),
     .invert_b                          (invert_b),
     .lu_op                             (lu_op),
     .inc_pc                            (inc_pc[1:0]),
     .opcode_op                         (opcode_op[4:0]),
     .int_type                          (int_type[1:0]),
     // Inputs
     .clk                               (clk),
     .rst_n                             (rst_n),
     .nmi                               (nmi),
     .int                               (int),
     .queue_out                         (queue_out[7:0]),
     .psw                               (psw[7:0]),
     .data_ready                        (data_ready),
     .queue_count                       (queue_count[2:0]),
     .divide_by_0                       (divide_by_0));
 
endmodule 
 
