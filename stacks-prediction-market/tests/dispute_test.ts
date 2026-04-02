import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT = 'prediction-market';

function setupResolvedMarket(chain: Chain, deployer: Account, wallet1: Account) {
  const deadline = chain.blockHeight + 150;
  chain.mineBlock([
    Tx.contractCall(CONTRACT, 'create-market', [
      types.utf8("Test market"), types.utf8("desc"),
      types.utf8("YES"), types.utf8("NO"), types.uint(deadline)
    ], deployer.address),
    Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)
  ]);
  chain.mineEmptyBlockUntil(deadline + 1);
  chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
  return deadline;
}

Clarinet.test({
  name: "DISPUTE: User can dispute a resolved market within window",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    setupResolvedMarket(chain, deployer, wallet1);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'dispute-market', [types.uint(1), types.utf8("Wrong outcome")], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "DISPUTE: Cannot dispute unresolved market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'create-market', [
        types.utf8("Test"), types.utf8("desc"), types.utf8("YES"), types.utf8("NO"),
        types.uint(chain.blockHeight + 300)
      ], deployer.address)
    ]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'dispute-market', [types.uint(1), types.utf8("reason")], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(103);
  }
});

Clarinet.test({
  name: "DISPUTE: Admin can resolve dispute with new outcome",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    setupResolvedMarket(chain, deployer, wallet1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'dispute-market', [types.uint(1), types.utf8("Wrong")], wallet1.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-dispute', [types.uint(1), types.uint(1), types.bool(true)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "DISPUTE: Cannot double-dispute",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    setupResolvedMarket(chain, deployer, wallet1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'dispute-market', [types.uint(1), types.utf8("Wrong")], wallet1.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'dispute-market', [types.uint(1), types.utf8("Again")], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(115);
  }
});

Clarinet.test({
  name: "DISPUTE: Non-admin cannot resolve dispute",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    setupResolvedMarket(chain, deployer, wallet1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'dispute-market', [types.uint(1), types.utf8("Wrong")], wallet1.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-dispute', [types.uint(1), types.uint(1), types.bool(true)], wallet2.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(100);
  }
});
