;; =========================================================
;; Stacks Prediction Market - Oracle Contract
;; oracle.clar
;; =========================================================

(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-NOT-AUTHORIZED  (err u200))
(define-constant ERR-FEED-NOT-FOUND  (err u201))
(define-constant ERR-FEED-EXISTS     (err u202))
(define-constant ERR-INVALID-VALUE   (err u203))
(define-constant ERR-OPERATOR-EXISTS (err u205))

(define-constant MAX-STALENESS-BLOCKS u288)

(define-data-var oracle-nonce uint u0)

(define-map oracle-operators
  { operator: principal }
  { active: bool, added-at: uint }
)

(define-map data-feeds
  { feed-id: (string-ascii 64) }
  {
    description: (string-utf8 256),
    value: (string-utf8 256),
    updated-at: uint,
    updated-by: principal,
    active: bool
  }
)

(define-map market-feeds
  { market-id: uint }
  { feed-id: (string-ascii 64), outcome-mapping: (string-utf8 512) }
)

(define-map feed-history
  { feed-id: (string-ascii 64), slot: uint }
  { value: (string-utf8 256), block-height: uint, operator: principal }
)

(define-map feed-history-nonce
  { feed-id: (string-ascii 64) }
  { count: uint }
)

(define-read-only (get-feed (feed-id (string-ascii 64)))
  (map-get? data-feeds { feed-id: feed-id })
)

(define-read-only (get-feed-value (feed-id (string-ascii 64)))
  (match (map-get? data-feeds { feed-id: feed-id })
    feed (ok (get value feed))
    (err u201)
  )
)

(define-read-only (is-feed-fresh (feed-id (string-ascii 64)))
  (match (map-get? data-feeds { feed-id: feed-id })
    feed (ok (<= (- block-height (get updated-at feed)) MAX-STALENESS-BLOCKS))
    (err u201)
  )
)

(define-read-only (is-operator (address principal))
  (match (map-get? oracle-operators { operator: address })
    op (get active op)
    false
  )
)

(define-read-only (get-market-feed (market-id uint))
  (map-get? market-feeds { market-id: market-id })
)

(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? oracle-operators { operator: operator })) ERR-OPERATOR-EXISTS)
    (map-set oracle-operators { operator: operator } { active: true, added-at: block-height })
    (ok true)
  )
)

(define-public (remove-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set oracle-operators { operator: operator } { active: false, added-at: block-height })
    (ok true)
  )
)

(define-public (create-feed (feed-id (string-ascii 64)) (description (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? data-feeds { feed-id: feed-id })) ERR-FEED-EXISTS)
    (map-set data-feeds
      { feed-id: feed-id }
      { description: description, value: u"", updated-at: block-height, updated-by: tx-sender, active: true }
    )
    (ok true)
  )
)

(define-public (update-feed (feed-id (string-ascii 64)) (value (string-utf8 256)))
  (let (
    (feed (unwrap! (map-get? data-feeds { feed-id: feed-id }) ERR-FEED-NOT-FOUND))
    (history-nonce (default-to { count: u0 } (map-get? feed-history-nonce { feed-id: feed-id })))
    (slot (mod (get count history-nonce) u10))
  )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-operator tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (get active feed) ERR-FEED-NOT-FOUND)
    (asserts! (> (len value) u0) ERR-INVALID-VALUE)
    (map-set feed-history { feed-id: feed-id, slot: slot } { value: value, block-height: block-height, operator: tx-sender })
    (map-set feed-history-nonce { feed-id: feed-id } { count: (+ (get count history-nonce) u1) })
    (map-set data-feeds { feed-id: feed-id } (merge feed { value: value, updated-at: block-height, updated-by: tx-sender }))
    (print { event: "feed-updated", feed-id: feed-id, value: value, operator: tx-sender })
    (ok true)
  )
)

(define-public (link-market-to-feed (market-id uint) (feed-id (string-ascii 64)) (outcome-mapping (string-utf8 512)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? data-feeds { feed-id: feed-id })) ERR-FEED-NOT-FOUND)
    (map-set market-feeds { market-id: market-id } { feed-id: feed-id, outcome-mapping: outcome-mapping })
    (print { event: "market-feed-linked", market-id: market-id, feed-id: feed-id })
    (ok true)
  )
)
