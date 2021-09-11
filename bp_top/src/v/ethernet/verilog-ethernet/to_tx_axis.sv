module to_tx_axis
    import bp_common_pkg::*;
    import bp_me_pkg::*;
#(parameter bp_params_e bp_params_p = e_bp_default_cfg
  ,parameter eth_cmd_width_p        = 3
  ,parameter axis_data_width_p      = 64
      `declare_bp_proc_params(bp_params_p)
      `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)
      `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
)
(
    input logic                                 clk_i
    , input logic                               reset_i

    , input logic [63:0]                        frame_data_i /* frame data, size */
    , input logic                               frame_data_v_i
    , output logic                              frame_data_yumi_o

    , output logic [1:0]                        tx_ext_state_o

    /* AXIS TX */
    , output logic [axis_data_width_p-1:0]      tx_axis_tdata_o
    , output logic [axis_data_width_p/8-1:0]    tx_axis_tkeep_o
    , output logic                              tx_axis_tvalid_o
    , input  logic                              tx_axis_tready_i
    , output logic                              tx_axis_tlast_o
    , output logic                              tx_axis_tuser_o
);
  localparam eth_tx_state_width_lp = 3;
  typedef enum logic [eth_tx_state_width_lp-1:0] {
      ETH_TX_STATE_SIZE             = 3'b000
      ,ETH_TX_STATE_PAYLOAD         = 3'b001
  } eth_tx_state_e;

  eth_tx_state_e tx_state_r, tx_state_n;
  logic frame_data_yumi;

  logic [15:0] tx_packet_size_r;
  logic [$clog2(axis_data_width_p/8) - 1:0]  tx_head_offset_r;
  logic [15:0] tx_ptr_r;
  logic [15:0] tx_ptr_end;
  logic [15:0] tx_packet_size_with_padding;
  logic [$clog2(axis_data_width_p/8) - 1:0] tx_data_remainder;
  logic tx_first_beat;

  assign tx_packet_size_with_padding = tx_packet_size_r + 16'(tx_head_offset_r);
  assign tx_data_remainder = tx_packet_size_with_padding[$clog2(axis_data_width_p/8) - 1:0];

  assign tx_ptr_end = (tx_packet_size_with_padding - 1) >> $clog2(axis_data_width_p/8);
  assign tx_axis_tlast_o = (tx_ptr_r == tx_ptr_end);
  assign tx_first_beat   = (tx_ptr_r == '0);

  always_comb begin
    tx_axis_tkeep_o = '0;
    if(tx_axis_tlast_o) begin
      case(tx_data_remainder)
        3'h0:
          tx_axis_tkeep_o = 8'b1111_1111;
        3'h1:
          tx_axis_tkeep_o = 8'b0000_0001;
        3'h2:
          tx_axis_tkeep_o = 8'b0000_0011;
        3'h3:
          tx_axis_tkeep_o = 8'b0000_0111;
        3'h4:
          tx_axis_tkeep_o = 8'b0000_1111;
        3'h5:
          tx_axis_tkeep_o = 8'b0001_1111;
        3'h6:
          tx_axis_tkeep_o = 8'b0011_1111;
        3'h7:
          tx_axis_tkeep_o = 8'b0111_1111;
      endcase
    end
    else begin
      if(tx_first_beat) begin
        case(tx_head_offset_r)
          3'h0:
            tx_axis_tkeep_o = 8'b1111_1111;
          3'h1:
            tx_axis_tkeep_o = 8'b0111_1111;
          3'h2:
            tx_axis_tkeep_o = 8'b0011_1111;
          3'h3:
            tx_axis_tkeep_o = 8'b0001_1111;
          3'h4:
            tx_axis_tkeep_o = 8'b0000_1111;
          3'h5:
            tx_axis_tkeep_o = 8'b0000_0111;
          3'h6:
            tx_axis_tkeep_o = 8'b0000_0011;
          3'h7:
            tx_axis_tkeep_o = 8'b0000_0001;
        endcase
      end
      else
        tx_axis_tkeep_o = '1;
    end
  end

  assign tx_axis_tvalid_o = frame_data_v_i & (tx_state_r == ETH_TX_STATE_PAYLOAD);
  assign tx_axis_tuser_o  = 1'b0;
  assign tx_axis_tdata_o  = frame_data_i;


  always_ff @(posedge clk_i) begin
    if(tx_state_r == ETH_TX_STATE_SIZE) begin
      if(frame_data_yumi) begin
        tx_packet_size_r <= frame_data_i[15:0];
        tx_head_offset_r <= frame_data_i[18:16];
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if(tx_state_r == ETH_TX_STATE_SIZE) begin
      if(frame_data_yumi)
        tx_ptr_r <= '0;
    end
    else if(tx_state_r == ETH_TX_STATE_PAYLOAD) begin
      if(frame_data_yumi)
        tx_ptr_r <= tx_ptr_r + 1;
    end
  end

  always_comb begin
    tx_state_n = tx_state_r;
    case(tx_state_r)
      ETH_TX_STATE_SIZE:
        if(frame_data_yumi)
          tx_state_n = ETH_TX_STATE_PAYLOAD;
      ETH_TX_STATE_PAYLOAD:
        if(tx_axis_tlast_o & frame_data_yumi)
          tx_state_n = ETH_TX_STATE_SIZE;
    endcase
  end


  always_comb begin
    frame_data_yumi = 1'b1; // make default OP non-blocking
    case(tx_state_r)
      ETH_TX_STATE_SIZE:
        frame_data_yumi = frame_data_v_i;
      ETH_TX_STATE_PAYLOAD:
        frame_data_yumi = (tx_axis_tvalid_o & tx_axis_tready_i);
    endcase
  end
  assign frame_data_yumi_o = frame_data_yumi;

  always_ff @(posedge clk_i) begin
    if(reset_i)
      tx_state_r <= ETH_TX_STATE_SIZE;
    else
      tx_state_r <= tx_state_n;
  end

  always_comb begin
    tx_ext_state_o = 2'b11;
    case(tx_state_r)
      ETH_TX_STATE_SIZE:
        tx_ext_state_o = 2'b00;
      ETH_TX_STATE_PAYLOAD:
        tx_ext_state_o = 2'b01;
    endcase
  end

endmodule


