import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import tempfile
import os

class ATM_GUI:
    def __init__(self, root):
        self.root = root
        self.root.title("ATM G31")
        
        self.card_number = tk.StringVar()
        self.pin = tk.StringVar()
        self.amount = tk.StringVar()
        self.new_pin = tk.StringVar()
        self.card_inserted = False
        self.pin_verified = False
        self.current_state = "IDLE"

        self.setup_gui()
    
    def setup_gui(self):
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        auth_frame = ttk.LabelFrame(main_frame, text="Card Authentication", padding="5")
        auth_frame.grid(row=0, column=0, columnspan=2, pady=5, sticky=(tk.W, tk.E))

        ttk.Label(auth_frame, text="Card Number:").grid(row=0, column=0, pady=5)
        self.card_entry = ttk.Entry(auth_frame, textvariable=self.card_number)
        self.card_entry.grid(row=0, column=1, pady=5)
        
        ttk.Label(auth_frame, text="PIN:").grid(row=1, column=0, pady=5)
        self.pin_entry = ttk.Entry(auth_frame, textvariable=self.pin, show="*")
        self.pin_entry.grid(row=1, column=1, pady=5)

        self.validate_btn = ttk.Button(auth_frame, text="Validate Card & PIN", command=self.validate_card_and_pin)
        self.validate_btn.grid(row=2, column=0, columnspan=2, pady=5)

        transaction_frame = ttk.LabelFrame(main_frame, text="Transaction", padding="5")
        transaction_frame.grid(row=1, column=0, columnspan=2, pady=5, sticky=(tk.W, tk.E))
        
        ttk.Label(transaction_frame, text="Amount:").grid(row=0, column=0, pady=5)
        self.amount_entry = ttk.Entry(transaction_frame, textvariable=self.amount)
        self.amount_entry.grid(row=0, column=1, pady=5)

        ttk.Label(transaction_frame, text="New PIN:").grid(row=1, column=0, pady=5)
        self.new_pin_entry = ttk.Entry(transaction_frame, textvariable=self.new_pin, show="*")
        self.new_pin_entry.grid(row=1, column=1, pady=5)

        menu_frame = ttk.LabelFrame(main_frame, text="Menu Options", padding="5")
        menu_frame.grid(row=2, column=0, columnspan=2, pady=5, sticky=(tk.W, tk.E))

        self.menu_buttons = {
            'balance': ttk.Button(menu_frame, text="Check Balance", command=self.check_balance),
            'withdraw': ttk.Button(menu_frame, text="Withdraw", command=self.withdraw),
            'deposit': ttk.Button(menu_frame, text="Deposit", command=self.deposit),
            'pin_change': ttk.Button(menu_frame, text="Change PIN", command=self.change_pin),
        }

        row = 0
        col = 0
        for button in self.menu_buttons.values():
            button.grid(row=row, column=col, padx=5, pady=5)
            col += 1
            if col > 1:
                col = 0
                row += 1

        self.exit_btn = ttk.Button(main_frame, text="Exit / Remove Card", command=self.exit_atm)
        self.exit_btn.grid(row=3, column=0, columnspan=2, pady=10)

        # Initialize GUI state
        self.update_gui_state()

    def validate_card_and_pin(self):
        if not self.card_number.get().isdigit():
            messagebox.showerror("Error", "Invalid card number")
            return
            
        if not self.pin.get().isdigit() or len(self.pin.get()) != 4:
            messagebox.showerror("Error", "Invalid PIN format")
            return
    
        testbench_path = self.create_verilog_testbench("validate")
        output = self.run_verilog_simulation(testbench_path)

        if output:
            state, balance, success, error = self.parse_simulation_results(output)
        
            if error:
                self.handle_error(error)
                self.pin_verified = False
            elif success:
                messagebox.showinfo("Success", "Card and PIN verified successfully")
                self.card_inserted = True
                self.pin_verified = True
                self.current_state = "MENU"
            else:
                messagebox.showerror("Error", "Invalid card or PIN")
                self.pin_verified = False
            
            self.update_gui_state()

    def update_gui_state(self):
        auth_state = 'normal' if self.current_state == "IDLE" else 'disabled'
        self.card_entry.config(state=auth_state)
        self.pin_entry.config(state=auth_state)
        self.validate_btn.config(state=auth_state)
        
        menu_state = 'normal' if self.pin_verified else 'disabled'
        for button in self.menu_buttons.values():
            button.config(state=menu_state)
            
        self.amount_entry.config(state=menu_state)
        self.new_pin_entry.config(state=menu_state)

    def handle_error(self, error_code):
        error_messages = {
            1: "Invalid card number",
            2: "Invalid PIN",
            3: "Insufficient funds",
            4: "Invalid amount",
            5: "Card blocked",
            6: "System error"
        }
        message = error_messages.get(error_code, "Unknown error")
        messagebox.showerror("Error", message)

    def create_verilog_testbench(self, operation):
        testbench = """
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
                if ("{operation}" == "validate") begin
                    card_number_input = {card_number};
                    #10 card_inserted = 1;
                    #20 pin_input = {pin};
                    #30;  // Wait for validation
                end
                else begin
                    // For other operations, ensure we're in a valid state first
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
                            pin_input = {new_pin};
                            #20 transaction_done = 1;
                        end
                    endcase
                end
                
                #100;  // Wait for operation to complete
                
                $display("State: %h", current_state);
                $display("Balance: %h", balance);
                $display("Success: %b", transaction_success);
                $display("Error: %h", error_code);
                $finish;
            end
            
            always #5 clk = ~clk;
            
        endmodule
        """.format(
            card_number=self.card_number.get(),
            pin=self.pin.get(),
            amount=self.amount.get() if self.amount.get() else '0',
            new_pin=self.new_pin.get() if self.new_pin.get() else '0',
            operation=operation
        )
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.v', delete=False) as f:
            f.write(testbench)
            return f.name

    def run_verilog_simulation(self, testbench_path):
        try:
            # Compile Verilog files
            subprocess.run(['iverilog', '-o', 'atm_sim', 'design.sv', testbench_path], check=True)
            
            # Run simulation
            result = subprocess.run(['vvp', 'atm_sim'], capture_output=True, text=True, check=True)
            
            # Clean up
            os.remove(testbench_path)
            os.remove('sim.vvp')
            
            return result.stdout
        except subprocess.CalledProcessError as e:
            messagebox.showerror("Error", f"Simulation failed: {e}")
            return None
    
    def check_balance(self):
        if not self.validate_state():
            return
            
        testbench_path = self.create_verilog_testbench("balance")
        output = self.run_verilog_simulation(testbench_path)
        
        if output:
            state, balance, success, error = self.parse_simulation_results(output)
            if error:
                self.handle_error(error)
            elif success:
                messagebox.showinfo("Balance", f"Your balance is ${balance}")

    def withdraw(self):
        if not self.validate_state(check_amount=True):
            return
            
        testbench_path = self.create_verilog_testbench("withdraw")
        output = self.run_verilog_simulation(testbench_path)
        
        if output:
            state, balance, success, error = self.parse_simulation_results(output)
            if error:
                self.handle_error(error)
            elif success:
                messagebox.showinfo("Success", f"Withdrawal successful\nRemaining balance: ${balance}")

    def deposit(self):
        if not self.validate_state(check_amount=True):
            return
            
        testbench_path = self.create_verilog_testbench("deposit")
        output = self.run_verilog_simulation(testbench_path)
        
        if output:
            state, balance, success, error = self.parse_simulation_results(output)
            if error:
                self.handle_error(error)
            elif success:
                messagebox.showinfo("Success", f"Deposit successful\nNew balance: ${balance}")

    def change_pin(self):
        if not self.validate_state(check_new_pin=True):
            return
            
        testbench_path = self.create_verilog_testbench("pin_change")
        output = self.run_verilog_simulation(testbench_path)
        
        if output:
            state, balance, success, error = self.parse_simulation_results(output)
            if error:
                self.handle_error(error)
            elif success:
                messagebox.showinfo("Success", "PIN changed successfully")
                self.exit_atm()

    def validate_state(self, check_amount=False, check_new_pin=False):
        if not self.card_inserted or not self.pin_verified:
            messagebox.showerror("Error", "Please validate card and PIN first")
            return False
            
        if check_amount:
            if not self.amount.get().isdigit() or int(self.amount.get()) <= 0:
                messagebox.showerror("Error", "Invalid amount")
                return False
                
        if check_new_pin:
            if not self.new_pin.get().isdigit() or len(self.new_pin.get()) != 4:
                messagebox.showerror("Error", "Invalid new PIN")
                return False
                
        return True

    def parse_simulation_results(self, output):
        state = None
        balance = None
        success = False
        error = None
        
        for line in output.split('\n'):
            if "State:" in line:
                state = int(line.split()[-1], 16)
            elif "Balance:" in line:
                balance = int(line.split()[-1], 16)
            elif "Success:" in line:
                success = line.split()[-1] == '1'
            elif "Error:" in line:
                error = int(line.split()[-1], 16)
                
        return state, balance, success, error

    def exit_atm(self):
        self.card_number.set("")
        self.pin.set("")
        self.amount.set("")
        self.new_pin.set("")
        self.card_inserted = False
        self.pin_verified = False
        self.current_state = "IDLE"
        self.update_gui_state()
        messagebox.showinfo("Exit", "Thank you for using the ATM")

if __name__ == "__main__":
    root = tk.Tk()
    app = ATM_GUI(root)
    root.mainloop()