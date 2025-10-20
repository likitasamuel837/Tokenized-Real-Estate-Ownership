;; TokenEstate - Fractional Real Estate Ownership

(define-non-fungible-token property-share uint)

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-property-not-found (err u101))
(define-constant err-share-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-share-count (err u104))
(define-constant err-property-exists (err u105))
(define-constant err-invalid-percentage (err u106))
(define-constant err-oracle-not-authorized (err u107))
(define-constant err-oracle-already-registered (err u108))
(define-constant err-oracle-not-found (err u109))
(define-constant err-valuation-not-found (err u110))
(define-constant err-pool-exists (err u111))
(define-constant err-pool-not-found (err u112))
(define-constant err-not-pool-admin (err u113))
(define-constant err-invalid-contribution (err u114))
(define-constant err-claim-not-found (err u115))
(define-constant err-claim-already-resolved (err u116))
(define-constant err-insufficient-pool-balance (err u117))
(define-constant err-not-pool-member (err u118))
(define-constant err-locked-up (err u119))

(define-data-var next-property-id uint u1)
(define-data-var lock-up-blocks uint u100)
(define-data-var next-share-id uint u1)
(define-data-var next-valuation-id uint u1)

(define-map properties 
    uint 
    {
        address: (string-ascii 100),
        value: uint,
        total-shares: uint,
        shares-issued: uint,
        owner: principal,
        rental-income: uint,
        created-at: uint,
        is-active: bool
    }
)

(define-map property-shares
    uint
    {
        property-id: uint,
        owner: principal,
        share-percentage: uint,
        purchase-price: uint,
        created-at: uint
    }
)

(define-map owner-properties
    principal
    (list 50 uint)
)

(define-map owner-shares
    principal
    (list 100 uint)
)

(define-map rental-distributions
    {property-id: uint, distribution-id: uint}
    {
        total-amount: uint,
        per-share: uint,
        distributed-at: uint,
        claimed-shares: (list 100 uint)
    }
)

(define-map property-distribution-counter
    uint
    uint
)

(define-map authorized-oracles
    principal
    bool
)

(define-map property-valuations
    {property-id: uint, valuation-id: uint}
    {
        value: uint,
        oracle: principal,
        updated-at: uint,
        confidence-score: uint
    }
)

(define-map latest-property-valuation
    uint
    {
        value: uint,
        oracle: principal,
        updated-at: uint,
        valuation-id: uint,
        confidence-score: uint
    }
)

(define-map property-valuation-counter
    uint
    uint
)

(define-map share-unlock-heights
    { share-id: uint }
    { unlock-height: uint }
)

;; Insurance pool maps
(define-map insurance-pools
    uint
    {
        total-premium: uint,
        total-claims: uint,
        admin: principal,
        created-at: uint,
        is-active: bool
    }
)

(define-map pool-members
    { property-id: uint, member: principal }
    {
        contribution: uint,
        joined-at: uint
    }
)

(define-map insurance-claims
    { property-id: uint, claim-id: uint }
    {
        claimer: principal,
        amount: uint,
        status: (string-ascii 20),
        submitted-at: uint,
        resolved-at: uint,
        reason: (string-ascii 200)
    }
)

(define-map pool-claim-counter
    uint
    uint
)

(define-public (register-property (address (string-ascii 100)) (value uint) (total-shares uint))
    (let 
        (
            (property-id (var-get next-property-id))
        )
        (asserts! (> total-shares u0) err-invalid-share-count)
        (asserts! (> value u0) err-insufficient-funds)
        (map-set properties property-id {
            address: address,
            value: value,
            total-shares: total-shares,
            shares-issued: u0,
            owner: tx-sender,
            rental-income: u0,
            created-at: stacks-block-height,
            is-active: true
        })
        (map-set property-distribution-counter property-id u0)
        (let ((current-properties (default-to (list) (map-get? owner-properties tx-sender))))
            (map-set owner-properties tx-sender (unwrap! (as-max-len? (append current-properties property-id) u50) err-invalid-share-count))
        )
        (var-set next-property-id (+ property-id u1))
        (map-set property-valuation-counter property-id u0)
        (ok property-id)
    )
)

(define-public (mint-share (property-id uint) (share-percentage uint) (price uint))
    (let 
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
            (share-id (var-get next-share-id))
        )
        (asserts! (get is-active property) err-not-authorized)
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        (asserts! (and (> share-percentage u0) (<= share-percentage u10000)) err-invalid-percentage)
        (asserts! (<= (+ (get shares-issued property) share-percentage) u10000) err-invalid-share-count)
        
        (try! (nft-mint? property-share share-id tx-sender))
        
        (map-set property-shares share-id {
            property-id: property-id,
            owner: tx-sender,
            share-percentage: share-percentage,
            purchase-price: price,
            created-at: stacks-block-height
        })
        
        (map-set properties property-id 
            (merge property {shares-issued: (+ (get shares-issued property) share-percentage)})
        )
        
        ;; Set unlock height for newly minted share
        (map-set share-unlock-heights
            { share-id: share-id }
            { unlock-height: (+ stacks-block-height (var-get lock-up-blocks)) }
        )
        
        (var-set next-share-id (+ share-id u1))
        (ok share-id)
    )
)

(define-public (transfer-share (share-id uint) (recipient principal) (price uint))
    (let 
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
            (unlock-data (unwrap! (map-get? share-unlock-heights { share-id: share-id }) err-locked-up))
        )
        ;; Check if share is still locked
        (asserts! (>= stacks-block-height (get unlock-height unlock-data)) err-locked-up)
        (asserts! (is-eq tx-sender (get owner share)) err-not-authorized)
        
        (try! (stx-transfer? price recipient tx-sender))
        (try! (nft-transfer? property-share share-id tx-sender recipient))
        
        (map-set property-shares share-id (merge share {owner: recipient, purchase-price: price}))
        
        (let ((current-shares (default-to (list) (map-get? owner-shares recipient))))
            (map-set owner-shares recipient (unwrap! (as-max-len? (append current-shares share-id) u100) err-invalid-share-count))
        )
        
        (ok true)
    )
)

(define-public (buy-share (share-id uint))
    (let 
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
            (price (get purchase-price share))
            (owner (get owner share))
        )
        (asserts! (not (is-eq tx-sender owner)) err-not-authorized)
        
        (try! (stx-transfer? price tx-sender owner))
        (try! (nft-transfer? property-share share-id owner tx-sender))
        
        (map-set property-shares share-id (merge share {owner: tx-sender, purchase-price: price}))
        
        ;; Update unlock height for new owner
        (map-set share-unlock-heights
            { share-id: share-id }
            { unlock-height: (+ stacks-block-height (var-get lock-up-blocks)) }
        )
        
        (let ((current-shares (default-to (list) (map-get? owner-shares tx-sender))))
            (map-set owner-shares tx-sender (unwrap! (as-max-len? (append current-shares share-id) u100) err-invalid-share-count))
        )
        
        (ok true)
    )
)

(define-public (distribute-rental-income (property-id uint) (amount uint))
    (let 
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
            (distribution-id (+ (default-to u0 (map-get? property-distribution-counter property-id)) u1))
            (per-share (/ amount (get shares-issued property)))
        )
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        (asserts! (> amount u0) err-insufficient-funds)
        (asserts! (> (get shares-issued property) u0) err-invalid-share-count)
        
        (map-set rental-distributions {property-id: property-id, distribution-id: distribution-id} {
            total-amount: amount,
            per-share: per-share,
            distributed-at: stacks-block-height,
            claimed-shares: (list)
        })
        
        (map-set property-distribution-counter property-id distribution-id)
        
        (map-set properties property-id 
            (merge property {rental-income: (+ (get rental-income property) amount)})
        )
        
        (ok distribution-id)
    )
)

(define-public (claim-rental-income (property-id uint) (distribution-id uint) (share-id uint))
    (let 
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
            (distribution (unwrap! (map-get? rental-distributions {property-id: property-id, distribution-id: distribution-id}) err-property-not-found))
            (claimed-shares (get claimed-shares distribution))
            (share-percentage (get share-percentage share))
            (payout (/ (* (get per-share distribution) share-percentage) u100))
        )
        (asserts! (is-eq tx-sender (get owner share)) err-not-authorized)
        (asserts! (is-eq (get property-id share) property-id) err-property-not-found)
        (asserts! (is-none (index-of claimed-shares share-id)) err-not-authorized)
        
        (map-set rental-distributions {property-id: property-id, distribution-id: distribution-id}
            (merge distribution {claimed-shares: (unwrap! (as-max-len? (append claimed-shares share-id) u100) err-invalid-share-count)})
        )
        
        (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
        (ok payout)
    )
)

(define-public (update-property-status (property-id uint) (is-active bool))
    (let 
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
        )
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        
        (map-set properties property-id (merge property {is-active: is-active}))
        (ok true)
    )
)

(define-public (update-share-price (share-id uint) (new-price uint))
    (let 
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
        )
        (asserts! (is-eq tx-sender (get owner share)) err-not-authorized)
        (asserts! (> new-price u0) err-insufficient-funds)
        
        (map-set property-shares share-id (merge share {purchase-price: new-price}))
        (ok true)
    )
)

(define-read-only (get-property (property-id uint))
    (map-get? properties property-id)
)

(define-read-only (get-share (share-id uint))
    (map-get? property-shares share-id)
)

(define-read-only (get-owner-properties (owner principal))
    (map-get? owner-properties owner)
)

(define-read-only (get-owner-shares (owner principal))
    (map-get? owner-shares owner)
)

(define-read-only (get-rental-distribution (property-id uint) (distribution-id uint))
    (map-get? rental-distributions {property-id: property-id, distribution-id: distribution-id})
)

(define-read-only (get-property-distribution-count (property-id uint))
    (map-get? property-distribution-counter property-id)
)

(define-read-only (get-share-owner (share-id uint))
    (nft-get-owner? property-share share-id)
)

(define-public (register-oracle (oracle-address principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-none (map-get? authorized-oracles oracle-address)) err-oracle-already-registered)
        (map-set authorized-oracles oracle-address true)
        (print {event: "oracle-registered", oracle: oracle-address, registered-by: tx-sender})
        (ok true)
    )
)

(define-public (revoke-oracle (oracle-address principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-some (map-get? authorized-oracles oracle-address)) err-oracle-not-found)
        (map-delete authorized-oracles oracle-address)
        (print {event: "oracle-revoked", oracle: oracle-address, revoked-by: tx-sender})
        (ok true)
    )
)

(define-public (update-property-valuation (property-id uint) (new-value uint) (confidence-score uint))
    (let 
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
            (valuation-id (+ (default-to u0 (map-get? property-valuation-counter property-id)) u1))
        )
        (asserts! (is-some (map-get? authorized-oracles tx-sender)) err-oracle-not-authorized)
        (asserts! (> new-value u0) err-insufficient-funds)
        (asserts! (and (>= confidence-score u0) (<= confidence-score u100)) err-invalid-percentage)
        
        (map-set property-valuations {property-id: property-id, valuation-id: valuation-id} {
            value: new-value,
            oracle: tx-sender,
            updated-at: stacks-block-height,
            confidence-score: confidence-score
        })
        
        (map-set latest-property-valuation property-id {
            value: new-value,
            oracle: tx-sender,
            updated-at: stacks-block-height,
            valuation-id: valuation-id,
            confidence-score: confidence-score
        })
        
        (map-set property-valuation-counter property-id valuation-id)
        (var-set next-valuation-id (+ (var-get next-valuation-id) u1))
        
        (print {event: "valuation-updated", property-id: property-id, new-value: new-value, oracle: tx-sender, valuation-id: valuation-id})
        (ok valuation-id)
    )
)

(define-public (calculate-share-value (share-id uint))
    (let 
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
            (property-id (get property-id share))
            (latest-valuation (map-get? latest-property-valuation property-id))
            (share-percentage (get share-percentage share))
        )
        (match latest-valuation
            valuation-data (ok (/ (* (get value valuation-data) share-percentage) u10000))
            err-valuation-not-found
        )
    )
)

(define-read-only (is-authorized-oracle (oracle-address principal))
    (default-to false (map-get? authorized-oracles oracle-address))
)

(define-read-only (get-latest-valuation (property-id uint))
    (map-get? latest-property-valuation property-id)
)

(define-read-only (get-property-valuation (property-id uint) (valuation-id uint))
    (map-get? property-valuations {property-id: property-id, valuation-id: valuation-id})
)

(define-read-only (get-property-valuation-count (property-id uint))
    (default-to u0 (map-get? property-valuation-counter property-id))
)

(define-read-only (get-valuation-history (property-id uint) (limit uint))
    (let 
        (
            (total-valuations (get-property-valuation-count property-id))
            (start-id (if (> total-valuations limit) (- total-valuations limit) u1))
            (max-recent (if (<= total-valuations u10) total-valuations u10))
        )
        (fold build-valuation-list (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (list))
    )
)

(define-private (build-valuation-list (index uint) (acc (list 10 uint)))
    (let 
        (
            (total-count (get-property-valuation-count u1))
            (actual-id (if (> index total-count) u0 index))
        )
        (if (> actual-id u0)
            (unwrap-panic (as-max-len? (append acc actual-id) u10))
            acc
        )
    )
)

(define-read-only (get-market-cap (property-id uint))
    (let 
        (
            (property (map-get? properties property-id))
            (latest-valuation (map-get? latest-property-valuation property-id))
        )
        (match property
            property-data 
            (match latest-valuation
                valuation-data (some (get value valuation-data))
                (some (get value property-data))
            )
            none
        )
    )
)

;; Insurance Pool Public Functions

(define-public (register-insurance-pool (property-id uint))
    (let
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
        )
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        (asserts! (is-none (map-get? insurance-pools property-id)) err-pool-exists)
        
        (map-set insurance-pools property-id {
            total-premium: u0,
            total-claims: u0,
            admin: tx-sender,
            created-at: stacks-block-height,
            is-active: true
        })
        (map-set pool-claim-counter property-id u0)
        
        (print {event: "insurance-pool-registered", property-id: property-id, admin: tx-sender})
        (ok property-id)
    )
)

(define-public (contribute-premium (property-id uint) (amount uint))
    (let
        (
            (pool (unwrap! (map-get? insurance-pools property-id) err-pool-not-found))
            (current-member (default-to {contribution: u0, joined-at: u0} (map-get? pool-members {property-id: property-id, member: tx-sender})))
        )
        (asserts! (get is-active pool) err-not-authorized)
        (asserts! (> amount u0) err-invalid-contribution)
        
        (map-set pool-members {property-id: property-id, member: tx-sender} {
            contribution: (+ (get contribution current-member) amount),
            joined-at: (if (> (get joined-at current-member) u0) (get joined-at current-member) stacks-block-height)
        })
        
        (map-set insurance-pools property-id
            (merge pool {total-premium: (+ (get total-premium pool) amount)})
        )
        
        (print {event: "premium-contributed", property-id: property-id, member: tx-sender, amount: amount})
        (ok true)
    )
)

(define-public (submit-claim (property-id uint) (amount uint) (reason (string-ascii 200)))
    (let
        (
            (pool (unwrap! (map-get? insurance-pools property-id) err-pool-not-found))
            (member (unwrap! (map-get? pool-members {property-id: property-id, member: tx-sender}) err-not-pool-member))
            (claim-id (+ (default-to u0 (map-get? pool-claim-counter property-id)) u1))
        )
        (asserts! (get is-active pool) err-not-authorized)
        (asserts! (> amount u0) err-invalid-contribution)
        
        (map-set insurance-claims {property-id: property-id, claim-id: claim-id} {
            claimer: tx-sender,
            amount: amount,
            status: "pending",
            submitted-at: stacks-block-height,
            resolved-at: u0,
            reason: reason
        })
        
        (map-set pool-claim-counter property-id claim-id)
        
        (print {event: "claim-submitted", property-id: property-id, claim-id: claim-id, claimer: tx-sender, amount: amount})
        (ok claim-id)
    )
)

(define-public (approve-claim (property-id uint) (claim-id uint))
    (let
        (
            (pool (unwrap! (map-get? insurance-pools property-id) err-pool-not-found))
            (claim (unwrap! (map-get? insurance-claims {property-id: property-id, claim-id: claim-id}) err-claim-not-found))
        )
        (asserts! (is-eq tx-sender (get admin pool)) err-not-pool-admin)
        (asserts! (is-eq (get status claim) "pending") err-claim-already-resolved)
        (asserts! (>= (get total-premium pool) (get amount claim)) err-insufficient-pool-balance)
        
        (map-set insurance-claims {property-id: property-id, claim-id: claim-id}
            (merge claim {
                status: "approved",
                resolved-at: stacks-block-height
            })
        )
        
        (map-set insurance-pools property-id
            (merge pool {
                total-premium: (- (get total-premium pool) (get amount claim)),
                total-claims: (+ (get total-claims pool) (get amount claim))
            })
        )
        
        (print {event: "claim-approved", property-id: property-id, claim-id: claim-id, amount: (get amount claim)})
        (ok true)
    )
)

(define-public (reject-claim (property-id uint) (claim-id uint))
    (let
        (
            (pool (unwrap! (map-get? insurance-pools property-id) err-pool-not-found))
            (claim (unwrap! (map-get? insurance-claims {property-id: property-id, claim-id: claim-id}) err-claim-not-found))
        )
        (asserts! (is-eq tx-sender (get admin pool)) err-not-pool-admin)
        (asserts! (is-eq (get status claim) "pending") err-claim-already-resolved)
        
        (map-set insurance-claims {property-id: property-id, claim-id: claim-id}
            (merge claim {
                status: "rejected",
                resolved-at: stacks-block-height
            })
        )
        
        (print {event: "claim-rejected", property-id: property-id, claim-id: claim-id})
        (ok true)
    )
)

(define-public (withdraw-pool-balance (property-id uint) (amount uint))
    (let
        (
            (pool (unwrap! (map-get? insurance-pools property-id) err-pool-not-found))
        )
        (asserts! (is-eq tx-sender (get admin pool)) err-not-pool-admin)
        (asserts! (> amount u0) err-invalid-contribution)
        (asserts! (>= (get total-premium pool) amount) err-insufficient-pool-balance)
        
        (map-set insurance-pools property-id
            (merge pool {total-premium: (- (get total-premium pool) amount)})
        )
        
        (print {event: "balance-withdrawn", property-id: property-id, amount: amount, admin: tx-sender})
        (ok true)
    )
)

(define-public (deactivate-pool (property-id uint))
    (let
        (
            (pool (unwrap! (map-get? insurance-pools property-id) err-pool-not-found))
        )
        (asserts! (is-eq tx-sender (get admin pool)) err-not-pool-admin)
        
        (map-set insurance-pools property-id
            (merge pool {is-active: false})
        )
        
        (print {event: "pool-deactivated", property-id: property-id})
        (ok true)
    )
)

;; Insurance Pool Read-Only Functions

(define-read-only (get-insurance-pool (property-id uint))
    (map-get? insurance-pools property-id)
)

(define-read-only (get-pool-member (property-id uint) (member principal))
    (map-get? pool-members {property-id: property-id, member: member})
)

(define-read-only (get-insurance-claim (property-id uint) (claim-id uint))
    (map-get? insurance-claims {property-id: property-id, claim-id: claim-id})
)

(define-read-only (get-pool-claims-count (property-id uint))
    (default-to u0 (map-get? pool-claim-counter property-id))
)

(define-read-only (get-member-contribution (property-id uint) (member principal))
    (match (map-get? pool-members {property-id: property-id, member: member})
        member-data (some (get contribution member-data))
        none
    )
)

(define-read-only (get-pool-status (property-id uint))
    (match (map-get? insurance-pools property-id)
        pool-data (some (get is-active pool-data))
        none
    )
)

(define-read-only (get-share-unlock-height (share-id uint))
    (map-get? share-unlock-heights { share-id: share-id })
)

(define-read-only (is-share-locked (share-id uint))
    (match (map-get? share-unlock-heights { share-id: share-id })
        unlock-data (< stacks-block-height (get unlock-height unlock-data))
        false
    )
)

(define-read-only (get-contract-info)
    {
        next-property-id: (var-get next-property-id),
        next-share-id: (var-get next-share-id),
        next-valuation-id: (var-get next-valuation-id),
        contract-owner: contract-owner,
        lock-up-blocks: (var-get lock-up-blocks)
    }
)
