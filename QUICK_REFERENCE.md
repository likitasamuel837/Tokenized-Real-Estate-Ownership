# 🚀 Buyback Feature - Quick Reference

## Feature Name
**Automated Revenue-Based Buyback Program**

## One-Line Summary
Property owners maintain liquidity reserves that automatically acquire shares from investors at market prices.

---

## 📋 Functions At A Glance

| Function | Parameters | Returns | Who Calls |
|----------|-----------|---------|-----------|
| `initialize-buyback-pool` | property-id | (ok true) | Property Owner |
| `allocate-to-buyback` | property-id, amount | (ok true) | Property Owner |
| `create-buyback-offer` | property-id, share-id, price, expires | (ok offer-id) | Shareholder |
| `execute-buyback` | offer-id | (ok tx-id) | Property Owner |
| `cancel-buyback-offer` | offer-id | (ok true) | Shareholder |
| `set-buyback-allocation-percentage` | percentage | (ok true) | Contract Owner |

---

## 🔍 Read-Only Functions

| Function | Parameters | Returns |
|----------|-----------|---------|
| `get-buyback-pool` | property-id | {reserve, total-allocated, created-at} \| none |
| `get-buyback-offer` | offer-id | {property-id, seller, share-id, price, expires, is-active} \| none |
| `get-buyback-transaction` | tx-id | {property-id, buyer, seller, share-id, price, executed-at} \| none |
| `get-buyback-allocation-percentage` | — | uint |

---

## ⚡ Typical Flow

```clarity
;; 1. Owner sets up
(initialize-buyback-pool u1)
(allocate-to-buyback u1 u100000)

;; 2. Shareholder sells
(create-buyback-offer u1 u5 u120 u200100)

;; 3. Owner buys
(execute-buyback u1)

;; 4. Verify
(get-buyback-transaction u1)
```

---

## 🔑 Key Data Structures

### buyback-pools
```clarity
{
  reserve: uint,
  total-allocated: uint,
  created-at: uint
}
```

### buyback-offers
```clarity
{
  property-id: uint,
  seller: principal,
  share-id: uint,
  price-per-share: uint,
  expires-at: uint,
  is-active: bool
}
```

### buyback-history
```clarity
{
  property-id: uint,
  buyer: principal,
  seller: principal,
  share-id: uint,
  price: uint,
  executed-at: uint
}
```

---

## 🚨 Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| u120 | err-buyback-pool-exists | Pool already initialized |
| u121 | err-buyback-pool-not-found | Pool doesn't exist |
| u122 | err-offer-not-found | Offer doesn't exist |
| u123 | err-offer-expired | Offer past expiration |
| u124 | err-insufficient-buyback-balance | Not enough reserve funds |
| u125 | err-invalid-offer-price | Price ≤ 0 |
| u126 | err-offer-not-active | Offer was cancelled |
| u127 | err-invalid-allocation-percentage | Percentage not 0-100 |

---

## 📊 State Variables

```clarity
buyback-allocation-percentage :: uint (default 10)
next-offer-id :: uint (starting at 1)
next-buyback-tx-id :: uint (starting at 1)
```

---

## 🛡️ Security Features

- ✅ Ownership verification on all functions
- ✅ Share existence and ownership checks
- ✅ Balance validation before transfers
- ✅ Expiration enforcement
- ✅ Atomic NFT/STX operations
- ✅ Event logging for audit trail

---

## 📈 Benefits

**For Property Owners**
- Efficient capital deployment
- Automatic price support
- Portfolio management control

**For Investors**
- Guaranteed exit liquidity
- Market-driven pricing
- Reduced illiquidity risk

**For Ecosystem**
- Sustainable token economics
- Price stability
- Increased adoption

---

## 🎯 Use Cases

1. **Monthly Revenue Sharing**: Allocate 10% of rental income to buyback
2. **Liquidity Events**: Execute buybacks when investors want to exit
3. **Price Support**: Use reserves to defend floor prices
4. **Portfolio Rebalancing**: Owners can reacquire shares strategically

---

## ✅ Validation Checklist

- ✅ Contract compiles (0 errors)
- ✅ All variables pre-defined
- ✅ LF line endings
- ✅ Backward compatible
- ✅ Tested with clarinet check
- ✅ Event logging enabled
- ✅ Comprehensive error handling

---

## 📚 Full Documentation

- **BUYBACK_FEATURE_GUIDE.md**: Detailed function docs
- **GITHUB_COMMIT_PR.md**: PR details
- **IMPLEMENTATION_SUMMARY.md**: Full implementation overview
- **contracts/TokenEstate.clar**: Source code

---

## 🚀 Deployment

```bash
# Verify compilation
clarinet check

# Deploy to testnet
clarinet deploy --testnet

# Interact via REPL
clarinet console
(initialize-buyback-pool u1)
```

---

## 📞 Quick Help

**Q: How do I start buybacks?**
A: `(initialize-buyback-pool u1)` then `(allocate-to-buyback u1 amount)`

**Q: How do shareholders sell?**
A: `(create-buyback-offer property-id share-id price expires-block)`

**Q: How does owner execute?**
A: `(execute-buyback offer-id)`

**Q: Can shareholders cancel offers?**
A: Yes: `(cancel-buyback-offer offer-id)`

**Q: Can I adjust allocation percentage?**
A: Yes: `(set-buyback-allocation-percentage new-percentage)`

---

## 🎉 Status

**✅ READY FOR DEPLOYMENT**

All code validated, documented, and production-ready.
