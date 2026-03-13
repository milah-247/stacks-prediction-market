import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface WalletState {
  address: string | null;
  mainnetAddress: string | null;
  testnetAddress: string | null;
  connected: boolean;
  stxBalance: number;
  connect: (address: string, mainnetAddress: string, testnetAddress: string) => void;
  disconnect: () => void;
  setBalance: (stx: number) => void;
}

export const useWalletStore = create<WalletState>()(
  persist(
    (set) => ({
      address: null,
      mainnetAddress: null,
      testnetAddress: null,
      connected: false,
      stxBalance: 0,
      connect: (address, mainnetAddress, testnetAddress) =>
        set({ address, mainnetAddress, testnetAddress, connected: true }),
      disconnect: () =>
        set({ address: null, mainnetAddress: null, testnetAddress: null, connected: false, stxBalance: 0 }),
      setBalance: (stx) => set({ stxBalance: stx }),
    }),
    {
      name: 'spm-wallet',
      partialize: (state) => ({ address: state.address, mainnetAddress: state.mainnetAddress, testnetAddress: state.testnetAddress, connected: state.connected }),
    }
  )
);
