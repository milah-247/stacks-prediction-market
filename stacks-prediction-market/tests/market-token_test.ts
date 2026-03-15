import { describe, it, expect } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

const simnet = await initSimnet();
const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const TOKEN = "market-token";

describe("SPM Token", () => {
  it("owner can mint tokens", () => {
    const { result } = simnet.callPublicFn(TOKEN, "mint", [
      Cl.uint(1_000_000), Cl.principal(wallet1),
    ], deployer);
    expect(result).toBeOk(Cl.bool(true));
  });

  it("non-owner cannot mint", () => {
    const { result } = simnet.callPublicFn(TOKEN, "mint", [
      Cl.uint(1_000_000), Cl.principal(wallet1),
    ], wallet1);
    expect(result).toBeErr(Cl.uint(300));
  });

  it("transfer works correctly", () => {
    simnet.callPublicFn(TOKEN, "mint", [Cl.uint(5_000_000), Cl.principal(wallet1)], deployer);
    const { result } = simnet.callPublicFn(TOKEN, "transfer", [
      Cl.uint(2_000_000), Cl.principal(wallet1), Cl.principal(wallet2), Cl.none(),
    ], wallet1);
    expect(result).toBeOk(Cl.bool(true));
  });

  it("owner can burn tokens", () => {
    simnet.callPublicFn(TOKEN, "mint", [Cl.uint(5_000_000), Cl.principal(wallet1)], deployer);
    const { result } = simnet.callPublicFn(TOKEN, "burn", [
      Cl.uint(2_000_000), Cl.principal(wallet1),
    ], wallet1);
    expect(result).toBeOk(Cl.bool(true));
  });
});
