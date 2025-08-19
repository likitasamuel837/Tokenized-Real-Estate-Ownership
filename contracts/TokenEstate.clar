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

(define-data-var next-property-id uint u1)
(define-data-var next-share-id uint u1)

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

(define-read-only (get-contract-info)
    {
        next-property-id: (var-get next-property-id),
        next-share-id: (var-get next-share-id),
        contract-owner: contract-owner
    }
)
