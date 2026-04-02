import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT = 'oracle';

Clarinet.test({
  name: "ORACLE: Owner can add an operator",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'add-operator', [types.principal(wallet1.address)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const isOp = chain.callReadOnlyFn(CONTRACT, 'is-operator', [types.principal(wallet1.address)], deployer.address);
    assertEquals(isOp.result, 'true');
  }
});

Clarinet.test({
  name: "ORACLE: Cannot add duplicate operator",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'add-operator', [types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'add-operator', [types.principal(wallet1.address)], deployer.address)]);
    block.receipts[0].result.expectErr().expectUint(205);
  }
});

Clarinet.test({
  name: "ORACLE: Owner can create a feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'create-feed', [
        types.ascii("BTC-USD"), types.utf8("Bitcoin USD price feed")
      ], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const feed = chain.callReadOnlyFn(CONTRACT, 'get-feed', [types.ascii("BTC-USD")], deployer.address);
    feed.result.expectSome();
  }
});

Clarinet.test({
  name: "ORACLE: Cannot create duplicate feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'create-feed', [types.ascii("BTC-USD"), types.utf8("desc")], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'create-feed', [types.ascii("BTC-USD"), types.utf8("desc2")], deployer.address)]);
    block.receipts[0].result.expectErr().expectUint(202);
  }
});

Clarinet.test({
  name: "ORACLE: Operator can update feed value",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'add-operator', [types.principal(wallet1.address)], deployer.address),
      Tx.contractCall(CONTRACT, 'create-feed', [types.ascii("BTC-USD"), types.utf8("BTC price")], deployer.address)
    ]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'update-feed', [types.ascii("BTC-USD"), types.utf8("65000")], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const val = chain.callReadOnlyFn(CONTRACT, 'get-feed-value', [types.ascii("BTC-USD")], deployer.address);
    val.result.expectOk().expectUtf8("65000");
  }
});

Clarinet.test({
  name: "ORACLE: Non-operator cannot update feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'create-feed', [types.ascii("ETH-USD"), types.utf8("ETH price")], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'update-feed', [types.ascii("ETH-USD"), types.utf8("3000")], wallet2.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(200);
  }
});

Clarinet.test({
  name: "ORACLE: Owner can link market to feed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'create-feed', [types.ascii("BTC-USD"), types.utf8("BTC price")], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'link-market-to-feed', [
        types.uint(1), types.ascii("BTC-USD"), types.utf8("above-100k:0,below-100k:1")
      ], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const mf = chain.callReadOnlyFn(CONTRACT, 'get-market-feed', [types.uint(1)], deployer.address);
    mf.result.expectSome();
  }
});

Clarinet.test({
  name: "ORACLE: Owner can remove operator",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'add-operator', [types.principal(wallet1.address)], deployer.address)]);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'remove-operator', [types.principal(wallet1.address)], deployer.address)]);
    const isOp = chain.callReadOnlyFn(CONTRACT, 'is-operator', [types.principal(wallet1.address)], deployer.address);
    assertEquals(isOp.result, 'false');
  }
});
