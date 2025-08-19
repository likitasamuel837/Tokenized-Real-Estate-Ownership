# 🏠 TokenEstate - Fractional Real Estate Ownership

Transform real estate investment through blockchain technology! TokenEstate enables property owners to fractionalize their real estate into NFT shares, making property investment more accessible and liquid.

## 🚀 Features

- **🏘️ Property Registration** - Register real estate properties on-chain
- **🔄 Fractional Ownership** - Split properties into tradeable NFT shares
- **💰 Rental Income Distribution** - Automatically distribute rental income to shareholders
- **📈 Share Trading** - Buy and sell property shares with transparent pricing
- **👥 Multi-Owner Management** - Track multiple shareholders per property
- **🔒 Secure Ownership** - Blockchain-verified ownership and transfers

## 📋 Contract Overview

The TokenEstate smart contract manages:

- **Properties**: Real estate assets with value, address, and share allocation
- **Shares**: NFT tokens representing fractional ownership percentages
- **Income Distribution**: Automated rental income splitting among shareholders
- **Trading**: Peer-to-peer share transfers with transparent pricing

## 🔧 Core Functions

### Property Management

```clarity
;; Register a new property
(register-property "123 Main St" u1000000 u100)

;; Update property status
(update-property-status u1 false)
```

### Share Operations

```clarity
;; Mint shares for a property (10% share at 100 STX)
(mint-share u1 u1000 u100)

;; Transfer share to another user
(transfer-share u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u150)

;; Buy an available share
(buy-share u1)

;; Update share price
(update-share-price u1 u200)
```

### Rental Income

```clarity
;; Distribute rental income (property owner only)
(distribute-rental-income u1 u10000)

;; Claim your share of distributed income
(claim-rental-income u1 u1 u1)
```

## 📊 Data Structures

### Property
- `address`: Physical address (string)
- `value`: Property valuation in microSTX
- `total-shares`: Maximum shares (10000 = 100%)
- `shares-issued`: Currently issued shares
- `owner`: Property owner principal
- `rental-income`: Total rental income received
- `created-at`: Registration block height
- `is-active`: Property status

### Share
- `property-id`: Associated property ID
- `owner`: Current share owner
- `share-percentage`: Ownership percentage (1-10000)
- `purchase-price`: Current price in STX
- `created-at`: Creation block height

## 🔍 Read-Only Functions

```clarity
;; Get property details
(get-property u1)

;; Get share information
(get-share u1)

;; Get user's properties
(get-owner-properties 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)

;; Get user's shares
(get-owner-shares 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)

;; Get rental distribution details
(get-rental-distribution u1 u1)

;; Get contract information
(get-contract-info)
```

## 🎯 Usage Examples

### 1. Property Owner Workflow

```clarity
;; 1. Register your property
(register-property "456 Oak Avenue" u2000000 u100)

;; 2. Create shares (25% at 500 STX each)
(mint-share u1 u2500 u500)
(mint-share u1 u2500 u500)

;; 3. Distribute monthly rental income
(distribute-rental-income u1 u50000)
```

### 2. Investor Workflow

```clarity
;; 1. Buy available shares
(buy-share u1)
(buy-share u2)

;; 2. Claim your rental income
(claim-rental-income u1 u1 u1)

;; 3. Trade shares
(update-share-price u1 u600)
(transfer-share u1 'SP3BUYER u600)
```

## ⚡ Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Stacks wallet for testing

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Tokenized-Real-Estate-Ownership
   ```

2. **Check contract syntax**
   ```bash
   clarinet check
   ```

3. **Run tests**
   ```bash
   npm install
   npm test
   ```

4. **Deploy to testnet**
   ```bash
   clarinet deploy --testnet
   ```

## 📝 Testing

The contract includes comprehensive error handling:

- `u100`: Not authorized
- `u101`: Property not found
- `u102`: Share not found
- `u103`: Insufficient funds
- `u104`: Invalid share count
- `u105`: Property already exists
- `u106`: Invalid percentage (must be 1-10000)

## 🔐 Security Features

- **Ownership Verification**: All functions verify caller permissions
- **Share Validation**: Prevents over-issuance of shares
- **Input Sanitization**: Validates all user inputs
- **Safe Math**: Uses built-in overflow protection
- **Transfer Safety**: Atomic operations for share transfers

## 🌟 Benefits

- **🚪 Lower Entry Barriers**: Invest in real estate with smaller amounts
- **💧 Improved Liquidity**: Trade property shares anytime
- **📊 Transparent Ownership**: All transactions recorded on-chain
- **⚡ Automated Distributions**: Smart contract handles rental income
- **🌍 Global Access**: Invest in properties worldwide
- **🔄 Portfolio Diversification**: Own fractions of multiple properties

## 🚧 Future Enhancements

- Property management voting system
- Integration with external oracles for property valuations
- Multi-currency support for international properties
- Property maintenance fee distribution
- Insurance and legal compliance modules

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines and submit pull requests.

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always conduct thorough testing before deploying to mainnet.
