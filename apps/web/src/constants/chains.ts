/**
 * Chain enumeration and configuration constants.
 * Migrated from extension `@debank/common` CHAINS_ENUM and `src/constant/index.ts`.
 */

/**
 * Comprehensive chain enum covering all supported mainnets and testnets.
 * Values match the `@debank/common` CHAINS_ENUM.
 */
export enum CHAINS_ENUM {
  // --- Major mainnets ---
  ETH = 'ETH',
  BSC = 'BSC',
  POLYGON = 'POLYGON',
  ARBITRUM = 'ARBITRUM',
  OP = 'OP',
  AVAX = 'AVAX',
  BASE = 'BASE',
  LINEA = 'LINEA',
  SCRL = 'SCRL',
  ERA = 'ERA',
  FTM = 'FTM',
  GNOSIS = 'GNOSIS',
  HECO = 'HECO',
  OKT = 'OKT',
  CELO = 'CELO',
  MOVR = 'MOVR',
  CRO = 'CRO',
  BOBA = 'BOBA',
  METIS = 'METIS',
  BTT = 'BTT',
  AURORA = 'AURORA',
  MOBM = 'MOBM',
  HMY = 'HMY',
  ASTAR = 'ASTAR',
  KLAY = 'KLAY',
  IOTX = 'IOTX',
  RSK = 'RSK',
  WAN = 'WAN',
  KCC = 'KCC',
  SGB = 'SGB',
  EVMOS = 'EVMOS',
  DFK = 'DFK',
  TLOS = 'TLOS',
  NOVA = 'NOVA',
  CANTO = 'CANTO',
  DOGE = 'DOGE',
  STEP = 'STEP',
  KAVA = 'KAVA',
  MADA = 'MADA',
  CFX = 'CFX',
  BRISE = 'BRISE',
  CKB = 'CKB',
  TOMB = 'TOMB',
  PZE = 'PZE',
  EOS = 'EOS',
  CORE = 'CORE',
  FLR = 'FLR',
  WEMIX = 'WEMIX',
  METER = 'METER',
  ETC = 'ETC',
  FSN = 'FSN',
  PULSE = 'PULSE',
  ROSE = 'ROSE',
  RONIN = 'RONIN',
  OAS = 'OAS',
  ZORA = 'ZORA',
  MANTLE = 'MANTLE',
  OPBNB = 'OPBNB',
  MANTA = 'MANTA',
  BEAM = 'BEAM',
  ZKFAIR = 'ZKFAIR',
  ZETA = 'ZETA',
  MODE = 'MODE',
  MERLIN = 'MERLIN',
  DYM = 'DYM',
  BLAST = 'BLAST',
  PLATON = 'PLATON',
  KARAK = 'KARAK',
  LYX = 'LYX',
  SBCH = 'SBCH',
  FUSE = 'FUSE',
  PEGO = 'PEGO',
  EON = 'EON',
  XAI = 'XAI',
  RARI = 'RARI',
  MAP = 'MAP',
  FRAX = 'FRAX',
  AZE = 'AZE',
  SX = 'SX',
  LOOT = 'LOOT',
  SHIB = 'SHIB',
  ALOT = 'ALOT',
  FX = 'FX',
  FON = 'FON',
  BFC = 'BFC',
  TENET = 'TENET',
  HUBBLE = 'HUBBLE',

  // --- Testnets (prefixed with T/G/S/etc.) ---
  GETH = 'GETH',
  GARBITRUM = 'GARBITRUM',
  CGNOSIS = 'CGNOSIS',
  TBSC = 'TBSC',
  MPOLYGON = 'MPOLYGON',
  GOP = 'GOP',
  GBOBA = 'GBOBA',
  GBASE = 'GBASE',
  GLINEA = 'GLINEA',
  TFTM = 'TFTM',
  TLYX = 'TLYX',
  TDEBANK = 'TDEBANK',
  TMNT = 'TMNT',
  GERA = 'GERA',
  PMANTA = 'PMANTA',
  TOPBNB = 'TOPBNB',
  TTENET = 'TTENET',
  TLOOT = 'TLOOT',
  SETH = 'SETH',
  SSCROLL = 'SSCROLL',
  AZETA = 'AZETA',
  TAVAX = 'TAVAX',
  PSHIB = 'PSHIB',
  GMETIS = 'GMETIS',
  SARB = 'SARB',
  TSTLS = 'TSTLS',
  CFLR = 'CFLR',
  ACELO = 'ACELO',
  DBTT = 'DBTT',
  TEVMOS = 'TEVMOS',
  TDFK = 'TDFK',
  TWEMIX = 'TWEMIX',
  TSTEP = 'TSTEP',
  METC = 'METC',
  TFSN = 'TFSN',
  AMOBM = 'AMOBM',
  TKCC = 'TKCC',
  TIOTX = 'TIOTX',
  TPLS = 'TPLS',
  HETH = 'HETH',
  BKLAY = 'BKLAY',
  CSGB = 'CSGB',
  TKAVA = 'TKAVA',
  DFX = 'DFX',
  TAURORA = 'TAURORA',
  TCRO = 'TCRO',
  SMODE = 'SMODE',
  TIMXZE = 'TIMXZE',
  KTAIKO = 'KTAIKO',
  TCFX = 'TCFX',
  TX1 = 'TX1',
  TSBY = 'TSBY',
  TAZE = 'TAZE',
  TBEAM = 'TBEAM',
  TFRAX = 'TFRAX',
  TPEGO = 'TPEGO',
  TFRAME = 'TFRAME',
  TRSK = 'TRSK',
  TALOT = 'TALOT',
  TBFC = 'TBFC',
  ABERA = 'ABERA',
  TSAVM = 'TSAVM',
  GXAI = 'GXAI',
  SXAI = 'SXAI',
  SBLAST = 'SBLAST',
  TRARI = 'TRARI',
}

// ---------------------------------------------------------------------------
// Chain ID mapping (decimal chain IDs for the most-used mainnets)
// ---------------------------------------------------------------------------

/** Maps CHAINS_ENUM values to EVM chain IDs (decimal). */
export const CHAIN_ID_MAP: Partial<Record<CHAINS_ENUM, number>> = {
  [CHAINS_ENUM.ETH]: 1,
  [CHAINS_ENUM.BSC]: 56,
  [CHAINS_ENUM.POLYGON]: 137,
  [CHAINS_ENUM.ARBITRUM]: 42161,
  [CHAINS_ENUM.OP]: 10,
  [CHAINS_ENUM.AVAX]: 43114,
  [CHAINS_ENUM.BASE]: 8453,
  [CHAINS_ENUM.LINEA]: 59144,
  [CHAINS_ENUM.SCRL]: 534352,
  [CHAINS_ENUM.ERA]: 324,
  [CHAINS_ENUM.FTM]: 250,
  [CHAINS_ENUM.GNOSIS]: 100,
  [CHAINS_ENUM.HECO]: 128,
  [CHAINS_ENUM.OKT]: 66,
  [CHAINS_ENUM.CELO]: 42220,
  [CHAINS_ENUM.MOVR]: 1285,
  [CHAINS_ENUM.CRO]: 25,
  [CHAINS_ENUM.BOBA]: 288,
  [CHAINS_ENUM.METIS]: 1088,
  [CHAINS_ENUM.BTT]: 199,
  [CHAINS_ENUM.AURORA]: 1313161554,
  [CHAINS_ENUM.KAVA]: 2222,
  [CHAINS_ENUM.NOVA]: 42170,
  [CHAINS_ENUM.ZORA]: 7777777,
  [CHAINS_ENUM.MANTLE]: 5000,
  [CHAINS_ENUM.OPBNB]: 204,
  [CHAINS_ENUM.MANTA]: 169,
  [CHAINS_ENUM.BLAST]: 81457,
  [CHAINS_ENUM.MODE]: 34443,
  [CHAINS_ENUM.ZETA]: 7000,
  [CHAINS_ENUM.MERLIN]: 4200,
  [CHAINS_ENUM.PZE]: 1101,
  [CHAINS_ENUM.KLAY]: 8217,
  [CHAINS_ENUM.RONIN]: 2020,
  [CHAINS_ENUM.PULSE]: 369,
  [CHAINS_ENUM.ZKFAIR]: 42766,
  [CHAINS_ENUM.BEAM]: 4337,
};

/** Maps numeric chain IDs back to CHAINS_ENUM */
export const CHAIN_ENUM_BY_ID: Record<number, CHAINS_ENUM> = Object.entries(
  CHAIN_ID_MAP,
).reduce(
  (acc, [enumKey, id]) => {
    if (id !== undefined) {
      acc[id] = enumKey as CHAINS_ENUM;
    }
    return acc;
  },
  {} as Record<number, CHAINS_ENUM>,
);

// ---------------------------------------------------------------------------
// Primary chain configuration data
// ---------------------------------------------------------------------------

export interface ChainInfo {
  /** Display name */
  name: string;
  /** CHAINS_ENUM key */
  enum: CHAINS_ENUM;
  /** Decimal chain ID */
  id: number;
  /** Hex chain ID (e.g. '0x1') */
  hex: string;
  /** DeBank server ID (e.g. 'eth', 'bsc') */
  serverId: string;
  /** Native token symbol */
  nativeTokenSymbol: string;
  /** Native token decimals */
  nativeTokenDecimals: number;
  /** Block explorer scan link template */
  scanLink: string;
}

/** Core mainnet chain configurations */
export const MAIN_CHAINS: ChainInfo[] = [
  {
    name: 'Ethereum',
    enum: CHAINS_ENUM.ETH,
    id: 1,
    hex: '0x1',
    serverId: 'eth',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://etherscan.io/tx/_s_',
  },
  {
    name: 'BNB Chain',
    enum: CHAINS_ENUM.BSC,
    id: 56,
    hex: '0x38',
    serverId: 'bsc',
    nativeTokenSymbol: 'BNB',
    nativeTokenDecimals: 18,
    scanLink: 'https://bscscan.com/tx/_s_',
  },
  {
    name: 'Polygon',
    enum: CHAINS_ENUM.POLYGON,
    id: 137,
    hex: '0x89',
    serverId: 'matic',
    nativeTokenSymbol: 'MATIC',
    nativeTokenDecimals: 18,
    scanLink: 'https://polygonscan.com/tx/_s_',
  },
  {
    name: 'Arbitrum',
    enum: CHAINS_ENUM.ARBITRUM,
    id: 42161,
    hex: '0xa4b1',
    serverId: 'arb',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://arbiscan.io/tx/_s_',
  },
  {
    name: 'Optimism',
    enum: CHAINS_ENUM.OP,
    id: 10,
    hex: '0xa',
    serverId: 'op',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://optimistic.etherscan.io/tx/_s_',
  },
  {
    name: 'Avalanche',
    enum: CHAINS_ENUM.AVAX,
    id: 43114,
    hex: '0xa86a',
    serverId: 'avax',
    nativeTokenSymbol: 'AVAX',
    nativeTokenDecimals: 18,
    scanLink: 'https://snowtrace.io/tx/_s_',
  },
  {
    name: 'Base',
    enum: CHAINS_ENUM.BASE,
    id: 8453,
    hex: '0x2105',
    serverId: 'base',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://basescan.org/tx/_s_',
  },
  {
    name: 'Linea',
    enum: CHAINS_ENUM.LINEA,
    id: 59144,
    hex: '0xe708',
    serverId: 'linea',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://lineascan.build/tx/_s_',
  },
  {
    name: 'Scroll',
    enum: CHAINS_ENUM.SCRL,
    id: 534352,
    hex: '0x82750',
    serverId: 'scrl',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://scrollscan.com/tx/_s_',
  },
  {
    name: 'zkSync Era',
    enum: CHAINS_ENUM.ERA,
    id: 324,
    hex: '0x144',
    serverId: 'era',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://explorer.zksync.io/tx/_s_',
  },
  {
    name: 'Fantom',
    enum: CHAINS_ENUM.FTM,
    id: 250,
    hex: '0xfa',
    serverId: 'ftm',
    nativeTokenSymbol: 'FTM',
    nativeTokenDecimals: 18,
    scanLink: 'https://ftmscan.com/tx/_s_',
  },
  {
    name: 'Gnosis Chain',
    enum: CHAINS_ENUM.GNOSIS,
    id: 100,
    hex: '0x64',
    serverId: 'xdai',
    nativeTokenSymbol: 'xDAI',
    nativeTokenDecimals: 18,
    scanLink: 'https://gnosisscan.io/tx/_s_',
  },
  {
    name: 'Blast',
    enum: CHAINS_ENUM.BLAST,
    id: 81457,
    hex: '0x13e31',
    serverId: 'blast',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://blastscan.io/tx/_s_',
  },
  {
    name: 'Mantle',
    enum: CHAINS_ENUM.MANTLE,
    id: 5000,
    hex: '0x1388',
    serverId: 'mnt',
    nativeTokenSymbol: 'MNT',
    nativeTokenDecimals: 18,
    scanLink: 'https://explorer.mantle.xyz/tx/_s_',
  },
  {
    name: 'Zora',
    enum: CHAINS_ENUM.ZORA,
    id: 7777777,
    hex: '0x76adf1',
    serverId: 'zora',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://explorer.zora.energy/tx/_s_',
  },
  {
    name: 'opBNB',
    enum: CHAINS_ENUM.OPBNB,
    id: 204,
    hex: '0xcc',
    serverId: 'opbnb',
    nativeTokenSymbol: 'BNB',
    nativeTokenDecimals: 18,
    scanLink: 'https://opbnbscan.com/tx/_s_',
  },
  {
    name: 'Mode',
    enum: CHAINS_ENUM.MODE,
    id: 34443,
    hex: '0x868b',
    serverId: 'mode',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://explorer.mode.network/tx/_s_',
  },
  {
    name: 'Manta Pacific',
    enum: CHAINS_ENUM.MANTA,
    id: 169,
    hex: '0xa9',
    serverId: 'manta',
    nativeTokenSymbol: 'ETH',
    nativeTokenDecimals: 18,
    scanLink: 'https://pacific-explorer.manta.network/tx/_s_',
  },
];

// ---------------------------------------------------------------------------
// L2 chain groupings (from extension src/constant/index.ts)
// ---------------------------------------------------------------------------

/** Non-OP-Stack L2 chains */
export const L2_ENUMS: string[] = [
  CHAINS_ENUM.ARBITRUM,
  CHAINS_ENUM.AURORA,
  CHAINS_ENUM.NOVA,
  CHAINS_ENUM.BOBA,
  CHAINS_ENUM.MANTLE,
  CHAINS_ENUM.LINEA,
  CHAINS_ENUM.MANTA,
  CHAINS_ENUM.SCRL,
  CHAINS_ENUM.ERA,
  CHAINS_ENUM.PZE,
  CHAINS_ENUM.OP,
  CHAINS_ENUM.BASE,
  CHAINS_ENUM.ZORA,
  CHAINS_ENUM.OPBNB,
  CHAINS_ENUM.BLAST,
  CHAINS_ENUM.MODE,
];

/** OP Stack L2 chains */
export const OP_STACK_ENUMS: string[] = [
  CHAINS_ENUM.OP,
  CHAINS_ENUM.BASE,
  CHAINS_ENUM.ZORA,
  CHAINS_ENUM.OPBNB,
  CHAINS_ENUM.BLAST,
  CHAINS_ENUM.MODE,
];

/** Arbitrum-like L2 chains */
export const ARB_LIKE_L2_CHAINS: string[] = [
  CHAINS_ENUM.ARBITRUM,
  CHAINS_ENUM.AURORA,
];

/** Chains that support L1 fee estimation */
export const CAN_ESTIMATE_L1_FEE_CHAINS: string[] = [
  ...OP_STACK_ENUMS,
  CHAINS_ENUM.SCRL,
  ...ARB_LIKE_L2_CHAINS,
  CHAINS_ENUM.PZE,
  CHAINS_ENUM.ERA,
  CHAINS_ENUM.LINEA,
];
