/**
 * Shared formatting utilities for the prediction market frontend.
 * Centralises STX, block, and address formatting previously duplicated across components.
 */

/** Convert micro-STX to STX with fixed decimal places */
export function formatSTX(microSTX: number, decimals = 2): string {
  return (microSTX / 1_000_000).toFixed(decimals) + ' STX';
}

/** Shorten a Stacks principal for display */
export function shortenAddress(address: string, chars = 6): string {
  if (address.length <= chars * 2 + 3) return address;
  return `${address.slice(0, chars)}...${address.slice(-chars)}`;
}

/** Estimate wall-clock time from block count (10 min/block) */
export function blocksToTime(blocks: number): string {
  const minutes = blocks * 10;
  if (minutes < 60) return `~${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `~${hours}h`;
  return `~${Math.floor(hours / 24)}d`;
}

/** Format a percentage from a numerator/denominator pair */
export function formatPercent(numerator: number, denominator: number): string {
  if (denominator === 0) return '0%';
  return ((numerator / denominator) * 100).toFixed(1) + '%';
}

/** Format a block height with locale separators */
export function formatBlock(block: number): string {
  return `#${block.toLocaleString()}`;
}
