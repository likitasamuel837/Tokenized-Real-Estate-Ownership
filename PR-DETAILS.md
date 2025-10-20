# Owner Lock-up Period

## Overview
Implements a lock-up mechanism that prevents share transfers for a configurable period (default: 100 blocks) after purchase. This feature restricts immediate share trading following acquisition, promoting long-term holding and reducing speculative trading.

## Technical Implementation

### New Data Structures
- **Error Constant**: `err-locked-up (err u119)` - Returned when attempting to transfer locked shares
- **Data Variable**: `lock-up-blocks` - Configurable lock-up period (default: u100)
- **Map**: `share-unlock-heights` - Tracks unlock block height for each share

### Modified Functions
1. **mint-share**: Sets initial unlock height = current block + lock-up-blocks
2. **transfer-share**: Validates current block >= unlock height before allowing transfer
3. **buy-share**: Resets unlock height for new owner upon purchase

### New Read-Only Functions
- **get-share-unlock-height(share-id)**: Returns the block height when share becomes transferable
- **is-share-locked(share-id)**: Returns boolean indicating current lock-up status

## Testing & Validation
- ✅ Contract passes `clarinet check` with no syntax errors
- ✅ Clarity v3 compliant with proper type safety
- ✅ Comprehensive error handling with new error constant
- ✅ CI/CD pipeline configured with GitHub Actions
- ✅ Line endings normalized (CRLF → LF)
- ✅ Independent feature with no cross-contract dependencies

## Security Considerations
- Lock-up constraint enforced at transfer level (cannot be bypassed)
- Read-only functions provide transparency for lock-up status
- Configurable lock-up period allows future adjustments via governance

## Future Enhancements
- Admin function to update lock-up-blocks value
- Per-share custom lock-up periods
- Event emissions for lock-up status changes
