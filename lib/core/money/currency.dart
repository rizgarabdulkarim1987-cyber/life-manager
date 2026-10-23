/// ISO 4217 minor-unit exponents for the currencies the app offers.
const kCurrencyExponents = {'IQD': 0, 'USD': 2, 'EUR': 2, 'GBP': 2, 'TRY': 2, 'JPY': 0, 'KWD': 3, 'BHD': 3, 'JOD': 3};

const kSeedCurrencies = ['IQD', 'USD'];

int currencyExponent(String code) => kCurrencyExponents[code] ?? 2;

BigInt pow10(int e) => BigInt.from(10).pow(e);
