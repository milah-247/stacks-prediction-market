import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT = 'referral';

Clarinet.test({
  name: "REFERRAL: User can register a referral",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'register-referral', [types.principal(wallet1.address)], wallet2.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "REFERRAL: Cannot self-refer",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'register-referral', [types.principal(wallet1.address)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(402);
  }
});

Clarinet.test({
  name: "REFERRAL: Cannot register twice",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'register-referral', [types.principal(wallet1.address)], wallet2.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'register-referral', [types.principal(wallet1.address)], wallet2.address)]);
    block.receipts[0].result.expectErr().expectUint(401);
  }
});

Clarinet.test({
  name: "REFERRAL: get-referrer returns correct data",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'register-referral', [types.principal(wallet1.address)], wallet2.address)]);
    const ref = chain.callReadOnlyFn(CONTRACT, 'get-referrer', [types.principal(wallet2.address)], wallet1.address);
    ref.result.expectSome();
  }
});
