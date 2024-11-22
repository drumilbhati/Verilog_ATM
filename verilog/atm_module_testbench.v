`include "design.v"

module tb_atm_module;
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

    wire [7:0] current_state;
    wire [15:0] balance;
    wire transaction_success;
    wire [7:0] error_code;

    // Register to store the transaction type
    reg [31:0] transaction_type;

    // Instantiate the ATM module
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
        forever #5 clk = ~clk; // 10 ns clock period
    end

    // Transaction type logic
    always @(*) begin
        if (balance_req)
            transaction_type = "Balance Inquiry";
        else if (withdrawal_req)
            transaction_type = "Withdrawal";
        else if (deposit_req)
            transaction_type = "Deposit";
        else if (pin_change_req)
            transaction_type = "PIN Change";
        else
            transaction_type = "None";
    end

    // Test sequence
    initial begin
        // Reset the system
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

        #20 rst_n = 1;

        // Test case 1: Valid card and PIN, balance inquiry
        #20;
        card_number_input = 8'h00;
        card_inserted = 1;
        #20;
        pin_input = 16'h1234;
        #40;
        balance_req = 1;
        #20 balance_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        // Test case 2: Valid card, invalid PIN (multiple attempts)
        #40;
        card_number_input = 8'h01;
        card_inserted = 1;
        #20;
        pin_input = 16'h1111;  // Incorrect PIN
        #40;
        pin_input = 16'h2222;  // Incorrect PIN
        #40;
        pin_input = 16'h3333;  // Incorrect PIN, triggers card lock

        // Test case 3: Withdrawal exceeding balance
        #40;
        card_number_input = 8'h00;
        pin_input = 16'h1234;
        #40;
        withdrawal_req = 1;
        amount = 16'hFFFF;  // Large withdrawal amount
        #20 withdrawal_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        // Test case 4: Successful withdrawal
        #40;
        withdrawal_req = 1;
        amount = 16'h0050;  // Valid withdrawal amount
        #20 withdrawal_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        // Test case 5: Deposit operation
        #40;
        deposit_req = 1;
        amount = 16'h0100;  // Deposit amount
        #20 deposit_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        // Test case 6: PIN change
        #40;
        pin_change_req = 1;
        pin_input = 16'h5678;  // New PIN
        #20 pin_change_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        // Test case 7: Invalid card
        #40;
        card_number_input = 8'hFF;  // Nonexistent card
        card_inserted = 1;
        #40;

        // Test case 8: Card removed during operation
        #40;
        card_number_input = 8'h00;
        card_inserted = 1;
        #20;
        pin_input = 16'h1234;
        #40;
        card_inserted = 0;  // Simulate card removal
        #40;

        // Finish simulation
        #100 $finish;
    end

    // Monitor to display simulation details
    initial begin
        $monitor("Time=%0t State=%h Card=%h Pin=%h Error=%h Balance=%h Success=%b Transaction=%s",
                 $time, current_state, card_number_input, pin_input, error_code,
                 balance, transaction_success, transaction_type);
                 
        $dumpfile("atm_test.vcd");
        $dumpvars(0, tb_atm_module);
    end
endmodule