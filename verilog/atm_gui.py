from tkinter import *
from tkinter import messagebox
import subprocess

# Function to simulate writing input data to a file
def write_to_file(card_number, pin):
    with open("input_data.txt", "w") as input_file:
        input_file.write(f"{card_number}\n")
        input_file.write(f"{pin}\n")

# Function to simulate running the testbench
def run_testbench():
    try:
        subprocess.run(['iverilog', '-o', 'atm_module_testbench.vvp', 'atm_module_testbench.v', 'design.v'], check=True)
        subprocess.run(['vvp', 'atm_module_testbench.vvp'], check=True)
        return "Success"
    except subprocess.CalledProcessError as e:
        return f"Error: {e}"

# Function to handle login and navigate to transaction window
def login():
    card_number = e1.get()
    pin = e2.get()
    if not card_number or not pin:
        messagebox.showerror("Error", "Card number and PIN must be provided!")
        return

    write_to_file(card_number, pin)
    result = run_testbench()
    if "Success" in result:
        open_transaction_window()
    else:
        messagebox.showerror("Testbench Error", result)

# Open transaction window
def open_transaction_window():
    master.withdraw()  # Hide the login window
    transaction_window = Toplevel()
    transaction_window.title("Transaction Options")

    Label(transaction_window, text="Select Transaction Type").pack(pady=10)
    
    Button(transaction_window, text="Withdraw Money", command=lambda: open_withdraw_window(transaction_window)).pack(pady=5)
    Button(transaction_window, text="Check Balance", command=lambda: show_result(transaction_window, "Your balance is $500")).pack(pady=5)
    Button(transaction_window, text="Exit", command=transaction_window.destroy).pack(pady=10)

# Open withdrawal window
def open_withdraw_window(transaction_window):
    transaction_window.withdraw()
    withdraw_window = Toplevel()
    withdraw_window.title("Withdraw Money")

    Label(withdraw_window, text="Enter Amount").pack(pady=10)
    amount_entry = Entry(withdraw_window)
    amount_entry.pack(pady=5)

    def process_withdrawal():
        amount = amount_entry.get()
        if not amount.isdigit():
            messagebox.showerror("Error", "Invalid amount entered!")
            return
        show_result(withdraw_window, f"Successfully withdrew ${amount}")

    Button(withdraw_window, text="Submit", command=process_withdrawal).pack(pady=5)
    Button(withdraw_window, text="Back", command=lambda: back_to_window(withdraw_window, transaction_window)).pack(pady=5)

# Display result window
def show_result(current_window, message):
    current_window.withdraw()
    result_window = Toplevel()
    result_window.title("Result")

    Label(result_window, text=message).pack(pady=10)
    Button(result_window, text="Back to Menu", command=lambda: back_to_window(result_window, master)).pack(pady=5)

# Navigate back to a previous window
def back_to_window(current_window, target_window):
    current_window.destroy()
    target_window.deiconify()

# Main application
if __name__ == "__main__":
    master = Tk()
    master.title("ATM Login")
    
    Label(master, text="Card Number").grid(row=0, column=0, padx=10, pady=5)
    e1 = Entry(master)
    e1.grid(row=0, column=1, padx=10, pady=5)

    Label(master, text="PIN").grid(row=1, column=0, padx=10, pady=5)
    e2 = Entry(master, show="*")
    e2.grid(row=1, column=1, padx=10, pady=5)

    Button(master, text="Login", command=login).grid(row=2, column=0, columnspan=2, pady=10)

    master.mainloop()
