;; =========================================================
;; Stacks Prediction Market - Governance Token (SIP-010)
;; market-token.clar
;; =========================================================

(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-NOT-AUTHORIZED       (err u300))
(define-constant ERR-NOT-TOKEN-OWNER      (err u301))
(define-constant ERR-INSUFFICIENT-BALANCE (err u302))
(define-constant ERR-INVALID-AMOUNT       (err u303))
(define-constant ERR-CAP-EXCEEDED         (err u304))

(define-constant TOKEN-NAME "Stacks Prediction Market")
(define-constant TOKEN-SYMBOL "SPM")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI (some u"https://stacksprediction.market/token/spm.json"))
(define-constant MAX-SUPPLY u1000000000000000)

(define-fungible-token spm-token MAX-SUPPLY)

(define-data-var total-minted uint u0)
(define-data-var minting-enabled bool true)

(define-map minter-allowances
  { minter: principal }
  { allowance: uint }
)

(define-read-only (get-name) (ok TOKEN-NAME))
(define-read-only (get-symbol) (ok TOKEN-SYMBOL))
(define-read-only (get-decimals) (ok TOKEN-DECIMALS))
(define-read-only (get-balance (account principal)) (ok (ft-get-balance spm-token account)))
(define-read-only (get-total-supply) (ok (ft-get-supply spm-token)))
(define-read-only (get-token-uri) (ok TOKEN-URI))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (ft-transfer? spm-token amount sender recipient))
    (match memo m (begin (print m) true) true)
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal))
  (let ((current-supply (ft-get-supply spm-token)))
    (asserts!
      (or (is-eq tx-sender CONTRACT-OWNER)
        (> (default-to u0 (get allowance (map-get? minter-allowances { minter: tx-sender }))) u0))
      ERR-NOT-AUTHORIZED
    )
    (asserts! (var-get minting-enabled) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ current-supply amount) MAX-SUPPLY) ERR-CAP-EXCEEDED)
    (try! (ft-mint? spm-token amount recipient))
    (var-set total-minted (+ (var-get total-minted) amount))
    (ok true)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) ERR-NOT-TOKEN-OWNER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (ft-burn? spm-token amount owner))
    (ok true)
  )
)

(define-public (set-minter-allowance (minter principal) (allowance uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set minter-allowances { minter: minter } { allowance: allowance })
    (ok true)
  )
)

(define-public (toggle-minting)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set minting-enabled (not (var-get minting-enabled)))
    (ok true)
  )
)

(define-public (reward-participant (participant principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (ft-mint? spm-token amount participant))
    (print { event: "participant-rewarded", participant: participant, amount: amount })
    (ok true)
  )
)
