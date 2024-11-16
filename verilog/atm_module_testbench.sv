module tb_atm_module;
    // Inputs
    reg clk;
    reg rst_n;
    reg card_inserted;
    reg [15:0] pin_input;
    reg balance_req;
    reg withdrawal_req;
    reg deposit_req;
    reg pin_change_req;
    reg transaction_done;
    reg [15:0] amount;
    reg [7:0] card_number_input;

    // Outputs
    wire [7:0] current_state;
    wire [15:0] balance;
    wire transaction_success;
    wire [7:0] error_code;

    // Instantiate ATM module
    atm_module uut (
        .clk(clk),
        .rst_n(rst_n),
        .card_inserted(card_inserted),
        .pin_input(pin_input),
        .balance_req(balance_req),
        .withdrawal_req(withdrawal_req),
        .deposit_req(deposit_req),
        .pin_change_req(pin_change_req),
        .transaction_done(transaction_done),
        .amount(amount),
        .card_number_input(card_number_input),
        .current_state(current_state),
        .balance(balance),
        .transaction_success(transaction_success),
        .error_code(error_code)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize inputs
        rst_n = 0;
        card_inserted = 0;
        pin_input = 16'h0000;
        balance_req = 0;
        withdrawal_req = 0;
        deposit_req = 0;
        pin_change_req = 0;
        transaction_done = 0;
        amount = 16'h0000;
        card_number_input = 8'h00;

        // Reset sequence
        #20 rst_n = 1;
        
        // Test Case 1: Valid card and PIN
        #20;
        card_number_input = 8'h00; // Card 0 (PIN=1234)
        card_inserted = 1;
        #20 card_inserted = 0;
        
        #20 pin_input = 16'h1234; // Correct PIN
        #40; // Wait for PIN verification
        
        // Check balance
        balance_req = 1;
        #20 balance_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;
        
        // Make withdrawal
        #20 withdrawal_req = 1;
        amount = 16'h0050; // Withdraw 80
        #20 withdrawal_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        // Test Case 2: Invalid PIN
        #40;
        card_number_input = 8'h01; // Card 1
        card_inserted = 1;
        #20 card_inserted = 0;
        
        #20 pin_input = 16'h0000; // Wrong PIN
        #40; // Wait for PIN verification

        // End simulation
        #100 $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0t rst_n=%b card_inserted=%b pin_input=%h current_state=%d balance=%h success=%b error=%h",
                 $time, rst_n, card_inserted, pin_input, current_state, balance, transaction_success, error_code);
    end

endmodule