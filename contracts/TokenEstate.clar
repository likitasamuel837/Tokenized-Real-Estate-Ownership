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
(define-constant err-buyback-pool-exists (err u120))
(define-constant err-buyback-pool-not-found (err u121))
(define-constant err-offer-not-found (err u122))
(define-constant err-offer-expired (err u123))
(define-constant err-insufficient-buyback-balance (err u124))
(define-constant err-invalid-offer-price (err u125))
(define-constant err-offer-not-active (err u126))
(define-constant err-invalid-allocation-percentage (err u127))

(define-data-var next-property-id uint u1)
(define-data-var next-share-id uint u1)
(define-data-var next-valuation-id uint u1)
(define-data-var buyback-allocation-percentage uint u10)
(define-data-var next-offer-id uint u1)
(define-data-var next-buyback-tx-id uint u1)

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

(define-map buyback-pools
    uint
    {
        reserve: uint,
        total-allocated: uint,
        created-at: uint
    }
)

(define-map buyback-offers
    uint
    {
        property-id: uint,
        seller: principal,
        share-id: uint,
        price-per-share: uint,
        expires-at: uint,
        is-active: bool
    }
)

(define-map buyback-history
    uint
    {
        property-id: uint,
        buyer: principal,
        seller: principal,
        share-id: uint,
        price: uint,
        executed-at: uint
    }
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
        
        (var-set next-share-id (+ share-id u1))
        (ok share-id)
    )
)

(define-public (transfer-share (share-id uint) (recipient principal) (price uint))
    (let 
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
        )
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

(define-read-only (get-contract-info)
    {
        next-property-id: (var-get next-property-id),
        next-share-id: (var-get next-share-id),
        next-valuation-id: (var-get next-valuation-id),
        contract-owner: contract-owner
    }
)

;; Buyback Feature Functions

(define-public (initialize-buyback-pool (property-id uint))
    (let
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
        )
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        (asserts! (is-none (map-get? buyback-pools property-id)) err-buyback-pool-exists)
        
        (map-set buyback-pools property-id {
            reserve: u0,
            total-allocated: u0,
            created-at: stacks-block-height
        })
        
        (print {event: "buyback-pool-initialized", property-id: property-id, owner: tx-sender})
        (ok true)
    )
)

(define-public (allocate-to-buyback (property-id uint) (amount uint))
    (let
        (
            (property (unwrap! (map-get? properties property-id) err-property-not-found))
            (pool (unwrap! (map-get? buyback-pools property-id) err-buyback-pool-not-found))
        )
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        (asserts! (> amount u0) err-insufficient-funds)
        
        (map-set buyback-pools property-id
            (merge pool {reserve: (+ (get reserve pool) amount), total-allocated: (+ (get total-allocated pool) amount)})
        )
        
        (print {event: "allocation-to-buyback", property-id: property-id, amount: amount})
        (ok true)
    )
)

(define-public (create-buyback-offer (property-id uint) (share-id uint) (price-per-share uint) (expires-at uint))
    (let
        (
            (share (unwrap! (map-get? property-shares share-id) err-share-not-found))
            (offer-id (var-get next-offer-id))
        )
        (asserts! (is-eq tx-sender (get owner share)) err-not-authorized)
        (asserts! (is-eq (get property-id share) property-id) err-property-not-found)
        (asserts! (> price-per-share u0) err-invalid-offer-price)
        (asserts! (> expires-at stacks-block-height) err-offer-expired)
        
        (map-set buyback-offers offer-id {
            property-id: property-id,
            seller: tx-sender,
            share-id: share-id,
            price-per-share: price-per-share,
            expires-at: expires-at,
            is-active: true
        })
        
        (var-set next-offer-id (+ offer-id u1))
        
        (print {event: "buyback-offer-created", offer-id: offer-id, property-id: property-id, seller: tx-sender, price: price-per-share})
        (ok offer-id)
    )
)

(define-public (execute-buyback (offer-id uint))
    (let
        (
            (offer (unwrap! (map-get? buyback-offers offer-id) err-offer-not-found))
            (pool (unwrap! (map-get? buyback-pools (get property-id offer)) err-buyback-pool-not-found))
            (share (unwrap! (map-get? property-shares (get share-id offer)) err-share-not-found))
            (total-cost (get price-per-share offer))
            (tx-id (var-get next-buyback-tx-id))
            (property (unwrap! (map-get? properties (get property-id offer)) err-property-not-found))
        )
        (asserts! (is-eq tx-sender (get owner property)) err-not-authorized)
        (asserts! (get is-active offer) err-offer-not-active)
        (asserts! (< stacks-block-height (get expires-at offer)) err-offer-expired)
        (asserts! (>= (get reserve pool) total-cost) err-insufficient-buyback-balance)
        
        (map-set buyback-offers offer-id (merge offer {is-active: false}))
        
        (map-set buyback-pools (get property-id offer)
            (merge pool {reserve: (- (get reserve pool) total-cost)})
        )
        
        (try! (nft-transfer? property-share (get share-id offer) (get seller offer) tx-sender))
        
        (try! (as-contract (stx-transfer? total-cost (get seller offer) tx-sender)))
        
        (map-set buyback-history tx-id {
            property-id: (get property-id offer),
            buyer: tx-sender,
            seller: (get seller offer),
            share-id: (get share-id offer),
            price: total-cost,
            executed-at: stacks-block-height
        })
        
        (var-set next-buyback-tx-id (+ tx-id u1))
        
        (print {event: "buyback-executed", offer-id: offer-id, property-id: (get property-id offer), tx-id: tx-id})
        (ok tx-id)
    )
)

(define-public (cancel-buyback-offer (offer-id uint))
    (let
        (
            (offer (unwrap! (map-get? buyback-offers offer-id) err-offer-not-found))
        )
        (asserts! (is-eq tx-sender (get seller offer)) err-not-authorized)
        (asserts! (get is-active offer) err-offer-not-active)
        
        (map-set buyback-offers offer-id (merge offer {is-active: false}))
        
        (print {event: "buyback-offer-cancelled", offer-id: offer-id})
        (ok true)
    )
)

(define-public (set-buyback-allocation-percentage (percentage uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (and (>= percentage u0) (<= percentage u100)) err-invalid-allocation-percentage)
        
        (var-set buyback-allocation-percentage percentage)
        
        (print {event: "allocation-percentage-updated", percentage: percentage})
        (ok true)
    )
)

(define-read-only (get-buyback-pool (property-id uint))
    (map-get? buyback-pools property-id)
)

(define-read-only (get-buyback-offer (offer-id uint))
    (map-get? buyback-offers offer-id)
)

(define-read-only (get-buyback-transaction (tx-id uint))
    (map-get? buyback-history tx-id)
)

(define-read-only (get-buyback-allocation-percentage)
    (var-get buyback-allocation-percentage)
)
