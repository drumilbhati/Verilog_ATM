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
    parameter BALANCE_ENQ   = 8'b0001_0000; 
    parameter WITHDRAWAL    = 8'b0001_0001;
    parameter DEPOSIT       = 8'b0001_0010;
    parameter PIN_CHANGE    = 8'b0001_0011;
    parameter AMOUNT_VALID  = 8'b0001_0100;
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

    // Initialize memory
    initial begin
        $readmemh("atm_data_g31.hex", card_data);
    end

    // Modified Sequential Logic Block
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
        end else begin
            current_state <= next_state;
            
            case (current_state)
                CARD_INSERT: begin
                    current_card_number <= card_number_input;
                    error_code <= NO_ERROR;
                    transaction_success <= 0;
                    pin_attempts <= 0; // Reset attempts on new card
                end

                CARD_VALIDATE: begin
                    if (card_data[current_card_number*4 + CARD_STATUS_IDX] != 16'h0001) begin
                        error_code <= INVALID_CARD;
                    end else begin
                        stored_pin <= card_data[current_card_number*4 + CARD_PIN_IDX];
                        daily_limit <= card_data[current_card_number*4 + CARD_LIMIT_IDX];
                        error_code <= NO_ERROR;
                    end
                end

                PIN_CHECK: begin
                    if (pin_input == stored_pin) begin
                        next_state = PIN_VALID; // Go to new intermediate state
                    end else if (pin_attempts >= 2) begin
                        next_state = CARD_ERROR;
                    end else begin
                        next_state = PIN_ERROR;
                    end
                end
                
                PIN_VALID: begin // New state handler
                    next_state = MENU;
                end
                
                MENU: begin
                    if (!card_inserted) // Add exit condition
                        next_state = IDLE;
                    else if (balance_req)
                        next_state = BALANCE_ENQ;
                    else if (withdrawal_req)
                        next_state = WITHDRAWAL;
                    else if (deposit_req)
                        next_state = DEPOSIT;
                    else if (pin_change_req)
                        next_state = PIN_CHANGE;
                end
                
                BALANCE_ENQ: begin
                    // Fix: Read balance using proper array indexing
                    balance <= card_data[current_card_number*4 + CARD_BALANCE_IDX];
                    if (transaction_done) begin
                        transaction_success <= 1;
                    end
                end

                WITHDRAWAL: begin
                    if (amount <= card_data[current_card_number*4 + CARD_BALANCE_IDX] &&
                        amount <= daily_limit) begin
                        if (transaction_done) begin
                            // Fix: Update balance first, then update card data
                            balance <= card_data[current_card_number*4 + CARD_BALANCE_IDX] - amount;
                            card_data[current_card_number*4 + CARD_BALANCE_IDX] <= 
                                card_data[current_card_number*4 + CARD_BALANCE_IDX] - amount;
                            transaction_success <= 1;
                            error_code <= NO_ERROR;
                        end
                    end else if (amount > daily_limit) begin
                        error_code <= LIMIT_EXCEED;
                    end else begin
                        error_code <= INSUF_BALANCE;
                    end
                end

                DEPOSIT: begin
                    if (transaction_done) begin
                        // Fix: Update balance first, then update card data
                        balance <= card_data[current_card_number*4 + CARD_BALANCE_IDX] + amount;
                        card_data[current_card_number*4 + CARD_BALANCE_IDX] <= 
                            card_data[current_card_number*4 + CARD_BALANCE_IDX] + amount;
                        transaction_success <= 1;
                        error_code <= NO_ERROR;
                    end
                end
                                
                PIN_CHANGE: begin
                    if (!card_inserted)
                        next_state = IDLE;
                    else if (transaction_done)
                        next_state = MENU;
                end
                
                AMOUNT_VALID: begin
                    if (!card_inserted)
                        next_state = IDLE;
                    else if (transaction_done)
                        next_state = PRINT_RECEIPT;
                end
                
                PRINT_RECEIPT: begin
                    if (!card_inserted)
                        next_state = IDLE;
                    else
                        next_state = MENU;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end

    // Modified Combinational Logic Block - Key Changes
    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (card_inserted)
                    next_state = CARD_INSERT;
            end

            CARD_INSERT: begin
                next_state = CARD_VALIDATE;
            end

            CARD_VALIDATE: begin
                if (card_data[current_card_number][CARD_STATUS_IDX] == 16'h0001)
                    next_state = CARD_VALID;
                else
                    next_state = CARD_ERROR;
            end

            CARD_ERROR: begin
                if (!card_inserted)
                    next_state = IDLE;
            end

            CARD_VALID: begin
                next_state = PIN_ENTRY;
            end

            PIN_ENTRY: begin
                next_state = PIN_CHECK;
            end

            PIN_CHECK: begin
                if (pin_input == stored_pin) begin
                    next_state = MENU;
                    pin_valid = 1;
                end else if (pin_attempts >= 2) begin // Check for 2 since increment happens after
                    next_state = CARD_ERROR;
                end else begin
                    next_state = PIN_ERROR;
                end
            end

            PIN_ERROR: begin
                next_state = PIN_ENTRY;
            end

            MENU: begin
                if (balance_req)
                    next_state = BALANCE_ENQ;
                else if (withdrawal_req)
                    next_state = WITHDRAWAL;
                else if (deposit_req)
                    next_state = DEPOSIT;
                else if (pin_change_req)
                    next_state = PIN_CHANGE;
            end

            BALANCE_ENQ: begin
                if (transaction_done)
                    next_state = PRINT_RECEIPT;
            end

            WITHDRAWAL: begin
                if (amount <= card_data[current_card_number][CARD_BALANCE_IDX] &&
                    amount <= daily_limit) begin
                    if (transaction_done)
                        next_state = AMOUNT_VALID;
                end else
                    next_state = MENU;
            end

            DEPOSIT: begin
                if (transaction_done)
                    next_state = AMOUNT_VALID;
            end

            PIN_CHANGE: begin
                if (transaction_done)
                    next_state = MENU;
            end

            AMOUNT_VALID: begin
                if (transaction_done)
                    next_state = PRINT_RECEIPT;
            end

            PRINT_RECEIPT: begin
                next_state = MENU;
            end

            default: next_state = IDLE;
        endcase
    end
endmodule