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
    output reg [7:0] current_state,
    output reg [15:0] balance,
    output reg transaction_success,
    output reg [7:0] error_code
);
    parameter IDLE = 8'b0000_0000;
    parameter CARD_INSERT = 8'b0000_0001;
    parameter CARD_VALIDATE = 8'b0000_0010;
    parameter CARD_ERROR = 8'b0000_0011;
    parameter CARD_VALID = 8'b0000_0100;
    parameter PIN_ENTRY = 8'b0000_0101;
    parameter PIN_CHECK = 8'b0000_0110;
    parameter PIN_ERROR = 8'b0000_0111;
    parameter MENU = 8'b0000_1001;
    parameter BALANCE_ENQ = 8'b1000_0001;
    parameter BALANCE_PROC = 8'b1100_0001;
    parameter PIN_CHANGE = 8'b1000_0010;
    parameter NEW_PIN_ENTRY = 8'b1100_0101;
    parameter PIN_VALIDATE = 8'b1100_0110;
    parameter DEPOSIT = 8'b1000_0110;
    parameter WITHDRAWAL = 8'b1000_0111;
    parameter AMOUNT_ENTRY = 8'b1000_1000;
    parameter AMOUNT_VALID = 8'b1000_1001;
    parameter PRINT_RECEIPT = 8'b1000_1010;

    // Error codes
    parameter NO_ERROR = 8'h00;
    parameter INVALID_CARD = 8'h01;
    parameter INVALID_PIN = 8'h02;
    parameter INSUF_BALANCE = 8'h03;
    parameter LIMIT_EXCEED = 8'h004;

    // Internal registers
    reg [7:0] state, next_state;
    reg [15:0] current_card_number;
    reg [15:0] stored_pin;
    reg [15:0] daily_limit;
    reg [15:0] transaction_count;
    reg card_active;

    // Memory arrays for data storage
    reg [15:0] card_data [0:1023];
    reg [15:0] transaction_history [0:1023];
    reg [15:0] transaction_ptr;

    // Card data structure indices
    parameter CARD_PIN_IDX = 0;
    parameter CARD_BALANCE_IDX = 1;
    parameter CARD_STATUS_IDX = 2;
    parameter CARD_LIMIT_IDX = 3;

    // Initialize memory from csv file
    initial begin
        $readmemh("atm_data_g31.csv", card_data);
        transaction_ptr = 16'h0000;
        transaction_count = 16'h000;
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            error_code <= NO_ERROR;
            transaction_success <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Validate card using a helper function
    function [15:0] validate_card;
        input [15:0] card_num;
        begin
            if (card_data[card_num][CARD_STATUS_IDX] == 16'h0001) begin
                validate_card = 16'h0001;
            end else begin
                validate_card = 16'h0000;
            end
        end
    endfunction

    // Pin validation helper function
    function [15:0] check_pin;
        input [15:0] entered_pin;
        input [15:0] card_num;
        begin
            if (entered_pin == card_data[card_num][CARD_PIN_IDX]) begin
                check_pin = 16'h0001;
            end else begin
                check_pin = 16'h0000;
            end
        end
    endfunction

    // task to log each transaction
    task log_transaction;
        input [15:0] card_num;
        input [15:0] transaction_type;
        input [15:0] transaction_amount;
        begin
            transaction_history[transaction_ptr] = {card_num[3:0], transaction_type[3:0], transaction_amount};
            transaction_ptr = transaction_ptr + 1;
            transaction_count = transaction_count + 1;
        end
    endtask

    always @(*) begin
        next_state = state;
        transaction_success = 0;
        error_code = NO_ERROR;

        case (state)
            IDLE: begin
                if (card_inserted) begin
                    next_state = CARD_INSERT;
                    current_card_number = amount;
                end
            end

            CARD_INSERT: begin
                if (validate_card(current_card_number) == 16'h0001) begin
                    next_state = CARD_VALID;
                    stored_pin = card_data[current_card_number][CARD_PIN_IDX];
                    daily_limit = card_data[current_card_number][CARD_LIMIT_IDX];
                end else begin
                    next_state = CARD_ERROR;
                    error_code = INVALID_CARD;
                end
            end

            CARD_VALID: begin
                next_state = PIN_ENTRY;
            end

            PIN_ENTRY: begin
                next_state = PIN_CHECK;
            end

            PIN_CHECK: begin
                if (check_pin(pin_input, current_card_number) == 16'h001) begin
                    next_state = MENU;
                end else begin
                    next_state = PIN_ERROR;
                    error_code = INVALID_PIN;
                end
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
                balance = card_data[current_card_number][CARD_BALANCE_IDX];
                if (transaction_done) begin
                    next_state = MENU;
                    log_transaction(current_card_number, 16'h0001, 16'h0000);
                end
            end

            WITHDRAWAL: begin
                if (amount <= card_data[current_card_number][CARD_BALANCE_IDX]) begin
                    if (amount <= daily_limit)
                    next_state = AMOUNT_VALID;
                    card_data[current_card_number][CARD_BALANCE_IDX] -= amount;
                    log_transaction(current_card_number, 16'h002, amount);
                    transaction_success = 1;
                end else begin
                    next_state = MENU;
                    error_code = LIMIT_EXCEED;
                end
            end else begin
                next_state = MENU;
                error_code = INSUF_BALANCE;
            end

            DEPOSIT: begin
                next_state = AMOUNT_VALID;
                card_data[current_card_number][CARD_BALANCE_IDX] += amount;
                log_transaction(current_card_number, 16'h0003, amount);
                transaction_success = 1;
            end
            
            PIN_CHANGE: begin
                next_state = NEW_PIN_ENTRY;
            end

            NEW_PIN_ENTRY: begin
                card_data[current_card_number][CARD_PIN_IDX] = pin_input;
                log_transaction(current_card_number, 16'h0004, 16'h0000);
                next_state = MENU;
                transaction_success = 1;
            end

            AMOUNT_VALID: begin
                next_state = PRINT_RECEIPT;
            end

            PRINT_RECEIPT: begin
                if (transaction_done)
                    next_state = MENU;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk) begin
        current_state <= state;
    end

endmodule