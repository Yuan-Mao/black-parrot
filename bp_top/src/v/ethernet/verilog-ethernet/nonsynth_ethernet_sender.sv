module nonsynth_ethernet_sender #
(
	parameter buf_size_p = 2048, // byte
	parameter send_width_p = 8, // byte
	parameter addr_width_lp = $clog2(buf_size_p / send_width_p)
)
(
	input logic                           clk_i
	,input logic                          reset_i

	,input logic                          send_i
	,input logic                          pause_i

    ,output logic [3:0]                   mii_txd_o
    ,output logic                         mii_tx_en_o
    ,output logic                         mii_tx_er_o
);
	localparam send_ptr_width_lp = $clog2(buf_size_p / send_width_p);
	localparam send_ptr_offset_width_lp = $clog2(send_width_p);

    localparam packet_size_lp = 16'd128;

	logic [send_width_p * 8 - 1:0] buffer_r [buf_size_p/send_width_p-1:0];

	logic [send_ptr_width_lp - 1:0] send_ptr_r;
	logic [15:0] packet_size_r;

	logic [send_ptr_width_lp - 1:0] send_ptr_end;
	logic [send_ptr_offset_width_lp - 1 :0] send_remaining;
	logic last_send_f;

	logic [send_width_p * 8- 1:0] axis_tdata_li;
	logic [send_width_p - 1:0]    axis_tkeep_li;
	logic                         axis_tvalid_li;
	logic                         axis_tlast_li;
    logic                         axis_tready_lo;
    logic                         axis_tuser_li;

	typedef enum logic {
		IDLE,
		SEND
	} state_e;

	state_e state_r, state_n;

	assign send_ptr_end = (packet_size_r - 1) >> $clog2(send_width_p);
	assign send_remaining = packet_size_r[$clog2(send_width_p) - 1:0];
	assign last_send_f = (send_ptr_r == send_ptr_end);

	assign axis_tdata_li = buffer_r[send_ptr_r];
	assign axis_tvalid_li = (state_r == SEND);
	assign axis_tlast_li = last_send_f;
	assign axis_tuser_li = 1'b0;

	always_ff @(posedge clk_i) begin
		assert(send_width_p == 8) else $error("sender now only supports width == 8");
	end

	always_comb begin
		if(!last_send_f)
			axis_tkeep_li = '1;
		else
			case(send_remaining)
				3'd0:
					axis_tkeep_li = 8'b1111_1111;
				3'd1:
					axis_tkeep_li = 8'b0000_0001;
				3'd2:
					axis_tkeep_li = 8'b0000_0011;
				3'd3:
					axis_tkeep_li = 8'b0000_0111;
				3'd4:
					axis_tkeep_li = 8'b0000_1111;
				3'd5:
					axis_tkeep_li = 8'b0001_1111;
				3'd6:
					axis_tkeep_li = 8'b0011_1111;
				3'd7:
					axis_tkeep_li = 8'b0111_1111;
				default:
					axis_tkeep_li = 'x;
			endcase
	end


	always_ff @(posedge clk_i) begin
		if(reset_i)
			state_r <= IDLE;
		else
			state_r <= state_n;
	end

    logic first_r, first_n;

	always_comb begin
		state_n = state_r;
        first_n = first_r;
		if(!pause_i) begin
			case(state_r)
				IDLE: begin
					if(send_i && ~first_r) begin
						state_n = SEND;
                        first_n = 1'b1;
                    end
				end
				SEND: begin
					if(last_send_f && axis_tready_lo) begin
						state_n = IDLE;
                    end
				end
			endcase
		end
	end

	always_ff @(posedge clk_i) begin
		if(reset_i) begin
			send_ptr_r <= '0;
            first_r <= '0;
		end
		else begin
            first_r <= first_n;
			case(state_r)
				IDLE: begin
					send_ptr_r <= '0;
				end
				SEND:
					if(!pause_i && axis_tready_lo)
						send_ptr_r <= send_ptr_r + send_ptr_width_lp'(1'b1);
			endcase
		end
	end


    eth_mac_mii_fifo #(.AXIS_DATA_WIDTH(64)) eth_mac_mii_fifo_tx
    (
    .rst(reset_i)
    ,.logic_clk(clk_i)
    ,.logic_rst(reset_i)

    ,.tx_axis_tdata(axis_tdata_li)
    ,.tx_axis_tkeep(axis_tkeep_li)
    ,.tx_axis_tvalid(axis_tvalid_li)
    ,.tx_axis_tready(axis_tready_lo)
    ,.tx_axis_tlast(axis_tlast_li)
    ,.tx_axis_tuser(axis_tuser_li)
    
    ,.rx_axis_tdata(/* UNUSED */)
    ,.rx_axis_tkeep(/* UNUSED */)
    ,.rx_axis_tvalid(/* UNUSED */)
    ,.rx_axis_tready(1'b0)
    ,.rx_axis_tlast(/* UNUSED */)
    ,.rx_axis_tuser(/* UNUSED */)

    ,.mii_rx_clk(clk_i)
    ,.mii_rxd(4'b0)
    ,.mii_rx_dv(1'b0)
    ,.mii_rx_er(1'b0)
    ,.mii_tx_clk(clk_i)
    ,.mii_txd(mii_txd_o)
    ,.mii_tx_en(mii_tx_en_o)
    ,.mii_tx_er(mii_tx_er_o)

    ,.tx_error_underflow()
    ,.tx_fifo_overflow()
    ,.tx_fifo_bad_frame()
    ,.tx_fifo_good_frame()
    ,.rx_error_bad_frame()
    ,.rx_error_bad_fcs()
    ,.rx_fifo_overflow()
    ,.rx_fifo_bad_frame()
    ,.rx_fifo_good_frame()

    ,.ifg_delay(8'd24)
    );


	always_ff @(posedge clk_i) begin
		if(reset_i)
			packet_size_r <= packet_size_lp;
	end

	initial begin
	    $readmemh("ethernet_frame.hex", buffer_r);
	end



endmodule
