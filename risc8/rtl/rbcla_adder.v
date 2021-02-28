
//
//   S.Arvind 
//   2/3/99
//   Ripple-Block Carry Look Ahead Adder 
//   Reference: Computer Arithmetic Algorithms - Israel Koren
//              Computer Arithmetic Systems    - Amos R. Omondi
//

module rbcla_adder (A, B, CI, SUM, CO);

  parameter width = 32;
  parameter bits_per_block = 4; // Try changing this to 8 for width > 32 for
                                // better area optimization
  parameter block_count = width/bits_per_block;

  input  [width-1:0] A, B;
  output [width-1:0] SUM;
  input  CI;
  output CO;

  wire [width-1:0] P, G;        // local propagate_carry & generate_carry
  reg  [width:0] C;             // carry
  reg  [block_count:0] P_star;  // group_propagate_carry
  reg  [block_count:0] G_star;  // group_generate_carry
  reg  X_star;
  wire [width-1:0] T;

  integer i, j, k, m, tmp;

  assign P = A | B;         
  assign G = A & B;
  assign T = A ^ B;
  assign CO = C[width];
  assign SUM = T ^ C[width-1:0];

  always @ (P or G or CI)
    begin
    C[0] = CI;
    for(i = 0; i < block_count; i = i + 1)
      begin
        tmp = i*bits_per_block;
        P_star[i] = 1;                   // generate group_propagate_carry
        for(j=tmp; j < tmp+bits_per_block; j=j+1)
          P_star[i] = P_star[i] & P[j];

        G_star[i] = 0;                  // generate group_generate_carry
        for(k=0; k < bits_per_block; k=k+1)
          begin
            X_star = G[tmp+k];
            for(j=tmp+k+1; j < tmp+bits_per_block; j=j+1)
              X_star = X_star & P[j];
            G_star[i] = G_star[i] | X_star; 
          end

        tmp = i + 1; // generate the interblock carry
        C[tmp*bits_per_block] = G_star[i] | C[i*bits_per_block] & P_star[i]; 
      end

    // generate local carries for all the blocks
    for(i = 0; i < block_count+1; i = i + 1)  
      begin
      for(m=1; m < bits_per_block; m=m+1)
        begin
          tmp = i*bits_per_block;
          if((tmp + m) <= width)
            begin
              C[tmp+m] = 0;
              for(k=0; k < m; k = k+1)
                begin
                  X_star = G[tmp+k];
                  for(j=k+1; j < m; j=j+1)
                    X_star = X_star & P[tmp+j];
                  C[tmp+m] = C[tmp+m] | X_star; 
                end
              X_star = C[tmp];
              for(j=0; j < m; j=j+1)
                X_star = X_star & P[tmp+j];
              C[tmp+m] = C[tmp+m] | X_star; 
            end
        end
      end
    end

endmodule

/*
   Here is how the carries are calculated for a block size of 4.
   Please refer to Computer Arithmetic Algorithms by Israel Koren.
 
  G0* = G3 + G2P3+ G1P2P3 + G0P1P2P3  // Group_generate_carry
  P0* = P0P1P2P3                      // Group_propagate_carry
 
  Gi = AiBi                           // local generate_carry
  Pi = Ai + Bi                        // local propagate_carry
 
  C0 = CI
  C1 = G0 + C0P0
  C2 = G1 + G0P1 + C0P0P1
  C2 = G2 + G1P1 + G0P1P2 + C0P0P1P2
  C4 = G0* + C0P0*
 
  similarly
 
  C8  = G1* + C4 P1*
  C12 = G2* + C8 P2*
 
*/

