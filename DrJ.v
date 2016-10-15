
module DrJ
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,				    //	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [3:0]   KEY;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];

    wire move_right;
    assign move_right = ~KEY[2];
    wire move_left;
    assign move_left = ~KEY[3];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] xScreen;
	wire [7:0] yScreen;
	wire [7:0] Xchk;
	wire [7:0] Ychk;


	wire writeEn, ENmove;
    wire change;
    wire [1:0] col;
    wire [7:0] xOFFS;
    wire [7:0] yOFFS;
    wire move_frame;
    /* if 01 we are checking if the pill can move down,
       if 10 we are checking if the pill can move right,
       if 11 we are checking if the pill can move left. */
    wire [1:0] check_m;
	 wire [1:0] check_c;
    wire [1:0] cmove; //can_move
	 wire [1:0] ccmove;
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	
    
    /*
	 vga_adapter VGA(
	 		.resetn(resetn),
	 		.clock(CLOCK_50),
	 		.colour(colour),
	 		.x(xScreen + 64),
	 		.y(yScreen + 50),
	 		.plot(writeEn),
	 		//  Signals for the DAC to drive the monitor. 
	 		.VGA_R(VGA_R),
	 		.VGA_G(VGA_G),
	 		.VGA_B(VGA_B),
	 		.VGA_HS(VGA_HS),
	 		.VGA_VS(VGA_VS),
	 		.VGA_BLANK(VGA_BLANK_N),
	 		.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
	 	defparam VGA.RESOLUTION = "160x120";
	 	defparam VGA.MONOCHROME = "FALSE";
	 	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	 	defparam VGA.BACKGROUND_IMAGE = "background.mif";

        */
        
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
    
    // Instansiate datapath
	datapath d0(.clk(CLOCK_50), .ResetN(resetn), .Xout(xScreen), .Yout(yScreen), .Xin(xOFFS), .Yin(yOFFS), .Xc(Xchk), .Yc(Ychk),
	 .change(change), .checkM(check_m), .checkC(check_c), .CanMove(cmove), .ControlCM(ccmove) , .plot(writeEn), .Colour(col), .ColourOut(colour), .enable_move(ENmove));

    // Instansiate FSM control
    control c0(.clk(CLOCK_50), .go(~KEY[1]),.enableMove(ENmove), .Reset_N(resetn), .can_move(cmove), .control_CM(ccmove), .MoveRight(move_right), .MoveLeft(move_left), .check_move(check_m), .check_control(check_c), .Update(change), .Xupdate(xOFFS),
    	.Yupdate(yOFFS), .Xcheck(Xchk), .Ycheck(Ychk), .ColourO(col)); 
endmodule

module datapath(input clk,
                input ResetN, 
                output reg [7:0] Xout, 
                output reg [7:0] Yout, 
                input [7:0] Xin, 
                input [7:0] Yin,
					 input [7:0] Xc, 
                input [7:0] Yc,
                input change,
                input [1:0] checkM,
					 input [1:0] checkC,
                output reg [1:0] CanMove,
					 output reg [1:0] ControlCM,
                output reg plot,
                input [1:0] Colour,
                output reg [2:0] ColourOut,
                output reg enable_move);

    reg [2:0] game_screen [0:53] [0:31];
	reg y_cleared;
    reg [3:0] colours [3:0];
    reg [7:0] x_l, y_l;
    reg [7:0] x_to_clear, y_to_clear, temp1, temp2, loopCount;
    reg [15:0] x_clear [0:31]; //first 8 bits are x coord last 8 are y
    reg [15:0] y_clear [0:53];  

	
	always @(posedge clk) begin
        colours[0] = 3'b000;
        colours[1] = 3'b001;
        colours[2] = 3'b100;
        colours[3] = 3'b110;

		plot = 1'b0;
        enable_move = 1'b1;
        y_cleared = 1'b0;
        CanMove = 2'b00;
        ControlCM = 2'b00;

        if(checkM == 2'b01) begin
            if(Yin == 8'd53)
                CanMove = 2'b10;
            else if(game_screen[Yin + 1][Xin] == 3'b000 && game_screen[Yin + 1][Xin + 1] == 3'b000)
                CanMove = 2'b01;
            else
                begin
                    CanMove = 2'b10;
                    y_to_clear = 8'd1;
                        loopCount = 8'd0;
                        y_clear[1][15:8] = Yin;
                        y_clear[1][7:0] = Xin;
                    x_to_clear = 8'd0;
                    //check under left
                    while(loopCount < 8'd54 && y_to_clear < 8'd53 && (Yin + y_to_clear) < 8'd54 && game_screen[Yin + y_to_clear][Xin] == game_screen[Yin][Xin]) begin
                        y_to_clear = y_to_clear + 8'd1;
                        y_clear[y_to_clear][15:8] = Yin + y_to_clear - 8'd1;
                        y_clear[y_to_clear][7:0] = Xin;
                        loopCount = loopCount + 8'd1;
                    end
                    if(y_to_clear < 8'd3)begin
                    y_to_clear = 8'd0;
                    end
                    loopCount = 8'd0;
                    temp1 = 8'd1;
                    temp2 = y_to_clear;
                    //check under right
                    while(loopCount < 8'd54 && y_to_clear < 8'd53 && (Yin + temp1) < 8'd54 && game_screen[Yin + temp1][Xin + 1'b1] == game_screen[Yin][Xin + 1'b1]) begin
                        y_to_clear = y_to_clear + 8'd1;
                        temp1 = temp1 + 8'd1;
                        y_clear[y_to_clear][15:8] = Yin + temp1 - 8'd1;
                        y_clear[y_to_clear][7:0] = Xin + 8'd1;
                        loopCount = loopCount + 8'd1;
                    end
                    if(temp1 < 8'd3)begin
                    y_to_clear = temp2;
                    end
                end
            end
          if(checkC == 2'b10) begin //Check right move
                if(Xc == 8'd30)
                    ControlCM = 2'b11;
                else if(game_screen[Yc][Xc + 2] == 3'b000)
                    ControlCM = 2'b01;
                else
                    ControlCM = 2'b11;
          end
          if(checkC == 2'b11) begin //Check left move
                if(Xc == 8'd0)
                ControlCM = 2'b11;
                else if(game_screen[Yc][Xc - 1] == 3'b000)
                    ControlCM = 2'b01;
                else
                ControlCM = 2'b11;
                
          end

        if(y_to_clear) begin
        enable_move = 1'b0;
        y_cleared = 1'b1;
        game_screen[y_clear[y_to_clear][15:8]][y_clear[y_to_clear][7:0]] = colours[0];
        Xout = y_clear[y_to_clear][7:0];
        Yout = y_clear[y_to_clear][15:8];
        ColourOut = colours[0];
        y_to_clear = y_to_clear - 1'b1;
        plot = 1'b1;
        end
        if(x_to_clear && ~y_cleared) begin
        enable_move = 1'b0;
        end

		if(change) begin
				game_screen[Yin][Xin] = colours[Colour];
				ColourOut = colours[Colour];
				Xout = Xin + 8'd1;
				Yout = Yin + 8'd1;
				plot = 1'b1;	 
        end
		  
	 if(!ResetN)
        begin
            x_to_clear = 8'd0;
            y_to_clear = 8'd0;
            for(x_l = 0; x_l < 32; x_l = x_l + 1) begin
                for(y_l = 0; y_l < 54; y_l = y_l + 1) begin
                    game_screen[y_l][x_l] = 3'b000;
                end
            end
        end
	end


endmodule

module control(input clk,
               input go,
               input enableMove, 
			   input Reset_N,
			   input [1:0] can_move,
			     input [1:0] control_CM,
               input MoveRight,
               input MoveLeft,
			   output reg [1:0] check_move,
				output reg [1:0] check_control,
			   output reg Update, 
			   output reg [7:0] Xupdate, 
			   output reg [7:0] Yupdate,
			   output reg [7:0] Xcheck, 
			   output reg [7:0] Ycheck,
               output reg [1:0] ColourO);

    reg [5:0] current_state, next_state;
    reg [5:0] user_current_state, user_next_state;
    reg [3:0] pill_colour;
    reg [7:0] pill_x, pill_y;
    reg [7:0] r_colour;
    reg [3:0] r_pill_colour [15:0]; 
    wire move_rate;
    reg c_move_rate;
    RateDivider MOVER(.clock(clk), .rate(30'd3/*30'd25000000*/), .clock_pulse(move_rate), .Clear_b(Reset_N));
	
	
    // counter pill_colour_select(.UpDown(1'b1), .Rate(move_rate), .Count(r_colour), .reset(Reset_N), .max(8'd15));
    // to fix timeing problem between fall and control move make two timers off by one clock cycle

    
    localparam  S_WAIT              = 5'd0,
                S_PLOT_VIRUSEONE    = 5'd1,
                S_PLOT_VIRUSETWO    = 5'd2,
                S_PLOT_VIRUSETHREE  = 5'd3,
                S_PLOT_VIRUSEFOUR   = 5'd4,
                S_PLOT_VIRUSEFIVE   = 5'd5,
                S_PLOT_VIRUSESIX    = 5'd6,
                S_PLOT_VIRUSESEVEN  = 5'd7,
                S_PLOT_VIRUSEEIGHT  = 5'd8,
                S_PLOT_VIRUSENINE   = 5'd9,
                S_PLOT_VIRUSETEN    = 5'd10,
                S_PLOT_PILL 		= 5'd11,
                S_PLOT_PILL_RIGHT 	= 5'd12,
                S_PLOT_PILL_LEFT 	= 5'd13,
                S_WAIT_MOVE_PILL	= 5'd14,
                S_WAIT_MOVE_CHECK   = 5'd15,
                S_CLEAR_PILL        = 5'd16,
                S_CLEAR_PILL_RIGHT  = 5'd17,
                S_CLEAR_PILL_LEFT   = 5'd18,
                S_MOVE_PILL 		= 5'd19,
                S_NEW_PILL          = 5'd20,

                MS_WAIT_INPUT       = 5'd0,
                MS_WAIT_R_MC        = 5'd1,
                MS_WAIT_L_MC        = 5'd2,        
                MS_R_CLEAR_RIGHT    = 5'd3,
                MS_R_CLEAR_LEFT     = 5'd4,
                MS_L_CLEAR_RIGHT    = 5'd5,
                MS_L_CLEAR_LEFT     = 5'd6,
					MS_CHECK_MOVE_RIGHT = 5'd7,
					MS_CHECK_MOVE_LEFT  = 5'd8,
                MS_MOVE_RIGHT       = 5'd9,
                MS_MOVE_LEFT        = 5'd10;

					 
   

 // Next state logic aka our state table
    always@(*)
    begin: state_tables
    r_pill_colour[0] = 4'b1001;
    r_pill_colour[1] = 4'b1101;
    r_pill_colour[2] = 4'b1010;
    r_pill_colour[3] = 4'b0111;
    r_pill_colour[4] = 4'b0110;
    r_pill_colour[5] = 4'b1011;
    r_pill_colour[6] = 4'b0101;
    r_pill_colour[7] = 4'b1001;
    r_pill_colour[8] = 4'b1110;
    r_pill_colour[9] = 4'b0111;
    r_pill_colour[10] = 4'b1101;
    r_pill_colour[11] = 4'b1111;
    r_pill_colour[12] = 4'b0101;
    r_pill_colour[13] = 4'b1011;
    r_pill_colour[14] = 4'b1110;
    r_pill_colour[15] = 4'b0110;
    r_colour = 4'd11;

            case (current_state)
                S_WAIT: next_state = go ?  S_PLOT_VIRUSEONE : S_WAIT; // Loop in current state until go signal goes low
                S_PLOT_VIRUSEONE: next_state = S_PLOT_VIRUSETWO; // Loop in current state until value is input
                S_PLOT_VIRUSETWO: next_state = S_PLOT_VIRUSETHREE;
                S_PLOT_VIRUSETHREE: next_state = S_PLOT_VIRUSEFOUR;
                S_PLOT_VIRUSEFOUR: next_state = S_PLOT_VIRUSEFIVE;
                S_PLOT_VIRUSEFIVE: next_state = S_PLOT_VIRUSESIX;
                S_PLOT_VIRUSESIX: next_state = S_PLOT_VIRUSESEVEN;
                S_PLOT_VIRUSESEVEN: next_state = S_PLOT_VIRUSEEIGHT;
                S_PLOT_VIRUSEEIGHT: next_state = S_PLOT_VIRUSENINE;
                S_PLOT_VIRUSENINE: next_state = S_PLOT_VIRUSETEN;
                S_PLOT_VIRUSETEN: next_state = S_PLOT_PILL;
                S_PLOT_PILL: next_state = S_PLOT_PILL_RIGHT;
                S_PLOT_PILL_RIGHT: next_state = S_PLOT_PILL_LEFT;
                S_PLOT_PILL_LEFT: next_state = S_WAIT_MOVE_PILL;
                S_WAIT_MOVE_PILL: next_state = move_rate && enableMove ? S_WAIT_MOVE_CHECK : S_WAIT_MOVE_PILL;
                S_WAIT_MOVE_CHECK: begin //if can_move is 0 we will wait, if it is 1 we will move the pill, if it is 2 we will create a new pill
                                    if (can_move == 2'b00)
                                        next_state = S_WAIT_MOVE_CHECK;
                                    if (can_move == 2'b01)
                                        next_state = S_CLEAR_PILL;
                                    if (can_move == 2'b10)
                                        next_state = S_NEW_PILL;
                                   end
                S_CLEAR_PILL: next_state = S_CLEAR_PILL_RIGHT;
                S_CLEAR_PILL_RIGHT: next_state = S_CLEAR_PILL_LEFT;
                S_CLEAR_PILL_LEFT: next_state = S_MOVE_PILL;                  
                S_MOVE_PILL: next_state = S_PLOT_PILL_RIGHT;
                S_NEW_PILL: next_state = S_PLOT_PILL_RIGHT;
            default:     next_state = S_WAIT;
        endcase
            case (user_current_state)
                MS_WAIT_INPUT:  begin
                                    if((MoveRight == 1'b0 && MoveLeft == 1'b0))
                                        user_next_state = MS_WAIT_INPUT;
                                    if((MoveRight == 1'b1) && c_move_rate && enableMove)
                                        user_next_state = MS_CHECK_MOVE_RIGHT;
                                    if((MoveLeft == 1'b1) && c_move_rate && enableMove)
                                        user_next_state = MS_CHECK_MOVE_LEFT;
                                end
					 MS_CHECK_MOVE_RIGHT: begin //if can_move is 0 we will wait, if it is 1 we will move the pill, if it is 2 we will create a new pill
                                    if (control_CM == 2'b00)
                                        user_next_state = MS_CHECK_MOVE_RIGHT;
                                    if (control_CM == 2'b01)
                                        user_next_state = MS_R_CLEAR_RIGHT;
									if (control_CM == 2'b11)
                                        user_next_state = MS_WAIT_INPUT;
												end		
				    MS_CHECK_MOVE_LEFT: begin //if can_move is 0 we will wait, if it is 1 we will move the pill, if it is 2 we will create a new pill
                                    if (control_CM == 2'b00)
                                        user_next_state = MS_CHECK_MOVE_LEFT;
                                    if (control_CM == 2'b01)
                                        user_next_state = MS_L_CLEAR_RIGHT;
									if (control_CM == 2'b11)
                                        user_next_state = MS_WAIT_INPUT;
                                   end					
                MS_R_CLEAR_RIGHT: user_next_state = MS_R_CLEAR_LEFT;
                MS_R_CLEAR_LEFT: user_next_state = MS_MOVE_RIGHT;
                MS_L_CLEAR_RIGHT: user_next_state = MS_L_CLEAR_LEFT;
                MS_L_CLEAR_LEFT: user_next_state = MS_MOVE_LEFT;
                MS_MOVE_LEFT: user_next_state = MS_WAIT_INPUT;
                MS_MOVE_RIGHT: user_next_state = MS_WAIT_INPUT;
                default:     user_next_state = MS_WAIT_INPUT;
        endcase
    end //State_tables


// Output logic aka all of our datapath control signals
    always @(posedge clk)
    begin: enable_signals
        // By default make all our signals 0
         Update = 1'b0;
         check_move = 2'b00;
		 check_control = 2'b00;
         c_move_rate = 1'b0;
         if(move_rate)
            c_move_rate <= 1'b1;

        case (current_state)
            S_PLOT_VIRUSEONE: begin
                ColourO = 2'd1;
                Xupdate = 8'd10;
                Yupdate = 8'd30;
                Update = 1'b1;
            end
            S_PLOT_VIRUSETWO: begin
                ColourO = 2'd2;
                Xupdate = 8'd4;
                Yupdate = 8'd38;
                Update = 1'b1;
            end
            S_PLOT_VIRUSETHREE: begin
                ColourO = 2'd3;
                Xupdate = 8'd20;
                Yupdate = 8'd19;
                Update = 1'b1;
            end
            S_PLOT_VIRUSEFOUR: begin
                ColourO = 2'd2;
                Xupdate = 8'd20;
                Yupdate = 8'd46;
                Update = 1'b1;
            end
            S_PLOT_VIRUSEFIVE: begin
                ColourO = 2'd3;
                Xupdate = 8'd30;
                Yupdate = 8'd26;
                Update = 1'b1;
            end
            S_PLOT_VIRUSESIX: begin
                ColourO = 2'd1;
                Xupdate = 8'd37;
                Yupdate = 8'd6;
                Update = 1'b1;
            end
            S_PLOT_VIRUSESEVEN: begin
                ColourO = 2'd2;
                Xupdate = 8'd4;
                Yupdate = 8'd31;
                Update = 1'b1;
            end
            S_PLOT_VIRUSEEIGHT: begin
                ColourO = 2'd3;
                Xupdate = 8'd9;
                Yupdate = 8'd16;
                Update = 1'b1;
            end
            S_PLOT_VIRUSENINE: begin
                ColourO = 2'd1;
                Xupdate = 8'd19;
                Yupdate = 8'd49;
                Update = 1'b1;
            end
            S_PLOT_VIRUSETEN: begin
                ColourO = 2'd2;
                Xupdate = 8'd28;
                Yupdate = 8'd34;
                Update = 1'b1;
            end
            S_PLOT_PILL: begin
            	pill_colour = r_pill_colour[r_colour];//($random % 3) + 1;
            end
            S_PLOT_PILL_RIGHT: begin
           		Xupdate = pill_x + 8'd1;
           		Yupdate = pill_y;
            	ColourO = pill_colour[3:2];
            	Update = 1'b1;
            end
            S_PLOT_PILL_LEFT: begin
           		Xupdate = pill_x;
           		Yupdate = pill_y;
            	ColourO = pill_colour[1:0];
            	Update = 1'b1;
            end
            S_WAIT_MOVE_CHECK: begin
                Xupdate = pill_x;
                Yupdate = pill_y;
                check_move = 2'b01;
            end
            S_CLEAR_PILL_LEFT: begin
                Xupdate = pill_x;
                Yupdate = pill_y;
                ColourO = 2'd0;
                Update = 1'b1;
            end
            S_CLEAR_PILL_RIGHT: begin
                Xupdate = pill_x + 1;
                Yupdate = pill_y;
                ColourO = 2'd0;
                Update = 1'b1;
            end
            S_MOVE_PILL: begin
                pill_y = pill_y + 8'd1;
            end
            S_NEW_PILL: begin
                pill_colour = 8'b1111;//r_pill_colour[r_colour];
                pill_y = 8'd0;
                pill_x = 8'd15;

            end
        // default:    // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase

        case (user_current_state)
            MS_R_CLEAR_RIGHT: begin
                Xupdate = pill_x + 8'd1;
                Yupdate = pill_y;
                ColourO = 2'b00;
                Update = 1'b1;
            end
            MS_R_CLEAR_LEFT: begin
                Xupdate = pill_x;
                Yupdate = pill_y;
                ColourO = 2'b00;
                Update = 1'b1;
            end
            MS_L_CLEAR_RIGHT: begin
                Xupdate = pill_x + 8'd1;
                Yupdate = pill_y;
                ColourO = 2'b00;
                Update = 1'b1;
            end
            MS_L_CLEAR_LEFT: begin
                Xupdate = pill_x;
                Yupdate = pill_y;
                ColourO = 2'b00;
                Update = 1'b1;
            end
            MS_MOVE_RIGHT: begin
					pill_x = pill_x + 8'd1;
            end
            MS_MOVE_LEFT: begin
					pill_x = pill_x - 8'd1;
            end
				MS_CHECK_MOVE_RIGHT: begin
					Xcheck = pill_x;
                    Ycheck = pill_y;
					check_control = 2'b10;
				end
				MS_CHECK_MOVE_LEFT: begin
					Xcheck = pill_x;
                    Ycheck = pill_y;
					check_control = 2'b11;
				end
        endcase
		  
		  if(!Reset_N)
            begin
            current_state <= S_WAIT;
            user_current_state <= MS_WAIT_INPUT;
            pill_colour = 4'd0;
            pill_y = 8'd0;
            pill_x = 8'd15;
            end
        else
            current_state <= next_state;
            user_current_state <= user_next_state;
    end // enable_signals
   

endmodule 



module counter(UpDown, Rate, Count, reset, max);
	input UpDown;
	input Rate;
	input reset;
	output reg [7:0] Count;
	input [7:0] max;

	always @(posedge Rate, negedge reset)
		begin
			if(reset == 0)
				Count <= 0;
			else if (Count == max)
				Count <= 0;
			else if(UpDown == 1)
				Count <= Count + 1'b1;
			else if(UpDown == 0)
				Count <= Count - 1'b1;
			
		end

endmodule


module RateDivider(clock, rate, clock_pulse, Clear_b);
	input clock;
	input [29:0] rate;
	reg [29:0] counter;
	output clock_pulse;
	input Clear_b;
	
	assign clock_pulse = (counter == 30'b000000000000000000000000000000)? 1'b1 : 1'b0;

	always @(posedge clock)
		begin
			if(Clear_b == 1'b0)
				counter <= 0;
			else if(counter == 30'b000000000000000000000000000000)
				counter <= rate;
			else
				counter <= counter - 1'b1;
		end

endmodule 