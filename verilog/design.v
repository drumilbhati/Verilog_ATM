module atm_module (
    input wire clk,
    input wire rst_n,
    input wire card_inserted,
    input wire [15:0] pin_input,
    input wire balance_req,
    input wire withdrawal_req,
    input wire deposit_req,
    input wire pin_change_req,
    input wire transaction_done,
    input wire [15:0] amount,
    input wire [7:0] card_number_input,
    output reg [7:0] current_state,
    output reg [15:0] balance,
    output reg transaction_success,
    output reg [7:0] error_code
);

    // State Parameters
    parameter IDLE = 8'b0000_0000;
    parameter CARD_INSERT = 8'b0000_0001;
    parameter CARD_VALIDATE = 8'b0000_0010;
    parameter CARD_ERROR = 8'b0000_0011;
    parameter CARD_VALID = 8'b0000_0100;
    parameter PIN_ENTRY = 8'b0000_0101;
    parameter PIN_CHECK = 8'b0000_0110;
    parameter PIN_ERROR = 8'b0000_0111;
    parameter PIN_VALID = 8'b0000_1000;
    parameter MENU = 8'b0000_1001;
    parameter BALANCE_ENQ = 8'b0001_0000;
    parameter WITHDRAWAL = 8'b0001_0001;
    parameter DEPOSIT = 8'b0001_0010;
    parameter PIN_CHANGE = 8'b0001_0011;
    parameter AMOUNT_VALID = 8'b0001_0100;
    parameter PRINT_RECEIPT = 8'b0001_0101;

    // Error Codes
    parameter NO_ERROR = 8'h00;
    parameter INVALID_CARD = 8'h01;
    parameter INVALID_PIN = 8'h02;
    parameter INSUF_BALANCE = 8'h03;
    parameter LIMIT_EXCEED = 8'h04;

    // Internal Registers
    reg [7:0] next_state;
    reg [7:0] current_card_number;
    reg [15:0] stored_pin;
    reg [15:0] daily_limit;
    reg [2:0] pin_attempts;
    reg pin_valid;

    // Memory Arrays
    reg [15:0] card_data [0:35];

    // Card Data Structure Indices
    parameter CARD_PIN_IDX = 0;
    parameter CARD_BALANCE_IDX = 1;
    parameter CARD_STATUS_IDX = 2;
    parameter CARD_LIMIT_IDX = 3;

    integer output_file;
    
    initial begin
        $readmemh("atm_data_g31.hex", card_data);
        output_file = $fopen("output_data.txt", "w");
        if (output_file == 0) begin
            $display("Error: Could not open output_data.hex");
            $finish;
        end
    end

    // Combined Sequential and State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            error_code <= NO_ERROR;
            transaction_success <= 0;
            pin_attempts <= 0;
            balance <= 16'h0000;
            current_card_number <= 8'h00;
            stored_pin <= 16'h0000;
            daily_limit <= 16'h0000;
            pin_valid <= 0;
            next_state <= IDLE;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (card_inserted)
                        next_state <= CARD_INSERT;
                end

                CARD_INSERT: begin
                    current_card_number <= card_number_input;
                    error_code <= NO_ERROR;
                    transaction_success <= 0;
                    pin_attempts <= 0;
                    next_state <= CARD_VALIDATE;
                end

                CARD_VALIDATE: begin
                    if (card_data[current_card_number*4 + CARD_STATUS_IDX] != 16'h0001) begin
                        error_code <= INVALID_CARD;
                        next_state <= CARD_ERROR;
                    end else begin
                        stored_pin <= card_data[current_card_number*4 + CARD_PIN_IDX];
                        daily_limit <= card_data[current_card_number*4 + CARD_LIMIT_IDX];
                        error_code <= NO_ERROR;
                        next_state <= CARD_VALID;
                    end
                end

                CARD_ERROR: begin
                    if (!card_inserted)
                        next_state <= IDLE;
                end

                CARD_VALID: begin
                    next_state <= PIN_ENTRY;
                end

                PIN_ENTRY: begin
                    next_state <= PIN_CHECK;
                end

                PIN_CHECK: begin
                    if (pin_input == stored_pin) begin
                        next_state <= MENU;
                        pin_valid <= 1;
                    end else begin
                        pin_attempts <= pin_attempts + 1;
                        if (pin_attempts >= 2) begin
                            next_state <= CARD_ERROR;
                        end else begin
                            next_state <= PIN_ERROR;
                        end
                    end
                end

                PIN_ERROR: begin
                    next_state <= PIN_ENTRY;
                end

                MENU: begin
                    if (!card_inserted)
                        next_state <= IDLE;
                    else if (balance_req)
                        next_state <= BALANCE_ENQ;
                    else if (withdrawal_req)
                        next_state <= WITHDRAWAL;
                    else if (deposit_req)
                        next_state <= DEPOSIT;
                    else if (pin_change_req)
                        next_state <= PIN_CHANGE;
                end

                BALANCE_ENQ: begin
                    balance <= card_data[current_card_number*4 + CARD_BALANCE_IDX];
                    if (transaction_done) begin
                        transaction_success <= 1;
                        next_state <= PRINT_RECEIPT;
                    end
                end

                WITHDRAWAL: begin
                    if (amount <= card_data[current_card_number*4 + CARD_BALANCE_IDX] &&
                        amount <= daily_limit) begin
                        if (transaction_done) begin
                            balance <= card_data[current_card_number*4 + CARD_BALANCE_IDX] - amount;
                            card_data[current_card_number*4 + CARD_BALANCE_IDX] <= 
                                card_data[current_card_number*4 + CARD_BALANCE_IDX] - amount;
                            transaction_success <= 1;
                            error_code <= NO_ERROR;
                            next_state <= AMOUNT_VALID;
                        end
                    end else begin
                        if (amount > daily_limit)
                            error_code <= LIMIT_EXCEED;
                        else
                            error_code <= INSUF_BALANCE;
                        next_state <= MENU;
                    end
                end

                DEPOSIT: begin
                    if (transaction_done) begin
                        balance <= card_data[current_card_number*4 + CARD_BALANCE_IDX] + amount;
                        card_data[current_card_number*4 + CARD_BALANCE_IDX] <= 
                            card_data[current_card_number*4 + CARD_BALANCE_IDX] + amount;
                        transaction_success <= 1;
                        error_code <= NO_ERROR;
                        next_state <= AMOUNT_VALID;
                    end
                end

                PIN_CHANGE: begin
                    if (!card_inserted)
                        next_state <= IDLE;
                    else if (transaction_done)
                        next_state <= MENU;
                end

                AMOUNT_VALID: begin
                    if (!card_inserted)
                        next_state <= IDLE;
                    else if (transaction_done)
                        next_state <= PRINT_RECEIPT;
                end

                PRINT_RECEIPT: begin
                    if (!card_inserted)
                        next_state <= IDLE;
                    else
                        next_state <= MENU;
                    $fwrite(output_file, "%b\n", balance);
                    $fwrite(output_file, "%b\n", error_code);
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule