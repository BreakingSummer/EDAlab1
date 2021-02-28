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
// File     : risc8_regb_biu.v
// Abstract : Register Bank and Bus Interface Unit
//
// History:
// ============================================================================
// 02/06/2000  arvind  1.0      Initial Release
// ============================================================================

 module risc8_regb_biu ( /*AUTOARG*/
  // Outputs
  cycle, write, ifetch, iack, ie, address, data_out, psw, a_data, 
  b_data, queue_out, queue_count, data_ready, 
  // Inputs
  clk, rst_n, a_addr, b_addr, w_addr, wr_reg, int_type, alu_out, 
  data_op, addr_op, opcode_op, inc_pc, next_psw, data_in, ready
  ); 
 
  output        cycle;              // bus-cycle
  output        write;              // write cycle
  output        ifetch;             // instruction fetch
  output        iack;               // interrupt ack. cycle
  output        ie;                 // interrupt enabled
  output [15:0] address;            // address bus
  output [7:0]  data_out;           // data output bus
  output [7:0]  psw;                // psw 
  output [7:0]  a_data;             // read data a 
  output [7:0]  b_data;             // read data b 
  output [7:0]  queue_out;          // instruction queue fifo output 
  output [2:0]  queue_count;        // instruction queue count
  output        data_ready;        
 
  input         clk;                // clock 
  input         rst_n;              // reset 
  input [3:0]   a_addr;             // a-bus read reg. address 
  input [3:0]   b_addr;             // b-bus read reg. address 
  input [3:0]   w_addr;             // write-back reg. address 
  input         wr_reg;             // write register 
  input [1:0]   int_type;           // interrupt type 
  input [7:0]   alu_out;            // write data 
  input [2:0]   data_op;            // data cycle operation 
  input [3:0]   addr_op;            // address register operation
  input [4:0]   opcode_op;          // opcode fetch operations
  input [1:0]   inc_pc;             // increment pc
  input [7:0]   next_psw;           // next psw low nibble
  input [7:0]   data_in;            // data input bus   
  input         ready;              // data ready
 
  reg  [15:0]   address;
  reg  [15:0]   address_save;
  reg  [15:0]   pc;
  reg  [15:0]   sp;
  reg  [7:0]    psw;
  reg  [7:0]    data_out; 

  reg [7:0]     ins_queue[0:3];     // 4-deep instruction queue
  reg [1:0]     in_pointer;         // ins. queue input pointer
  reg [1:0]     out_pointer;        // ins. queue output pointer
  reg [2:0]     queue_count;        // ins. queue count
  
  reg [1:0]     bus_state;          // bus state
  reg           write;
  reg           cycle;
  reg           iack;
  reg           ifetch;
  reg [1:0]     next_bus_state;          
  reg           next_write;
  reg           next_cycle;
  reg           next_iack;
  reg           next_ifetch;
  reg           clear_queue;
 
  wire [7:0]    w_data;             // write data
  wire [7:0]    queue_out;          // instruction queue output
  wire [15:0]   inc_address;
  wire [15:0]   dec_address;
  wire          ifetch_ready; 
  wire          queue_full; 
  wire          queue_almost_full; 
  wire          data_access;
  wire          write_access;
  wire          read_opcode;
  wire          stop_fetch;
  wire          iack_access;
  wire          data_access_next;
  wire          save_address_reg;
  wire          cycle_complete;

  assign read_opcode       = opcode_op[0] & data_ready; 
  assign stop_fetch        = opcode_op[4];
  assign ie                = psw[4]; 
  assign queue_full        = (queue_count == 3'b100);
  assign queue_almost_full = (queue_count == 3'b011);
  assign cycle_complete    = ~cycle  | (cycle & ready);
  assign ifetch_ready      = cycle & ifetch & ready;
  assign w_data            = (cycle & ~ifetch & ~iack & ~write)?  data_in : 
                                                                  alu_out; 
  assign write_access      = data_op[0];
  assign data_access       = data_op[1];
  assign iack_access       = data_op[2];

  assign save_address_reg  = (addr_op == `ADOPldlsv) | (addr_op == `ADOPrsp); 
  assign data_access_next  = (addr_op == `ADOPldl) | (addr_op == `ADOPldlisp) | 
                             (addr_op == `ADOPrsp) | (addr_op == `ADOPldlssp) |
                             (addr_op == `ADOPldlsv) | (addr_op == `ADOPint);
  assign data_ready        =  cycle_complete | 
                             (cycle & ifetch &  ~data_access_next);
  
  // -------------
  // REGISTER BANK
  // -------------

  // The Regbank could be replaced by a 2-read/1-write 3 port synchronous RAM 
  // as shown bellow Example: RAM3PORT U0(clk, a_addr, b_addr,wdata, wr_reg, 
  // A_DATA, b_data); Mapping: reg_file [0:7]= R0, R1, R2, R3, R4, R5, R6, R7 
 
  reg [7:0]     reg_file [0:7]; 

  assign a_data = (a_addr == `ADRpsw) ? psw      : ( 
                  (a_addr == `ADRpcl) ? pc[7:0]  : ( 
                  (a_addr == `ADRpch) ? pc[15:8] : ( 
                  (a_addr == `ADRspl) ? sp[7:0]  : ( 
                  (a_addr == `ADRsph) ? sp[15:8] : reg_file[a_addr[2:0]])))); 
 
  assign b_data = (b_addr == `ADRpsw) ? psw      : (
                  (b_addr == `ADRpcl) ? pc[7:0]  : (
                  (b_addr == `ADRpch) ? pc[15:8] :  reg_file[b_addr[2:0]])); 
 
  // Do not overwrite regbank during Reset, preserve the old value 
  always @ (posedge clk) 
    begin 
      if(wr_reg && !w_addr[3])
        reg_file[w_addr[2:0]] <= w_data; 
    end 
 
 
  // Program Counter, PSW and SP 
  always @ (posedge clk or negedge rst_n) 
    begin 
      if(!rst_n) 
        begin 
          pc <= 16'h0;
          psw <= 8'h0; 
          sp  <= 16'hf000;
        end 
      else 
        begin
          if(wr_reg && w_addr == `ADRpsw) 
            psw <= w_data;
          else 
            psw <= next_psw; 

          if(wr_reg && w_addr == `ADRpcl & data_ready) 
            pc[7:0] <= w_data; 
          else if(wr_reg && w_addr == `ADRpch & data_ready) 
            pc[15:8] <= w_data; 
          else if(iack & ready & cycle)
            pc  <= {6'b000000, data_in, 2'b00};
          else if((cycle_complete) & (addr_op == `ADOPint))
            begin
              if(int_type == 2'b01)      pc <= 16'h0004;
              else if(int_type == 2'b10) pc <= 16'h0008;
            end 
          else if(data_ready)
            pc <= pc + inc_pc;

          if(wr_reg && w_addr == `ADRspl &  data_ready) 
            sp[7:0] <= w_data; 
          else if(wr_reg && w_addr == `ADRsph & data_ready) 
            sp[15:8] <= w_data; 
          else if( addr_op == `ADOPldlisp | addr_op == `ADOPint)
            sp[15:0] <= inc_address;
          else if( addr_op == `ADOPldlssp)
            sp[15:0] <= address;
        end 
    end 

  // ------------------
  // BUS INTERFACE UNIT
  // ------------------
 
  // Instruction Queue
  assign queue_out  = ins_queue[out_pointer];

  always @ (posedge clk or negedge rst_n)
    begin
      if(!rst_n)
        begin
          in_pointer  <= 2'b00;
          out_pointer <= 2'b00;
          queue_count <= 3'b000;
        end
      else
        begin
          if(clear_queue)  
            begin
              in_pointer  <= 2'b00;
              out_pointer <= 2'b00;
              queue_count <= 3'b000;
            end
          else 
            begin
              if(ifetch_ready)
                begin
                  ins_queue[in_pointer] <= data_in; 
                  in_pointer <= in_pointer + 1;
                end
              if(read_opcode)
                out_pointer <= out_pointer + 1;
              if(ifetch_ready & ~read_opcode)
                queue_count <= queue_count + 1;
              else if(~ifetch_ready & read_opcode) 
                queue_count <= queue_count - 1;
            end
        end
      end

  // bus-cycle state machine
  `define bus_idle  2'b00
  `define bus_inst  2'b01
  `define bus_data  2'b10
  `define bus_iack  2'b11

  always @ (bus_state or data_access or data_access_next or ifetch
            or iack_access or queue_almost_full or queue_full or ready
            or stop_fetch or write_access or cycle or write or iack)
    begin
      next_bus_state = bus_state;
      next_cycle     = cycle;  next_write  = write;
      next_ifetch    = ifetch; next_iack   = iack;
      
      case(bus_state)
      `bus_idle: 
        begin
          if(iack_access)
            begin
              next_bus_state = `bus_iack;
              next_cycle     = 1'b1; next_write  = 1'b0;
              next_ifetch    = 1'b0; next_iack   = 1'b1;
            end
          else if(data_access)
            begin
              next_bus_state = `bus_data;
              next_cycle     = 1'b1; next_write  = write_access;
              next_ifetch    = 1'b0; next_iack   = 1'b0;
            end
          else if(~queue_full & ~stop_fetch & ~data_access_next)
            begin
              next_bus_state = `bus_inst;
              next_cycle     = 1'b1; next_write  = 1'b0;
              next_ifetch    = 1'b1; next_iack   = 1'b0;
            end
        end
      `bus_data: 
        begin
          if(ready & iack_access)
            begin
              next_bus_state = `bus_iack;
              next_cycle     = 1'b1; next_write  = 1'b0;
              next_ifetch    = 1'b0; next_iack   = 1'b1;
             end
          else if(ready & data_access)
            begin
              next_bus_state = `bus_data;
              next_cycle     = 1'b1; next_write  = write_access;
              next_ifetch    = 1'b0; next_iack   = 1'b0;
            end
          else if(ready & ~queue_full & ~stop_fetch & ~data_access_next)
            begin
              next_bus_state = `bus_inst;
              next_cycle     = 1'b1; next_write  = 1'b0;
              next_ifetch    = 1'b1; next_iack   = 1'b0;
            end
          else if (ready)
            begin
              next_bus_state = `bus_idle;
              next_cycle     = 1'b0; next_write  = 1'b0;
              next_ifetch    = 1'b0; next_iack   = 1'b0;
            end
        end
      `bus_iack:
        begin
          if(ready) 
            begin
              next_bus_state = `bus_idle;
              next_cycle     = 1'b0; next_write  = 1'b0;
              next_ifetch    = 1'b0; next_iack   = 1'b0;
            end
         end
      `bus_inst:
        begin
          if(ready & data_access)
            begin
              next_bus_state = `bus_data;
              next_cycle     = 1'b1; next_write  = write_access;
              next_ifetch    = 1'b0; next_iack   = 1'b0;
            end
          else if(ready & ~queue_almost_full & ~stop_fetch & 
                  ~data_access_next)
            begin
              next_bus_state = `bus_inst;
              next_cycle     = 1'b1; next_write  = 1'b0;
              next_ifetch    = 1'b1; next_iack   = 1'b0;
            end
          else if(ready)
            begin 
              next_bus_state = `bus_idle;
              next_cycle     = 1'b0; next_write  = 1'b0;
              next_ifetch    = 1'b0; next_iack   = 1'b0;
            end
        end
      endcase
    end

  always @ (posedge clk or negedge rst_n)
    begin
      if(!rst_n)
        begin
          bus_state <= `bus_idle;
          cycle     <= 1'b0; 
          write     <= 1'b0;
          ifetch    <= 1'b0; 
          iack      <= 1'b0;
        end
      else
        begin
          bus_state <= next_bus_state;
          cycle     <= next_cycle; 
          write     <= next_write;
          ifetch    <= next_ifetch; 
          iack      <= next_iack | ((int_type == 2'b01) & (addr_op == `ADOPint)
                       & (cycle_complete));
        end
    end

  assign inc_address = address + 1; 
  assign dec_address = address - 1; 
  // address and data_out generation 
  always @ (posedge clk or negedge rst_n)
    begin
      if(!rst_n)
        begin
          address      <= 16'h0;
          address_save <= 16'h0;  // can be moved to a_reg, p_reg to save area
          data_out     <= 8'h0;
          clear_queue  <= 1'b0;
        end
      else
        begin
          if(data_ready)
            clear_queue     <= opcode_op[3];
          if(save_address_reg)
            address_save  <= inc_address;
          if(iack & ready & cycle)
            address       <= {6'b000000, data_in, 2'b00};
          else if(cycle_complete)
          case(addr_op)
            `ADOPldlsv : address[7:0]  <= alu_out;
            `ADOPldl   : address[7:0]  <= alu_out;
            `ADOPldlisp: address[7:0]  <= alu_out;
            `ADOPldlssp: address[7:0]  <= alu_out;
            `ADOPldh   : address[15:8] <= alu_out;
            `ADOPinc   : address       <= inc_address;
            `ADOPdec   : address       <= dec_address;
            `ADOPrec   : address       <= address_save;
            `ADOPrsp   : address       <= sp;
            `ADOPan    : address       <= {a_data, b_data};
            `ADOPint: begin
               if(int_type == 2'b01)      address <= 16'h0004;
               else if(int_type == 2'b10) address <= 16'h0008;
               else         address  <= {6'b000000, data_in, 2'b00};
               end
            `ADOPnul: begin
               if(cycle & ready)
                 address               <= inc_address;
               end     
          endcase

          if(write_access & cycle_complete)
            data_out     <= b_data;
        end
    end
    
endmodule 
 
