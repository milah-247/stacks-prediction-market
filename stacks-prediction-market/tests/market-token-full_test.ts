import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT = 'market-token';

Clarinet.test({
  name: "TOKEN: get-name returns correct token name",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const result = chain.callReadOnlyFn(CONTRACT, 'get-name', [], deployer.address);
    result.result.expectOk().expectAscii("Stacks Prediction Market");
  }
});

Clarinet.test({
  name: "TOKEN: get-symbol returns SPM",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.callReadOnlyFn(CONTRACT, 'get-symbol', [], deployer.address).result.expectOk().expectAscii("SPM");
  }
});

Clarinet.test({
  name: "TOKEN: Owner can mint tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const bal = chain.callReadOnlyFn(CONTRACT, 'get-balance', [types.principal(wallet1.address)], deployer.address);
    bal.result.expectOk().expectUint(1_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: Non-owner cannot mint",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(300);
  }
});

Clarinet.test({
  name: "TOKEN: Owner can transfer tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'mint', [types.uint(5_000_000), types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'transfer', [
        types.uint(2_000_000), types.principal(wallet1.address), types.principal(wallet2.address), types.none()
      ], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(CONTRACT, 'get-balance', [types.principal(wallet2.address)], deployer.address)
      .result.expectOk().expectUint(2_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: User can burn own tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'mint', [types.uint(3_000_000), types.principal(wallet1.address)], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'burn', [types.uint(1_000_000), types.principal(wallet1.address)], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    chain.callReadOnlyFn(CONTRACT, 'get-balance', [types.principal(wallet1.address)], deployer.address)
      .result.expectOk().expectUint(2_000_000);
  }
});

Clarinet.test({
  name: "TOKEN: Owner can reward participant",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'reward-participant', [types.principal(wallet1.address), types.uint(500_000)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "TOKEN: Owner can toggle minting off",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'toggle-minting', [], deployer.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'mint', [types.uint(1_000_000), types.principal(wallet1.address)], deployer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(300);
  }
});
