import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.7.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

const STAKING = 'spm-staking';
const TOKEN = 'market-token';
const STAKE_AMOUNT = types.uint(1_000_000); // 1 SPM

function mintTokens(chain: Chain, deployer: Account, recipient: Account, amount = 10_000_000) {
  return chain.mineBlock([
    Tx.contractCall(TOKEN, 'mint', [types.uint(amount), types.principal(recipient.address)], deployer.address)
  ]);
}

Clarinet.test({
  name: "STAKING: Should stake SPM tokens successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    mintTokens(chain, deployer, user);
    const block = chain.mineBlock([
      Tx.contractCall(STAKING, 'stake', [STAKE_AMOUNT], user.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    const stake = chain.callReadOnlyFn(STAKING, 'get-stake', [types.principal(user.address)], user.address);
    const data = stake.result.expectSome().expectTuple();
    assertEquals(data['amount'], 'u1000000');
  }
});

Clarinet.test({
  name: "STAKING: Should reject unstake before lock period ends",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    mintTokens(chain, deployer, user);
    chain.mineBlock([Tx.contractCall(STAKING, 'stake', [STAKE_AMOUNT], user.address)]);
    const block = chain.mineBlock([
      Tx.contractCall(STAKING, 'unstake', [STAKE_AMOUNT], user.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(403); // ERR-LOCK-ACTIVE
  }
});

Clarinet.test({
  name: "STAKING: Should allow unstake after lock period",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    mintTokens(chain, deployer, user);
    chain.mineBlock([Tx.contractCall(STAKING, 'stake', [STAKE_AMOUNT], user.address)]);
    chain.mineEmptyBlockUntil(chain.blockHeight + 1009); // past LOCK-PERIOD-BLOCKS
    const block = chain.mineBlock([
      Tx.contractCall(STAKING, 'unstake', [STAKE_AMOUNT], user.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "STAKING: Should reject zero-amount stake",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(STAKING, 'stake', [types.uint(0)], user.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(401); // ERR-ZERO-AMOUNT
  }
});

Clarinet.test({
  name: "STAKING: Only owner can set reward rate",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(STAKING, 'set-reward-rate', [types.uint(100)], user.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(400); // ERR-NOT-AUTHORIZED
  }
});
