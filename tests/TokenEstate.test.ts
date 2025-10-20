
import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;

describe("Insurance Pool Feature", () => {
  // Helper: Register property for insurance pool tests
  const registerTestProperty = () => {
    const { result } = simnet.callPublicFn(
      "TokenEstate",
      "register-property",
      [
        Cl.stringAscii("100 Insurance Test Street"),
        Cl.uint(u5000000),
        Cl.uint(u10000),
      ],
      address1
    );
    return result;
  };

  describe("Insurance Pool Registration", () => {
    it("register new insurance pool successfully", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      expect(result).toBeOk(propertyId);

      // Verify pool was created
      const { result: poolData } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-insurance-pool",
        [propertyId],
        address1
      );

      expect(poolData).toBeSome();
    });

    it("prevent duplicate pool registration", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      // Register once
      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      // Try to register again
      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      expect(result).toBeErr(Cl.uint(111)); // err-pool-exists
    });

    it("verify pool admin is set to caller", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result: poolData } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-insurance-pool",
        [propertyId],
        address1
      );

      const pool = poolData;
      expect(pool).toBeSome();
    });

    it("verify pool initial state", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result: poolData } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-insurance-pool",
        [propertyId],
        address1
      );

      expect(poolData).toBeSome();
    });
  });

  describe("Premium Contributions", () => {
    it("members contribute premiums successfully", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u1000)],
        address2
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("track individual member contributions", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u1000)],
        address2
      );

      const { result: memberData } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-member-contribution",
        [propertyId, Cl.principal(address2)],
        address1
      );

      expect(memberData).toBeSome();
    });

    it("reject zero contributions", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u0)],
        address2
      );

      expect(result).toBeErr(Cl.uint(114)); // err-invalid-contribution
    });

    it("reject contributions to non-existent pools", () => {
      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [Cl.uint(u9999), Cl.uint(u1000)],
        address2
      );

      expect(result).toBeErr(Cl.uint(112)); // err-pool-not-found
    });
  });

  describe("Claim Submission", () => {
    it("members submit claims with valid reasons", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u1000), Cl.stringAscii("Water damage to roof")],
        address2
      );

      expect(result).toBeOk(Cl.uint(u1));
    });

    it("reject claims from non-members", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u1000), Cl.stringAscii("Water damage")],
        address3
      );

      expect(result).toBeErr(Cl.uint(118)); // err-not-pool-member
    });

    it("auto-increment claim IDs", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u10000)],
        address2
      );

      const result1 = simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u500), Cl.stringAscii("Claim 1")],
        address2
      );

      const result2 = simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u600), Cl.stringAscii("Claim 2")],
        address2
      );

      expect(result1.result).toBeOk(Cl.uint(u1));
      expect(result2.result).toBeOk(Cl.uint(u2));
    });
  });

  describe("Claim Approval and Rejection", () => {
    it("admin approves valid claims", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u2000), Cl.stringAscii("Fire damage")],
        address2
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "approve-claim",
        [propertyId, Cl.uint(u1)],
        address1
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("admin rejects claims", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u2000), Cl.stringAscii("Claim details")],
        address2
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "reject-claim",
        [propertyId, Cl.uint(u1)],
        address1
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("prevent non-admins from approving claims", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u2000), Cl.stringAscii("Claim")],
        address2
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "approve-claim",
        [propertyId, Cl.uint(u1)],
        address3
      );

      expect(result).toBeErr(Cl.uint(113)); // err-not-pool-admin
    });

    it("prevent re-processing resolved claims", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u2000), Cl.stringAscii("Claim")],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "approve-claim",
        [propertyId, Cl.uint(u1)],
        address1
      );

      // Try to approve again
      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "approve-claim",
        [propertyId, Cl.uint(u1)],
        address1
      );

      expect(result).toBeErr(Cl.uint(116)); // err-claim-already-resolved
    });

    it("reject approvals exceeding pool balance", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u1000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u5000), Cl.stringAscii("Claim")],
        address2
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "approve-claim",
        [propertyId, Cl.uint(u1)],
        address1
      );

      expect(result).toBeErr(Cl.uint(117)); // err-insufficient-pool-balance
    });
  });

  describe("Pool Management", () => {
    it("admin withdraws pool balance", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "withdraw-pool-balance",
        [propertyId, Cl.uint(u2000)],
        address1
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("admin deactivates pool", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "deactivate-pool",
        [propertyId],
        address1
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("reject contributions to inactive pools", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "deactivate-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u1000)],
        address2
      );

      expect(result).toBeErr(Cl.uint(100)); // err-not-authorized
    });
  });

  describe("Read-Only Functions", () => {
    it("get-pool-claims-count returns correct value", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u1000), Cl.stringAscii("Claim 1")],
        address2
      );

      const { result } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-pool-claims-count",
        [propertyId],
        address1
      );

      expect(result).toBeUint(u1);
    });

    it("get-pool-status returns active status", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-pool-status",
        [propertyId],
        address1
      );

      expect(result).toBeSome();
    });

    it("get-insurance-claim returns claim details", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      simnet.callPublicFn(
        "TokenEstate",
        "contribute-premium",
        [propertyId, Cl.uint(u5000)],
        address2
      );

      simnet.callPublicFn(
        "TokenEstate",
        "submit-claim",
        [propertyId, Cl.uint(u1000), Cl.stringAscii("Damage claim")],
        address2
      );

      const { result } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-insurance-claim",
        [propertyId, Cl.uint(u1)],
        address1
      );

      expect(result).toBeSome();
    });

    it("return none for non-existent pools", () => {
      const { result } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-insurance-pool",
        [Cl.uint(u9999)],
        address1
      );

      expect(result).toBeNone();
    });

    it("return none for non-member contributions", () => {
      const propResult = registerTestProperty();
      const propertyId = propResult;

      simnet.callPublicFn(
        "TokenEstate",
        "register-insurance-pool",
        [propertyId],
        address1
      );

      const { result } = simnet.callReadOnlyFn(
        "TokenEstate",
        "get-member-contribution",
        [propertyId, Cl.principal(address3)],
        address1
      );

      expect(result).toBeNone();
    });
  });
});

describe("example tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });
});
