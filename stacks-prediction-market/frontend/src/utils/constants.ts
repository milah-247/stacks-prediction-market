export const CONTRACTS = {
  predictionMarket: {
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    name: 'prediction-market',
  },
  oracle: {
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    name: 'oracle',
  },
  marketToken: {
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    name: 'market-token',
  },
} as const;

export const CURRENT_NETWORK = (process.env.NEXT_PUBLIC_NETWORK || 'testnet') as 'mainnet' | 'testnet' | 'devnet';

export const STACKS_API_URL = {
  mainnet: 'https://api.mainnet.hiro.so',
  testnet: 'https://api.testnet.hiro.so',
  devnet: 'http://localhost:3999',
}[CURRENT_NETWORK];

export const CONTRACT_CONSTANTS = {
  MAX_BET_PERCENT: 20,
  EARLY_WITHDRAWAL_FEE_BPS: 500,
  PLATFORM_FEE_BPS: 200,
  BETTING_CUTOFF_BLOCKS: 144,
  MIN_DEADLINE_BLOCKS: 144,
  DISPUTE_WINDOW_BLOCKS: 144,
  BLOCKS_PER_DAY: 144,
  MICRO_STX_PER_STX: 1_000_000,
} as const;

export const APP_CONFIG = {
  name: 'Stacks Prediction Market',
  description: 'Decentralized prediction markets on the Stacks blockchain',
  appIconUrl: '/icon-512.png',
} as const;
