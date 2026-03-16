import {
  callReadOnlyFunction,
  cvToValue,
  uintCV,
  stringUtf8CV,
  principalCV,
  AnchorMode,
  PostConditionMode,
  makeStandardSTXPostCondition,
  FungibleConditionCode,
} from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';
import { CONTRACTS, CURRENT_NETWORK, STACKS_API_URL, CONTRACT_CONSTANTS } from './constants';

export function getNetwork() {
  if (CURRENT_NETWORK === 'mainnet') return new StacksMainnet();
  return new StacksTestnet({ url: STACKS_API_URL });
}

export interface Market {
  id: number;
  creator: string;
  title: string;
  description: string;
  outcomeCount: number;
  deadline: number;
  resolutionBlock: number;
  resolved: boolean;
  winningOutcome: number;
  totalPool: number;
  disputed: boolean;
  oracleResolved: boolean;
  createdAt: number;
}

export interface MarketOutcome { label: string; pool: number; }
export interface Bet { amount: number; claimed: boolean; withdrawn: boolean; }
export interface ClaimStatus { claimed: boolean; amount: number; }

async function readContract(functionName: string, args: any[]): Promise<any> {
  const result = await callReadOnlyFunction({
    contractAddress: CONTRACTS.predictionMarket.address,
    contractName: CONTRACTS.predictionMarket.name,
    functionName,
    functionArgs: args,
    network: getNetwork(),
    senderAddress: CONTRACTS.predictionMarket.address,
  });
  return cvToValue(result);
}

export async function fetchMarket(marketId: number): Promise<Market | null> {
  try {
    const result = await readContract('get-market', [uintCV(marketId)]);
    if (!result) return null;
    return {
      id: marketId,
      creator: result.creator.value,
      title: result.title,
      description: result.description,
      outcomeCount: Number(result['outcome-count']),
      deadline: Number(result.deadline),
      resolutionBlock: Number(result['resolution-block']),
      resolved: result.resolved,
      winningOutcome: Number(result['winning-outcome']),
      totalPool: Number(result['total-pool']),
      disputed: result.disputed,
      oracleResolved: result['oracle-resolved'],
      createdAt: Number(result['created-at']),
    };
  } catch { return null; }
}

export async function fetchMarketCount(): Promise<number> {
  try { return Number(await readContract('get-market-count', [])); } catch { return 0; }
}

export async function fetchMarketOutcome(marketId: number, outcomeIndex: number): Promise<MarketOutcome | null> {
  try {
    const result = await readContract('get-market-outcome', [uintCV(marketId), uintCV(outcomeIndex)]);
    if (!result) return null;
    return { label: result.label, pool: Number(result.pool) };
  } catch { return null; }
}

export async function fetchAllMarkets(): Promise<Market[]> {
  const count = await fetchMarketCount();
  const results = await Promise.all(Array.from({ length: count }, (_, i) => fetchMarket(i + 1)));
  return (results.filter(Boolean) as Market[]).reverse();
}

export async function fetchUserBet(marketId: number, userAddress: string, outcomeIndex: number): Promise<Bet | null> {
  try {
    const result = await readContract('get-bet', [uintCV(marketId), principalCV(userAddress), uintCV(outcomeIndex)]);
    if (!result) return null;
    return { amount: Number(result.amount), claimed: result.claimed, withdrawn: result.withdrawn };
  } catch { return null; }
}

export async function fetchClaimStatus(marketId: number, userAddress: string): Promise<ClaimStatus | null> {
  try {
    const result = await readContract('get-claim-status', [uintCV(marketId), principalCV(userAddress)]);
    if (!result) return null;
    return { claimed: result.claimed, amount: Number(result.amount) };
  } catch { return null; }
}

export async function calculateWinnings(marketId: number, userAddress: string): Promise<number> {
  try { return Number((await readContract('calculate-winnings', [uintCV(marketId), principalCV(userAddress)]))?.value || 0); }
  catch { return 0; }
}

export function buildCreateMarketTx(params: { title: string; description: string; outcomeA: string; outcomeB: string; deadline: number; }) {
  return {
    contractAddress: CONTRACTS.predictionMarket.address,
    contractName: CONTRACTS.predictionMarket.name,
    functionName: 'create-market',
    functionArgs: [stringUtf8CV(params.title), stringUtf8CV(params.description), stringUtf8CV(params.outcomeA), stringUtf8CV(params.outcomeB), uintCV(params.deadline)],
    network: getNetwork(),
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };
}

export function buildPlaceBetTx(params: { marketId: number; outcomeIndex: number; amount: number; senderAddress: string; }) {
  return {
    contractAddress: CONTRACTS.predictionMarket.address,
    contractName: CONTRACTS.predictionMarket.name,
    functionName: 'place-bet',
    functionArgs: [uintCV(params.marketId), uintCV(params.outcomeIndex), uintCV(params.amount)],
    network: getNetwork(),
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Deny,
    postConditions: [makeStandardSTXPostCondition(params.senderAddress, FungibleConditionCode.Equal, params.amount)],
  };
}

export function buildClaimWinningsTx(marketId: number) {
  return { contractAddress: CONTRACTS.predictionMarket.address, contractName: CONTRACTS.predictionMarket.name, functionName: 'claim-winnings', functionArgs: [uintCV(marketId)], network: getNetwork(), anchorMode: AnchorMode.Any, postConditionMode: PostConditionMode.Allow };
}

export function buildEarlyWithdrawTx(marketId: number, outcomeIndex: number) {
  return { contractAddress: CONTRACTS.predictionMarket.address, contractName: CONTRACTS.predictionMarket.name, functionName: 'early-withdraw', functionArgs: [uintCV(marketId), uintCV(outcomeIndex)], network: getNetwork(), anchorMode: AnchorMode.Any, postConditionMode: PostConditionMode.Allow };
}

export function buildResolveMarketTx(marketId: number, winningOutcome: number) {
  return { contractAddress: CONTRACTS.predictionMarket.address, contractName: CONTRACTS.predictionMarket.name, functionName: 'resolve-market', functionArgs: [uintCV(marketId), uintCV(winningOutcome)], network: getNetwork(), anchorMode: AnchorMode.Any, postConditionMode: PostConditionMode.Allow };
}

export const microSTXtoSTX = (micro: number) => micro / CONTRACT_CONSTANTS.MICRO_STX_PER_STX;
export const stxToMicroSTX = (stx: number) => Math.floor(stx * CONTRACT_CONSTANTS.MICRO_STX_PER_STX);
export const formatSTX = (micro: number, decimals = 2) => `${microSTXtoSTX(micro).toFixed(decimals)} STX`;
export const estimateDeadlineBlock = (current: number, days: number) => current + days * CONTRACT_CONSTANTS.BLOCKS_PER_DAY;
export const isMarketBettingOpen = (market: Market, current: number) => !market.resolved && current < market.deadline - CONTRACT_CONSTANTS.BETTING_CUTOFF_BLOCKS;
export const getOutcomePercentage = (pool: number, total: number) => total === 0 ? 50 : Math.round((pool / total) * 100);

export function getMarketStatus(market: Market, currentBlock: number): string {
  if (market.disputed) return 'Disputed';
  if (market.resolved) return 'Resolved';
  if (currentBlock >= market.deadline) return 'Awaiting Resolution';
  if (!isMarketBettingOpen(market, currentBlock)) return 'Betting Closed';
  return 'Active';
}
// Returns estimated payout multiplier for a given outcome
export function getPayoutMultiplier(outcomePool: number, totalPool: number): string {
  if (outcomePool === 0) return '∞';
  const fee = totalPool * (CONTRACT_CONSTANTS.PLATFORM_FEE_BPS / CONTRACT_CONSTANTS.BPS_DENOMINATOR);
  const distributable = totalPool - fee;
  const multiplier = distributable / outcomePool;
  return `${multiplier.toFixed(2)}x`;
}

// Returns true if market deadline has passed but market is not yet resolved
export function isAwaitingResolution(market: Market, currentBlock: number): boolean {
  return !market.resolved && currentBlock >= market.deadline;
}

// Returns the block number when betting closes (144 blocks before deadline)
export function getBettingCutoffBlock(market: Market): number {
  return market.deadline - CONTRACT_CONSTANTS.BETTING_CUTOFF_BLOCKS;
}
```
