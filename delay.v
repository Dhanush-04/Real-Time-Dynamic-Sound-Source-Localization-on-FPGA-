`timescale 1ns / 1ps

module axis_volume_controller #(
    parameter SWITCH_WIDTH = 4, // WARNING: this module has not been tested with other values of SWITCH_WIDTH, it will likely need some changes
    parameter DATA_WIDTH = 24
) (
    input wire clk,    
    input wire [1:0] sw,
    //AXIS SLAVE INTERFACE
    input  wire [DATA_WIDTH-1:0] s_axis_data,
    input  wire s_axis_valid,
    output reg  s_axis_ready = 1'b1,
    input  wire s_axis_last,
    
    // AXIS MASTER INTERFACE
    output reg [DATA_WIDTH-1:0] m_axis_data = 1'b0,
    output reg m_axis_valid = 1'b0,
    input  wire m_axis_ready,
    output reg m_axis_last = 1'b0
);
    localparam MULTIPLIER_WIDTH = 24;
    reg [MULTIPLIER_WIDTH+DATA_WIDTH-1:0] data [1:0];
    
//     reg [DATA_WIDTH-1:0] data_buffer_r [9:0];
     reg [DATA_WIDTH-1:0] data_buffer [29:0];
     reg[2:0] select = 0;
     reg[25:0] shi = 26'b0;
     reg i_k, start = 1'b0;
     integer i,j,k;
     integer m = 0, l = 0;
     

    initial begin
        for (i = 0; i < 30; i = i + 1) begin
            data_buffer[i] <= 24'b0;
//            data_buffer_l[i] <= 24'b0;
        end        
    end
    
    reg [SWITCH_WIDTH-1:0] sw_sync_r [2:0];
    wire [SWITCH_WIDTH-1:0] sw_sync = sw_sync_r[2];
        
    reg [SWITCH_WIDTH-1:0] sw_sync_r1 [2:0];
    wire [SWITCH_WIDTH-1:0] sw_sync1 = sw_sync_r1[2];
        
    reg [SWITCH_WIDTH-1:0] sw_sync_r2 [2:0];
    wire [SWITCH_WIDTH-1:0] sw_sync2 = sw_sync_r2[2];
    
    reg [SWITCH_WIDTH-1:0] sw1;
    reg [SWITCH_WIDTH-1:0] sw2;
    reg forward = 1'b1;
    reg l_forward = 1'b1;

//    wire [SWITCH_WIDTH:0] m = {1'b0, sw_sync} + 1;
    reg [MULTIPLIER_WIDTH:0] multiplier = 'b0; // range of 0x00:0x10 for width=4
    reg [MULTIPLIER_WIDTH:0] multiplier1 = 'b0; // range of 0x00:0x10 for width=4
    reg [MULTIPLIER_WIDTH:0] multiplier2 = 'b0; // range of 0x00:0x10 for width=4

    reg [3:0] mymulti [15:0];
    
   initial begin
    mymulti[5'b00000] = 4'b1111; //0
    mymulti[5'b00001] = 4'b1000; //15
    mymulti[5'b00010] = 4'b0100; //N.D
    mymulti[5'b00011] = 4'b1000; //15
    mymulti[5'b00100] = 4'b1111; //0
    mymulti[5'b00101] = 4'b1111;
    mymulti[5'b00110] = 4'b1111;
    mymulti[5'b00111] = 4'b1111;
    mymulti[5'b01000] = 4'b1111;
    mymulti[5'b01001] = 4'b1111;
    mymulti[5'b01010] = 4'b1111;
    mymulti[5'b01011] = 4'b1111;
    mymulti[5'b01100] = 4'b1111;
    mymulti[5'b01101] = 4'b1111;
    mymulti[5'b01110] = 4'b1111;
    mymulti[5'b01111] = 4'b1111;
    end
    wire m_select = m_axis_last;
    wire m_new_word = (m_axis_valid == 1'b1 && m_axis_ready == 1'b1) ? 1'b1 : 1'b0;
    wire m_new_packet = (m_new_word == 1'b1 && m_axis_last == 1'b1) ? 1'b1 : 1'b0;
    
    wire s_select = s_axis_last;
    wire s_new_word = (s_axis_valid == 1'b1 && s_axis_ready == 1'b1) ? 1'b1 : 1'b0;
    wire s_new_packet = (s_new_word == 1'b1 && s_axis_last == 1'b1) ? 1'b1 : 1'b0;
    reg s_new_packet_r = 1'b0;
    
    reg [4:0] counter = 5'b00000;
     always@(posedge clk) begin
        sw1<= mymulti[counter];
        sw2<= mymulti[5'b01000 - counter];
        sw_sync_r1[2] <= sw_sync_r1[1];
        sw_sync_r1[1] <= sw_sync_r1[0];
        sw_sync_r1[0] <= sw1;
        
        sw_sync_r2[2] <= sw_sync_r2[1];
        sw_sync_r2[1] <= sw_sync_r2[0];
        sw_sync_r2[0] <= sw2;
        
        sw_sync_r[2] <= sw_sync_r[1];
        sw_sync_r[1] <= sw_sync_r[0];
        sw_sync_r[0] <= 4'b1111;

        multiplier <= {sw_sync,{MULTIPLIER_WIDTH{1'b0}}} / {SWITCH_WIDTH{1'b1}};
        multiplier1 <= {sw_sync1,{MULTIPLIER_WIDTH{1'b0}}} / {SWITCH_WIDTH{1'b1}};
        multiplier2 <= {sw_sync2,{MULTIPLIER_WIDTH{1'b0}}} / {SWITCH_WIDTH{1'b1}};

        s_new_packet_r <= s_new_packet;
    end
   
   //shifting registers 
   always@(posedge clk)begin
    
        if(s_new_word == 1'b1) begin
            if(s_select == 1'b0) begin
               for(i = 1; i<30; i=i+1) begin
                    data_buffer[i-1] <= data_buffer[i];
               end
            data_buffer[29] <= s_axis_data;
            end
                              
        end
                
       
   end
   //11111111111111111111111111
//   26'b11111111111111111111111111
// 3'b111

   //select controller
always@(posedge clk) begin
        if (shi == 26'b11111111111111111111111111) begin
            if (forward == 1'b1) begin                       
                    if (select != 3'b100) begin
                        select = select + 1;
                    end
                    else if(select == 3'b100) begin                          
                        forward = 1'b0; // Update forward here
                        select = 3'b100;
                    end   
                           
            end

            else begin
                    if (select != 3'b000) begin
                        select = select - 1;
                    end
                    else if(select == 3'b000) begin
                        forward = 1'b1; // Update forward here
                        select = 3'b000;
                    end               
            end           
            shi <= 0;
            counter[2:0] = select;
        end
        
        else
            shi <= shi + 1;    
      end
          
   
///m edits

   
   always@(posedge clk)begin
     if(sw == 2'b01) begin   
        if(select ==3'b000)begin   
            //here edit1
           if (s_new_word == 1'b1)begin// sign extend and register AXIS slave data
                if (s_select == 1'b0)
                data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
                else
                data[s_select] <= {{MULTIPLIER_WIDTH{data_buffer[0][DATA_WIDTH-1]}}, data_buffer[0]};
            end 
            else if (s_new_packet_r == 1'b1) begin
                data[0] <= $signed(data[0]) * multiplier; // core volume control algorithm, infers a DSP48 slice
                data[1] <= $signed(data[1]) * multiplier;
            end
        end 
            
        
        else if(select == 3'b001) begin
            if (s_new_word == 1'b1)begin// sign extend and register AXIS slave data
                        if (s_select == 1'b0)
                        data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
                        else
                        data[s_select] <= {{MULTIPLIER_WIDTH{data_buffer[15][DATA_WIDTH-1]}}, data_buffer[15]};
                    end
            else if (s_new_packet_r == 1'b1) begin
                data[0] <= $signed(data[0]) * multiplier; // core volume control algorithm, infers a DSP48 slice
                data[1] <= $signed(data[1]) * multiplier;
            end  
        end 

        else if(select == 3'b010) begin
            if (s_new_word == 1'b1)begin// sign extend and register AXIS slave data
                        if (s_select == 1'b0)
                        data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
                        else
                        data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
                    end
            else if (s_new_packet_r == 1'b1) begin
                data[0] <= $signed(data[0]) * multiplier; // core volume control algorithm, infers a DSP48 slice
                data[1] <= $signed(data[1]) * multiplier;
            end  
        end 

        else if(select == 3'b011) begin
            if (s_new_word == 1'b1)begin// sign extend and register AXIS slave data
                        if (s_select == 1'b0)
                        data[s_select] <= {{MULTIPLIER_WIDTH{data_buffer[15][DATA_WIDTH-1]}}, data_buffer[15]};
                        else
                        data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
                    end
            else if (s_new_packet_r == 1'b1) begin
                data[0] <= $signed(data[0]) * multiplier; // core volume control algorithm, infers a DSP48 slice
                data[1] <= $signed(data[1]) * multiplier;
            end  
        end 

        else if(select == 3'b100) begin
            if (s_new_word == 1'b1)begin// sign extend and register AXIS slave data
                        if (s_select == 1'b0)
                        data[s_select] <= {{MULTIPLIER_WIDTH{data_buffer[0][DATA_WIDTH-1]}}, data_buffer[0]};
                        else
                        data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
                    end
            else if (s_new_packet_r == 1'b1) begin
                data[0] <= $signed(data[0]) * multiplier; // core volume control algorithm, infers a DSP48 slice
                data[1] <= $signed(data[1]) * multiplier;
            end  
        end 

     end
     
     else if(sw==2'b00) begin
        if (s_new_word == 1'b1)begin// sign extend and register AXIS slave data
             if (s_select == 1'b0)
                data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
             else
                data[s_select] <= {{MULTIPLIER_WIDTH{s_axis_data[DATA_WIDTH-1]}}, s_axis_data};
        end 
            else if (s_new_packet_r == 1'b1) begin
                data[0] <= $signed(data[0]) * multiplier; // core volume control algorithm, infers a DSP48 slice
                data[1] <= $signed(data[1]) * multiplier;
            end
     end         
   end  
 
///////
////from here
    always@(posedge clk)
        if (s_new_packet_r == 1'b1)
            m_axis_valid <= 1'b1;
        else if (m_new_packet == 1'b1)
            m_axis_valid <= 1'b0;
            
    always@(posedge clk)
        if (m_new_packet == 1'b1)
            m_axis_last <= 1'b0;
        else if (m_new_word == 1'b1)
            m_axis_last <= 1'b1;
            
    always@(m_axis_valid, data[0], data[1], m_select)
        if (m_axis_valid == 1'b1)
            m_axis_data = data[m_select][MULTIPLIER_WIDTH+DATA_WIDTH-1:MULTIPLIER_WIDTH];
        else
            m_axis_data = 'b0;
            
    always@(posedge clk)
        if (s_new_packet == 1'b1)
            s_axis_ready <= 1'b0;
        else if (m_new_packet == 1'b1)
            s_axis_ready <= 1'b1;
    
endmodule