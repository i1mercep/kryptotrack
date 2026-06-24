function getCryptoSymbols() {
    return cryptoSymbols;
}

function getCryptoSymbol(coinId, coinSymbol) {
    var normalizedCoinId = String(coinId || "").trim().toLowerCase();
    var normalizedCoinSymbol = String(coinSymbol || "").trim().toLowerCase();

    if (normalizedCoinId !== "" && cryptoSymbols[normalizedCoinId]) {
        return cryptoSymbols[normalizedCoinId];
    }
    if (normalizedCoinSymbol !== "" && cryptoSymbolAliases[normalizedCoinSymbol]) {
        return cryptoSymbolAliases[normalizedCoinSymbol];
    }

    return "";
}

var cryptoSymbols = {
    "bitcoin": "₿",
    "ethereum": "Ξ",
    "solana": "◎",
    "tether": "₮",
    "litecoin": "Ł",
    "dogecoin": "Đ",
    "xrp": "✕",
    "zcash": "ⓩ",
    "cardano": "₳",
    "bitcoin-cash": "Ƀ",
    "monero": "ɱ",
    "iota": "ι",
    "peercoin": "₱",
    "primecoin": "Ψ",
    "namecoin": "₦",
    "stellar": "★",
    "nano": "Ñ",
    "vertcoin": "Ɏ",
    "gridcoin": "ǥ",
    "auroracoin": "Þ"
};

var cryptoSymbolAliases = {
    "btc": "₿",
    "eth": "Ξ",
    "sol": "◎",
    "usdt": "₮",
    "ltc": "Ł",
    "doge": "Đ",
    "xrp": "✕",
    "zec": "ⓩ",
    "ada": "₳",
    "bch": "Ƀ",
    "xmr": "ɱ",
    "miota": "ι",
    "ppc": "₱",
    "xpm": "Ψ",
    "nmc": "₦",
    "xlm": "★",
    "xno": "Ñ",
    "vtc": "Ɏ",
    "grc": "ǥ",
    "aur": "Þ"
};
