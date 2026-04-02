;; =========================================================
;; Stacks Prediction Market - On-chain Governance
;; governance.clar
;; =========================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED  (err u500))
(define-constant ERR-NOT-FOUND       (err u501))
(define-constant ERR-ALREADY-VOTED   (err u502))
(define-constant ERR-VOTING-CLOSED   (err u503))
(define-constant ERR-ALREADY-EXISTS  (err u504))

(define-constant VOTING-PERIOD-BLOCKS u2016) ;; ~2 weeks
(define-constant QUORUM-THRESHOLD u1000000000) ;; 1000 SPM (6 decimals)

(define-data-var proposal-nonce uint u0)

(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { support: bool, weight: uint }
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (is-proposal-passing (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    p (ok (and
            (> (get votes-for p) (get votes-against p))
            (>= (+ (get votes-for p) (get votes-against p)) QUORUM-THRESHOLD)))
    (err u501)
  )
)

(define-public (create-proposal (title (string-utf8 128)) (description (string-utf8 512)))
  (let (
    (proposal-id (+ (var-get proposal-nonce) u1))
    (balance (unwrap! (contract-call? .market-token get-balance tx-sender) ERR-NOT-AUTHORIZED))
  )
    (asserts! (> balance u0) ERR-NOT-AUTHORIZED)
    (var-set proposal-nonce proposal-id)
    (map-set proposals { proposal-id: proposal-id }
      { proposer: tx-sender,
        title: title,
        description: description,
        votes-for: u0,
        votes-against: u0,
        end-block: (+ block-height VOTING-PERIOD-BLOCKS),
        executed: false })
    (print { event: "proposal-created", proposal-id: proposal-id, proposer: tx-sender })
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
    (weight (unwrap! (contract-call? .market-token get-balance tx-sender) ERR-NOT-AUTHORIZED))
  )
    (asserts! (< block-height (get end-block proposal)) ERR-VOTING-CLOSED)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
    (asserts! (> weight u0) ERR-NOT-AUTHORIZED)
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } { support: support, weight: weight })
    (map-set proposals { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if support (+ (get votes-for proposal) weight) (get votes-for proposal)),
        votes-against: (if support (get votes-against proposal) (+ (get votes-against proposal) weight))
      }))
    (print { event: "voted", proposal-id: proposal-id, voter: tx-sender, support: support, weight: weight })
    (ok true)
  )
)
