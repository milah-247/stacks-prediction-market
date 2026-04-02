;; =========================================================
;; Stacks Prediction Market - Market Factory Contract
;; market-factory.clar
;; =========================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-TEMPLATE-NOT-FOUND (err u501))
(define-constant ERR-TEMPLATE-EXISTS (err u502))
(define-constant ERR-INVALID-FEE (err u503))
(define-constant MAX-CREATION-FEE-BPS u1000) ;; 10% max

(define-data-var creation-fee-bps uint u50) ;; 0.5% default
(define-data-var factory-treasury principal CONTRACT-OWNER)
(define-data-var markets-created uint u0)

(define-map market-templates
  { template-id: (string-ascii 32) }
  {
    name: (string-utf8 64),
    description: (string-utf8 256),
    default-duration-blocks: uint,
    outcome-count: uint,
    active: bool,
    created-by: principal
  }
)

(define-map factory-markets
  { index: uint }
  { market-id: uint, template-id: (string-ascii 32), creator: principal, created-at: uint }
)

(define-read-only (get-template (template-id (string-ascii 32)))
  (map-get? market-templates { template-id: template-id })
)

(define-read-only (get-creation-fee) (var-get creation-fee-bps))
(define-read-only (get-markets-created) (var-get markets-created))

(define-read-only (get-factory-market (index uint))
  (map-get? factory-markets { index: index })
)

(define-public (register-template
    (template-id (string-ascii 32))
    (name (string-utf8 64))
    (description (string-utf8 256))
    (default-duration-blocks uint)
    (outcome-count uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? market-templates { template-id: template-id })) ERR-TEMPLATE-EXISTS)
    (map-set market-templates { template-id: template-id }
      { name: name, description: description, default-duration-blocks: default-duration-blocks,
        outcome-count: outcome-count, active: true, created-by: tx-sender })
    (print { event: "template-registered", template-id: template-id })
    (ok true)
  )
)

(define-public (record-market-from-template (market-id uint) (template-id (string-ascii 32)))
  (let ((idx (+ (var-get markets-created) u1)))
    (asserts! (is-some (map-get? market-templates { template-id: template-id })) ERR-TEMPLATE-NOT-FOUND)
    (var-set markets-created idx)
    (map-set factory-markets { index: idx }
      { market-id: market-id, template-id: template-id, creator: tx-sender, created-at: block-height })
    (print { event: "factory-market-recorded", market-id: market-id, template-id: template-id })
    (ok idx)
  )
)

(define-public (set-creation-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps MAX-CREATION-FEE-BPS) ERR-INVALID-FEE)
    (var-set creation-fee-bps new-fee-bps)
    (ok true)
  )
)

(define-public (set-factory-treasury (new-treasury principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set factory-treasury new-treasury)
    (ok true)
  )
)
