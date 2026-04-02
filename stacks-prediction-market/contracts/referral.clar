;; =========================================================
;; Stacks Prediction Market - Referral Contract
;; referral.clar
;; =========================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-ALREADY-REGISTERED (err u401))
(define-constant ERR-SELF-REFERRAL (err u402))
(define-constant ERR-NO-REFERRER (err u403))
(define-constant REFERRAL-FEE-BPS u100) ;; 1% of bet routed to referrer

(define-map referrals
  { referee: principal }
  { referrer: principal, registered-at: uint, total-earned: uint }
)

(define-map referrer-stats
  { referrer: principal }
  { total-referrals: uint, total-earned: uint }
)

(define-read-only (get-referrer (referee principal))
  (map-get? referrals { referee: referee })
)

(define-read-only (get-referrer-stats (referrer principal))
  (map-get? referrer-stats { referrer: referrer })
)

(define-public (register-referral (referrer principal))
  (begin
    (asserts! (not (is-eq tx-sender referrer)) ERR-SELF-REFERRAL)
    (asserts! (is-none (map-get? referrals { referee: tx-sender })) ERR-ALREADY-REGISTERED)
    (map-set referrals { referee: tx-sender }
      { referrer: referrer, registered-at: block-height, total-earned: u0 })
    (let ((stats (default-to { total-referrals: u0, total-earned: u0 }
                   (map-get? referrer-stats { referrer: referrer }))))
      (map-set referrer-stats { referrer: referrer }
        (merge stats { total-referrals: (+ (get total-referrals stats) u1) }))
    )
    (print { event: "referral-registered", referee: tx-sender, referrer: referrer })
    (ok true)
  )
)

(define-public (credit-referral (referee principal) (bet-amount uint))
  (let (
    (ref-data (unwrap! (map-get? referrals { referee: referee }) ERR-NO-REFERRER))
    (referrer (get referrer ref-data))
    (reward (/ (* bet-amount REFERRAL-FEE-BPS) u10000))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set referrals { referee: referee }
      (merge ref-data { total-earned: (+ (get total-earned ref-data) reward) }))
    (let ((stats (default-to { total-referrals: u0, total-earned: u0 }
                   (map-get? referrer-stats { referrer: referrer }))))
      (map-set referrer-stats { referrer: referrer }
        (merge stats { total-earned: (+ (get total-earned stats) reward) }))
    )
    (ok reward)
  )
)
