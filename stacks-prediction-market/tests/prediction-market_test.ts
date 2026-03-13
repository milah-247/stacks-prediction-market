import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const CONTRACT = 'prediction-market';
const MARKET_TITLE = types.utf8("Will BTC reach $100k by EOY?");
const MARKET_DESC = types.utf8("Bitcoin price prediction market");
const OUTCOME_A = types.utf8("YES");
const OUTCOME_B = types.utf8("NO");

function createMarket(chain: Chain, deployer: Account, deadline?: number) {
  const dl = deadline ?? chain.blockHeight + 300;
  return chain.mineBlock([
    Tx.contractCall(CONTRACT, 'create-market', [
      MARKET_TITLE, MARKET_DESC, OUTCOME_A, OUTCOME_B, types.uint(dl)
    ], deployer.address)
  ]);
}

Clarinet.test({
  name: "CREATION: Should create a YES/NO market successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = createMarket(chain, deployer);
    assertEquals(block.receipts[0].result, '(ok u1)');
    const market = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address);
    const data = market.result.expectSome().expectTuple();
    assertEquals(data['resolved'], 'false');
    assertEquals(data['outcome-count'], 'u2');
    assertEquals(data['total-pool'], 'u0');
  }
});

Clarinet.test({
  name: "CREATION: Should create a multi-outcome (3-way) market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'create-market-multi', [
        types.utf8("Who will win?"), types.utf8("Election market"),
        types.utf8("Candidate A"), types.utf8("Candidate B"), types.utf8("Other"),
        types.uint(chain.blockHeight + 300)
      ], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok u1)');
    const market = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address);
    assertEquals(market.result.expectSome().expectTuple()['outcome-count'], 'u3');
  }
});

Clarinet.test({
  name: "CREATION: Should increment market IDs sequentially",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u1)');
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u2)');
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u3)');
    chain.callReadOnlyFn(CONTRACT, 'get-market-count', [], deployer.address).result.expectUint(3);
  }
});

Clarinet.test({
  name: "CREATION: Should fail with empty title",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'create-market', [
        types.utf8(""), MARKET_DESC, OUTCOME_A, OUTCOME_B, types.uint(chain.blockHeight + 300)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(117);
  }
});

Clarinet.test({
  name: "CREATION: Should fail if deadline is too soon",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    createMarket(chain, deployer, chain.blockHeight + 50).receipts[0].result.expectErr().expectUint(112);
  }
});

Clarinet.test({
  name: "BETTING: Should place a bet on YES outcome",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(1_000_000)], wallet1.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    assertEquals(block.receipts[0].events[0].type, 'stx_transfer_event');
  }
});

Clarinet.test({
  name: "BETTING: Should update outcome pool after bet",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(2_000_000)], wallet1.address)
    ]);
    const market = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address);
    market.result.expectSome().expectTuple()['total-pool'].expectUint(2_000_000);
  }
});

Clarinet.test({
  name: "BETTING: Should reject zero-value bets",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(0)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(106);
  }
});

Clarinet.test({
  name: "BETTING: Should reject invalid market ID",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(999), types.uint(0), types.uint(1_000_000)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(101);
  }
});

Clarinet.test({
  name: "BETTING: Should reject invalid outcome index",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(5), types.uint(1_000_000)], wallet1.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(105);
  }
});

Clarinet.test({
  name: "RESOLUTION: Admin can resolve market after deadline",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineEmptyBlockUntil(deadline + 1);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const data = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address).result.expectSome().expectTuple();
    assertEquals(data['resolved'], 'true');
    data['winning-outcome'].expectUint(0);
  }
});

Clarinet.test({
  name: "RESOLUTION: Cannot resolve before deadline",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    createMarket(chain, deployer);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(102);
  }
});

Clarinet.test({
  name: "RESOLUTION: Cannot resolve already resolved market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(1)], deployer.address)]);
    block.receipts[0].result.expectErr().expectUint(104);
  }
});

Clarinet.test({
  name: "RESOLUTION: Non-authorized user cannot resolve",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet2 = accounts.get('wallet_2')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineEmptyBlockUntil(deadline + 1);
    const block = chain.mineBlock([
      Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], wallet2.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(100);
  }
});

Clarinet.test({
  name: "PAYOUT: Winner can claim proportional winnings",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(10_000_000)], wallet1.address),
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(1), types.uint(5_000_000)], wallet2.address)
    ]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    assertEquals(block.receipts[0].result.indexOf('ok'), 0);
    assertEquals(block.receipts[0].events[0].type, 'stx_transfer_event');
  }
});

Clarinet.test({
  name: "PAYOUT: Prevents double claiming",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(108);
  }
});

Clarinet.test({
  name: "PAYOUT: Cannot claim before market resolved",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'claim-winnings', [types.uint(1)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(103);
  }
});

Clarinet.test({
  name: "WITHDRAWAL: User can withdraw early with fee",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 300;
    createMarket(chain, deployer, deadline);
    const betAmount = 10_000_000;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(betAmount)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    const expected = betAmount - Math.floor(betAmount * 500 / 10000);
    assertEquals(block.receipts[0].result, `(ok u${expected})`);
  }
});

Clarinet.test({
  name: "WITHDRAWAL: Cannot withdraw after market resolved",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(104);
  }
});

Clarinet.test({
  name: "WITHDRAWAL: Cannot double-withdraw",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    createMarket(chain, deployer);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(5_000_000)], wallet1.address)]);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'early-withdraw', [types.uint(1), types.uint(0)], wallet1.address)]);
    block.receipts[0].result.expectErr().expectUint(108);
  }
});

Clarinet.test({
  name: "ADMIN: Can set oracle principal",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'set-oracle', [types.principal(wallet1.address)], deployer.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "ORACLE: Oracle can resolve market at any time",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'set-oracle', [types.principal(wallet1.address)], deployer.address)]);
    createMarket(chain, deployer);
    const block = chain.mineBlock([Tx.contractCall(CONTRACT, 'oracle-resolve-market', [types.uint(1), types.uint(1)], wallet1.address)]);
    assertEquals(block.receipts[0].result, '(ok true)');
    const data = chain.callReadOnlyFn(CONTRACT, 'get-market', [types.uint(1)], deployer.address).result.expectSome().expectTuple();
    assertEquals(data['resolved'], 'true');
    assertEquals(data['oracle-resolved'], 'true');
  }
});

Clarinet.test({
  name: "ADMIN: Can pause and unpause contract",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    chain.mineBlock([Tx.contractCall(CONTRACT, 'toggle-pause', [], deployer.address)]);
    createMarket(chain, deployer).receipts[0].result.expectErr().expectUint(100);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'toggle-pause', [], deployer.address)]);
    assertEquals(createMarket(chain, deployer).receipts[0].result, '(ok u1)');
  }
});

Clarinet.test({
  name: "CALC: Calculate winnings returns correct amount",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const deadline = chain.blockHeight + 150;
    createMarket(chain, deployer, deadline);
    chain.mineBlock([
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(0), types.uint(10_000_000)], wallet1.address),
      Tx.contractCall(CONTRACT, 'place-bet', [types.uint(1), types.uint(1), types.uint(10_000_000)], wallet2.address)
    ]);
    chain.mineEmptyBlockUntil(deadline + 1);
    chain.mineBlock([Tx.contractCall(CONTRACT, 'resolve-market', [types.uint(1), types.uint(0)], deployer.address)]);
    const calc = chain.callReadOnlyFn(CONTRACT, 'calculate-winnings', [types.uint(1), types.principal(wallet1.address)], deployer.address);
    calc.result.expectOk().expectUint(19_600_000);
  }
});
