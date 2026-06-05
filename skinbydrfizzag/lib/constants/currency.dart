class CurrencyConstants {
  // Currency settings
  static const String defaultCurrencySymbol = 'AED';
  static const String defaultCurrencyCode = 'AED';
  static const String defaultCurrencyName = 'United Arab Emirates Dirham';
  
  // Conversion rates (relative to base currency)
  static const Map<String, double> exchangeRates = {
    'USD': 1.0,
    'EUR': 1.0,
    'GBP': 1.0,
    'AED': 1.0,
    'PKR': 1.0,
    'SAR': 1.0,
    'INR': 1.0,
  };

  // Format currency based on the selected currency
  static String formatCurrency(double amount, {String? currencyCode}) {
    final code = currencyCode ?? defaultCurrencyCode;
    final exchangeRate = exchangeRates[code] ?? 1.0;
    final convertedAmount = amount * exchangeRate;
    
    switch (code) {
      case 'AED':
        return 'AED ${convertedAmount.toStringAsFixed(2)}';
      case 'USD':
        return '\$${convertedAmount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${convertedAmount.toStringAsFixed(2)}';
      case 'GBP':
        return '£${convertedAmount.toStringAsFixed(2)}';
      case 'PKR':
        return 'Rs ${convertedAmount.toStringAsFixed(0)}';
      case 'SAR':
        return 'SAR ${convertedAmount.toStringAsFixed(2)}';
      case 'INR':
        return '₹${convertedAmount.toStringAsFixed(2)}';
      default:
        return '$code ${convertedAmount.toStringAsFixed(2)}';
    }
  }
}
