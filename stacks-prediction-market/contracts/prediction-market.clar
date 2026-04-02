;; =========================================================
;; Stacks Prediction Market - Core Contract
;; prediction-market.clar
;; =========================================================

;; ---- Constants ----

(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-NOT-AUTHORIZED          (err u100))
(define-constant ERR-MARKET-NOT-FOUND        (err u101))
(define-constant ERR-MARKET-CLOSED           (err u102))
(define-constant ERR-MARKET-NOT-RESOLVED     (err u103))
(define-constant ERR-MARKET-ALREADY-RESOLVED (err u104))
(define-constant ERR-INVALID-OUTCOME         (err u105))
(define-constant ERR-ZERO-BET               (err u106))
(define-constant ERR-BET-TOO-LARGE          (err u107))
(define-constant ERR-ALREADY-CLAIMED        (err u108))
(define-constant ERR-NO-WINNINGS            (err u109))
(define-constant ERR-DEADLINE-PASSED        (err u110))
(define-constant ERR-BETTING-CUTOFF         (err u111))
(define-constant ERR-INVALID-DEADLINE       (err u112))
(define-constant ERR-NO-BET-FOUND          (err u113))
(define-constant ERR-WITHDRAWAL-FAILED      (err u114))
(define-constant ERR-MARKET-DISPUTED        (err u115))
(define-constant ERR-INVALID-TITLE          (err u117))
(define-constant ERR-TRANSFER-FAILED        (err u119))

(define-constant MAX-BET-PERCENT u20)
(define-constant EARLY-WITHDRAWAL-FEE-BPS u500)
(define-constant BPS-DENOMINATOR u10000)
(define-constant BETTING-CUTOFF-BLOCKS u144)
(define-constant MIN-DEADLINE-BLOCKS u144)
(define-constant PLATFORM-FEE-BPS u200)
(define-constant DISPUTE-WINDOW-BLOCKS u144)

;; ---- Data Variables ----

(define-data-var market-nonce uint u0)
(define-data-var platform-treasury principal CONTRACT-OWNER)
(define-data-var oracle-principal principal CONTRACT-OWNER)
(define-data-var total-platform-fees uint u0)
(define-data-var paused bool false)
(define-data-var reentrancy-lock bool false)

;; ---- Data Maps ----

(define-map markets
  { market-id: uint }
  {
    creator: principal,
    title: (string-utf8 256),
    description: (string-utf8 1024),
    outcome-count: uint,
    deadline: uint,
    resolution-block: uint,
    resolved: bool,
    winning-outcome: uint,
    total-pool: uint,
    disputed: bool,
    oracle-resolved: bool,
    created-at: uint
  }
)

(define-map market-outcomes
  { market-id: uint, outcome-index: uint }
  { label: (string-utf8 64), pool: uint }
)

(define-map bets
  { market-id: uint, user: principal, outcome-index: uint }
  { amount: uint, claimed: bool, withdrawn: bool }
)

(define-map claimed-winnings
  { market-id: uint, user: principal }
  { claimed: bool, amount: uint }
)

(define-map user-market-outcomes
  { market-id: uint, user: principal, slot: uint }
  { outcome-index: uint }
)

(define-map user-market-bet-count
  { market-id: uint, user: principal }
  { count: uint }
)

(define-map disputes
  { market-id: uint }
  { disputer: principal, reason: (string-utf8 256), block-height: uint }
)

;; ---- Read-Only Functions ----

(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

(define-read-only (get-market-outcome (market-id uint) (outcome-index uint))
  (map-get? market-outcomes { market-id: market-id, outcome-index: outcome-index })
)

(define-read-only (get-bet (market-id uint) (user principal) (outcome-index uint))
  (map-get? bets { market-id: market-id, user: user, outcome-index: outcome-index })
)

(define-read-only (get-claim-status (market-id uint) (user principal))
  (map-get? claimed-winnings { market-id: market-id, user: user })
)

(define-read-only (get-market-count)
  (var-get market-nonce)
)

(define-read-only (get-oracle-principal)
  (var-get oracle-principal)
)

(define-read-only (get-platform-fees)
  (var-get total-platform-fees)
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (calculate-winnings (market-id uint) (user principal))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) (err u0)))
    (winning-outcome (get winning-outcome market))
    (total-pool (get total-pool market))
    (winning-pool-data (unwrap! (map-get? market-outcomes { market-id: market-id, outcome-index: winning-outcome }) (err u0)))
    (winning-pool (get pool winning-pool-data))
    (user-bet (unwrap! (map-get? bets { market-id: market-id, user: user, outcome-index: winning-outcome }) (err u0)))
    (user-amount (get amount user-bet))
    (platform-fee (/ (* total-pool PLATFORM-FEE-BPS) BPS-DENOMINATOR))
    (distributable-pool (- total-pool platform-fee))
  )
    (if (is-eq winning-pool u0)
      (ok u0)
      (ok (/ (* user-amount distributable-pool) winning-pool))
    )
  )
)

(define-read-only (get-early-withdrawal-amount (market-id uint) (user principal) (outcome-index uint))
  (let (
    (bet-data (unwrap! (map-get? bets { market-id: market-id, user: user, outcome-index: outcome-index }) (err u0)))
    (amount (get amount bet-data))
    (fee (/ (* amount EARLY-WITHDRAWAL-FEE-BPS) BPS-DENOMINATOR))
  )
    (ok (- amount fee))
  )
)

;; ---- Private Helpers ----

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-oracle)
  (is-eq tx-sender (var-get oracle-principal))
)

(define-private (assert-not-paused)
  (if (var-get paused)
    ERR-NOT-AUTHORIZED
    (ok true)
  )
)

(define-private (assert-no-reentrance)
  (if (var-get reentrancy-lock)
    ERR-NOT-AUTHORIZED
    (begin (var-set reentrancy-lock true) (ok true))
  )
)

(define-private (release-lock)
  (var-set reentrancy-lock false)
)

(define-private (store-outcome (market-id uint) (index uint) (label (string-utf8 64)))
  (map-set market-outcomes
    { market-id: market-id, outcome-index: index }
    { label: label, pool: u0 }
  )
)

;; ---- Admin Functions ----

(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set oracle-principal new-oracle)
    (ok true)
  )
)

(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set platform-treasury new-treasury)
    (ok true)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set paused (not (var-get paused)))
    (ok true)
  )
)

(define-public (withdraw-platform-fees)
  (let (
    (fees (var-get total-platform-fees))
    (treasury (var-get platform-treasury))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> fees u0) ERR-NO-WINNINGS)
    (var-set total-platform-fees u0)
    (as-contract (stx-transfer? fees tx-sender treasury))
  )
)

;; ---- Core: Market Creation ----

(define-public (create-market
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (outcome-a (string-utf8 64))
    (outcome-b (string-utf8 64))
    (deadline uint))
  (let (
    (market-id (+ (var-get market-nonce) u1))
    (current-block block-height)
  )
    (try! (assert-not-paused))
    (asserts! (> (len title) u0) ERR-INVALID-TITLE)
    (asserts! (> deadline (+ current-block MIN-DEADLINE-BLOCKS)) ERR-INVALID-DEADLINE)
    (var-set market-nonce market-id)
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        outcome-count: u2,
        deadline: deadline,
        resolution-block: u0,
        resolved: false,
        winning-outcome: u0,
        total-pool: u0,
        disputed: false,
        oracle-resolved: false,
        created-at: current-block
      }
    )
    (store-outcome market-id u0 outcome-a)
    (store-outcome market-id u1 outcome-b)
    (print { event: "market-created", market-id: market-id, creator: tx-sender, title: title, deadline: deadline })
    (ok market-id)
  )
)

(define-public (create-market-multi
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (outcome-a (string-utf8 64))
    (outcome-b (string-utf8 64))
    (outcome-c (string-utf8 64))
    (deadline uint))
  (let (
    (market-id (+ (var-get market-nonce) u1))
    (current-block block-height)
  )
    (try! (assert-not-paused))
    (asserts! (> (len title) u0) ERR-INVALID-TITLE)
    (asserts! (> deadline (+ current-block MIN-DEADLINE-BLOCKS)) ERR-INVALID-DEADLINE)
    (var-set market-nonce market-id)
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        outcome-count: u3,
        deadline: deadline,
        resolution-block: u0,
        resolved: false,
        winning-outcome: u0,
        total-pool: u0,
        disputed: false,
        oracle-resolved: false,
        created-at: current-block
      }
    )
    (store-outcome market-id u0 outcome-a)
    (store-outcome market-id u1 outcome-b)
    (store-outcome market-id u2 outcome-c)
    (print { event: "market-created-multi", market-id: market-id, creator: tx-sender, title: title })
    (ok market-id)
  )
)

;; ---- Core: Place Bet ----

(define-public (place-bet (market-id uint) (outcome-index uint) (amount uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    (outcome-data (unwrap! (map-get? market-outcomes { market-id: market-id, outcome-index: outcome-index }) ERR-INVALID-OUTCOME))
    (current-block block-height)
    (deadline (get deadline market))
    (total-pool (get total-pool market))
    (cutoff-block (- deadline BETTING-CUTOFF-BLOCKS))
    (existing-bet (default-to { amount: u0, claimed: false, withdrawn: false }
      (map-get? bets { market-id: market-id, user: tx-sender, outcome-index: outcome-index })))
    (new-pool (+ (get pool outcome-data) amount))
    (new-total-pool (+ total-pool amount))
  )
    (try! (assert-not-paused))
    (asserts! (not (get resolved market)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (not (get disputed market)) ERR-MARKET-DISPUTED)
    (asserts! (< current-block cutoff-block) ERR-BETTING-CUTOFF)
    (asserts! (< current-block deadline) ERR-DEADLINE-PASSED)
    (asserts! (< outcome-index (get outcome-count market)) ERR-INVALID-OUTCOME)
    (asserts! (> amount u0) ERR-ZERO-BET)
    (if (> total-pool u0)
      (asserts! (<= amount (/ (* new-total-pool MAX-BET-PERCENT) u100)) ERR-BET-TOO-LARGE)
      true
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set market-outcomes
      { market-id: market-id, outcome-index: outcome-index }
      { label: (get label outcome-data), pool: new-pool }
    )
    (map-set markets
      { market-id: market-id }
      (merge market { total-pool: new-total-pool })
    )
    (map-set bets
      { market-id: market-id, user: tx-sender, outcome-index: outcome-index }
      { amount: (+ (get amount existing-bet) amount), claimed: false, withdrawn: false }
    )
    (if (is-eq (get amount existing-bet) u0)
      (let ((bet-count (default-to { count: u0 } (map-get? user-market-bet-count { market-id: market-id, user: tx-sender }))))
        (map-set user-market-outcomes
          { market-id: market-id, user: tx-sender, slot: (get count bet-count) }
          { outcome-index: outcome-index }
        )
        (map-set user-market-bet-count
          { market-id: market-id, user: tx-sender }
          { count: (+ (get count bet-count) u1) }
        )
      )
      true
    )
    (print { event: "bet-placed", market-id: market-id, user: tx-sender, outcome-index: outcome-index, amount: amount })
    (ok true)
  )
)

;; ---- Core: Market Resolution ----

(define-public (resolve-market (market-id uint) (winning-outcome uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
  )
    (asserts! (or (is-contract-owner) (is-eq tx-sender (get creator market))) ERR-NOT-AUTHORIZED)
    (asserts! (not (get resolved market)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (not (get disputed market)) ERR-MARKET-DISPUTED)
    (asserts! (>= block-height (get deadline market)) ERR-MARKET-CLOSED)
    (asserts! (< winning-outcome (get outcome-count market)) ERR-INVALID-OUTCOME)
    (map-set markets
      { market-id: market-id }
      (merge market { resolved: true, winning-outcome: winning-outcome, resolution-block: block-height, oracle-resolved: false })
    )
    (print { event: "market-resolved", market-id: market-id, winning-outcome: winning-outcome, resolver: tx-sender })
    (ok true)
  )
)

(define-public (oracle-resolve-market (market-id uint) (winning-outcome uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
  )
    (asserts! (is-oracle) ERR-NOT-AUTHORIZED)
    (asserts! (not (get resolved market)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (< winning-outcome (get outcome-count market)) ERR-INVALID-OUTCOME)
    (map-set markets
      { market-id: market-id }
      (merge market { resolved: true, winning-outcome: winning-outcome, resolution-block: block-height, oracle-resolved: true })
    )
    (print { event: "oracle-resolved", market-id: market-id, winning-outcome: winning-outcome, oracle: tx-sender })
    (ok true)
  )
)

;; ---- Core: Claim Winnings ----

(define-public (claim-winnings (market-id uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    (winning-outcome (get winning-outcome market))
    (total-pool (get total-pool market))
    (existing-claim (map-get? claimed-winnings { market-id: market-id, user: tx-sender }))
    (winning-pool-data (unwrap! (map-get? market-outcomes { market-id: market-id, outcome-index: winning-outcome }) ERR-INVALID-OUTCOME))
    (winning-pool (get pool winning-pool-data))
    (user-bet (unwrap! (map-get? bets { market-id: market-id, user: tx-sender, outcome-index: winning-outcome }) ERR-NO-BET-FOUND))
    (user-amount (get amount user-bet))
    (platform-fee (/ (* total-pool PLATFORM-FEE-BPS) BPS-DENOMINATOR))
    (distributable-pool (- total-pool platform-fee))
    (payout (if (is-eq winning-pool u0) u0 (/ (* user-amount distributable-pool) winning-pool)))
  )
    (asserts! (get resolved market) ERR-MARKET-NOT-RESOLVED)
    (asserts! (not (get disputed market)) ERR-MARKET-DISPUTED)
    (asserts! (is-none existing-claim) ERR-ALREADY-CLAIMED)
    (asserts! (not (get claimed user-bet)) ERR-ALREADY-CLAIMED)
    (asserts! (> user-amount u0) ERR-NO-BET-FOUND)
    (asserts! (> payout u0) ERR-NO-WINNINGS)
    (map-set claimed-winnings { market-id: market-id, user: tx-sender } { claimed: true, amount: payout })
    (map-set bets
      { market-id: market-id, user: tx-sender, outcome-index: winning-outcome }
      (merge user-bet { claimed: true })
    )
    (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
    (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
    (print { event: "winnings-claimed", market-id: market-id, user: tx-sender, payout: payout })
    (ok payout)
  )
)

;; ---- Advanced: Early Withdrawal ----

(define-public (early-withdraw (market-id uint) (outcome-index uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    (outcome-data (unwrap! (map-get? market-outcomes { market-id: market-id, outcome-index: outcome-index }) ERR-INVALID-OUTCOME))
    (user-bet (unwrap! (map-get? bets { market-id: market-id, user: tx-sender, outcome-index: outcome-index }) ERR-NO-BET-FOUND))
    (bet-amount (get amount user-bet))
    (fee (/ (* bet-amount EARLY-WITHDRAWAL-FEE-BPS) BPS-DENOMINATOR))
    (refund (- bet-amount fee))
  )
    (try! (assert-not-paused))
    (asserts! (not (get resolved market)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (not (get withdrawn user-bet)) ERR-ALREADY-CLAIMED)
    (asserts! (not (get claimed user-bet)) ERR-ALREADY-CLAIMED)
    (asserts! (< block-height (get deadline market)) ERR-DEADLINE-PASSED)
    (asserts! (> bet-amount u0) ERR-NO-BET-FOUND)
    (map-set market-outcomes
      { market-id: market-id, outcome-index: outcome-index }
      (merge outcome-data { pool: (- (get pool outcome-data) bet-amount) })
    )
    (map-set markets
      { market-id: market-id }
      (merge market { total-pool: (- (get total-pool market) bet-amount) })
    )
    (map-set bets
      { market-id: market-id, user: tx-sender, outcome-index: outcome-index }
      (merge user-bet { withdrawn: true, amount: u0 })
    )
    (var-set total-platform-fees (+ (var-get total-platform-fees) fee))
    (try! (as-contract (stx-transfer? refund tx-sender tx-sender)))
    (print { event: "early-withdrawal", market-id: market-id, user: tx-sender, outcome-index: outcome-index, refund: refund, fee: fee })
    (ok refund)
  )
)

;; ---- Advanced: Dispute Resolution ----

(define-public (dispute-market (market-id uint) (reason (string-utf8 256)))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    (resolution-block (get resolution-block market))
  )
    (asserts! (get resolved market) ERR-MARKET-NOT-RESOLVED)
    (asserts! (not (get disputed market)) ERR-MARKET-DISPUTED)
    (asserts! (<= block-height (+ resolution-block DISPUTE-WINDOW-BLOCKS)) ERR-DEADLINE-PASSED)
    (map-set markets { market-id: market-id } (merge market { disputed: true }))
    (map-set disputes { market-id: market-id } { disputer: tx-sender, reason: reason, block-height: block-height })
    (print { event: "market-disputed", market-id: market-id, disputer: tx-sender, reason: reason })
    (ok true)
  )
)

(define-public (resolve-dispute (market-id uint) (new-winning-outcome uint) (uphold-dispute bool))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (get disputed market) ERR-MARKET-NOT-RESOLVED)
    (asserts! (< new-winning-outcome (get outcome-count market)) ERR-INVALID-OUTCOME)
    (map-set markets { market-id: market-id } (merge market { disputed: false, winning-outcome: new-winning-outcome }))
    (print { event: "dispute-resolved", market-id: market-id, new-winning-outcome: new-winning-outcome, upheld: uphold-dispute })
    (ok true)
  )
)
