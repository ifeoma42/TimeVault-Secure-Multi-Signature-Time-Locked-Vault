# TimeVault: Secure Multi-Signature Time-Locked Vault

**TimeVault** is a secure and flexible smart contract designed for conditional asset storage and controlled release. Built on the Clarity smart contract language, TimeVault enables users to create multi-signature vaults with time-locked withdrawals, partial withdrawals, and emergency unlock mechanisms. It is ideal for managing funds in a decentralized and secure manner, ensuring that assets are only released under specific conditions.

---

## Features

1. **Multi-Signature Security**:
   - Requires multiple authorized signers to approve withdrawals.
   - Configurable signature threshold for added flexibility.

2. **Time-Locked Withdrawals**:
   - Funds are locked until a specified timestamp.
   - Ensures assets cannot be accessed prematurely.

3. **Partial Withdrawals**:
   - Allows partial withdrawals with a lower signature threshold.
   - Useful for accessing a portion of funds without full consensus.

4. **Emergency Unlock**:
   - Optional emergency unlock mechanism with a guardian.
   - Can be configured to allow withdrawals after a specified time delay.

5. **Guardian Role**:
   - A designated guardian can oversee the vault and enable emergency withdrawals.

6. **Transparent and Auditable**:
   - All vault configurations and transactions are stored on-chain.
   - Read-only functions to query vault details and status.

---

## How It Works

### 1. **Create a Vault**
   - Deploy a new vault with a specified unlock timestamp, signature threshold, and list of authorized signers.
   - Optionally, configure a guardian and enable emergency unlock functionality.

### 2. **Deposit Funds**
   - Transfer funds into the vault during creation or afterward.
   - Funds are locked until the unlock timestamp or until emergency conditions are met.

### 3. **Request Partial Withdrawals**
   - Authorized signers can request partial withdrawals for a specified amount.
   - Partial withdrawals require a lower signature threshold than full withdrawals.

### 4. **Approve Withdrawals**
   - Authorized signers approve withdrawal requests by submitting their signatures.
   - Once the required number of signatures is reached, the withdrawal can be executed.

### 5. **Execute Withdrawals**
   - Approved withdrawals are executed, transferring funds to the specified recipient.

### 6. **Emergency Unlock**
   - If enabled, the guardian can unlock the vault after the emergency unlock timestamp.
   - Funds can be withdrawn without meeting the usual signature threshold.

---

## Smart Contract Functions

### Core Functions
- **`create-new-vault`**: Deploy a new vault with specified parameters.
- **`request-partial-funds`**: Request a partial withdrawal from the vault.
- **`approve-partial-withdrawal`**: Approve a partial withdrawal request.
- **`execute-approved-withdrawal`**: Execute an approved withdrawal.

### Read-Only Functions
- **`fetch-vault-details`**: Retrieve details of a specific vault.

---

## Usage

### Deploying a Vault
To create a new vault, call the `create-new-vault` function with the following parameters:
- `unlock-timestamp`: The timestamp when the vault unlocks.
- `signature-threshold`: The number of signatures required for withdrawals.
- `authorized-signers`: A list of up to 5 authorized signers.
- `initial-funds`: The initial amount of funds to deposit.
- `backup-guardian`: (Optional) The guardian address for emergency unlocks.
- `emergency-unlock-active`: Whether emergency unlock is enabled.
- `emergency-unlock-timestamp`: (Optional) The timestamp for emergency unlock.
- `partial-threshold`: The threshold for partial withdrawals.
- `partial-signature-threshold`: The number of signatures required for partial withdrawals.

Example:
```clarity
(create-new-vault 
  u1735689600 
  u3 
  (list 'SP1ABC123 'SP1XYZ456 'SP1DEF789) 
  u1000000 
  (some 'SP1GUARDIAN) 
  true 
  (some u1735689600) 
  u2 
  u2
)
```

### Requesting a Partial Withdrawal
To request a partial withdrawal, call the `request-partial-funds` function:
- `vault-identifier`: The ID of the vault.
- `withdrawal-amount`: The amount to withdraw.
- `destination`: The recipient address.

Example:
```clarity
(request-partial-funds u1 u500000 'SP1RECIPIENT)
```

### Approving a Withdrawal
To approve a withdrawal request, call the `approve-partial-withdrawal` function:
- `vault-identifier`: The ID of the vault.
- `withdrawal-identifier`: The ID of the withdrawal request.

Example:
```clarity
(approve-partial-withdrawal u1 u1)
```

### Executing a Withdrawal
To execute an approved withdrawal, call the `execute-approved-withdrawal` function:
- `vault-identifier`: The ID of the vault.
- `withdrawal-identifier`: The ID of the withdrawal request.

Example:
```clarity
(execute-approved-withdrawal u1 u1)
```

---

## Error Codes

| Code | Error Name                       | Description                                      |
|------|----------------------------------|--------------------------------------------------|
| u1   | ERROR-NOT-AUTHORIZED             | Caller is not authorized to perform the action.  |
| u2   | ERROR-INSUFFICIENT-SIGNATURES    | Insufficient signatures for the operation.       |
| u3   | ERROR-TIME-LOCK-ACTIVE           | The vault is still time-locked.                  |
| u4   | ERROR-INVALID-SIGNER             | Invalid signer provided.                         |
| u5   | ERROR-ALREADY-SIGNED             | Signer has already approved the request.         |
| u6   | ERROR-EMERGENCY-UNLOCK-DISABLED  | Emergency unlock is not enabled for this vault.  |
| u7   | ERROR-GUARDIAN-REQUIRED          | Guardian approval is required.                   |
| u8   | ERROR-INSUFFICIENT-FUNDS         | Insufficient funds in the vault.                 |
| u9   | ERROR-INVALID-WITHDRAWAL         | Invalid withdrawal amount or parameters.         |
| u10  | ERROR-INVALID-PARAMETER          | Invalid input parameter provided.                |

---

## Security Considerations
- Ensure that the `signature-threshold` is set appropriately to prevent unauthorized withdrawals.
- Use a trusted guardian for emergency unlocks.
- Regularly audit the vault configuration and signer list.


---

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

---

**TimeVault**: Secure your assets with confidence. 🚀