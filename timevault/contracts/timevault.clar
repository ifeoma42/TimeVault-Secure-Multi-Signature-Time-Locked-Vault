;; TimeVault: Secure Multi-Signature Time-Locked Vault
;; A secure smart contract for conditional asset storage and controlled release

(define-constant ERROR-NOT-AUTHORIZED (err u1))
(define-constant ERROR-INSUFFICIENT-SIGNATURES (err u2))
(define-constant ERROR-TIME-LOCK-ACTIVE (err u3))
(define-constant ERROR-INVALID-SIGNER (err u4))
(define-constant ERROR-ALREADY-SIGNED (err u5))
(define-constant ERROR-EMERGENCY-UNLOCK-DISABLED (err u6))
(define-constant ERROR-GUARDIAN-REQUIRED (err u7))
(define-constant ERROR-INSUFFICIENT-FUNDS (err u8))
(define-constant ERROR-INVALID-WITHDRAWAL (err u9))
(define-constant ERROR-INVALID-PARAMETER (err u10))

;; Validate unsigned integer input
(define-private (validate-uint-input (value uint))
  (and (> value u0) (<= value u340282366920938463463374607431768211455))
)

;; Validate list of signers
(define-private (validate-signer-list (signers (list 5 principal)))
  (and 
    (> (len signers) u0) 
    (<= (len signers) u5)
    (is-none (index-of signers tx-sender))
  )
)

;; Vault configuration storage
(define-map vault-settings
  { vault-identifier: uint }
  {
    unlock-timestamp: uint,
    signature-threshold: uint,
    authorized-signers: (list 5 principal),
    total-funds: uint,
    claimed-funds: uint,
    confirmed-signers: (list 5 principal),
    backup-guardian: (optional principal),
    emergency-unlock-active: bool,
    emergency-unlock-timestamp: (optional uint),
    partial-withdrawal-settings: {
      partial-threshold: uint,
      partial-signature-threshold: uint
    }
  }
)

;; Track signatures for partial withdrawals
(define-map partial-withdrawal-approvals
  { vault-identifier: uint, withdrawal-identifier: uint, signer: principal }
  { has-approved: bool }
)

;; Track partial withdrawal requests
(define-map partial-withdrawal-queue
  { vault-identifier: uint, withdrawal-identifier: uint }
  {
    withdrawal-amount: uint,
    approved-signers: (list 5 principal),
    is-approved: bool,
    destination: principal
  }
)

;; Create a new time-locked multi-signature vault
(define-public (create-new-vault 
  (unlock-timestamp uint)
  (signature-threshold uint)
  (authorized-signers (list 5 principal))
  (initial-funds uint)
  (backup-guardian (optional principal))
  (emergency-unlock-active bool)
  (emergency-unlock-timestamp (optional uint))
  (partial-threshold uint)
  (partial-signature-threshold uint))
  (let 
    (
      (vault-identifier (var-get next-vault-identifier))
      (sender tx-sender)
    )
    ;; Validate all input parameters
    (asserts! (validate-uint-input initial-funds) ERROR-INVALID-PARAMETER)
    (asserts! (validate-uint-input unlock-timestamp) ERROR-INVALID-PARAMETER)
    (asserts! (validate-signer-list authorized-signers) ERROR-INVALID-SIGNER)
    
    ;; Validate signature thresholds
    (asserts! (> signature-threshold u0) ERROR-INVALID-SIGNER)
    (asserts! (<= signature-threshold (len authorized-signers)) ERROR-INSUFFICIENT-SIGNATURES)
    (asserts! (<= partial-signature-threshold signature-threshold) ERROR-INVALID-SIGNER)
    (asserts! (validate-uint-input partial-threshold) ERROR-INVALID-PARAMETER)
    
    ;; Validate emergency unlock timestamp if provided
    (asserts! 
      (match emergency-unlock-timestamp 
        unlock-time (validate-uint-input unlock-time)
        true
      )
      ERROR-INVALID-PARAMETER
    )
    
    ;; Transfer initial funds to the contract
    (try! (stx-transfer? initial-funds sender (as-contract tx-sender)))
    
    ;; Store vault configuration
    (map-set vault-settings 
      { vault-identifier: vault-identifier }
      {
        unlock-timestamp: unlock-timestamp,
        signature-threshold: signature-threshold,
        authorized-signers: authorized-signers,
        total-funds: initial-funds,
        claimed-funds: u0,
        confirmed-signers: (list),
        backup-guardian: backup-guardian,
        emergency-unlock-active: emergency-unlock-active,
        emergency-unlock-timestamp: emergency-unlock-timestamp,
        partial-withdrawal-settings: {
          partial-threshold: partial-threshold,
          partial-signature-threshold: partial-signature-threshold
        }
      }
    )
    
    ;; Increment vault identifier
    (var-set next-vault-identifier (+ vault-identifier u1))
    
    (ok vault-identifier)
  )
)

;; Request a partial withdrawal
(define-public (request-partial-funds 
  (vault-identifier uint) 
  (withdrawal-amount uint) 
  (destination principal))
  (let 
    (
      (vault (unwrap! 
        (map-get? vault-settings { vault-identifier: vault-identifier }) 
        ERROR-NOT-AUTHORIZED
      ))
      (sender tx-sender)
      (withdrawal-identifier (var-get next-withdrawal-identifier))
      (partial-settings (get partial-withdrawal-settings vault))
    )
    ;; Validate input parameters
    (asserts! (validate-uint-input vault-identifier) ERROR-INVALID-PARAMETER)
    (asserts! (validate-uint-input withdrawal-amount) ERROR-INVALID-PARAMETER)
    
    ;; Validate destination address
    (asserts! (not (is-eq destination tx-sender)) ERROR-NOT-AUTHORIZED)
    
    ;; Validate withdrawal amount
    (asserts! 
      (>= 
        (- (get total-funds vault) (get claimed-funds vault)) 
        withdrawal-amount
      ) 
      ERROR-INSUFFICIENT-FUNDS
    )
    (asserts! (> withdrawal-amount u0) ERROR-INVALID-WITHDRAWAL)
    (asserts! 
      (<= withdrawal-amount (/ (get total-funds vault) (get partial-threshold partial-settings))) 
      ERROR-INVALID-WITHDRAWAL
    )
    
    ;; Create partial withdrawal request
    (map-set partial-withdrawal-queue
      { vault-identifier: vault-identifier, withdrawal-identifier: withdrawal-identifier }
      {
        withdrawal-amount: withdrawal-amount,
        approved-signers: (list),
        is-approved: false,
        destination: destination
      }
    )
    
    ;; Increment withdrawal identifier
    (var-set next-withdrawal-identifier (+ withdrawal-identifier u1))
    
    (ok withdrawal-identifier)
  )
)

;; Approve a partial withdrawal request
(define-public (approve-partial-withdrawal 
  (vault-identifier uint) 
  (withdrawal-identifier uint))
  (let 
    (
      (vault (unwrap! 
        (map-get? vault-settings { vault-identifier: vault-identifier }) 
        ERROR-NOT-AUTHORIZED
      ))
      (withdrawal-request (unwrap! 
        (map-get? partial-withdrawal-queue { 
          vault-identifier: vault-identifier, 
          withdrawal-identifier: withdrawal-identifier 
        }) 
        ERROR-NOT-AUTHORIZED
      ))
      (sender tx-sender)
      (partial-settings (get partial-withdrawal-settings vault))
    )
    ;; Validate input parameters
    (asserts! (validate-uint-input vault-identifier) ERROR-INVALID-PARAMETER)
    (asserts! (validate-uint-input withdrawal-identifier) ERROR-INVALID-PARAMETER)
    
    ;; Validate approver
    (asserts! (is-some (index-of (get authorized-signers vault) sender)) ERROR-NOT-AUTHORIZED)
    (asserts! 
      (is-none (map-get? partial-withdrawal-approvals { 
        vault-identifier: vault-identifier, 
        withdrawal-identifier: withdrawal-identifier, 
        signer: sender 
      })) 
      ERROR-NOT-AUTHORIZED
    )
    
    ;; Record approval
    (map-set partial-withdrawal-approvals 
      { 
        vault-identifier: vault-identifier, 
        withdrawal-identifier: withdrawal-identifier, 
        signer: sender 
      }
      { has-approved: true }
    )
    
    ;; Update approved signers for withdrawal request
    (map-set partial-withdrawal-queue
      { vault-identifier: vault-identifier, withdrawal-identifier: withdrawal-identifier }
      (merge withdrawal-request { 
        approved-signers: (unwrap-panic (as-max-len? 
          (append (get approved-signers withdrawal-request) sender) 
          u5
        )) 
      })
    )
    
    ;; Check if withdrawal can be executed
    (if (>= (len (get approved-signers withdrawal-request)) (get partial-signature-threshold partial-settings))
      (begin
        ;; Mark withdrawal as approved
        (map-set partial-withdrawal-queue
          { vault-identifier: vault-identifier, withdrawal-identifier: withdrawal-identifier }
          (merge withdrawal-request { is-approved: true })
        )
        true
      )
      true
    )
    
    (ok true)
  )
)

;; Execute an approved partial withdrawal
(define-public (execute-approved-withdrawal 
  (vault-identifier uint) 
  (withdrawal-identifier uint))
  (let 
    (
      (vault (unwrap! 
        (map-get? vault-settings { vault-identifier: vault-identifier }) 
        ERROR-NOT-AUTHORIZED
      ))
      (withdrawal-request (unwrap! 
        (map-get? partial-withdrawal-queue { 
          vault-identifier: vault-identifier, 
          withdrawal-identifier: withdrawal-identifier 
        }) 
        ERROR-NOT-AUTHORIZED
      ))
      (partial-settings (get partial-withdrawal-settings vault))
    )
    ;; Validate input parameters
    (asserts! (validate-uint-input vault-identifier) ERROR-INVALID-PARAMETER)
    (asserts! (validate-uint-input withdrawal-identifier) ERROR-INVALID-PARAMETER)
    
    ;; Validate withdrawal approval status
    (asserts! (get is-approved withdrawal-request) ERROR-NOT-AUTHORIZED)
    
    ;; Transfer funds to the destination
    (try! 
      (as-contract 
        (stx-transfer? 
          (get withdrawal-amount withdrawal-request) 
          tx-sender 
          (get destination withdrawal-request)
        )
      )
    )
    
    ;; Update vault funds
    (map-set vault-settings 
      { vault-identifier: vault-identifier }
      (merge vault { 
        claimed-funds: (+ (get claimed-funds vault) (get withdrawal-amount withdrawal-request)) 
      })
    )
    
    (ok true)
  )
)

;; Initialize counters
(define-data-var next-vault-identifier uint u1)
(define-data-var next-withdrawal-identifier uint u1)

;; Read-only function to fetch vault details
(define-read-only (fetch-vault-details (vault-identifier uint))
  (map-get? vault-settings { vault-identifier: vault-identifier })
)