import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const TOKEN = 'market-token';

Clarinet.test({
  name: "TOKEN: Owner can mint SPM tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(TOKEN, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(TOKEN, 'get-balance', [types.principal(wallet1.address)], deployer.address).result.expectOk().expectUint(1_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: Non-owner cannot mint",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(TOKEN, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(300);
  }
});

Clarinet.test({
  name: "TOKEN: Transfer works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(TOKEN, 'mint', [types.uint(5_000_000), types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(TOKEN, 'transfer', [types.uint(2_000_000), types.principal(wallet1.address), types.principal(wallet2.address), types.none()], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(TOKEN, 'get-balance', [types.principal(wallet2.address)], deployer.address).result.expectOk().expectUint(2_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: SIP-010 metadata is correct",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.callReadOnlyFn(TOKEN, 'get-name', [], deployer.address).result.expectOk().expectAscii("Stacks Prediction Market");
    chain.callReadOnlyFn(TOKEN, 'get-symbol', [], deployer.address).result.expectOk().expectAscii("SPM");
    chain.callReadOnlyFn(TOKEN, 'get-decimals', [], deployer.address).result.expectOk().expectUint(6);
  }
});

Clarinet.test({
  name: "TOKEN: Owner can burn tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(TOKEN, 'mint', [types.uint(5_000_000), types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(TOKEN, 'burn', [types.uint(2_000_000), types.principal(wallet1.address)], wallet1.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(TOKEN, 'get-balance', [types.principal(wallet1.address)], deployer.address).result.expectOk().expectUint(3_000_000);
  }
});
