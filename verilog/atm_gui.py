import tkinter as tk
from tkinter import ttk, messagebox
import re
import subprocess
import tempfile
import os
from gui_api import ATMInputGenerator

class ATMApp:
    def __init__(self, root):
        self.root = root
        self.root.title("ATM Banking System")
        self.root.geometry("400x600")
        self.root.configure(bg='#f0f0f0')

        # Style configuration
        self.style = ttk.Style()
        self.style.configure('TLabel', background='#f0f0f0', font=('Arial', 10))
        self.style.configure('TButton', font=('Arial', 10))
        self.style.configure('Title.TLabel', font=('Arial', 16, 'bold'), foreground='#2c3e50')

        # Input generator
        self.generator = ATMInputGenerator()

        # State variables
        self.card_number = tk.StringVar()
        self.pin = tk.StringVar()
        self.amount = tk.StringVar()
        self.new_pin = tk.StringVar()

        # Create main container
        self.container = ttk.Frame(root, style='TFrame')
        self.container.pack(fill='both', expand=True, padx=20, pady=20)

        # Create frames for different stages
        self.create_login_frame()

    def create_login_frame(self):
        # Clear existing widgets
        for widget in self.container.winfo_children():
            widget.destroy()

        # Login Frame
        login_frame = ttk.Frame(self.container)
        login_frame.pack(fill='both', expand=True)

        # Title
        ttk.Label(login_frame, text="ATM Login", style='Title.TLabel').pack(pady=(20, 30))

        # Card Number
        card_label = ttk.Label(login_frame, text="Card Number:")
        card_label.pack(pady=(10, 5))
        card_entry = ttk.Entry(login_frame, textvariable=self.card_number, width=30)
        card_entry.pack(pady=(0, 10))

        # PIN
        pin_label = ttk.Label(login_frame, text="PIN:")
        pin_label.pack(pady=(10, 5))
        pin_entry = ttk.Entry(login_frame, textvariable=self.pin, show="*", width=30)
        pin_entry.pack(pady=(0, 20))

        # Login Button
        login_button = ttk.Button(login_frame, text="Login", 
                                  command=self.validate_login, 
                                  style='Accent.TButton')
        login_button.pack(pady=20)

    def validate_login(self):
        # Validate card number and PIN format
        if not re.match(r'^\d{8}$', self.card_number.get()):
            messagebox.showerror("Error", "Card number must be 8 digits")
            return
        
        if not re.match(r'^\d{4}$', self.pin.get()):
            messagebox.showerror("Error", "PIN must be 4 digits")
            return

        # Run Verilog simulation for validation
        try:
            testbench_path = self.create_verilog_testbench("validate")
            output = self.run_verilog_simulation(testbench_path)

            if output:
                state, balance, success, error = self.parse_simulation_results(output)
                
                if success:
                    # Move to transaction window
                    self.create_transaction_frame(balance)
                elif error:
                    self.handle_error(error)
                else:
                    messagebox.showerror("Error", "Invalid card or PIN")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def create_transaction_frame(self, balance):
        # Clear existing widgets
        for widget in self.container.winfo_children():
            widget.destroy()

        # Transaction Frame
        transaction_frame = ttk.Frame(self.container)
        transaction_frame.pack(fill='both', expand=True)

        # Title and Balance
        ttk.Label(transaction_frame, text="ATM Transactions", 
                  style='Title.TLabel').pack(pady=(20, 10))
        ttk.Label(transaction_frame, 
                  text=f"Current Balance: ${balance}", 
                  font=('Arial', 12)).pack(pady=(0, 20))

        # Transaction Buttons
        transaction_options = [
            ("Check Balance", self.check_balance),
            ("Withdraw", self.withdraw),
            ("Deposit", self.deposit),
            ("Change PIN", self.change_pin),
            ("Exit", self.exit_atm)
        ]

        for label, command in transaction_options:
            btn = ttk.Button(transaction_frame, text=label, 
                             command=command, width=30)
            btn.pack(pady=10)

    def check_balance(self):
        testbench_path = self.create_verilog_testbench("balance")
        output = self.run_verilog_simulation(testbench_path)
        
        if output:
            state, balance, success, error = self.parse_simulation_results(output)
            if error:
                self.handle_error(error)
            elif success:
                messagebox.showinfo("Balance", f"Your balance is ${balance}")

    def withdraw(self):
        # Create withdraw amount popup
        withdraw_window = tk.Toplevel(self.root)
        withdraw_window.title("Withdraw")
        withdraw_window.geometry("300x200")

        ttk.Label(withdraw_window, text="Enter Withdrawal Amount:").pack(pady=(20, 10))
        amount_entry = ttk.Entry(withdraw_window, textvariable=self.amount)
        amount_entry.pack(pady=(0, 10))
        amount_entry.focus()

        def process_withdrawal():
            if not re.match(r'^\d+$', self.amount.get()):
                messagebox.showerror("Error", "Invalid amount")
                return
            
            testbench_path = self.create_verilog_testbench("withdraw")
            output = self.run_verilog_simulation(testbench_path)
            
            if output:
                state, balance, success, error = self.parse_simulation_results(output)
                if error:
                    self.handle_error(error)
                elif success:
                    messagebox.showinfo("Success", f"Withdrawal successful\nRemaining balance: ${balance}")
                    withdraw_window.destroy()

        ttk.Button(withdraw_window, text="Withdraw", command=process_withdrawal).pack(pady=10)

    def deposit(self):
        # Create deposit amount popup
        deposit_window = tk.Toplevel(self.root)
        deposit_window.title("Deposit")
        deposit_window.geometry("300x200")

        ttk.Label(deposit_window, text="Enter Deposit Amount:").pack(pady=(20, 10))
        amount_entry = ttk.Entry(deposit_window, textvariable=self.amount)
        amount_entry.pack(pady=(0, 10))
        amount_entry.focus()

        def process_deposit():
            if not re.match(r'^\d+$', self.amount.get()):
                messagebox.showerror("Error", "Invalid amount")
                return
            
            testbench_path = self.create_verilog_testbench("deposit")
            output = self.run_verilog_simulation(testbench_path)
            
            if output:
                state, balance, success, error = self.parse_simulation_results(output)
                if error:
                    self.handle_error(error)
                elif success:
                    messagebox.showinfo("Success", f"Deposit successful\nNew balance: ${balance}")
                    deposit_window.destroy()

        ttk.Button(deposit_window, text="Deposit", command=process_deposit).pack(pady=10)

    def change_pin(self):
        # Create change PIN popup
        pin_window = tk.Toplevel(self.root)
        pin_window.title("Change PIN")
        pin_window.geometry("300x250")

        ttk.Label(pin_window, text="Enter New PIN:").pack(pady=(20, 10))
        new_pin_entry = ttk.Entry(pin_window, textvariable=self.new_pin, show="*")
        new_pin_entry.pack(pady=(0, 10))
        new_pin_entry.focus()

        def process_pin_change():
            if not re.match(r'^\d{4}$', self.new_pin.get()):
                messagebox.showerror("Error", "New PIN must be 4 digits")
                return
            
            testbench_path = self.create_verilog_testbench("pin_change")
            output = self.run_verilog_simulation(testbench_path)
            
            if output:
                state, balance, success, error = self.parse_simulation_results(output)
                if error:
                    self.handle_error(error)
                elif success:
                    messagebox.showinfo("Success", "PIN changed successfully")
                    pin_window.destroy()
                    self.exit_atm()

        ttk.Button(pin_window, text="Change PIN", command=process_pin_change).pack(pady=10)

    def exit_atm(self):
        # Reset variables and go back to login screen
        self.card_number.set("")
        self.pin.set("")
        self.amount.set("")
        self.new_pin.set("")
        self.create_login_frame()

    def create_verilog_testbench(self, operation):
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
                card_number_input = {int(self.card_number.get())};
                #10 card_inserted = 1;
                #20 pin_input = {int(self.pin.get())};
                #30;  // Wait for PIN verification
                
                case ("{operation}")
                    "validate": begin
                        // Just verify card and PIN
                        #100;
                    end
                    "balance": begin
                        #10 balance_req = 1;
                        #20 transaction_done = 1;
                    end
                    "withdraw": begin
                        #10 withdrawal_req = 1;
                        amount = {int(self.amount.get()) if self.amount.get() else 0};
                        #20 transaction_done = 1;
                    end
                    "deposit": begin
                        #10 deposit_req = 1;
                        amount = {int(self.amount.get()) if self.amount.get() else 0};
                        #20 transaction_done = 1;
                    end
                    "pin_change": begin
                        #10 pin_change_req = 1;
                        pin_input = {int(self.new_pin.get()) if self.new_pin.get() else 0};
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
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.v', delete=False) as f:
            f.write(testbench)
            return f.name

    def run_verilog_simulation(self, testbench_path):
        try:
            subprocess.run('iverilog -o atm_sim ${testbench_path} design.v')
            result = subprocess.run('vvp atm_sim')
            os.remove(testbench_path)
            os.remove('atm_sim')
            
            return result.stdout
        except subprocess.CalledProcessError as e:
            messagebox.showerror("Error", f"Simulation failed: {e}")
            return None

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

def main():
    root = tk.Tk()
    root.resizable(False, False)
    app = ATMApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()