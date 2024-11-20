import os
import subprocess
import random
from typing import Dict, List, Union
import tempfile

class ATMInputGenerator:
    def __init__(self, input_file='atm_input.txt', output_file='atm_output.txt'):
        """
        Initialize ATM input generator with configurable input file
        """
        self.input_file = input_file
        self.output_file = output_file
        self.OPERATIONS = {
            'BALANCE_CHECK' : 0x0001,
            'WITHDRAWAL' : 0x0002,
            'DEPOSIT' : 0x0004,
            "PIN_CHANGE" : 0x0008
        }

    def generate_card_data(
        self, 
        card_number,
        pin, 
        amount, 
        operation
    ) -> Dict[str, Union[int, str]]:
        """
        Generate synthetic card data with optional overrides
        
        :param card_number: Optional specific card number (8-bit)
        :param pin: Optional specific PIN (4-digit)
        :param amount: Optional specific transaction amount
        :param operation: Optional specific operation type
        :return: Dictionary with card transaction data
        """
        return {
            'card_number': card_number if card_number is not None else random.randint(0, 255),
            'pin': pin if pin is not None else random.randint(1000, 9999),
            'amount': amount if amount is not None else random.randint(10, 1000),
            'operation': operation if operation is not None else random.choice(list(self.OPERATIONS.values()))
        }

    def run_testbench(
        self, 
        testbench_path: str, 
        design_path: str = 'design.sv'
    ) -> Dict[str, Union[int, bool]]:
        """
        Run Verilog testbench and parse its output
        
        :param testbench_path: Path to the testbench Verilog file
        :param design_path: Path to the design Verilog file
        :return: Dictionary with simulation results
        """
        try:
            compile_cmd = ['iverilog', '-o', 'atm_sim', design_path, testbench_path]
            subprocess.run(compile_cmd, check=True, capture_output=True, text=True)
            
            run_cmd = ['vvp', 'atm_sim']
            result = subprocess.run(run_cmd, capture_output=True, text=True, check=True)
            
            with open(self.output_file, 'w') as f:
                f.write(result.stdout)
            
            return self.parse_testbench_output(result.stdout)
        
        except subprocess.CalledProcessError as e:
            print(f"Simulation error: {e}")
            print(f"Stdout: {e.stdout}")
            print(f"Stderr: {e.stderr}")
            raise
        finally:
            for file in ['atm_sim', testbench_path]:
                try:
                    os.remove(file)
                except FileNotFoundError:
                    pass
    

    def write_input_txt(
        self,
        card_number,
        pin,
        amount,
        operation,
        num_transactions: int = 1
    ) -> None:
        """
        Write transactions to input text file with optional specific transaction
        
        :param card_number: Specific card number (8-bit)
        :param pin: Specific PIN (4-digit)
        :param amount: Specific transaction amount
        :param operation: Specific operation type
        :param num_transactions: Number of transactions to generate
        """
        with open(self.input_file, 'w') as f:
            for _ in range(num_transactions):
                card_data = self.generate_card_data(card_number, pin, amount, operation)

                transaction_line = (
                    f"TRANSACTION {card_data['card_number'] : 02X}"
                    f"{card_data['pin']:04X} "
                    f"{card_data['amount']:04X} "
                    f"{card_data['operation']:04X}\n"
                )
                f.write(transaction_line)

    def parse_testbench_output(self, output: str) -> Dict[str, Union[int, bool]]:
        """
        Parse the testbench simulation output
        
        :param output: Raw output from the testbench simulation
        :return: Parsed results dictionary
        """
        results = {
            'state': None,
            'balance': None,
            'success': False,
            'error': None
        }
        
        for line in output.split('\n'):
            if "State:" in line:
                results['state'] = int(line.split()[-1], 16)
            elif "Balance:" in line:
                results['balance'] = int(line.split()[-1], 16)
            elif "Success:" in line:
                results['success'] = line.split()[-1] == '1'
            elif "Error:" in line:
                results['error'] = int(line.split()[-1], 16)
        
        return results
    
    def create_verilog_testbench(
        self, 
        operation: str, 
        card_number: int, 
        pin: int, 
        amount: int = 0, 
        new_pin: int = None
    ) -> str:
        """
        Create a Verilog testbench for different ATM operations
        
        :param operation: Type of operation (validate, balance, withdraw, deposit, pin_change)
        :param card_number: Card number for the transaction
        :param pin: Current PIN
        :param amount: Transaction amount (for withdraw/deposit)
        :param new_pin: New PIN (for PIN change)
        :return: Path to the generated testbench file
        """
        # Your existing testbench template with dynamic parameters
        testbench = f"""
        `timescale 1ns/1ps
        
        module atm_tb;
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
            
            // Instantiate ATM module
            atm_module atm (
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
                // Initialize signals
                clk = 0;
                rst_n = 0;
                card_inserted = 0;
                pin_input = 0;
                balance_req = 0;
                withdrawal_req = 0;
                deposit_req = 0;
                pin_change_req = 0;
                transaction_done = 0;
                amount = 0;
                card_number_input = 0;
                
                // Reset sequence
                #10 rst_n = 1;
                
                // Insert card and validate
                card_number_input = {card_number};
                #10 card_inserted = 1;
                #20 pin_input = {pin};
                #30;  // Wait for PIN verification
                
                case ("{operation}")
                    "balance": begin
                        #10 balance_req = 1;
                        #20 transaction_done = 1;
                    end
                    "withdraw": begin
                        #10 withdrawal_req = 1;
                        amount = {amount};
                        #20 transaction_done = 1;
                    end
                    "deposit": begin
                        #10 deposit_req = 1;
                        amount = {amount};
                        #20 transaction_done = 1;
                    end
                    "pin_change": begin
                        #10 pin_change_req = 1;
                        pin_input = {new_pin or pin};
                        #20 transaction_done = 1;
                    end
                endcase
                
                #100;  // Wait for operation to complete
                
                $display("State: %h", current_state);
                $display("Balance: %h", balance);
                $display("Success: %b", transaction_success);
                $display("Error: %h", error_code);
                $finish;
            end
            
            always #5 clk = ~clk;
            
        endmodule
        """
        
        # Create a temporary Verilog file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.v', delete=False) as f:
            f.write(testbench)
            return f.name