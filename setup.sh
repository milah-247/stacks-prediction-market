#!/usr/bin/env bash
# =============================================================================
# STACKS PREDICTION MARKET — FULL PROJECT SETUP SCRIPT
# Run this script once to create every file in the project.
# Usage: bash setup.sh
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[create]${NC} $1"; }
ok()  { echo -e "${GREEN}[done]${NC}   $1"; }

ROOT="stacks-prediction-market"

echo ""
echo "================================================="
echo "  Stacks Prediction Market — Project Generator"
echo "================================================="
echo ""

# ===========================================================================
# CREATE DIRECTORY STRUCTURE
# ===========================================================================

log "Creating directory structure..."
mkdir -p $ROOT/{contracts,tests,scripts}
mkdir -p $ROOT/.github/workflows
mkdir -p $ROOT/frontend/src/{components/{ui,market,wallet},pages/market,hooks,utils,styles}
mkdir -p $ROOT/frontend/public
ok "Directories created"

# ===========================================================================
# ROOT FILES
# ===========================================================================

log "Writing Clarinet.toml..."
cat > $ROOT/Clarinet.toml << 'EOF'
[project]
name = "stacks-prediction-market"
description = "Decentralized prediction market on Stacks blockchain"
authors = ["Solo Developer"]
telemetry = false
cache_dir = "./.cache"

[contracts.prediction-market]
path = "contracts/prediction-market.clar"
clarity_version = 2
epoch = "2.5"

[contracts.oracle]
path = "contracts/oracle.clar"
clarity_version = 2
epoch = "2.5"

[contracts.market-token]
path = "contracts/market-token.clar"
clarity_version = 2
epoch = "2.5"

[repl]
costs_version = 2
parser_version = 2
EOF
ok "Clarinet.toml"

log "Writing package.json (root)..."
cat > $ROOT/package.json << 'EOF'
{
  "name": "stacks-prediction-market",
  "version": "0.1.0",
  "description": "Decentralized prediction market on the Stacks blockchain",
  "private": true,
  "scripts": {
    "check": "clarinet check",
    "test": "clarinet test",
    "test:coverage": "clarinet test --coverage",
    "dev": "cd frontend && npm run dev",
    "build": "cd frontend && npm run build",
    "install:frontend": "cd frontend && npm install",
    "deploy:testnet": "bash scripts/deploy.sh testnet",
    "deploy:mainnet": "bash scripts/deploy.sh mainnet",
    "devnet:start": "clarinet devnet start",
    "devnet:stop": "clarinet devnet stop"
  },
  "keywords": ["stacks", "blockchain", "prediction-market", "defi", "clarity"],
  "license": "MIT"
}
EOF
ok "package.json (root)"

log "Writing .gitignore..."
cat > $ROOT/.gitignore << 'EOF'
node_modules/
frontend/node_modules/
.npm
frontend/.next/
frontend/out/
frontend/.vercel/
.env
.env.local
.env.*.local
frontend/.env
frontend/.env.local
frontend/.env.*.local
.cache/
coverage/
*.lcov
*.key
*.pem
mnemonic.txt
deployer.key
dist/
build/
*.tgz
.vscode/
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db
*.log
npm-debug.log*
*.tsbuildinfo
EOF
ok ".gitignore"

# ===========================================================================
# SMART CONTRACTS
# ===========================================================================

log "Writing contracts/prediction-market.clar..."
cat > $ROOT/contracts/prediction-market.clar << 'EOF'
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
EOF
ok "contracts/prediction-market.clar"

log "Writing contracts/oracle.clar..."
cat > $ROOT/contracts/oracle.clar << 'EOF'
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
EOF
ok "contracts/oracle.clar"

log "Writing contracts/market-token.clar..."
cat > $ROOT/contracts/market-token.clar << 'EOF'
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
    (match memo m (print m) true)
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
EOF
ok "contracts/market-token.clar"

# ===========================================================================
# TESTS
# ===========================================================================

log "Writing tests/prediction-market_test.ts..."
cat > $ROOT/tests/prediction-market_test.ts << 'EOF'
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT = 'prediction-market';
const MARKET_TITLE = types.utf8("Will BTC reach $100k by EOY?");
const MARKET_DESC = types.utf8("Bitcoin price prediction market");
const OUTCOME_A = types.utf8("YES");
const OUTCOME_B = types.utf8("NO");

function createMarket(chain: Chain, deployer: Account, deadline?: number) {
  const dl = deadline ?? chain.blockHeight + 300;
  return chain.mineBlock([
    Tx.contractCall(CONTRACT, 'create-market', [
      MARKET_TITLE, MARKET_DESC, OUTCOME_A, OUTCOME_B, types.uint(dl)
    ], deployer.address)
  ]);
}

Clarinet.test({
  name: "CREATION: Should create a YES/NO market successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = createMarket(chain, deployer);
    assertEquals(block.receipts[0].result, '(ok u1)');
    const market = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address);
    const data = market.result.expectSome().expectTuple();
    assertEquals(data['resolved'], 'false');
    assertEquals(data['outcome-count'], 'u2');
    assertEquals(data['total-pool'], 'u0');
  }
});

Clarinet.test({
  name: "CREATION: Should create a multi-outcome (3-way) market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'create-market-multi', [
        types.utf8("Who will win?"), types.utf8("Election market"),
        types.utf8("Candidate A"), types.utf8("Candidate B"), types.utf8("Other"),
        types.uint(chain.blockHeight + 300)
      ], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok u1)');
    const market = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address);
    assertEquals(market.result.expectSome().expectTuple()['outcome-count'], 'u3');
  }
});

Clarinet.test({
  name: "CREATION: Should increment market IDs sequentially",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u1)');
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u2)');
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u3)');
    chain.callReadOnlyFn(CONTRACT, 'get-market-count', [], deployer.address).result.expectUint(3);
  }
});

Clarinet.test({
  name: "CREATION: Should fail with empty title",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'create-market', [
        types.utf8(""), MARKET_DESC, OUTCOME_A, OUTCOME_B, types.uint(chain.blockHeight + 300)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(117);
  }
});

Clarinet.test({
  name: "CREATION: Should fail if deadline is too soon",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    createMarket(chain, deployer, chain.blockHeight + 50).receipts[0].result.expectErr().expectUint(112);
  }
});

Clarinet.test({
  name: "BETTING: Should place a bet on YES outcome",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(1_000_000)], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    assertEquals(block.receipts[0].events[0].type, 'stx_transfer_event');
  }
});

Clarinet.test({
  name: "BETTING: Should update outcome pool after bet",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(2_000_000)], wallet1.address)
    ]);
    const market = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address);
    market.result.expectSome().expectTuple()['total-pool'].expectUint(2_000_000);
  }
});

Clarinet.test({
  name: "BETTING: Should reject zero-value bets",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(0)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(106);
  }
});

Clarinet.test({
  name: "BETTING: Should reject invalid market ID",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(999), types.uint(0), types.uint(1_000_000)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(101);
  }
});

Clarinet.test({
  name: "BETTING: Should reject invalid outcome index",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(5), types.uint(1_000_000)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(105);
  }
});

Clarinet.test({
  name: "RESOLUTION: Admin can resolve market after deadline",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineEmptyBlockUntil(deadline + 1);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const data = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address).result.expectSome().expectTuple();
    assertEquals(data['resolved'], 'true');
    data['winning-outcome'].expectUint(0);
  }
});

Clarinet.test({
  name: "RESOLUTION: Cannot resolve before deadline",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(102);
  }
});

Clarinet.test({
  name: "RESOLUTION: Cannot resolve already resolved market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(1)], deployer.address)]);
    block.receipts[0].result.expectErr().expectUint(104);
  }
});

Clarinet.test({
  name: "RESOLUTION: Non-authorized user cannot resolve",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet2 = accounts.get('wallet_2')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineEmptyBlockUntil(deadline + 1);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], wallet2.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(100);
  }
});

Clarinet.test({
  name: "PAYOUT: Winner can claim proportional winnings",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(10_000_000)], wallet1.address),
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(1), types.uint(5_000_000)], wallet2.address)
    ]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    assertEquals(block.receipts[0].result.indexOf('ok'), 0);
    assertEquals(block.receipts[0].events[0].type, 'stx_transfer_event');
  }
});

Clarinet.test({
  name: "PAYOUT: Prevents double claiming",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(108);
  }
});

Clarinet.test({
  name: "PAYOUT: Cannot claim before market resolved",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(103);
  }
});

Clarinet.test({
  name: "WITHDRAWAL: User can withdraw early with fee",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 300;
    createMarket(chain, deployer, deadline);
    const betAmount = 10_000_000;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(betAmount)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    const expected = betAmount - Math.floor(betAmount * 500 / 10000);
    assertEquals(block.receipts[0].result, `(ok u${expected})`);
  }
});

Clarinet.test({
  name: "WITHDRAWAL: Cannot withdraw after market resolved",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(104);
  }
});

Clarinet.test({
  name: "WITHDRAWAL: Cannot double-withdraw",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(108);
  }
});

Clarinet.test({
  name: "ADMIN: Can set oracle principal",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'set-oracle', [types.principal(wallet1.address)], deployer.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "ORACLE: Oracle can resolve market at any time",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'set-oracle', [types.principal(wallet1.address)], deployer.address)]);
    createMarket(chain, deployer);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'oracle-resolve-market', [types.uint(1), types.uint(1)], wallet1.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const data = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address).result.expectSome().expectTuple();
    assertEquals(data['resolved'], 'true');
    assertEquals(data['oracle-resolved'], 'true');
  }
});

Clarinet.test({
  name: "ADMIN: Can pause and unpause contract",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'toggle-pause', [], deployer.address)]);
    createMarket(chain, deployer).receipts[0].result.expectErr().expectUint(100);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'toggle-pause', [], deployer.address)]);
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u1)');
  }
});

Clarinet.test({
  name: "CALC: Calculate winnings returns correct amount",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(10_000_000)], wallet1.address),
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(1), types.uint(10_000_000)], wallet2.address)
    ]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const calc = chain.callReadOnlyFn(CONTRACT, 'calculate-winnings', [types.uint(1), types.principal(wallet1.address)], deployer.address);
    calc.result.expectOk().expectUint(19_600_000);
  }
});
EOF
ok "tests/prediction-market_test.ts"

log "Writing tests/oracle_test.ts..."
cat > $ROOT/tests/oracle_test.ts << 'EOF'
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const ORACLE = 'oracle';
const FEED_ID = "btc-usd-price";

Clarinet.test({
  name: "ORACLE: Owner can create data feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC/USD price feed")], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "ORACLE: Cannot create duplicate feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC price")], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("Duplicate")], deployer.address)]);
    block.receipts[0].result.expectErr().expectUint(202);
  }
});

Clarinet.test({
  name: "ORACLE: Owner can update feed value",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC price")], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(ORACLE, 'update-feed', [types.ascii(FEED_ID), types.utf8("100000")], deployer.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(ORACLE, 'get-feed-value', [types.ascii(FEED_ID)], deployer.address).result.expectOk().expectUtf8("100000");
  }
});

Clarinet.test({
  name: "ORACLE: Authorized operator can update feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([
      Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC price")], deployer.address),
      Tx.contractCall(ORACLE, 'add-operator', [types.principal(wallet1.address)], deployer.address)
    ]);
    const block = chain.mineBlock([Tx.contractCall(ORACLE, 'update-feed', [types.ascii(FEED_ID), types.utf8("95000")], wallet1.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "ORACLE: Non-operator cannot update feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC price")], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(ORACLE, 'update-feed', [types.ascii(FEED_ID), types.utf8("hack")], wallet2.address)]);
    block.receipts[0].result.expectErr().expectUint(200);
  }
});

Clarinet.test({
  name: "ORACLE: Can link market to feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC price")], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(ORACLE, 'link-market-to-feed', [
        types.uint(1), types.ascii(FEED_ID), types.utf8('{"YES": ">100000", "NO": "<=100000"}')
      ], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "ORACLE: Freshness check works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([
      Tx.contractCall(ORACLE, 'create-feed', [types.ascii(FEED_ID), types.utf8("BTC price")], deployer.address),
      Tx.contractCall(ORACLE, 'update-feed', [types.ascii(FEED_ID), types.utf8("100000")], deployer.address)
    ]);
    chain.callReadOnlyFn(ORACLE, 'is-feed-fresh', [types.ascii(FEED_ID)], deployer.address).result.expectOk().expectBool(true);
  }
});
EOF
ok "tests/oracle_test.ts"

log "Writing tests/market-token_test.ts..."
cat > $ROOT/tests/market-token_test.ts << 'EOF'
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const TOKEN = 'market-token';

Clarinet.test({
  name: "TOKEN: Owner can mint SPM tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(TOKEN, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(TOKEN, 'get-balance', [types.principal(wallet1.address)], deployer.address).result.expectOk().expectUint(1_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: Non-owner cannot mint",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(TOKEN, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(300);
  }
});

Clarinet.test({
  name: "TOKEN: Transfer works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(TOKEN, 'mint', [types.uint(5_000_000), types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(TOKEN, 'transfer', [types.uint(2_000_000), types.principal(wallet1.address), types.principal(wallet2.address), types.none()], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(TOKEN, 'get-balance', [types.principal(wallet2.address)], deployer.address).result.expectOk().expectUint(2_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: SIP-010 metadata is correct",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.callReadOnlyFn(TOKEN, 'get-name', [], deployer.address).result.expectOk().expectAscii("Stacks Prediction Market");
    chain.callReadOnlyFn(TOKEN, 'get-symbol', [], deployer.address).result.expectOk().expectAscii("SPM");
    chain.callReadOnlyFn(TOKEN, 'get-decimals', [], deployer.address).result.expectOk().expectUint(6);
  }
});

Clarinet.test({
  name: "TOKEN: Owner can burn tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(TOKEN, 'mint', [types.uint(5_000_000), types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(TOKEN, 'burn', [types.uint(2_000_000), types.principal(wallet1.address)], wallet1.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(TOKEN, 'get-balance', [types.principal(wallet1.address)], deployer.address).result.expectOk().expectUint(3_000_000);
  }
});
EOF
ok "tests/market-token_test.ts"

# ===========================================================================
# SCRIPTS
# ===========================================================================

log "Writing scripts/deploy.sh..."
cat > $ROOT/scripts/deploy.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

NETWORK=${1:-testnet}
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
err()  { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

echo ""; echo "=== Stacks PM Deploy: $NETWORK ==="; echo ""

command -v clarinet >/dev/null 2>&1 || err "Clarinet not found"
info "Running clarinet check..."
clarinet check && ok "Check passed"
info "Running tests..."
clarinet test && ok "Tests passed"

case $NETWORK in
  mainnet)  NETWORK_FLAG="--mainnet" ;;
  testnet)  NETWORK_FLAG="--testnet" ;;
  devnet)   NETWORK_FLAG="--devnet"  ;;
  *) err "Unknown network: $NETWORK" ;;
esac

for CONTRACT in market-token oracle prediction-market; do
  info "Deploying $CONTRACT..."
  clarinet deploy --manifest Clarinet.toml $NETWORK_FLAG --contract "$CONTRACT" \
    && ok "Deployed: $CONTRACT" \
    || err "Failed: $CONTRACT"
done

echo ""; echo "=== Deployment complete ==="; echo ""
echo "Next: update NEXT_PUBLIC_CONTRACT_ADDRESS in frontend/.env.local"
EOF
chmod +x $ROOT/scripts/deploy.sh
ok "scripts/deploy.sh"

# ===========================================================================
# CI/CD
# ===========================================================================

log "Writing .github/workflows/ci.yml..."
cat > $ROOT/.github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  contracts:
    name: Clarity Contracts
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Clarinet
        run: |
          curl -fsSL https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz \
            | tar -xz -C /usr/local/bin
      - run: clarinet check
      - run: clarinet test --coverage
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/

  frontend:
    name: Frontend Build
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
      - run: npm ci
      - run: npm run type-check
      - run: npm run lint
      - run: npm run build
        env:
          NEXT_PUBLIC_NETWORK: testnet
          NEXT_PUBLIC_CONTRACT_ADDRESS: ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
          NEXT_PUBLIC_STACKS_API_URL: https://api.testnet.hiro.so
EOF
ok ".github/workflows/ci.yml"

# ===========================================================================
# FRONTEND — CONFIG FILES
# ===========================================================================

log "Writing frontend/package.json..."
cat > $ROOT/frontend/package.json << 'EOF'
{
  "name": "stacks-prediction-market-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "@stacks/connect": "^7.10.1",
    "@stacks/network": "^6.8.1",
    "@stacks/transactions": "^6.11.2",
    "next": "14.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "zustand": "^4.5.0",
    "date-fns": "^3.3.1",
    "clsx": "^2.1.0"
  },
  "devDependencies": {
    "@types/node": "^20.11.5",
    "@types/react": "^18.2.48",
    "@types/react-dom": "^18.2.18",
    "typescript": "^5.3.3",
    "eslint": "^8.56.0",
    "eslint-config-next": "14.1.0"
  }
}
EOF
ok "frontend/package.json"

log "Writing frontend/next.config.js..."
cat > $ROOT/frontend/next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    NEXT_PUBLIC_NETWORK: process.env.NEXT_PUBLIC_NETWORK || 'testnet',
    NEXT_PUBLIC_CONTRACT_ADDRESS: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    NEXT_PUBLIC_STACKS_API_URL: process.env.NEXT_PUBLIC_STACKS_API_URL || 'https://api.testnet.hiro.so',
  },
};
module.exports = nextConfig;
EOF
ok "frontend/next.config.js"

log "Writing frontend/tsconfig.json..."
cat > $ROOT/frontend/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOF
ok "frontend/tsconfig.json"

log "Writing frontend/.env.local.example..."
cat > $ROOT/frontend/.env.local.example << 'EOF'
# Network: mainnet | testnet | devnet
NEXT_PUBLIC_NETWORK=testnet

# Your deployed contract address
NEXT_PUBLIC_CONTRACT_ADDRESS=ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM

# Stacks API base URL
NEXT_PUBLIC_STACKS_API_URL=https://api.testnet.hiro.so
EOF
ok "frontend/.env.local.example"

# ===========================================================================
# FRONTEND — SOURCE FILES
# ===========================================================================

log "Writing frontend/src/utils/constants.ts..."
cat > $ROOT/frontend/src/utils/constants.ts << 'EOF'
export const CONTRACTS = {
  predictionMarket: {
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    name: 'prediction-market',
  },
  oracle: {
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    name: 'oracle',
  },
  marketToken: {
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    name: 'market-token',
  },
} as const;

export const CURRENT_NETWORK = (process.env.NEXT_PUBLIC_NETWORK || 'testnet') as 'mainnet' | 'testnet' | 'devnet';

export const STACKS_API_URL = {
  mainnet: 'https://api.mainnet.hiro.so',
  testnet: 'https://api.testnet.hiro.so',
  devnet: 'http://localhost:3999',
}[CURRENT_NETWORK];

export const CONTRACT_CONSTANTS = {
  MAX_BET_PERCENT: 20,
  EARLY_WITHDRAWAL_FEE_BPS: 500,
  PLATFORM_FEE_BPS: 200,
  BETTING_CUTOFF_BLOCKS: 144,
  MIN_DEADLINE_BLOCKS: 144,
  DISPUTE_WINDOW_BLOCKS: 144,
  BLOCKS_PER_DAY: 144,
  MICRO_STX_PER_STX: 1_000_000,
} as const;

export const APP_CONFIG = {
  name: 'Stacks Prediction Market',
  description: 'Decentralized prediction markets on the Stacks blockchain',
  appIconUrl: '/icon-512.png',
} as const;
EOF
ok "frontend/src/utils/constants.ts"

log "Writing frontend/src/utils/contracts.ts..."
cat > $ROOT/frontend/src/utils/contracts.ts << 'EOF'
import {
  callReadOnlyFunction,
  cvToValue,
  uintCV,
  stringUtf8CV,
  principalCV,
  AnchorMode,
  PostConditionMode,
  makeStandardSTXPostCondition,
  FungibleConditionCode,
} from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';
import { CONTRACTS, CURRENT_NETWORK, STACKS_API_URL, CONTRACT_CONSTANTS } from './constants';

export function getNetwork() {
  if (CURRENT_NETWORK === 'mainnet') return new StacksMainnet();
  return new StacksTestnet({ url: STACKS_API_URL });
}

export interface Market {
  id: number;
  creator: string;
  title: string;
  description: string;
  outcomeCount: number;
  deadline: number;
  resolutionBlock: number;
  resolved: boolean;
  winningOutcome: number;
  totalPool: number;
  disputed: boolean;
  oracleResolved: boolean;
  createdAt: number;
}

export interface MarketOutcome { label: string; pool: number; }
export interface Bet { amount: number; claimed: boolean; withdrawn: boolean; }
export interface ClaimStatus { claimed: boolean; amount: number; }

async function readContract(functionName: string, args: any[]): Promise<any> {
  const result = await callReadOnlyFunction({
    contractAddress: CONTRACTS.predictionMarket.address,
    contractName: CONTRACTS.predictionMarket.name,
    functionName,
    functionArgs: args,
    network: getNetwork(),
    senderAddress: CONTRACTS.predictionMarket.address,
  });
  return cvToValue(result);
}

export async function fetchMarket(marketId: number): Promise<Market | null> {
  try {
    const result = await readContract('get-market', [uintCV(marketId)]);
    if (!result) return null;
    return {
      id: marketId,
      creator: result.creator.value,
      title: result.title,
      description: result.description,
      outcomeCount: Number(result['outcome-count']),
      deadline: Number(result.deadline),
      resolutionBlock: Number(result['resolution-block']),
      resolved: result.resolved,
      winningOutcome: Number(result['winning-outcome']),
      totalPool: Number(result['total-pool']),
      disputed: result.disputed,
      oracleResolved: result['oracle-resolved'],
      createdAt: Number(result['created-at']),
    };
  } catch { return null; }
}

export async function fetchMarketCount(): Promise<number> {
  try { return Number(await readContract('get-market-count', [])); } catch { return 0; }
}

export async function fetchMarketOutcome(marketId: number, outcomeIndex: number): Promise<MarketOutcome | null> {
  try {
    const result = await readContract('get-market-outcome', [uintCV(marketId), uintCV(outcomeIndex)]);
    if (!result) return null;
    return { label: result.label, pool: Number(result.pool) };
  } catch { return null; }
}

export async function fetchAllMarkets(): Promise<Market[]> {
  const count = await fetchMarketCount();
  const results = await Promise.all(Array.from({ length: count }, (_, i) => fetchMarket(i + 1)));
  return (results.filter(Boolean) as Market[]).reverse();
}

export async function fetchUserBet(marketId: number, userAddress: string, outcomeIndex: number): Promise<Bet | null> {
  try {
    const result = await readContract('get-bet', [uintCV(marketId), principalCV(userAddress), uintCV(outcomeIndex)]);
    if (!result) return null;
    return { amount: Number(result.amount), claimed: result.claimed, withdrawn: result.withdrawn };
  } catch { return null; }
}

export async function fetchClaimStatus(marketId: number, userAddress: string): Promise<ClaimStatus | null> {
  try {
    const result = await readContract('get-claim-status', [uintCV(marketId), principalCV(userAddress)]);
    if (!result) return null;
    return { claimed: result.claimed, amount: Number(result.amount) };
  } catch { return null; }
}

export async function calculateWinnings(marketId: number, userAddress: string): Promise<number> {
  try { return Number((await readContract('calculate-winnings', [uintCV(marketId), principalCV(userAddress)]))?.value || 0); }
  catch { return 0; }
}

export function buildCreateMarketTx(params: { title: string; description: string; outcomeA: string; outcomeB: string; deadline: number; }) {
  return {
    contractAddress: CONTRACTS.predictionMarket.address,
    contractName: CONTRACTS.predictionMarket.name,
    functionName: 'create-market',
    functionArgs: [stringUtf8CV(params.title), stringUtf8CV(params.description), stringUtf8CV(params.outcomeA), stringUtf8CV(params.outcomeB), uintCV(params.deadline)],
    network: getNetwork(),
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };
}

export function buildPlaceBetTx(params: { marketId: number; outcomeIndex: number; amount: number; senderAddress: string; }) {
  return {
    contractAddress: CONTRACTS.predictionMarket.address,
    contractName: CONTRACTS.predictionMarket.name,
    functionName: 'place-bet',
    functionArgs: [uintCV(params.marketId), uintCV(params.outcomeIndex), uintCV(params.amount)],
    network: getNetwork(),
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Deny,
    postConditions: [makeStandardSTXPostCondition(params.senderAddress, FungibleConditionCode.Equal, params.amount)],
  };
}

export function buildClaimWinningsTx(marketId: number) {
  return { contractAddress: CONTRACTS.predictionMarket.address, contractName: CONTRACTS.predictionMarket.name, functionName: 'claim-winnings', functionArgs: [uintCV(marketId)], network: getNetwork(), anchorMode: AnchorMode.Any, postConditionMode: PostConditionMode.Allow };
}

export function buildEarlyWithdrawTx(marketId: number, outcomeIndex: number) {
  return { contractAddress: CONTRACTS.predictionMarket.address, contractName: CONTRACTS.predictionMarket.name, functionName: 'early-withdraw', functionArgs: [uintCV(marketId), uintCV(outcomeIndex)], network: getNetwork(), anchorMode: AnchorMode.Any, postConditionMode: PostConditionMode.Allow };
}

export function buildResolveMarketTx(marketId: number, winningOutcome: number) {
  return { contractAddress: CONTRACTS.predictionMarket.address, contractName: CONTRACTS.predictionMarket.name, functionName: 'resolve-market', functionArgs: [uintCV(marketId), uintCV(winningOutcome)], network: getNetwork(), anchorMode: AnchorMode.Any, postConditionMode: PostConditionMode.Allow };
}

export const microSTXtoSTX = (micro: number) => micro / CONTRACT_CONSTANTS.MICRO_STX_PER_STX;
export const stxToMicroSTX = (stx: number) => Math.floor(stx * CONTRACT_CONSTANTS.MICRO_STX_PER_STX);
export const formatSTX = (micro: number, decimals = 2) => `${microSTXtoSTX(micro).toFixed(decimals)} STX`;
export const estimateDeadlineBlock = (current: number, days: number) => current + days * CONTRACT_CONSTANTS.BLOCKS_PER_DAY;
export const isMarketBettingOpen = (market: Market, current: number) => !market.resolved && current < market.deadline - CONTRACT_CONSTANTS.BETTING_CUTOFF_BLOCKS;
export const getOutcomePercentage = (pool: number, total: number) => total === 0 ? 50 : Math.round((pool / total) * 100);

export function getMarketStatus(market: Market, currentBlock: number): string {
  if (market.disputed) return 'Disputed';
  if (market.resolved) return 'Resolved';
  if (currentBlock >= market.deadline) return 'Awaiting Resolution';
  if (!isMarketBettingOpen(market, currentBlock)) return 'Betting Closed';
  return 'Active';
}
EOF
ok "frontend/src/utils/contracts.ts"

log "Writing frontend/src/hooks/useWallet.ts..."
cat > $ROOT/frontend/src/hooks/useWallet.ts << 'EOF'
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface WalletState {
  address: string | null;
  mainnetAddress: string | null;
  testnetAddress: string | null;
  connected: boolean;
  stxBalance: number;
  connect: (address: string, mainnetAddress: string, testnetAddress: string) => void;
  disconnect: () => void;
  setBalance: (stx: number) => void;
}

export const useWalletStore = create<WalletState>()(
  persist(
    (set) => ({
      address: null,
      mainnetAddress: null,
      testnetAddress: null,
      connected: false,
      stxBalance: 0,
      connect: (address, mainnetAddress, testnetAddress) =>
        set({ address, mainnetAddress, testnetAddress, connected: true }),
      disconnect: () =>
        set({ address: null, mainnetAddress: null, testnetAddress: null, connected: false, stxBalance: 0 }),
      setBalance: (stx) => set({ stxBalance: stx }),
    }),
    {
      name: 'spm-wallet',
      partialize: (state) => ({ address: state.address, mainnetAddress: state.mainnetAddress, testnetAddress: state.testnetAddress, connected: state.connected }),
    }
  )
);
EOF
ok "frontend/src/hooks/useWallet.ts"

log "Writing frontend/src/hooks/useMarkets.ts..."
cat > $ROOT/frontend/src/hooks/useMarkets.ts << 'EOF'
import { useState, useEffect, useCallback } from 'react';
import { fetchAllMarkets, fetchMarket, fetchMarketOutcome, fetchUserBet, fetchClaimStatus, calculateWinnings, type Market, type MarketOutcome, type Bet } from '../utils/contracts';
import { STACKS_API_URL } from '../utils/constants';

export function useMarkets() {
  const [markets, setMarkets] = useState<Market[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    try { setLoading(true); setError(null); setMarkets(await fetchAllMarkets()); }
    catch { setError('Failed to load markets'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); const i = setInterval(load, 30_000); return () => clearInterval(i); }, [load]);
  return { markets, loading, error, refetch: load };
}

export function useMarket(marketId: number) {
  const [market, setMarket] = useState<Market | null>(null);
  const [outcomes, setOutcomes] = useState<MarketOutcome[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    try {
      setLoading(true); setError(null);
      const m = await fetchMarket(marketId);
      if (!m) { setError('Market not found'); return; }
      setMarket(m);
      const outs = await Promise.all(Array.from({ length: m.outcomeCount }, (_, i) => fetchMarketOutcome(marketId, i)));
      setOutcomes(outs.filter(Boolean) as MarketOutcome[]);
    } catch { setError('Failed to load market'); }
    finally { setLoading(false); }
  }, [marketId]);
  useEffect(() => { load(); const i = setInterval(load, 15_000); return () => clearInterval(i); }, [load]);
  return { market, outcomes, loading, error, refetch: load };
}

export function useUserBets(marketId: number, userAddress: string | null, outcomeCount: number) {
  const [bets, setBets] = useState<(Bet | null)[]>([]);
  const [loading, setLoading] = useState(false);
  const load = useCallback(async () => {
    if (!userAddress) { setBets([]); return; }
    setLoading(true);
    try {
      const results = await Promise.all(Array.from({ length: outcomeCount }, (_, i) => fetchUserBet(marketId, userAddress, i)));
      setBets(results);
    } finally { setLoading(false); }
  }, [marketId, userAddress, outcomeCount]);
  useEffect(() => { load(); }, [load]);
  return { bets, loading, refetch: load };
}

export function useClaimInfo(marketId: number, userAddress: string | null, resolved: boolean) {
  const [claimStatus, setClaimStatus] = useState<{ claimed: boolean; amount: number } | null>(null);
  const [potentialWinnings, setPotentialWinnings] = useState(0);
  const [loading, setLoading] = useState(false);
  useEffect(() => {
    if (!userAddress || !resolved) return;
    setLoading(true);
    Promise.all([fetchClaimStatus(marketId, userAddress), calculateWinnings(marketId, userAddress)])
      .then(([status, winnings]) => { setClaimStatus(status); setPotentialWinnings(winnings); })
      .finally(() => setLoading(false));
  }, [marketId, userAddress, resolved]);
  return { claimStatus, potentialWinnings, loading };
}

export function useCurrentBlock() {
  const [currentBlock, setCurrentBlock] = useState(0);
  useEffect(() => {
    async function fetch() {
      try {
        const res = await window.fetch(`${STACKS_API_URL}/v2/info`);
        const data = await res.json();
        setCurrentBlock(data.stacks_tip_height || 0);
      } catch {}
    }
    fetch();
    const i = setInterval(fetch, 30_000);
    return () => clearInterval(i);
  }, []);
  return currentBlock;
}
EOF
ok "frontend/src/hooks/useMarkets.ts"

log "Writing frontend/src/styles/globals.css..."
cat > $ROOT/frontend/src/styles/globals.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Space+Mono:ital,wght@0,400;0,700;1,400&family=Syne:wght@400;600;700;800&display=swap');

:root {
  --bg-primary: #06070f;
  --bg-secondary: #0d0f1e;
  --bg-card: #111428;
  --bg-card-hover: #161b33;
  --text-primary: #e8eaf8;
  --text-secondary: #8b90b8;
  --text-muted: #4a5080;
  --accent-electric: #5b8cf7;
  --accent-gold: #f0c040;
  --accent-green: #3dd68c;
  --accent-red: #f05572;
  --accent-purple: #a855f7;
  --border-subtle: rgba(91, 140, 247, 0.15);
  --border-active: rgba(91, 140, 247, 0.5);
  --glow-blue: 0 0 20px rgba(91, 140, 247, 0.3);
  --glow-gold: 0 0 20px rgba(240, 192, 64, 0.3);
  --glow-green: 0 0 20px rgba(61, 214, 140, 0.3);
  --radius-sm: 6px; --radius-md: 12px; --radius-lg: 20px;
  --font-display: 'Syne', sans-serif;
  --font-mono: 'Space Mono', monospace;
}
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  font-family: var(--font-mono);
  background-color: var(--bg-primary);
  color: var(--text-primary);
  line-height: 1.6;
  min-height: 100vh;
  overflow-x: hidden;
}
body::before {
  content: '';
  position: fixed; inset: 0;
  background-image: linear-gradient(rgba(91, 140, 247, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(91, 140, 247, 0.03) 1px, transparent 1px);
  background-size: 40px 40px;
  pointer-events: none; z-index: 0;
}
h1,h2,h3,h4,h5,h6 { font-family: var(--font-display); font-weight: 700; line-height: 1.2; }
.container { max-width: 1200px; margin: 0 auto; padding: 0 24px; }
.card {
  background: var(--bg-card); border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg); padding: 24px; transition: all 0.2s ease;
  position: relative; overflow: hidden;
}
.card::before {
  content: ''; position: absolute; top: 0; left: 0; right: 0; height: 1px;
  background: linear-gradient(90deg, transparent, var(--accent-electric), transparent);
  opacity: 0; transition: opacity 0.3s ease;
}
.card:hover { border-color: var(--border-active); background: var(--bg-card-hover); transform: translateY(-2px); box-shadow: var(--glow-blue); }
.card:hover::before { opacity: 1; }
.btn {
  font-family: var(--font-mono); font-size: 13px; font-weight: 700; letter-spacing: 0.05em;
  padding: 10px 20px; border-radius: var(--radius-sm); border: none; cursor: pointer;
  transition: all 0.2s ease; text-transform: uppercase; display: inline-flex; align-items: center; gap: 8px; text-decoration: none;
}
.btn-primary { background: var(--accent-electric); color: #fff; }
.btn-primary:hover { background: #7aaeff; box-shadow: var(--glow-blue); transform: translateY(-1px); }
.btn-secondary { background: transparent; color: var(--accent-electric); border: 1px solid var(--accent-electric); }
.btn-secondary:hover { background: rgba(91, 140, 247, 0.1); }
.btn-gold { background: var(--accent-gold); color: #1a1000; }
.btn-gold:hover { box-shadow: var(--glow-gold); transform: translateY(-1px); }
.btn-danger { background: var(--accent-red); color: #fff; }
.btn-sm { padding: 6px 12px; font-size: 11px; }
.btn-lg { padding: 14px 28px; font-size: 15px; }
.btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none !important; }
.input {
  width: 100%; font-family: var(--font-mono); font-size: 14px;
  background: var(--bg-secondary); border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm); color: var(--text-primary); padding: 12px 16px;
  transition: all 0.2s ease; outline: none;
}
.input:focus { border-color: var(--accent-electric); box-shadow: 0 0 0 3px rgba(91, 140, 247, 0.15); }
.input::placeholder { color: var(--text-muted); }
textarea.input { resize: vertical; min-height: 100px; }
.label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-secondary); margin-bottom: 6px; }
.badge { display: inline-flex; align-items: center; gap: 4px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; padding: 3px 8px; border-radius: 100px; }
.badge-active { background: rgba(61, 214, 140, 0.15); color: var(--accent-green); border: 1px solid rgba(61, 214, 140, 0.3); }
.badge-resolved { background: rgba(91, 140, 247, 0.15); color: var(--accent-electric); border: 1px solid rgba(91, 140, 247, 0.3); }
.badge-disputed { background: rgba(240, 85, 114, 0.15); color: var(--accent-red); border: 1px solid rgba(240, 85, 114, 0.3); }
.badge-closed { background: rgba(139, 144, 184, 0.15); color: var(--text-secondary); border: 1px solid rgba(139, 144, 184, 0.3); }
.progress-bar { height: 8px; border-radius: 100px; background: var(--bg-secondary); overflow: hidden; }
.progress-fill { height: 100%; border-radius: 100px; transition: width 0.5s ease; }
.progress-yes { background: linear-gradient(90deg, var(--accent-green), #5af0a0); }
.progress-no { background: linear-gradient(90deg, var(--accent-red), #f07090); }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
@keyframes slideIn { from { opacity: 0; transform: translateY(16px); } to { opacity: 1; transform: translateY(0); } }
@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
.animate-slide-in { animation: slideIn 0.4s ease forwards; }
.loading-pulse { animation: pulse 1.5s ease-in-out infinite; }
.skeleton {
  background: linear-gradient(90deg, var(--bg-card) 25%, var(--bg-card-hover) 50%, var(--bg-card) 75%);
  background-size: 200% 100%; animation: shimmer 1.5s infinite; border-radius: var(--radius-sm);
}
.text-electric { color: var(--accent-electric); }
.text-gold { color: var(--accent-gold); }
.text-green { color: var(--accent-green); }
.text-red { color: var(--accent-red); }
.text-muted { color: var(--text-muted); }
.font-display { font-family: var(--font-display); }
.divider { border: none; border-top: 1px solid var(--border-subtle); margin: 20px 0; }
.w-full { width: 100%; }
.text-center { text-align: center; }
EOF
ok "frontend/src/styles/globals.css"

log "Writing frontend/src/components/wallet/WalletButton.tsx..."
cat > $ROOT/frontend/src/components/wallet/WalletButton.tsx << 'EOF'
import { useCallback, useEffect } from 'react';
import { showConnect, UserSession, AppConfig } from '@stacks/connect';
import { useWalletStore } from '../../hooks/useWallet';
import { APP_CONFIG, CURRENT_NETWORK } from '../../utils/constants';

const appConfig = new AppConfig(['store_write', 'publish_data']);
export const userSession = new UserSession({ appConfig });

export function WalletButton() {
  const { connected, address, connect, disconnect } = useWalletStore();

  useEffect(() => {
    if (userSession.isUserSignedIn()) {
      const data = userSession.loadUserData();
      const addr = CURRENT_NETWORK === 'mainnet' ? data.profile.stxAddress.mainnet : data.profile.stxAddress.testnet;
      connect(addr, data.profile.stxAddress.mainnet, data.profile.stxAddress.testnet);
    }
  }, [connect]);

  const handleConnect = useCallback(() => {
    showConnect({
      appDetails: { name: APP_CONFIG.name, icon: APP_CONFIG.appIconUrl },
      userSession,
      onFinish: () => {
        const data = userSession.loadUserData();
        const addr = CURRENT_NETWORK === 'mainnet' ? data.profile.stxAddress.mainnet : data.profile.stxAddress.testnet;
        connect(addr, data.profile.stxAddress.mainnet, data.profile.stxAddress.testnet);
      },
    });
  }, [connect]);

  const handleDisconnect = useCallback(() => { userSession.signUserOut(); disconnect(); }, [disconnect]);

  if (connected && address) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-sm)', padding: '8px 14px', fontSize: '12px', color: 'var(--text-secondary)' }}>
          <span style={{ color: 'var(--accent-green)', marginRight: '6px' }}>●</span>
          {address.slice(0, 6)}...{address.slice(-4)}
        </div>
        <button className="btn btn-secondary btn-sm" onClick={handleDisconnect}>Disconnect</button>
      </div>
    );
  }
  return <button className="btn btn-primary" onClick={handleConnect}><span>⬡</span> Connect Wallet</button>;
}
EOF
ok "frontend/src/components/wallet/WalletButton.tsx"

log "Writing frontend/src/components/ui/Navbar.tsx..."
cat > $ROOT/frontend/src/components/ui/Navbar.tsx << 'EOF'
import Link from 'next/link';
import { useRouter } from 'next/router';
import { WalletButton } from '../wallet/WalletButton';
import { useCurrentBlock } from '../../hooks/useMarkets';

export function Navbar() {
  const router = useRouter();
  const currentBlock = useCurrentBlock();
  const navLinks = [{ href: '/', label: 'Markets' }, { href: '/create', label: 'Create' }, { href: '/dashboard', label: 'Dashboard' }];
  return (
    <header style={{ position: 'sticky', top: 0, zIndex: 100, background: 'rgba(6, 7, 15, 0.9)', backdropFilter: 'blur(20px)', borderBottom: '1px solid var(--border-subtle)' }}>
      <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: '64px' }}>
        <Link href="/" style={{ textDecoration: 'none' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '32px', height: '32px', background: 'var(--accent-electric)', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '16px' }}>⬡</div>
            <div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '15px', color: 'var(--text-primary)' }}>StacksPM</div>
              <div style={{ fontSize: '9px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>Prediction Market</div>
            </div>
          </div>
        </Link>
        <nav style={{ display: 'flex', gap: '4px' }}>
          {navLinks.map(({ href, label }) => {
            const isActive = router.pathname === href;
            return (
              <Link key={href} href={href} style={{ textDecoration: 'none', padding: '6px 14px', borderRadius: 'var(--radius-sm)', fontSize: '12px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.08em', color: isActive ? 'var(--accent-electric)' : 'var(--text-secondary)', background: isActive ? 'rgba(91, 140, 247, 0.1)' : 'transparent', border: isActive ? '1px solid rgba(91, 140, 247, 0.2)' : '1px solid transparent', transition: 'all 0.2s ease' }}>
                {label}
              </Link>
            );
          })}
        </nav>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {currentBlock > 0 && <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>Block #{currentBlock.toLocaleString()}</div>}
          <WalletButton />
        </div>
      </div>
    </header>
  );
}
EOF
ok "frontend/src/components/ui/Navbar.tsx"

log "Writing frontend/src/components/market/MarketCard.tsx..."
cat > $ROOT/frontend/src/components/market/MarketCard.tsx << 'EOF'
import Link from 'next/link';
import { type Market, type MarketOutcome, formatSTX, getMarketStatus, getOutcomePercentage, isMarketBettingOpen } from '../../utils/contracts';
import { useCurrentBlock } from '../../hooks/useMarkets';

function StatusBadge({ status }: { status: string }) {
  const cls: Record<string, string> = { 'Active': 'badge-active', 'Resolved': 'badge-resolved', 'Disputed': 'badge-disputed', 'Awaiting Resolution': 'badge-closed', 'Betting Closed': 'badge-closed' };
  const dot: Record<string, string> = { 'Active': '●', 'Resolved': '✓', 'Disputed': '!', 'Awaiting Resolution': '◌', 'Betting Closed': '⏸' };
  return <span className={`badge ${cls[status] || 'badge-closed'}`}>{dot[status] || '●'} {status}</span>;
}

export function MarketCard({ market, outcomes }: { market: Market; outcomes: MarketOutcome[] }) {
  const currentBlock = useCurrentBlock();
  const status = getMarketStatus(market, currentBlock);
  const bettingOpen = isMarketBettingOpen(market, currentBlock);
  const blocksLeft = market.deadline - currentBlock;
  const daysLeft = Math.max(0, Math.floor(blocksLeft / 144));
  const hoursLeft = Math.max(0, Math.floor((blocksLeft % 144) / 6));
  const yesPool = outcomes[0]?.pool || 0;
  const yesPercent = getOutcomePercentage(yesPool, market.totalPool);
  const noPercent = 100 - yesPercent;

  return (
    <Link href={`/market/${market.id}`} style={{ textDecoration: 'none' }}>
      <div className="card" style={{ cursor: 'pointer' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
          <div style={{ fontSize: '10px', fontWeight: '700', letterSpacing: '0.1em', color: 'var(--text-muted)', textTransform: 'uppercase' }}>MARKET #{market.id}</div>
          <StatusBadge status={status} />
        </div>
        <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: '700', marginBottom: '16px', lineHeight: '1.3' }}>{market.title}</h3>
        {market.outcomeCount === 2 && (
          <div style={{ marginBottom: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '12px' }}>
              <span style={{ color: 'var(--accent-green)', fontWeight: '700' }}>{outcomes[0]?.label || 'YES'} {yesPercent}%</span>
              <span style={{ color: 'var(--accent-red)', fontWeight: '700' }}>{noPercent}% {outcomes[1]?.label || 'NO'}</span>
            </div>
            <div className="progress-bar">
              <div className="progress-fill progress-yes" style={{ width: `${yesPercent}%` }} />
            </div>
          </div>
        )}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px', paddingTop: '16px', borderTop: '1px solid var(--border-subtle)' }}>
          <div>
            <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '2px' }}>Pool</div>
            <div style={{ fontSize: '14px', fontWeight: '700', color: 'var(--accent-gold)' }}>{formatSTX(market.totalPool)}</div>
          </div>
          <div>
            <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '2px' }}>{market.resolved ? 'Winner' : 'Time Left'}</div>
            <div style={{ fontSize: '14px', fontWeight: '700', color: market.resolved ? 'var(--accent-green)' : 'var(--text-primary)' }}>
              {market.resolved ? (outcomes[market.winningOutcome]?.label || 'Resolved') : (blocksLeft > 0 ? `${daysLeft}d ${hoursLeft}h` : 'Ended')}
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            {bettingOpen && <span style={{ fontSize: '11px', fontWeight: '700', color: 'var(--accent-electric)', textTransform: 'uppercase' }}>Bet Now →</span>}
          </div>
        </div>
      </div>
    </Link>
  );
}
EOF
ok "frontend/src/components/market/MarketCard.tsx"

log "Writing frontend/src/components/market/BetPanel.tsx..."
cat > $ROOT/frontend/src/components/market/BetPanel.tsx << 'EOF'
import { useState } from 'react';
import { openContractCall } from '@stacks/connect';
import { type Market, type MarketOutcome, buildPlaceBetTx, buildEarlyWithdrawTx, buildClaimWinningsTx, formatSTX, stxToMicroSTX, microSTXtoSTX, isMarketBettingOpen, getOutcomePercentage } from '../../utils/contracts';
import { useWalletStore } from '../../hooks/useWallet';
import { useUserBets, useClaimInfo, useCurrentBlock } from '../../hooks/useMarkets';

export function BetPanel({ market, outcomes, onSuccess }: { market: Market; outcomes: MarketOutcome[]; onSuccess?: () => void; }) {
  const { connected, address } = useWalletStore();
  const currentBlock = useCurrentBlock();
  const { bets, refetch: refetchBets } = useUserBets(market.id, address, market.outcomeCount);
  const { claimStatus, potentialWinnings } = useClaimInfo(market.id, address, market.resolved);
  const [selectedOutcome, setSelectedOutcome] = useState<number | null>(null);
  const [betAmountSTX, setBetAmountSTX] = useState('');
  const [loading, setLoading] = useState(false);
  const [txMessage, setTxMessage] = useState<string | null>(null);

  const bettingOpen = isMarketBettingOpen(market, currentBlock);
  const betAmountMicro = stxToMicroSTX(parseFloat(betAmountSTX) || 0);

  async function handlePlaceBet() {
    if (!connected || selectedOutcome === null || betAmountMicro === 0) return;
    setLoading(true);
    try {
      await openContractCall({
        ...buildPlaceBetTx({ marketId: market.id, outcomeIndex: selectedOutcome, amount: betAmountMicro, senderAddress: address! }),
        onFinish: (data: any) => { setTxMessage(`Bet placed! TX: ${data.txId.slice(0, 12)}...`); setBetAmountSTX(''); setSelectedOutcome(null); setTimeout(() => { refetchBets(); onSuccess?.(); }, 3000); },
        onCancel: () => setLoading(false),
      });
    } catch { setTxMessage('Transaction failed.'); } finally { setLoading(false); }
  }

  async function handleClaim() {
    setLoading(true);
    try {
      await openContractCall({ ...buildClaimWinningsTx(market.id), onFinish: (data: any) => { setTxMessage(`Claimed! TX: ${data.txId.slice(0, 12)}...`); refetchBets(); onSuccess?.(); }, onCancel: () => setLoading(false) });
    } catch { setTxMessage('Claim failed.'); } finally { setLoading(false); }
  }

  async function handleEarlyWithdraw(outcomeIndex: number) {
    setLoading(true);
    try {
      await openContractCall({ ...buildEarlyWithdrawTx(market.id, outcomeIndex), onFinish: (data: any) => { setTxMessage(`Withdrawn! TX: ${data.txId.slice(0, 12)}...`); refetchBets(); onSuccess?.(); }, onCancel: () => setLoading(false) });
    } catch { setTxMessage('Withdrawal failed.'); } finally { setLoading(false); }
  }

  if (!connected) return (
    <div className="card" style={{ textAlign: 'center', padding: '40px' }}>
      <div style={{ fontSize: '32px', marginBottom: '12px' }}>⬡</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>Connect your wallet</div>
      <div style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Connect a Stacks wallet to place bets or claim winnings</div>
    </div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      {market.resolved && !market.disputed && (
        <div className="card" style={{ borderColor: 'rgba(61, 214, 140, 0.3)' }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '16px', fontWeight: '700', marginBottom: '16px' }}>🏆 Claim Winnings</div>
          {claimStatus?.claimed ? (
            <div style={{ color: 'var(--accent-green)', fontSize: '14px' }}>✓ Claimed {formatSTX(claimStatus.amount)}</div>
          ) : potentialWinnings > 0 ? (
            <>
              <div style={{ marginBottom: '16px' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Your Winnings</div>
                <div style={{ fontSize: '28px', fontWeight: '700', color: 'var(--accent-gold)', fontFamily: 'var(--font-display)' }}>{formatSTX(potentialWinnings)}</div>
              </div>
              <button className="btn btn-gold w-full btn-lg" onClick={handleClaim} disabled={loading}>{loading ? 'Processing...' : '⬡ Claim Winnings'}</button>
            </>
          ) : <div style={{ color: 'var(--text-muted)', fontSize: '14px' }}>No winnings to claim.</div>}
        </div>
      )}

      {bettingOpen && (
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '16px', fontWeight: '700', marginBottom: '20px' }}>Place a Bet</div>
          <div style={{ marginBottom: '20px' }}>
            <div className="label">Choose Outcome</div>
            <div style={{ display: 'grid', gridTemplateColumns: `repeat(${outcomes.length}, 1fr)`, gap: '8px' }}>
              {outcomes.map((outcome, i) => {
                const pct = getOutcomePercentage(outcome.pool, market.totalPool);
                const isSelected = selectedOutcome === i;
                const colors = ['var(--accent-green)', 'var(--accent-red)', 'var(--accent-purple)'];
                const color = colors[i % colors.length];
                return (
                  <button key={i} onClick={() => setSelectedOutcome(i)} style={{ background: isSelected ? `rgba(${i === 0 ? '61,214,140' : '240,85,114'}, 0.15)` : 'var(--bg-secondary)', border: `2px solid ${isSelected ? color : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-md)', padding: '14px', cursor: 'pointer', transition: 'all 0.2s ease', textAlign: 'center' }}>
                    <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', color: isSelected ? color : 'var(--text-primary)', fontSize: '15px' }}>{outcome.label}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>{pct}% · {formatSTX(outcome.pool)}</div>
                  </button>
                );
              })}
            </div>
          </div>
          <div style={{ marginBottom: '16px' }}>
            <label className="label">Bet Amount (STX)</label>
            <div style={{ position: 'relative' }}>
              <input type="number" className="input" placeholder="0.0" value={betAmountSTX} onChange={e => setBetAmountSTX(e.target.value)} min="0" step="0.1" style={{ paddingRight: '60px' }} />
              <span style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '12px', fontWeight: '700' }}>STX</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '8px', marginBottom: '20px' }}>
            {[1, 5, 10, 25].map(amt => <button key={amt} className="btn btn-secondary btn-sm" onClick={() => setBetAmountSTX(String(amt))}>{amt} STX</button>)}
          </div>
          <button className="btn btn-primary w-full btn-lg" onClick={handlePlaceBet} disabled={loading || selectedOutcome === null || betAmountMicro === 0}>
            {loading ? 'Confirming...' : selectedOutcome !== null ? `Bet on ${outcomes[selectedOutcome]?.label}` : 'Select an outcome'}
          </button>
        </div>
      )}

      {bets.some(b => b && b.amount > 0) && (
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '16px', fontWeight: '700', marginBottom: '16px' }}>Your Bets</div>
          {bets.map((bet, i) => {
            if (!bet || bet.amount === 0) return null;
            return (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px', background: 'var(--bg-secondary)', borderRadius: 'var(--radius-sm)', marginBottom: '8px' }}>
                <div>
                  <div style={{ fontWeight: '700', fontSize: '14px' }}>{outcomes[i]?.label || `Outcome ${i}`}</div>
                  <div style={{ color: 'var(--accent-gold)', fontSize: '13px' }}>
                    {formatSTX(bet.amount)}
                    {bet.claimed && <span style={{ color: 'var(--accent-green)', marginLeft: '8px' }}>✓ Claimed</span>}
                    {bet.withdrawn && <span style={{ color: 'var(--text-muted)', marginLeft: '8px' }}>Withdrawn</span>}
                  </div>
                </div>
                {!market.resolved && !bet.withdrawn && !bet.claimed && bettingOpen && (
                  <button className="btn btn-secondary btn-sm" onClick={() => handleEarlyWithdraw(i)} disabled={loading}>Withdraw (5% fee)</button>
                )}
              </div>
            );
          })}
        </div>
      )}

      {txMessage && (
        <div style={{ background: 'var(--bg-card)', border: '1px solid var(--accent-electric)', borderRadius: 'var(--radius-md)', padding: '12px 16px', fontSize: '13px', color: 'var(--accent-electric)' }}>
          {txMessage}
        </div>
      )}
    </div>
  );
}
EOF
ok "frontend/src/components/market/BetPanel.tsx"

log "Writing frontend/src/pages/_app.tsx..."
cat > $ROOT/frontend/src/pages/_app.tsx << 'EOF'
import type { AppProps } from 'next/app';
import { Navbar } from '../components/ui/Navbar';
import '../styles/globals.css';

export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <Navbar />
      <main style={{ position: 'relative', zIndex: 1, minHeight: 'calc(100vh - 64px)' }}>
        <Component {...pageProps} />
      </main>
      <footer style={{ borderTop: '1px solid var(--border-subtle)', padding: '24px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '11px', fontFamily: 'var(--font-mono)', letterSpacing: '0.05em' }}>
        STACKS PREDICTION MARKET — BUILT ON BITCOIN · OPEN SOURCE ·{' '}
        <a href="https://github.com/your-repo/stacks-prediction-market" target="_blank" rel="noopener noreferrer" style={{ color: 'var(--accent-electric)', textDecoration: 'none' }}>GITHUB</a>
      </footer>
    </>
  );
}
EOF
ok "frontend/src/pages/_app.tsx"

log "Writing frontend/src/pages/index.tsx..."
cat > $ROOT/frontend/src/pages/index.tsx << 'EOF'
import { useState, useEffect } from 'react';
import Head from 'next/head';
import Link from 'next/link';
import { MarketCard } from '../components/market/MarketCard';
import { useMarkets } from '../hooks/useMarkets';
import { fetchMarketOutcome, type Market, type MarketOutcome } from '../utils/contracts';

function SkeletonCard() {
  return (
    <div className="card" style={{ pointerEvents: 'none' }}>
      <div className="skeleton" style={{ height: '12px', width: '80px', marginBottom: '16px' }} />
      <div className="skeleton" style={{ height: '24px', width: '85%', marginBottom: '8px' }} />
      <div className="skeleton" style={{ height: '8px', marginBottom: '20px' }} />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
        <div className="skeleton" style={{ height: '36px' }} />
        <div className="skeleton" style={{ height: '36px' }} />
        <div className="skeleton" style={{ height: '36px' }} />
      </div>
    </div>
  );
}

function useMarketsWithOutcomes(markets: Market[]) {
  const [outcomesMap, setOutcomesMap] = useState<Record<number, MarketOutcome[]>>({});
  useEffect(() => {
    if (markets.length === 0) return;
    Promise.all(markets.map(async m => {
      const outs = await Promise.all(Array.from({ length: m.outcomeCount }, (_, i) => fetchMarketOutcome(m.id, i)));
      return [m.id, outs.filter(Boolean) as MarketOutcome[]] as const;
    })).then(entries => setOutcomesMap(Object.fromEntries(entries)));
  }, [markets]);
  return outcomesMap;
}

type FilterType = 'all' | 'active' | 'resolved';

export default function HomePage() {
  const { markets, loading, error, refetch } = useMarkets();
  const outcomesMap = useMarketsWithOutcomes(markets);
  const [filter, setFilter] = useState<FilterType>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const totalPool = markets.reduce((s, m) => s + m.totalPool, 0);
  const filtered = markets.filter(m => {
    const matchSearch = m.title.toLowerCase().includes(searchQuery.toLowerCase());
    const matchFilter = filter === 'all' || (filter === 'active' && !m.resolved) || (filter === 'resolved' && m.resolved);
    return matchSearch && matchFilter;
  });

  return (
    <>
      <Head><title>Stacks Prediction Market — Decentralized Forecasting</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ marginBottom: '48px', maxWidth: '640px' }}>
          <div style={{ fontSize: '11px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.15em', color: 'var(--accent-electric)', marginBottom: '16px' }}>⬡ On-Chain · Trustless · Permissionless</div>
          <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: 'clamp(36px, 5vw, 60px)', lineHeight: '1.05', letterSpacing: '-0.03em', marginBottom: '20px', background: 'linear-gradient(135deg, var(--text-primary) 0%, var(--accent-electric) 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
            Predict the Future.<br />Win with Proof.
          </h1>
          <p style={{ fontSize: '16px', color: 'var(--text-secondary)', lineHeight: '1.7', marginBottom: '24px' }}>
            Decentralized prediction markets built on Stacks. Bet STX on real-world outcomes, governed entirely by Clarity smart contracts.
          </p>
          <Link href="/create" className="btn btn-primary btn-lg">+ Create Market</Link>
        </div>

        {!loading && markets.length > 0 && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '48px' }}>
            {[
              { label: 'Total Markets', value: markets.length },
              { label: 'Active', value: markets.filter(m => !m.resolved).length },
              { label: 'Volume (STX)', value: (totalPool / 1_000_000).toFixed(1) },
              { label: 'Resolved', value: markets.filter(m => m.resolved).length },
            ].map(({ label, value }) => (
              <div key={label} style={{ background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '20px', textAlign: 'center' }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '28px', color: 'var(--accent-electric)', marginBottom: '4px' }}>{value}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>{label}</div>
              </div>
            ))}
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', gap: '16px', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', gap: '8px' }}>
            {(['all', 'active', 'resolved'] as FilterType[]).map(f => (
              <button key={f} onClick={() => setFilter(f)} style={{ padding: '6px 14px', borderRadius: 'var(--radius-sm)', border: filter === f ? '1px solid var(--accent-electric)' : '1px solid var(--border-subtle)', background: filter === f ? 'rgba(91, 140, 247, 0.15)' : 'transparent', color: filter === f ? 'var(--accent-electric)' : 'var(--text-secondary)', cursor: 'pointer', fontSize: '12px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.06em', fontFamily: 'var(--font-mono)', transition: 'all 0.2s ease' }}>{f}</button>
            ))}
          </div>
          <input type="text" className="input" placeholder="Search markets..." value={searchQuery} onChange={e => setSearchQuery(e.target.value)} style={{ maxWidth: '280px' }} />
        </div>

        {error && (
          <div style={{ background: 'rgba(240, 85, 114, 0.1)', border: '1px solid rgba(240, 85, 114, 0.3)', borderRadius: 'var(--radius-md)', padding: '16px', color: 'var(--accent-red)', marginBottom: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>{error}</span>
            <button className="btn btn-secondary btn-sm" onClick={refetch}>Retry</button>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '20px' }}>
          {loading ? Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />) : filtered.map(market => <MarketCard key={market.id} market={market} outcomes={outcomesMap[market.id] || []} />)}
        </div>

        {!loading && filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: '80px 0' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>⬡</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', marginBottom: '8px' }}>{searchQuery ? 'No markets found' : 'No markets yet'}</div>
            <div style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>{searchQuery ? 'Try a different search' : 'Be the first to create a prediction market'}</div>
            {!searchQuery && <Link href="/create" className="btn btn-primary">Create First Market</Link>}
          </div>
        )}
      </div>
    </>
  );
}
EOF
ok "frontend/src/pages/index.tsx"

log "Writing frontend/src/pages/create.tsx..."
cat > $ROOT/frontend/src/pages/create.tsx << 'EOF'
import { useState } from 'react';
import Head from 'next/head';
import { useRouter } from 'next/router';
import { openContractCall } from '@stacks/connect';
import { useWalletStore } from '../hooks/useWallet';
import { buildCreateMarketTx, estimateDeadlineBlock } from '../utils/contracts';
import { useCurrentBlock } from '../hooks/useMarkets';

export default function CreateMarketPage() {
  const router = useRouter();
  const { connected } = useWalletStore();
  const currentBlock = useCurrentBlock();
  const [step, setStep] = useState(1);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [outcomeA, setOutcomeA] = useState('YES');
  const [outcomeB, setOutcomeB] = useState('NO');
  const [daysUntilDeadline, setDaysUntilDeadline] = useState(7);
  const [loading, setLoading] = useState(false);
  const [txMessage, setTxMessage] = useState('');
  const deadlineBlock = estimateDeadlineBlock(currentBlock, daysUntilDeadline);
  const steps = [{ num: 1, label: 'Market Info' }, { num: 2, label: 'Outcomes' }, { num: 3, label: 'Timeline' }, { num: 4, label: 'Review' }];

  if (!connected) return (
    <div className="container" style={{ padding: '80px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: '48px', marginBottom: '16px' }}>⬡</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Your Wallet</div>
      <div style={{ color: 'var(--text-secondary)' }}>You need a Stacks wallet to create prediction markets.</div>
    </div>
  );

  async function handleSubmit() {
    setLoading(true);
    try {
      await openContractCall({
        ...buildCreateMarketTx({ title: title.trim(), description: description.trim(), outcomeA: outcomeA.trim(), outcomeB: outcomeB.trim(), deadline: deadlineBlock }),
        onFinish: (data: any) => { setTxMessage(`Market created! TX: ${data.txId}`); setTimeout(() => router.push('/'), 2000); },
        onCancel: () => setLoading(false),
      });
    } catch { setTxMessage('Transaction failed.'); } finally { setLoading(false); }
  }

  return (
    <>
      <Head><title>Create Market — Stacks Prediction Market</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ maxWidth: '640px', margin: '0 auto' }}>
          <div style={{ marginBottom: '40px' }}>
            <div style={{ fontSize: '11px', color: 'var(--accent-electric)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '8px' }}>New Prediction Market</div>
            <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '36px', letterSpacing: '-0.02em' }}>Create a Market</h1>
          </div>

          <div style={{ display: 'flex', gap: '0', marginBottom: '40px', position: 'relative' }}>
            <div style={{ position: 'absolute', top: '14px', left: '14px', right: '14px', height: '2px', background: 'var(--border-subtle)', zIndex: 0 }} />
            {steps.map(({ num, label }) => {
              const isActive = step === num; const isDone = step > num;
              return (
                <div key={num} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative', zIndex: 1 }}>
                  <div style={{ width: '28px', height: '28px', borderRadius: '50%', background: isDone ? 'var(--accent-green)' : isActive ? 'var(--accent-electric)' : 'var(--bg-card)', border: `2px solid ${isDone ? 'var(--accent-green)' : isActive ? 'var(--accent-electric)' : 'var(--border-subtle)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '11px', fontWeight: '700', color: isDone || isActive ? '#fff' : 'var(--text-muted)' }}>
                    {isDone ? '✓' : num}
                  </div>
                  <div style={{ fontSize: '10px', marginTop: '6px', color: isActive ? 'var(--accent-electric)' : 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', fontWeight: isActive ? '700' : '400' }}>{label}</div>
                </div>
              );
            })}
          </div>

          {step === 1 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>What are you predicting?</div>
              <div style={{ marginBottom: '20px' }}>
                <label className="label">Market Title *</label>
                <input className="input" type="text" placeholder="e.g. Will BTC reach $150k before Dec 31?" value={title} onChange={e => setTitle(e.target.value)} maxLength={200} />
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px', textAlign: 'right' }}>{title.length}/200</div>
              </div>
              <div style={{ marginBottom: '20px' }}>
                <label className="label">Description (optional)</label>
                <textarea className="input" placeholder="Provide resolution criteria..." value={description} onChange={e => setDescription(e.target.value)} maxLength={800} rows={4} />
              </div>
              <button className="btn btn-primary w-full" onClick={() => setStep(2)} disabled={title.trim().length === 0}>Continue →</button>
            </div>
          )}

          {step === 2 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>Define the outcomes</div>
              <div style={{ marginBottom: '16px' }}>
                <label className="label">Outcome A *</label>
                <input className="input" value={outcomeA} onChange={e => setOutcomeA(e.target.value)} placeholder="YES" maxLength={50} />
              </div>
              <div style={{ marginBottom: '20px' }}>
                <label className="label">Outcome B *</label>
                <input className="input" value={outcomeB} onChange={e => setOutcomeB(e.target.value)} placeholder="NO" maxLength={50} />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <button className="btn btn-secondary w-full" onClick={() => setStep(1)}>← Back</button>
                <button className="btn btn-primary w-full" onClick={() => setStep(3)} disabled={!outcomeA.trim() || !outcomeB.trim()}>Continue →</button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>Set the deadline</div>
              <div style={{ marginBottom: '24px' }}>
                <label className="label">Days until market closes</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px', marginBottom: '16px' }}>
                  {[1, 3, 7, 14, 30, 60, 90, 180].map(d => (
                    <button key={d} onClick={() => setDaysUntilDeadline(d)} style={{ padding: '10px', border: `2px solid ${daysUntilDeadline === d ? 'var(--accent-electric)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-sm)', background: daysUntilDeadline === d ? 'rgba(91,140,247,0.1)' : 'var(--bg-secondary)', color: daysUntilDeadline === d ? 'var(--accent-electric)' : 'var(--text-secondary)', cursor: 'pointer', fontSize: '12px', fontWeight: '700', fontFamily: 'var(--font-mono)' }}>{d}d</button>
                  ))}
                </div>
                <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '16px', fontSize: '13px', color: 'var(--text-secondary)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}><span>Current block:</span><span style={{ color: 'var(--text-primary)', fontWeight: '700' }}>#{currentBlock.toLocaleString()}</span></div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Deadline block:</span><span style={{ color: 'var(--accent-electric)', fontWeight: '700' }}>#{deadlineBlock.toLocaleString()}</span></div>
                </div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <button className="btn btn-secondary w-full" onClick={() => setStep(2)}>← Back</button>
                <button className="btn btn-primary w-full" onClick={() => setStep(4)}>Review →</button>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>Review & Deploy</div>
              <div style={{ background: 'var(--bg-secondary)', borderRadius: 'var(--radius-md)', padding: '20px', marginBottom: '24px' }}>
                <div style={{ marginBottom: '12px' }}><div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '4px' }}>Title</div><div style={{ fontFamily: 'var(--font-display)', fontWeight: '700' }}>{title}</div></div>
                <div style={{ marginBottom: '12px' }}><div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '8px' }}>Outcomes</div><div style={{ display: 'flex', gap: '8px' }}>{[outcomeA, outcomeB].map((o, i) => <span key={i} style={{ padding: '4px 12px', background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: '100px', fontSize: '13px', fontWeight: '700' }}>{o}</span>)}</div></div>
                <div><div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '4px' }}>Deadline</div><div style={{ fontSize: '14px' }}>Block <span style={{ color: 'var(--accent-electric)', fontWeight: '700' }}>#{deadlineBlock.toLocaleString()}</span> (~{daysUntilDeadline} days)</div></div>
              </div>
              {txMessage && <div style={{ background: 'rgba(91, 140, 247, 0.1)', border: '1px solid var(--accent-electric)', borderRadius: 'var(--radius-md)', padding: '12px 16px', fontSize: '13px', color: 'var(--accent-electric)', marginBottom: '16px', wordBreak: 'break-all' }}>{txMessage}</div>}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <button className="btn btn-secondary w-full" onClick={() => setStep(3)}>← Back</button>
                <button className="btn btn-primary w-full btn-lg" onClick={handleSubmit} disabled={loading}>{loading ? 'Deploying...' : '⬡ Deploy Market'}</button>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
}
EOF
ok "frontend/src/pages/create.tsx"

log "Writing frontend/src/pages/market/[id].tsx..."
cat > $ROOT/frontend/src/pages/market/\[id\].tsx << 'EOF'
import { useRouter } from 'next/router';
import Head from 'next/head';
import { openContractCall } from '@stacks/connect';
import { useMarket, useCurrentBlock } from '../../hooks/useMarkets';
import { BetPanel } from '../../components/market/BetPanel';
import { useWalletStore } from '../../hooks/useWallet';
import { formatSTX, getMarketStatus, getOutcomePercentage, buildResolveMarketTx } from '../../utils/contracts';
import { useState } from 'react';

export default function MarketDetailPage() {
  const router = useRouter();
  const { id } = router.query;
  const marketId = parseInt(id as string);
  const { market, outcomes, loading, error, refetch } = useMarket(marketId);
  const currentBlock = useCurrentBlock();
  const { address } = useWalletStore();
  const [resolving, setResolving] = useState(false);
  const [resolveMessage, setResolveMessage] = useState('');

  if (loading) return (
    <div className="container" style={{ padding: '48px 24px' }}>
      <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
        <div className="skeleton" style={{ height: '32px', width: '200px', marginBottom: '24px' }} />
        <div className="skeleton" style={{ height: '48px', width: '80%', marginBottom: '48px' }} />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '24px' }}>
          <div className="skeleton" style={{ height: '400px', borderRadius: 'var(--radius-lg)' }} />
          <div className="skeleton" style={{ height: '400px', borderRadius: 'var(--radius-lg)' }} />
        </div>
      </div>
    </div>
  );

  if (error || !market) return (
    <div className="container" style={{ padding: '48px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: '48px', marginBottom: '16px' }}>⚠</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', marginBottom: '8px' }}>{error || 'Market not found'}</div>
      <button className="btn btn-secondary" onClick={() => router.push('/')}>← Back to Markets</button>
    </div>
  );

  const status = getMarketStatus(market, currentBlock);
  const blocksLeft = market.deadline - currentBlock;
  const daysLeft = Math.floor(Math.max(0, blocksLeft) / 144);
  const hoursLeft = Math.floor((Math.max(0, blocksLeft) % 144) / 6);
  const canResolve = (address === market.creator) && !market.resolved && currentBlock >= market.deadline;

  async function handleResolve(winningOutcome: number) {
    setResolving(true);
    try {
      await openContractCall({ ...buildResolveMarketTx(market!.id, winningOutcome), onFinish: (data: any) => { setResolveMessage(`Resolved! TX: ${data.txId.slice(0, 12)}...`); setTimeout(refetch, 3000); }, onCancel: () => setResolving(false) });
    } catch { setResolveMessage('Resolution failed.'); } finally { setResolving(false); }
  }

  const statusColors: Record<string, string> = { 'Active': 'var(--accent-green)', 'Resolved': 'var(--accent-electric)', 'Disputed': 'var(--accent-red)', 'Awaiting Resolution': 'var(--accent-gold)', 'Betting Closed': 'var(--text-muted)' };

  return (
    <>
      <Head><title>{market.title} — Stacks PM</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
          <button onClick={() => router.push('/')} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', fontSize: '13px', cursor: 'pointer', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '6px', fontFamily: 'var(--font-mono)' }}>← All Markets</button>
          <div style={{ marginBottom: '40px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>MARKET #{market.id}</div>
              <div style={{ fontSize: '11px', fontWeight: '700', color: statusColors[status] || 'var(--text-muted)', textTransform: 'uppercase' }}>● {status}</div>
              {market.oracleResolved && <div style={{ fontSize: '11px', color: 'var(--accent-purple)', fontWeight: '700' }}>⬡ Oracle Verified</div>}
            </div>
            <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: 'clamp(24px, 4vw, 40px)', letterSpacing: '-0.02em', lineHeight: '1.1', marginBottom: '16px' }}>{market.title}</h1>
            <p style={{ color: 'var(--text-secondary)', fontSize: '15px', lineHeight: '1.7', maxWidth: '640px' }}>{market.description}</p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '24px', alignItems: 'start' }}>
            <div>
              <div className="card" style={{ marginBottom: '20px' }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', marginBottom: '20px' }}>Current Odds</div>
                {outcomes.map((outcome, i) => {
                  const pct = getOutcomePercentage(outcome.pool, market.totalPool);
                  const colors = ['var(--accent-green)', 'var(--accent-red)', 'var(--accent-purple)'];
                  const color = colors[i % colors.length];
                  return (
                    <div key={i} style={{ marginBottom: '12px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: color }} />
                          <span style={{ fontWeight: '700' }}>{outcome.label}</span>
                        </div>
                        <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
                          <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>{formatSTX(outcome.pool)}</span>
                          <span style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '18px', color }}>{pct}%</span>
                        </div>
                      </div>
                      <div style={{ height: '10px', background: 'var(--bg-secondary)', borderRadius: '100px', overflow: 'hidden' }}>
                        <div style={{ height: '100%', width: `${pct}%`, background: `linear-gradient(90deg, ${color}, ${color}88)`, borderRadius: '100px', transition: 'width 0.8s ease' }} />
                      </div>
                    </div>
                  );
                })}
                <hr className="divider" />
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px' }}>
                  {[
                    { label: 'Total Pool', value: formatSTX(market.totalPool), color: 'var(--accent-gold)' },
                    { label: 'Deadline Block', value: `#${market.deadline.toLocaleString()}`, color: 'var(--text-primary)' },
                    { label: 'Time Left', value: market.resolved ? '—' : blocksLeft > 0 ? `${daysLeft}d ${hoursLeft}h` : 'Ended', color: 'var(--text-primary)' },
                  ].map(({ label, value, color }) => (
                    <div key={label}>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '4px' }}>{label}</div>
                      <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', color }}>{value}</div>
                    </div>
                  ))}
                </div>
              </div>

              {market.resolved && outcomes[market.winningOutcome] && (
                <div className="card" style={{ borderColor: 'rgba(61,214,140,0.4)', background: 'rgba(61,214,140,0.05)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ fontSize: '32px' }}>🏆</div>
                    <div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '4px' }}>Winning Outcome</div>
                      <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '22px', color: 'var(--accent-green)' }}>{outcomes[market.winningOutcome].label}</div>
                    </div>
                  </div>
                </div>
              )}

              {canResolve && (
                <div className="card" style={{ marginTop: '20px', borderColor: 'rgba(240,192,64,0.3)' }}>
                  <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', marginBottom: '16px', color: 'var(--accent-gold)' }}>⚡ Resolve Market</div>
                  <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '16px' }}>Select the winning outcome:</div>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {outcomes.map((o, i) => <button key={i} className="btn btn-gold" onClick={() => handleResolve(i)} disabled={resolving}>{o.label} Wins</button>)}
                  </div>
                  {resolveMessage && <div style={{ marginTop: '12px', fontSize: '13px', color: 'var(--accent-electric)' }}>{resolveMessage}</div>}
                </div>
              )}
            </div>

            <div style={{ position: 'sticky', top: '80px' }}>
              <BetPanel market={market} outcomes={outcomes} onSuccess={refetch} />
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
EOF
ok "frontend/src/pages/market/[id].tsx"

log "Writing frontend/src/pages/dashboard.tsx..."
cat > $ROOT/frontend/src/pages/dashboard.tsx << 'EOF'
import Head from 'next/head';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useWalletStore } from '../hooks/useWallet';
import { useMarkets, useCurrentBlock } from '../hooks/useMarkets';
import { fetchUserBet, fetchClaimStatus, calculateWinnings, formatSTX, getMarketStatus, type Market } from '../utils/contracts';

interface UserMarketData {
  market: Market;
  bets: { outcomeIndex: number; amount: number; claimed: boolean; withdrawn: boolean }[];
  claimStatus: { claimed: boolean; amount: number } | null;
  potentialWinnings: number;
}

export default function DashboardPage() {
  const { connected, address } = useWalletStore();
  const { markets, loading: marketsLoading } = useMarkets();
  const currentBlock = useCurrentBlock();
  const [userMarkets, setUserMarkets] = useState<UserMarketData[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!address || markets.length === 0) return;
    setLoading(true);
    (async () => {
      const results: UserMarketData[] = [];
      for (const market of markets) {
        const rawBets = await Promise.all(Array.from({ length: market.outcomeCount }, (_, i) => fetchUserBet(market.id, address!, i)));
        const bets = rawBets.map((b, i) => b && b.amount > 0 ? { outcomeIndex: i, ...b } : null).filter(Boolean) as any[];
        if (bets.length > 0) {
          const [claimStatus, potentialWinnings] = await Promise.all([
            market.resolved ? fetchClaimStatus(market.id, address!) : Promise.resolve(null),
            market.resolved ? calculateWinnings(market.id, address!) : Promise.resolve(0),
          ]);
          results.push({ market, bets, claimStatus, potentialWinnings });
        }
      }
      setUserMarkets(results);
      setLoading(false);
    })();
  }, [address, markets]);

  if (!connected) return (
    <div className="container" style={{ padding: '80px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: '48px', marginBottom: '16px' }}>⬡</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Your Wallet</div>
      <div style={{ color: 'var(--text-secondary)' }}>View your prediction market activity across all markets.</div>
    </div>
  );

  const totalBet = userMarkets.reduce((s, { bets }) => s + bets.reduce((b, bet) => b + bet.amount, 0), 0);
  const totalClaimable = userMarkets.reduce((s, { potentialWinnings }) => s + potentialWinnings, 0);
  const totalClaimed = userMarkets.filter(({ claimStatus }) => claimStatus?.claimed).reduce((s, { claimStatus }) => s + (claimStatus?.amount || 0), 0);

  return (
    <>
      <Head><title>Dashboard — Stacks Prediction Market</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ marginBottom: '40px' }}>
          <div style={{ fontSize: '11px', color: 'var(--accent-electric)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '8px' }}>Your Activity</div>
          <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '36px', letterSpacing: '-0.02em', marginBottom: '8px' }}>Dashboard</h1>
          <div style={{ color: 'var(--text-muted)', fontSize: '13px', fontFamily: 'var(--font-mono)' }}>{address?.slice(0, 8)}...{address?.slice(-6)}</div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '40px' }}>
          {[
            { label: 'Markets Entered', value: userMarkets.length.toString(), color: 'var(--accent-electric)' },
            { label: 'Active Bets', value: userMarkets.filter(({ market }) => !market.resolved).length.toString(), color: 'var(--accent-green)' },
            { label: 'Total Wagered', value: formatSTX(totalBet), color: 'var(--accent-gold)' },
            { label: 'Winnings Claimed', value: formatSTX(totalClaimed), color: 'var(--accent-green)' },
          ].map(({ label, value, color }) => (
            <div key={label} style={{ background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '20px' }}>
              <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '8px' }}>{label}</div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '22px', color }}>{value}</div>
            </div>
          ))}
        </div>

        {totalClaimable > 0 && (
          <div style={{ background: 'rgba(61, 214, 140, 0.08)', border: '1px solid rgba(61, 214, 140, 0.3)', borderRadius: 'var(--radius-md)', padding: '20px 24px', marginBottom: '32px' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', color: 'var(--accent-green)' }}>🏆 {formatSTX(totalClaimable)} ready to claim</div>
            <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>You have unclaimed winnings on resolved markets</div>
          </div>
        )}

        {loading || marketsLoading ? (
          <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>
            <div className="loading-pulse" style={{ fontSize: '32px', marginBottom: '12px' }}>⬡</div>
            <div>Loading your activity...</div>
          </div>
        ) : userMarkets.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '80px 0' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>📊</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', marginBottom: '8px' }}>No activity yet</div>
            <div style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>You haven't placed any bets yet.</div>
            <Link href="/" className="btn btn-primary">Browse Markets</Link>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {userMarkets.map(({ market, bets, claimStatus, potentialWinnings }) => {
              const hasUnclaimed = market.resolved && potentialWinnings > 0 && !claimStatus?.claimed;
              return (
                <div key={market.id} style={{ background: 'var(--bg-card)', border: `1px solid ${hasUnclaimed ? 'rgba(61, 214, 140, 0.3)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-lg)', padding: '24px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '6px' }}>Market #{market.id} · {getMarketStatus(market, currentBlock)}</div>
                      <Link href={`/market/${market.id}`} style={{ textDecoration: 'none' }}>
                        <h3 style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '17px', color: 'var(--text-primary)', lineHeight: '1.3', cursor: 'pointer' }}>{market.title}</h3>
                      </Link>
                    </div>
                    {hasUnclaimed && <Link href={`/market/${market.id}`} className="btn btn-gold btn-sm" style={{ marginLeft: '16px', whiteSpace: 'nowrap' }}>Claim {formatSTX(potentialWinnings)}</Link>}
                    {claimStatus?.claimed && <span style={{ color: 'var(--accent-green)', fontSize: '13px', fontWeight: '700', marginLeft: '16px' }}>✓ Claimed {formatSTX(claimStatus.amount)}</span>}
                  </div>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {bets.map((bet: any) => (
                      <div key={bet.outcomeIndex} style={{ background: 'var(--bg-secondary)', border: `1px solid ${market.resolved && market.winningOutcome === bet.outcomeIndex ? 'rgba(61,214,140,0.4)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-sm)', padding: '8px 12px', fontSize: '12px' }}>
                        <span style={{ fontWeight: '700' }}>Outcome {bet.outcomeIndex}</span>
                        <span style={{ color: 'var(--accent-gold)', marginLeft: '8px', fontWeight: '700' }}>{formatSTX(bet.amount)}</span>
                        {market.resolved && market.winningOutcome === bet.outcomeIndex && <span style={{ marginLeft: '6px' }}>🏆</span>}
                        {bet.withdrawn && <span style={{ color: 'var(--text-muted)', marginLeft: '6px', fontSize: '11px' }}>withdrawn</span>}
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </>
  );
}
EOF
ok "frontend/src/pages/dashboard.tsx"

# ===========================================================================
# DONE
# ===========================================================================

echo ""
echo "================================================="
echo "  Project created successfully!"
echo "  Location: ./$ROOT"
echo "================================================="
echo ""
echo "Next steps:"
echo ""
echo "  1.  cd $ROOT"
echo "  2.  clarinet check"
echo "  3.  clarinet test"
echo "  4.  cd frontend && npm install && cd .."
echo "  5.  cp frontend/.env.local.example frontend/.env.local"
echo "  6.  npm run dev   (starts frontend at http://localhost:3000)"
echo ""
echo "  Deploy to testnet:"
echo "  7.  bash scripts/deploy.sh testnet"
echo ""
