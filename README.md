# ATM System Verilog Implementation

## Overview

This project implements a complete ATM (Automated Teller Machine) system using Verilog HDL. The system simulates real-world ATM functionality with secure card validation, PIN verification, and various banking operations.

## Features

- Card validation and insertion handling
- Secure PIN verification system
- Multiple transaction types:
  - Balance inquiry
  - Cash withdrawal
  - Cash deposit
  - PIN change
- Transaction logging system
- Daily withdrawal limit enforcement
- Error handling and status reporting
- Built-in testbench for verification

## Technical Specifications

### State Machine

The system implements a comprehensive state machine with the following main states:

- IDLE (8'b0000_0000)
- CARD_INSERT (8'b0000_0001)
- PIN_ENTRY (8'b0000_0101)
- MENU (8'b0000_1001)
- BALANCE_ENQ (8'b1000_0001)
- WITHDRAWAL (8'b1000_0111)
- DEPOSIT (8'b1000_0110)
- PIN_CHANGE (8'b1000_0010)

### Error Handling

The system includes comprehensive error detection with the following codes:

- NO_ERROR (8'h00)
- INVALID_CARD (8'h01)
- INVALID_PIN (8'h02)
- INSUF_BALANCE (8'h03)
- LIMIT_EXCEED (8'h04)
- CARD_BLOCKED (8'h05)

### Memory Management

- Card data storage using memory arrays
- Transaction history logging
- CSV file integration for initial card data loading

## Input/Output Ports

### Inputs

- `clk`: System clock
- `rst_n`: Active-low reset
- `card_inserted`: Card insertion signal
- `pin_input[15:0]`: PIN entry
- `amount[15:0]`: Transaction amount
- Various request signals (balance_req, withdrawal_req, deposit_req, pin_change_req)

### Outputs

- `current_state[7:0]`: Current system state
- `balance[15:0]`: Account balance
- `transaction_success`: Transaction status flag
- `error_code[7:0]`: Error status

## Getting Started

### Prerequisites

- Verilog HDL compatible simulator (e.g., ModelSim, XSIM, Icarus Verilog)
- CSV file named "atm_data_g31.csv" containing initial card data

### File Structure

```
├── atm_system.v          # Main ATM system module
├── atm_data_g31.csv     # Card data initialization file
└── atm_system_tb.v      # Testbench module (included in main file)
```

### Running Tests

The testbench includes various test scenarios:

1. Card insertion
2. PIN verification
3. Balance inquiry
4. Withdrawal operation

To run the tests:

1. Compile both the main module and testbench
2. Ensure atm_data_g31.csv is in the correct directory
3. Run the simulation using your preferred simulator

## Implementation Details

### Card Data Structure

Card information is stored in memory arrays with the following indices:

- CARD_PIN_IDX (0): PIN information
- CARD_BALANCE_IDX (1): Current balance
- CARD_STATUS_IDX (2): Card status
- CARD_LIMIT_IDX (3): Daily withdrawal limit

### Transaction Logging

The system maintains a transaction history with:

- Card number
- Transaction type
- Transaction amount

## Security Features

- PIN verification system
- Card validation checks
- Daily withdrawal limits
- Transaction logging for audit purposes
- Card blocking capability

## Future Enhancements

Potential areas for improvement:

- Multiple currency support
- Enhanced security features
- Network interface integration
- Multiple card support
- GUI interface integration

## Testing Considerations

The testbench provides basic functionality testing. For production use, consider adding:

- Edge case testing
- Stress testing
- Security vulnerability testing
- Timing violation checks

## Notes

- The system uses 8-bit state encodings for improved stability
- Error codes are implemented as 8-bit values
- The system assumes active-low reset
- Transaction history is maintained until power cycle
