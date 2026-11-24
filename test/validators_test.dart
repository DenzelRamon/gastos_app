import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/validators.dart';

void main() {
  group('email', () {
    test('acepta correos válidos', () {
      expect(Validators.email('ana@correo.com'), isNull);
      expect(Validators.email('  a.b+c@mail.co.mx '), isNull);
    });
    test('rechaza vacíos y mal formados', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('sin-arroba.com'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
  });

  group('password', () {
    test('acepta contraseña fuerte', () {
      expect(Validators.password('Segura123'), isNull);
    });
    test('rechaza débiles', () {
      expect(Validators.password('corta1A'), isNotNull);
      expect(Validators.password('sinmayuscula1'), isNotNull);
      expect(Validators.password('SINMINUSCULA1'), isNotNull);
      expect(Validators.password('SinNumeroAqui'), isNotNull);
    });
  });

  group('amount', () {
    test('acepta montos positivos', () {
      expect(Validators.amount('150'), isNull);
      expect(Validators.amount('99.50'), isNull);
    });
    test('rechaza cero, negativos y texto', () {
      expect(Validators.amount('0'), isNotNull);
      expect(Validators.amount('-5'), isNotNull);
      expect(Validators.amount('abc'), isNotNull);
      expect(Validators.amount(''), isNotNull);
    });
    // Regresión del hotfix: estos valores pasaban la validación local pero
    // Postgres los rechazaba y bloqueaba toda la sincronización.
    test('rechaza montos fuera del rango de la base de datos', () {
      expect(Validators.amount('1000000000'), isNotNull);
      expect(Validators.amount('99999999999999999999'), isNotNull);
      expect(Validators.amount('999999999.99'), isNull);
    });
    test('rechaza más de 2 decimales', () {
      expect(Validators.amount('1.999'), isNotNull);
      expect(Validators.amount('10.5'), isNull);
    });
    test('rechaza notación científica, NaN e Infinity', () {
      expect(Validators.amount('1e5'), isNotNull);
      expect(Validators.amount('Infinity'), isNotNull);
      expect(Validators.amount('NaN'), isNotNull);
      expect(Validators.amount('.5'), isNotNull);
      expect(Validators.amount('10.'), isNotNull);
    });
  });

  group('description / sanitize', () {
    test('colapsa espacios', () {
      expect(Validators.sanitize('  Tacos   al   pastor '), 'Tacos al pastor');
    });
    test('valida longitud', () {
      expect(Validators.description('a'), isNotNull);
      expect(Validators.description('Tacos'), isNull);
      expect(Validators.description('x' * 81), isNotNull);
    });
  });
}
