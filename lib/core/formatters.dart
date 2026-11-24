import 'package:intl/intl.dart';

import 'config.dart';

/// Formatos de moneda y fecha con la librería `intl`.
class Fmt {
  const Fmt._();

  static final NumberFormat _money = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: AppConfig.currencySymbol,
    decimalDigits: 2,
  );
  static final DateFormat _date = DateFormat.yMMMd(AppConfig.currencyLocale);
  static final DateFormat _month = DateFormat.MMM(AppConfig.currencyLocale);

  static String money(num value) => _money.format(value);
  static String date(DateTime d) => _date.format(d);
  static String monthShort(DateTime d) => _month.format(d);
}
