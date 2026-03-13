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
