import { describe, it, expect } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

const simnet = await initSimnet();
const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const ORACLE = "oracle";
const FEED_ID = "btc-usd-price";

describe("Oracle", () => {
  it("owner can create data feed", () => {
    const { result } = simnet.callPublicFn(ORACLE, "create-feed", [
      Cl.stringAscii(FEED_ID), Cl.stringUtf8("BTC/USD price feed"),
    ], deployer);
    expect(result).toBeOk(Cl.bool(true));
  });

  it("cannot create duplicate feed", () => {
    simnet.callPublicFn(ORACLE, "create-feed", [Cl.stringAscii(FEED_ID), Cl.stringUtf8("BTC")], deployer);
    const { result } = simnet.callPublicFn(ORACLE, "create-feed", [Cl.stringAscii(FEED_ID), Cl.stringUtf8("dup")], deployer);
    expect(result).toBeErr(Cl.uint(202));
  });

  it("owner can update feed value", () => {
    simnet.callPublicFn(ORACLE, "create-feed", [Cl.stringAscii(FEED_ID), Cl.stringUtf8("BTC")], deployer);
    const { result } = simnet.callPublicFn(ORACLE, "update-feed", [
      Cl.stringAscii(FEED_ID), Cl.stringUtf8("100000"),
    ], deployer);
    expect(result).toBeOk(Cl.bool(true));
  });

  it("authorized operator can update feed", () => {
    simnet.callPublicFn(ORACLE, "create-feed", [Cl.stringAscii(FEED_ID), Cl.stringUtf8("BTC")], deployer);
    simnet.callPublicFn(ORACLE, "add-operator", [Cl.principal(wallet1)], deployer);
    const { result } = simnet.callPublicFn(ORACLE, "update-feed", [
      Cl.stringAscii(FEED_ID), Cl.stringUtf8("95000"),
    ], wallet1);
    expect(result).toBeOk(Cl.bool(true));
  });

  it("non-operator cannot update feed", () => {
    simnet.callPublicFn(ORACLE, "create-feed", [Cl.stringAscii(FEED_ID), Cl.stringUtf8("BTC")], deployer);
    const { result } = simnet.callPublicFn(ORACLE, "update-feed", [
      Cl.stringAscii(FEED_ID), Cl.stringUtf8("hack"),
    ], wallet2);
    expect(result).toBeErr(Cl.uint(200));
  });

  it("can link market to feed", () => {
    simnet.callPublicFn(ORACLE, "create-feed", [Cl.stringAscii(FEED_ID), Cl.stringUtf8("BTC")], deployer);
    const { result } = simnet.callPublicFn(ORACLE, "link-market-to-feed", [
      Cl.uint(1), Cl.stringAscii(FEED_ID), Cl.stringUtf8('{"YES":">100000"}'),
    ], deployer);
    expect(result).toBeOk(Cl.bool(true));
  });
});
