
module bp_burst_to_lite
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = "inv"

   , parameter logic master_p = 0

   `declare_bp_mem_if_widths(paddr_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in_mem)
   `declare_bp_mem_if_widths(paddr_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out_mem)
   )
  (input                                     clk_i
   , input                                   reset_i

   // Master BP Burst
   , input [in_mem_msg_header_width_lp-1:0]  mem_header_i
   , input                                   mem_header_v_i
   , output logic                            mem_header_ready_o

   , input [in_data_width_p-1:0]             mem_data_i
   , input                                   mem_data_v_i
   , output logic                            mem_data_ready_o

   // Client BP Lite
   , output logic [out_mem_msg_width_lp-1:0] mem_o
   , output logic                            mem_v_o
   , input                                   mem_yumi_i
   );

  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, in_mem);
  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, out_mem);

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam burst_words_lp = out_data_width_p/in_data_width_p;
  localparam burst_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  bp_in_mem_msg_header_s header_lo;
  logic header_v_lo;
  bsg_one_fifo
   #(.width_p($bits(bp_in_mem_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_header_i)
     ,.ready_o(mem_header_ready_o)
     ,.v_i(mem_header_v_i)

     ,.data_o(header_lo)
     ,.v_o(header_v_lo)
     ,.yumi_i(mem_yumi_i)
     );

  bp_in_mem_msg_header_s mem_header_cast_i;
  assign mem_header_cast_i = mem_header_i;
  wire is_wr = mem_header_cast_i.msg_type inside {e_mem_msg_uc_wr, e_mem_msg_wr};
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(burst_words_lp);
  wire [data_len_width_lp-1:0] num_burst_cmds = (master_p ^ is_wr)
    ? 1'b1
    : `BSG_MAX(((1'b1 << mem_header_cast_i.size) / in_data_bytes_lp), 1'b1);
  logic [out_data_width_p-1:0] data_lo;
  logic data_v_lo;
  bsg_serial_in_parallel_out_dynamic
   #(.width_p(in_data_width_p), .max_els_p(burst_words_lp))
   sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_data_i)
     ,.len_i(num_burst_cmds-1'b1)
     ,.ready_o(mem_data_ready_o)
     ,.v_i(mem_data_v_i)

     ,.data_o(data_lo)
     ,.v_o(data_v_lo)
     // We gate the yumi signal since reads will not produce data
     ,.yumi_i(data_v_lo & mem_yumi_i)

     // We rely on fifo ready signal
     ,.len_ready_o(/* Unused */)
     );

  bp_out_mem_msg_s mem_cast_o;
  assign mem_cast_o = '{header: header_lo, data: data_lo};
  assign mem_o = mem_cast_o;
  wire is_rd_out = header_lo.msg_type inside {e_mem_msg_uc_rd, e_mem_msg_rd};
  assign mem_v_o = header_v_lo & (data_v_lo | (master_p == is_rd_out));

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p < out_data_width_p)
        else $error("Master data cannot be larger than client");
      assert (out_data_width_p % in_data_width_p == 0)
        else $error("Client data must be a multiple of master data");
    end

  always_ff @(negedge clk_i)
    begin
    //  if (mem_v_i)
    //    $display("[%t] Stream received: %p %x", $time, mem_header_cast_i, mem_data_i);

    //  if (mem_yumi_i)
    //    $display("[%t] Msg sent: %p", $time, mem_cast_o);
    end
  //synopsys translate_on

endmodule

