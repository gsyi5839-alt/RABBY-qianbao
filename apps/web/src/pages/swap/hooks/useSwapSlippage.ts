import { useLocalStorage } from '../../../hooks/useLocalStorage';

const SLIPPAGE_KEY = 'rabby_swap_slippage';
const DEFAULT_SLIPPAGE = 0.5;

export function useSwapSlippage() {
  const [slippage, setSlippage] = useLocalStorage<number>(
    SLIPPAGE_KEY,
    DEFAULT_SLIPPAGE,
  );

  return { slippage, setSlippage };
}
