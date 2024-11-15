
module atm_testbench;
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
    wire [7:0] current_state;
    wire [15:0] balance;
    wire transaction_success;
    wire [7:0] error;

    atm_module inst1(
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
        .current_state(current_state),
        .balance(balance),
        .transaction_success(transaction_success),
        error_code(error_code)
    );

    // clock generation
    initial begin
        clk = 0;
        forever #5 cl = ~clk;
    end

    initial begin
        rst_n = 0;
        card_inserted = 0;
        pin_input = 0;
        balance_req = 0;
        withdrawal_req = 0;
        deposit_req = 0;
        pin_change_req = 0;
        transaction_done = 0;
        amount = 0;

        #10 rst_n = 1;

        #10 card_inserted = 1;
        amount = 16'h0001;
        #10 card_inserted = 0;

        #20 pin_input = 16'h1234;

        #20 balance_req = 1;
        #10 balance_req = 0;
        #20 transaction_done = 1;
        #10 transaction_done = 0;

        #20 withdrawal_req = 1;
        amount = 16'h0064;
        #10 withdrawal_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;


        #100 $finish;
    end
    
    initial begin
        $monitor("Time=%0t rst_n=%0b card_inserted=%0b pin_input=%0h state=%0h balance=%0h success=%0b error=%0h",
                 $time, rst_n, card_inserted, pin_input, current_state, balance, 
                 transaction_success, error_code);
    end
endmodule