import SwiftUI

/// Provides cryptocurrency icon URLs from ErikThiart/cryptocurrency-icons repository
/// GitHub: https://github.com/ErikThiart/cryptocurrency-icons (MIT License)
/// Icons sourced from CoinMarketCap, available in 16/32/64/128 px PNG
enum CryptoIconProvider {
    
    /// Base raw URL for the repository
    private static let baseURL = "https://raw.githubusercontent.com/ErikThiart/cryptocurrency-icons/master"
    
    /// Available icon sizes
    enum IconSize: Int {
        case small = 16
        case medium = 32
        case large = 64
        case xlarge = 128
    }
    
    /// Get icon URL for a token symbol
    /// - Parameters:
    ///   - symbol: Token symbol (e.g. "BTC", "ETH")
    ///   - size: Icon size (default: 128)
    /// - Returns: URL string for the icon
    static func iconURL(for symbol: String, size: IconSize = .xlarge) -> String {
        let name = resolveIconName(for: symbol.uppercased())
        return "\(baseURL)/\(size.rawValue)/\(name).png"
    }
    
    /// Get icon URL, preferring an existing logoURL, falling back to this provider
    /// - Parameters:
    ///   - logoURL: Existing logo URL from API (may be nil or empty)
    ///   - symbol: Token symbol for fallback
    ///   - size: Icon size
    /// - Returns: Best available URL string
    static func bestIconURL(logoURL: String?, symbol: String, size: IconSize = .xlarge) -> String {
        if let logo = logoURL, !logo.isEmpty, URL(string: logo) != nil {
            return logo
        }
        return iconURL(for: symbol, size: size)
    }
    
    /// Resolve token symbol to repository icon file name
    /// The repository uses lowercase cryptocurrency names (e.g. "bitcoin", "ethereum")
    private static func resolveIconName(for symbol: String) -> String {
        // Check known mapping first
        if let name = symbolToName[symbol] {
            return name
        }
        // Fallback: use lowercase symbol itself (works for some coins)
        return symbol.lowercased()
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

// MARK: - SwiftUI View Extension

/// A reusable crypto icon view with automatic caching
/// Uses ImageCacheManager for memory + disk two-level cache
struct CryptoIconView: View {
    let symbol: String
    let logoURL: String?
    var size: CGFloat = 40
    
    var body: some View {
        let urlString = CryptoIconProvider.bestIconURL(
            logoURL: logoURL,
            symbol: symbol,
            size: iconSize
        )
        
        if let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } placeholder: {
                fallbackIcon
            }
        } else {
            fallbackIcon
        }
    }
    
    private var iconSize: CryptoIconProvider.IconSize {
        if size <= 16 { return .small }
        if size <= 32 { return .medium }
        if size <= 64 { return .large }
        return .xlarge
    }
    
    private var fallbackIcon: some View {
        Circle()
            .fill(symbolColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(String(symbol.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(symbolColor)
            )
    }
    
    /// Generate a consistent color based on the symbol
    private var symbolColor: Color {
        let hash = symbol.uppercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let colors: [Color] = [.blue, .purple, .orange, .green, .red, .pink, .indigo, .teal, .cyan, .mint]
        return colors[hash % colors.count]
    }
}
