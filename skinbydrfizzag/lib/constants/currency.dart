class CurrencyConstants {
  // Currency settings
  static const String defaultCurrencySymbol = 'AED';
  static const String defaultCurrencyCode = 'AED';
  static const String defaultCurrencyName = 'United Arab Emirates Dirham';
  
  // Conversion rates (relative to USD)
  static const Map<String, double> exchangeRates = {
    'USD': 1.0,        // US Dollar
    'EUR': 0.93,       // Euro
    'GBP': 0.79,       // British Pound
    'AED': 3.67,       // UAE Dirham
    'PKR': 278.80,     // Pakistani Rupee
    'SAR': 3.75,       // Saudi Riyal
    'INR': 83.33,      // Indian Rupee
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
