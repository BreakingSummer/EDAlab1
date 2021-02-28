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
// File     : risc8_parameters.v
// Abstract : Parameter File
//
// History:
// ============================================================================
// 02/06/2000  arvind   1.0      Initial Release
// ============================================================================

// When this parameter is set to "1", 33 latches are added in the alu data path
// (Adder/Logic unit) to reduce switching activity so as to save dynamic power.
`define ADD_ALU_LATCHES 0

