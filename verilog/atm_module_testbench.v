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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
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
        
        #20 withdrawal_req = 1;
        amount = 16'h0050;
        #20 withdrawal_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        #40;
        card_number_input = 8'h01;
        #20;
        
        pin_input = 16'h0000;
        #40;
        
        #300;
        
        card_inserted = 0;
        #20;
        
        #20 card_number_input = 8'h02;
        card_inserted = 1;
        #40;

        #20 card_number_input = 8'h00;
        #20 pin_input = 16'h1234;
        #40 deposit_req = 1;
        amount = 16'h0100;
        #20 deposit_req = 0;
        #20 transaction_done = 1;
        #20 transaction_done = 0;

        #100 $finish;
    end

    initial begin
        $monitor("Time=%0t State=%h Card=%h Pin=%h Error=%h Balance=%h Success=%b",
                 $time, current_state, card_number_input, pin_input, error_code,
                 balance, transaction_success);
                 
        $dumpfile("atm_test.vcd");
        $dumpvars(0, tb_atm_module);
    end
endmodule