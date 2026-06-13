class CurrencyUtils {
  static const Map<String, String> _symbolMap = {
    'INR': '₹',
    'EUR': '€',
    'USD': '\$',
    'GBP': '£',
    'JPY': '¥',
    'AED': 'د.إ',
    'SGD': 'S\$',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'CHF',
    'CNY': '¥',
    'NZD': 'NZ\$',
  };

  static const Map<String, double> exchangeRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'INR': 83.5,
    'GBP': 0.79,
    'JPY': 157.0,
    'AED': 3.67,
    'SGD': 1.35,
    'AUD': 1.51,
    'CAD': 1.37,
    'CHF': 0.90,
    'CNY': 7.24,
    'NZD': 1.63,
  };

  /// Converts an amount from one currency to another using the predefined exchange rates.
  static double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency.toUpperCase().trim() == toCurrency.toUpperCase().trim()) {
      return amount;
    }
    final fromRate = exchangeRates[fromCurrency.toUpperCase().trim()] ?? 1.0;
    final toRate = exchangeRates[toCurrency.toUpperCase().trim()] ?? 1.0;
    // Base is USD: convert to USD first, then to target currency
    final amountInUsd = amount / fromRate;
    return amountInUsd * toRate;
  }

  /// Returns the corresponding symbol for an ISO currency code, falling back to the code itself.
  static String symbolFor(String code) {
    final normalized = code.toUpperCase().trim();
    return _symbolMap[normalized] ?? normalized;
  }

  /// Formats an amount with the correct symbol based on the currency code.
  static String format(double amount, String code) {
    final symbol = symbolFor(code);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Returns a flag emoji corresponding to the currency code if charted.
  static String flagEmojiFor(String code) {
    switch (code.toUpperCase().trim()) {
      case 'INR': return '🇮🇳';
      case 'EUR': return '🇪🇺';
      case 'USD': return '🇺🇸';
      case 'GBP': return '🇬🇧';
      case 'JPY': return '🇯🇵';
      case 'AED': return '🇦🇪';
      case 'SGD': return '🇸🇬';
      case 'AUD': return '🇦🇺';
      case 'CAD': return '🇨🇦';
      case 'CHF': return '🇨🇭';
      case 'CNY': return '🇨🇳';
      case 'NZD': return '🇳🇿';
      default: return '🏳️';
    }
  }
}
