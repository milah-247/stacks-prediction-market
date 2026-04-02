;; =========================================================
;; Stacks Prediction Market - SPM Token Staking Contract
;; spm-staking.clar
;; =========================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED    (err u400))
(define-constant ERR-ZERO-AMOUNT       (err u401))
(define-constant ERR-INSUFFICIENT-STAKE (err u402))
(define-constant ERR-LOCK-ACTIVE       (err u403))

(define-constant LOCK-PERIOD-BLOCKS u1008) ;; ~1 week

(define-map stakes
  { staker: principal }
  { amount: uint, locked-until: uint, rewards-claimed: uint }
)

(define-data-var total-staked uint u0)
(define-data-var reward-rate-bps uint u50) ;; 0.5% per lock period

(define-read-only (get-stake (staker principal))
  (map-get? stakes { staker: staker })
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-pending-rewards (staker principal))
  (match (map-get? stakes { staker: staker })
    s (let ((amount (get amount s)))
        (ok (/ (* amount (var-get reward-rate-bps)) u10000)))
    (ok u0)
  )
)

(define-public (stake (amount uint))
  (let (
    (existing (default-to { amount: u0, locked-until: u0, rewards-claimed: u0 }
      (map-get? stakes { staker: tx-sender })))
  )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (try! (contract-call? .market-token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set stakes { staker: tx-sender }
      { amount: (+ (get amount existing) amount),
        locked-until: (+ block-height LOCK-PERIOD-BLOCKS),
        rewards-claimed: (get rewards-claimed existing) })
    (var-set total-staked (+ (var-get total-staked) amount))
    (print { event: "staked", staker: tx-sender, amount: amount })
    (ok true)
  )
)

(define-public (unstake (amount uint))
  (let (
    (s (unwrap! (map-get? stakes { staker: tx-sender }) ERR-INSUFFICIENT-STAKE))
  )
    (asserts! (>= (get amount s) amount) ERR-INSUFFICIENT-STAKE)
    (asserts! (>= block-height (get locked-until s)) ERR-LOCK-ACTIVE)
    (map-set stakes { staker: tx-sender }
      (merge s { amount: (- (get amount s) amount) }))
    (var-set total-staked (- (var-get total-staked) amount))
    (try! (as-contract (contract-call? .market-token transfer amount tx-sender tx-sender none)))
    (print { event: "unstaked", staker: tx-sender, amount: amount })
    (ok true)
  )
)

(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set reward-rate-bps new-rate)
    (ok true)
  )
)
