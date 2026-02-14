import SwiftUI

/// Provides cryptocurrency icon URLs with multi-level fallback:
/// 1. OpenAPI logo_url (most accurate)
/// 2. Built-in mapping tables (chain icons + top token icons)
/// 3. Generic CDN: https://token-icons.s3.amazonaws.com/[address].png
/// 4. SF Symbol placeholder ("dollarsign.circle")
///
/// GitHub icons source: https://github.com/ErikThiart/cryptocurrency-icons (MIT License)
enum CryptoIconProvider {

    // MARK: - Base URLs

    /// Base raw URL for the ErikThiart repository
    private static let baseURL = "https://raw.githubusercontent.com/ErikThiart/cryptocurrency-icons/master"

    /// Generic token icon CDN (address-based)
    private static let tokenIconCDN = "https://token-icons.s3.amazonaws.com"

    /// Default SF Symbol placeholder name
    static let defaultPlaceholder = "dollarsign.circle"

    // MARK: - Icon Sizes

    /// Available icon sizes from the repository
    enum IconSize: Int {
        case small = 16
        case medium = 32
        case large = 64
        case xlarge = 128
    }

    // MARK: - Chain Icon Mapping (Offline Fallback)

    /// Built-in chain ID -> icon name mapping for main chains.
    /// Used for offline fallback when API-provided chain icons are unavailable.
    static let chainIcons: [String: String] = [
        "1":     "ethereum",       // ETH Mainnet
        "56":    "binance",        // BSC
        "137":   "polygon",        // Polygon
        "42161": "arbitrum",       // Arbitrum One
        "10":    "optimism",       // Optimism
        "43114": "avalanche",      // Avalanche C-Chain
        "250":   "fantom",         // Fantom Opera
        "8453":  "base",           // Base
        "324":   "zksync",         // zkSync Era
        "59144": "linea",          // Linea
    ]

    /// Chain ID -> stable CDN URL for chain icons.
    /// These are well-known URLs that remain stable over time.
    private static let chainIconCDNURLs: [String: String] = [
        "1":     "https://icons.llamao.fi/icons/chains/rsz_ethereum.jpg",
        "56":    "https://icons.llamao.fi/icons/chains/rsz_binance.jpg",
        "137":   "https://icons.llamao.fi/icons/chains/rsz_polygon.jpg",
        "42161": "https://icons.llamao.fi/icons/chains/rsz_arbitrum.jpg",
        "10":    "https://icons.llamao.fi/icons/chains/rsz_optimism.jpg",
        "43114": "https://icons.llamao.fi/icons/chains/rsz_avalanche.jpg",
        "250":   "https://icons.llamao.fi/icons/chains/rsz_fantom.jpg",
        "8453":  "https://icons.llamao.fi/icons/chains/rsz_base.jpg",
        "324":   "https://icons.llamao.fi/icons/chains/rsz_zksync-era.jpg",
        "59144": "https://icons.llamao.fi/icons/chains/rsz_linea.jpg",
    ]

    /// SF Symbol fallback for chains (used when neither CDN nor repo icon is reachable)
    private static let chainSFSymbols: [String: String] = [
        "1":     "diamond.fill",
        "56":    "b.circle.fill",
        "137":   "triangle.fill",
        "42161": "a.circle.fill",
        "10":    "o.circle.fill",
        "43114": "a.circle.fill",
        "250":   "f.circle.fill",
        "8453":  "b.circle.fill",
        "324":   "z.circle.fill",
        "59144": "l.circle.fill",
    ]

    // MARK: - Top 50 Token Icon Mapping

    /// Contract address (lowercased, on Ethereum mainnet) -> stable icon URL.
    /// Covers the top 50 most commonly used tokens for fast offline resolution.
    static let topTokenIcons: [String: String] = [
        // Stablecoins
        "0xdac17f958d2ee523a2206206994597c13d831ec7": "tether",             // USDT
        "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48": "usd-coin",           // USDC
        "0x6b175474e89094c44da98b954eedeac495271d0f": "multi-collateral-dai",// DAI
        "0x4fabb145d64652a948d72533023f6e7a623c7c53": "binance-usd",        // BUSD
        "0x0000000000085d4780b73119b644ae5ecd22b376": "trueusd",            // TUSD
        "0x8e870d67f660d95d5be530380d0ec0bd388289e1": "pax-dollar",         // USDP
        "0x853d955acef822db058eb8505911ed77f175b99e": "frax",               // FRAX
        "0x5f98805a4e8be255a32880fdec7f6728c6568ba0": "liquity-usd",        // LUSD

        // Wrapped / staked ETH
        "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599": "wrapped-bitcoin",    // WBTC
        "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2": "weth",               // WETH
        "0xae7ab96520de3a18e5e111b5eaab095312d7fe84": "lido-staked-ether",  // stETH
        "0xae78736cd615f374d3085123a210448e74fc6393": "rocket-pool-eth",    // rETH
        "0xbe9895146f7af43049ca1c1ae358b0541ea49704": "coinbase-wrapped-staked-eth", // cbETH

        // DeFi blue chips
        "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984": "uniswap",            // UNI
        "0x514910771af9ca656af840dff83e8264ecf986ca": "chainlink",          // LINK
        "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9": "aave",               // AAVE
        "0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f": "synthetix-network-token", // SNX
        "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2": "maker",              // MKR
        "0xd533a949740bb3306d119cc777fa900ba034cd52": "curve-dao-token",    // CRV
        "0xc00e94cb662c3520282e6f5717214004a7f26888": "compound",           // COMP
        "0x111111111117dc0aa78b770fa6a738034120c302": "1inch",              // 1INCH
        "0x6b3595068778dd592e39a122f4f5a5cf09c90fe2": "sushiswap",          // SUSHI
        "0xba100000625a3754423978a60c9317c58a424e3d": "balancer",           // BAL
        "0x0bc529c00c6401aef6d220be8c6ea1667f6ad93e": "yearn-finance",      // YFI
        "0xe41d2489571d322189246dafa5ebde1f4699f498": "0x",                 // ZRX
        "0x5a98fcbea516cf06857215779fd812ca3bef1b32": "lido-dao",           // LDO
        "0xd33526068d116ce69f19a9ee46f0bd304f21a51f": "rocket-pool",        // RPL
        "0xc18360217d8f7ab5e7c516566761ea12ce7f9d72": "ethereum-name-service", // ENS
        "0x4e3fbd56cd56c3e72c1403e103b45db9da5b9d2b": "convex-finance",     // CVX
        "0x3432b6a60d23ca0dfca7761b7ab56459d9c964d0": "frax-share",         // FXS

        // Gaming / Metaverse
        "0x3845badade8e6dff049820680d1f14bd3903a5d0": "the-sandbox",        // SAND
        "0x0f5d2fb29fb7d3cfee444a200298f468908cc942": "decentraland",       // MANA
        "0xbb0e17ef65f82ab018d8edd776e8dd940327b28b": "axie-infinity",      // AXS
        "0x15d4c048f83bd7e37d49ea4c83a07267ec4203da": "gala",               // GALA
        "0xf629cbd94d3791c9250152bd8dfbdf380e2a3b9c": "enjin-coin",         // ENJ
        "0x0d8775f648430679a709e98d2b0cb6250d2887ef": "basic-attention-token", // BAT
        "0x3506424f91fd33084466f402d5d97f05f8e3b4af": "chiliz",             // CHZ

        // Meme tokens
        "0x6982508145454ce325ddbe47a25d4ec3d2311933": "pepe",               // PEPE
        "0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce": "shiba-inu",          // SHIB
        "0x761d38e5ddf6ccf6cf7c55759d5210750b5d60f3": "floki-inu",          // FLOKI

        // AI tokens
        "0xaea46a60368a7bd060eec7df8cba43b7ef41ad85": "fetch",              // FET
        "0x6de037ef9ad2725eb40118bb1702ebb27e4aeb24": "render-token",       // RNDR
        "0x5b7533812759b45c2b44c19e320ba2cd2681b542": "singularitynet",     // AGIX
        "0x967da4048cd07ab37855c090aaf366e4ce1b9f48": "ocean-protocol",     // OCEAN

        // Layer 2 / Infrastructure
        "0xb50721bcf8d664c30412cfbc6cf7a15145234ad1": "arbitrum",           // ARB
        "0x4200000000000000000000000000000000000042": "optimism-ethereum",  // OP
        "0xf57e7e7c23978c3caec3c3548e3d615c346e79ff": "immutable-x",       // IMX
        "0x65ef703f5594d2573eb71aaf55bc0cb548492df4": "pendle",             // PENDLE
        "0xfc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a": "gmx",               // GMX
        "0x6810e776880c02933d47db1b9fc05908e5386b96": "gnosis-gno",        // GNO
        "0xdefa4e8a7bcba345f687a2f1456f5edd9ce97202": "kyber-network-crystal", // KNC
    ]

    // MARK: - URL Generation Strategy

    /// Get the best available icon URL for a token, following priority:
    /// 1. OpenAPI `logo_url` (most accurate)
    /// 2. Built-in top token mapping (by contract address)
    /// 3. Built-in symbol-to-name mapping
    /// 4. Generic CDN: https://token-icons.s3.amazonaws.com/[address].png
    /// 5. Returns nil -> caller should show SF Symbol placeholder
    ///
    /// - Parameters:
    ///   - logoURL: API-provided logo URL (highest priority)
    ///   - symbol: Token ticker symbol (e.g. "ETH", "USDT")
    ///   - address: Contract address (optional, for CDN fallback)
    ///   - size: Icon size for repository-based URLs
    /// - Returns: Best available URL string, or nil if no URL can be constructed
    static func bestIconURL(
        logoURL: String?,
        symbol: String,
        address: String? = nil,
        size: IconSize = .xlarge
    ) -> String? {
        // Priority 1: OpenAPI logo_url
        if let logo = logoURL, !logo.isEmpty, URL(string: logo) != nil {
            return logo
        }

        // Priority 2: Top token mapping by contract address
        if let addr = address?.lowercased(), let name = topTokenIcons[addr] {
            return "\(baseURL)/\(size.rawValue)/\(name).png"
        }

        // Priority 3: Symbol-to-name mapping
        if let name = symbolToName[symbol.uppercased()] {
            return "\(baseURL)/\(size.rawValue)/\(name).png"
        }

        // Priority 4: Generic CDN by contract address
        if let addr = address, !addr.isEmpty {
            return "\(tokenIconCDN)/\(addr.lowercased()).png"
        }

        // Priority 5: Try lowercase symbol as filename (works for some)
        let lowered = symbol.lowercased()
        if !lowered.isEmpty {
            return "\(baseURL)/\(size.rawValue)/\(lowered).png"
        }

        // No URL available - caller should use placeholder
        return nil
    }

    /// Get icon URL for a chain by chain ID.
    /// Priority: CDN URL -> repository icon -> nil (use SF Symbol fallback)
    ///
    /// - Parameters:
    ///   - chainId: Chain ID string (e.g. "1" for Ethereum)
    ///   - logoURL: API-provided chain logo URL (highest priority)
    /// - Returns: Best available URL string, or nil
    static func chainIconURL(chainId: String, logoURL: String? = nil) -> String? {
        // Priority 1: API-provided URL
        if let logo = logoURL, !logo.isEmpty, URL(string: logo) != nil {
            return logo
        }

        // Priority 2: Stable CDN URL
        if let cdnURL = chainIconCDNURLs[chainId] {
            return cdnURL
        }

        // Priority 3: Repository icon
        if let name = chainIcons[chainId] {
            return "\(baseURL)/128/\(name).png"
        }

        return nil
    }

    /// Get SF Symbol name for a chain (used as final fallback)
    /// - Parameter chainId: Chain ID string
    /// - Returns: SF Symbol name, defaults to "network" if chain is unknown
    static func chainSFSymbol(for chainId: String) -> String {
        return chainSFSymbols[chainId] ?? "network"
    }

    /// Get all supported chain IDs (for preloading)
    static var allChainIds: [String] {
        return Array(chainIcons.keys).sorted()
    }

    /// Get all chain icon URLs (for preloading)
    static var allChainIconURLs: [String] {
        return allChainIds.compactMap { chainIconURL(chainId: $0) }
    }

    // MARK: - Legacy Compatibility

    /// Get icon URL for a token symbol (legacy API, kept for backward compatibility)
    static func iconURL(for symbol: String, size: IconSize = .xlarge) -> String {
        let name = resolveIconName(for: symbol.uppercased())
        return "\(baseURL)/\(size.rawValue)/\(name).png"
    }

    /// Resolve token symbol to repository icon file name
    private static func resolveIconName(for symbol: String) -> String {
        if let name = symbolToName[symbol] {
            return name
        }
        return symbol.lowercased()
    }

    // MARK: - Initial Letter Avatar Colors

    /// Generate a consistent color for a token symbol.
    /// The color is determined by hashing the symbol so the same token always gets the same color.
    static func symbolColor(for symbol: String) -> Color {
        let hash = symbol.uppercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let colors: [Color] = [
            .blue, .purple, .orange, .green, .red,
            .pink, .indigo, .teal, .cyan, .mint,
            Color(red: 0.95, green: 0.6, blue: 0.1),  // gold
            Color(red: 0.2, green: 0.7, blue: 0.4),    // emerald
        ]
        return colors[abs(hash) % colors.count]
    }

    // MARK: - Symbol to Name Mapping
    // Maps token ticker symbols to the icon file names in the repository

    private static let symbolToName: [String: String] = [
        // Top cryptocurrencies
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "USDT": "tether",
        "BNB": "bnb",
        "SOL": "solana",
        "USDC": "usd-coin",
        "XRP": "xrp",
        "ADA": "cardano",
        "DOGE": "dogecoin",
        "TRX": "tron",
        "TON": "toncoin",
        "DOT": "polkadot-new",
        "MATIC": "polygon",
        "POL": "polygon",
        "DAI": "multi-collateral-dai",
        "SHIB": "shiba-inu",
        "AVAX": "avalanche",
        "LINK": "chainlink",
        "UNI": "uniswap",
        "ATOM": "cosmos",
        "LTC": "litecoin",
        "XMR": "monero",
        "ETC": "ethereum-classic",
        "BCH": "bitcoin-cash",
        "XLM": "stellar",
        "APT": "aptos",
        "NEAR": "near-protocol",
        "FIL": "filecoin",
        "ARB": "arbitrum",
        "OP": "optimism-ethereum",
        "ALGO": "algorand",
        "VET": "vechain",
        "HBAR": "hedera",
        "ICP": "internet-computer",
        "FTM": "fantom",
        "AAVE": "aave",
        "GRT": "the-graph",
        "MKR": "maker",
        "SAND": "the-sandbox",
        "MANA": "decentraland",
        "AXS": "axie-infinity",
        "SNX": "synthetix-network-token",
        "CRV": "curve-dao-token",
        "LDO": "lido-dao",
        "RPL": "rocket-pool",
        "ENS": "ethereum-name-service",
        "COMP": "compound",
        "1INCH": "1inch",
        "SUSHI": "sushiswap",
        "BAL": "balancer",
        "YFI": "yearn-finance",
        "ZRX": "0x",
        "CAKE": "pancakeswap",
        "CRO": "cronos",
        "QNT": "quant",
        "EGLD": "elrond-erd-2",
        "THETA": "theta-network",
        "XTZ": "tezos",
        "EOS": "eos",
        "FLOW": "flow",
        "NEO": "neo",
        "KSM": "kusama",
        "ROSE": "oasis-network",
        "ZEC": "zcash",
        "KAVA": "kava",
        "MINA": "mina-protocol",
        "ONE": "harmony",
        "FLR": "flare",
        "IMX": "immutable-x",
        "APE": "apecoin-ape",
        "GMT": "stepn",
        "GALA": "gala",
        "CHZ": "chiliz",
        "ENJ": "enjin-coin",
        "BAT": "basic-attention-token",
        "CELO": "celo",
        "ANKR": "ankr",
        "CKB": "nervos-network",
        "DASH": "dash",
        "WAVES": "waves",
        "ZIL": "zilliqa",
        "ICX": "icon",
        "IOTA": "iota",
        "ONT": "ontology",
        "SC": "siacoin",
        "RVN": "ravencoin",
        "DYDX": "dydx",
        "LUNC": "terra-luna",
        "LUNA": "terra-luna-v2",
        "UST": "terrausd",
        "BUSD": "binance-usd",
        "TUSD": "trueusd",
        "USDP": "pax-dollar",
        "FRAX": "frax",
        "LUSD": "liquity-usd",
        "WBTC": "wrapped-bitcoin",
        "WETH": "weth",
        "STETH": "lido-staked-ether",
        "RETH": "rocket-pool-eth",
        "CBETH": "coinbase-wrapped-staked-eth",
        "PEPE": "pepe",
        "WIF": "dogwifhat",
        "BONK": "bonk1",
        "FLOKI": "floki-inu",
        "FET": "fetch",
        "RNDR": "render-token",
        "AGIX": "singularitynet",
        "OCEAN": "ocean-protocol",
        "INJ": "injective-protocol",
        "SUI": "sui",
        "SEI": "sei-network",
        "TIA": "celestia",
        "JUP": "jupiter-ag",
        "STX": "stacks",
        "CFX": "conflux-network",
        "WLD": "worldcoin-org",
        "BLUR": "blur",
        "PENDLE": "pendle",
        "SSV": "ssv-network",
        "GMX": "gmx",
        "RDNT": "radiant-capital",
        "MAGIC": "magic",
        "GNO": "gnosis-gno",
        "KNC": "kyber-network-crystal",
        "MASK": "mask-network",
        "BAND": "band-protocol",
        "API3": "api3",
        "STORJ": "storj",
        "SKL": "skale",
        "CELR": "celer-network",
        "CTSI": "cartesi",
        "SYN": "synapse-2",
        "SPELL": "spell-token",
        "LOOKS": "looksrare",
        "X2Y2": "x2y2",
        "BICO": "biconomy",
        "HFT": "hashflow",
        "GTC": "gitcoin",
        "RAD": "radicle",
        "CVX": "convex-finance",
        "FXS": "frax-share",
        "TRIBE": "tribe",
        "RBN": "ribbon-finance",
        "PERP": "perpetual-protocol",
        "MPL": "maple",
        "BADGER": "badger-dao",
        "ALCX": "alchemix",
        "LQTY": "liquity",
    ]
}
