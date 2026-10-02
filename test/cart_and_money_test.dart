import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidgo_web/models/product.dart';
import 'package:rapidgo_web/models/shop.dart';
import 'package:rapidgo_web/services/cart_service.dart';
import 'package:rapidgo_web/services/config_service.dart';
import 'package:rapidgo_web/utils/cedula_formatter.dart';
import 'package:rapidgo_web/utils/money.dart';

const _shopA = Shop(id: 1, name: 'Arepera', isOpen: true);
const _shopB = Shop(id: 2, name: 'Cafetería', isOpen: true);

Product _p(int id, String price, {bool available = true}) => Product(
      id: id,
      kind: 'item',
      name: 'Producto $id',
      price: Money.parse(price),
      available: available,
    );

void main() {
  group('Money', () {
    test('parses the NUMERIC(14,2) strings the API sends', () {
      expect(Money.parse('12.30').cents, 1230);
      expect(Money.parse('0.05').cents, 5);
      expect(Money.parse('7').cents, 700);
      expect(Money.parse(null), Money.zero);
      expect(Money.parse('').cents, 0);
    });

    test('adds without float drift', () {
      var total = Money.zero;
      for (var i = 0; i < 10; i++) {
        total += Money.parse('0.10');
      }
      expect(total.toWire(), '1.00');
    });

    test('formats bolívares the Venezuelan way, wire format unchanged', () {
      expect(Money.parse('5').bs(), 'Bs 5,00');
      expect(Money.parse('1234.56').bs(), 'Bs 1.234,56');
      expect(Money(123456789).bs(), 'Bs 1.234.567,89');
      expect(Money.parse('1234.56').bs(symbol: false), '1.234,56');
      expect((Money.parse('3') - Money.parse('5')).bs(), '-Bs 2,00');

      expect(Money.parse('1234.56').toWire(), '1234.56');
      expect(Money.parse('5.5').toWire(), '5.50');
    });

    test('the USD estimate is display-only and never fakes a zero', () {
      final m = Money.parse('1000.00');
      expect(m.usdHint(1000), '≈ \$1.00');
      expect(m.usdEstimate(1000), '\$1.00');
      expect(m.usdHint(null), '');
      expect(m.usdHint(0), '');
      expect(Money.zero.usdHint(null), '');
    });

    test('parseInput accepts either convention', () {
      expect(Money.parseInput('1.234,56')!.cents, 123456);
      expect(Money.parseInput('1234.56')!.cents, 123456);
      expect(Money.parseInput('1234')!.cents, 123400);
      expect(Money.parseInput('1.234')!.cents, 123400);
      expect(Money.parseInput('Bs 2.500,00')!.cents, 250000);
      expect(Money.parseInput(''), isNull);
      expect(Money.parseInput('abc'), isNull);
    });
  });

  group('CartService', () {
    test('totals the lines', () {
      final cart = CartService();
      addTearDown(cart.dispose);

      cart.add(_shopA, _p(1, '2.50'), qty: 2);
      cart.add(_shopA, _p(2, '1.25'));
      expect(cart.total.toWire(), '6.25');
      expect(cart.itemCount, 3);
    });

    test('refuses a second shop instead of silently mixing them', () {
      final cart = CartService();
      addTearDown(cart.dispose);

      cart.add(_shopA, _p(1, '2.00'));
      expect(cart.add(_shopB, _p(9, '3.00')), 'switch_shop');
      expect(cart.shop?.id, 1);
    });

    test('caps quantity per product', () {
      final cart = CartService();
      addTearDown(cart.dispose);

      final product = _p(1, '1.00');
      cart.add(_shopA, product, qty: CartService.maxQtyPerProduct);
      expect(cart.add(_shopA, product), isNotNull);
      expect(cart.qtyOf(1), CartService.maxQtyPerProduct);
    });

    test('keeps one idempotency key until it is consumed', () {
      final cart = CartService();
      addTearDown(cart.dispose);

      final first = cart.idempotencyKey;
      expect(cart.idempotencyKey, first, reason: 'a retry must reuse the key');

      cart.consumeIdempotencyKey();
      expect(cart.idempotencyKey, isNot(first));
    });

    test('reconcile drops items the shop 86d and adopts new prices', () {
      final cart = CartService();
      addTearDown(cart.dispose);

      cart.add(_shopA, _p(1, '2.00'));
      cart.add(_shopA, _p(2, '3.00'));

      final changed = cart.reconcile([_p(1, '2.50'), _p(2, '3.00', available: false)]);

      expect(cart.qtyOf(2), 0, reason: 'unavailable item is removed');
      expect(cart.total.toWire(), '2.50', reason: 'new price is adopted');
      expect(changed.length, 2);
    });

    test('clearing the last line clears the shop', () {
      final cart = CartService();
      addTearDown(cart.dispose);

      cart.add(_shopA, _p(1, '2.00'));
      cart.remove(1);
      expect(cart.isEmpty, isTrue);
      expect(cart.shop, isNull);
    });
  });

  group('CedulaInputFormatter', () {
    const f = CedulaInputFormatter();

    TextEditingValue type(String previous, String next) => f.formatEditUpdate(
          TextEditingValue(text: previous),
          TextEditingValue(text: next),
        );

    test('adds V- when the customer just types digits', () {
      expect(type('', '1').text, 'V-1');
      expect(type('V-1', 'V-12').text, 'V-12');
      expect(type('V-1234567', 'V-12345678').text, 'V-12345678');
    });

    test('respects an explicit prefix letter', () {
      expect(type('', 'E').text, 'E-');
      expect(type('E-', 'E-1234567').text, 'E-1234567');
      expect(type('', 'j12345678').text, 'J-12345678');
    });

    test('tolerates a pasted value in any shape', () {
      expect(type('', 'V12345678').text, 'V-12345678');
      expect(type('', 'v-12.345.678').text, 'V-12345678');
    });

    test('caps the digits and keeps the caret at the end', () {
      final v = type('V-1234567890', 'V-123456789012');
      expect(v.text, 'V-1234567890');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('deleting back past the dash clears the field', () {
      expect(type('V-1', 'V-').text, '');
    });

    test('normalize and isComplete agree with the server format', () {
      expect(CedulaInputFormatter.normalize(' v12345678 '), 'V-12345678');
      expect(CedulaInputFormatter.isComplete('V-12345678'), isTrue);
      expect(CedulaInputFormatter.isComplete('V-123'), isFalse);
      expect(CedulaInputFormatter.isComplete('12345678'), isFalse);
    });
  });

  group('RapidGoConfig fee preview', () {
    const config = RapidGoConfig(serviceFeePct: 1);

    test('matches the server: integer cents, half-up', () {
      expect(config.feeFor(Money.parse('18.50')).toWire(), '0.19');
      expect(config.feeFor(Money.parse('10.00')).toWire(), '0.10');
      expect(config.totalFor(Money.parse('18.50')).toWire(), '18.69');
    });

    test('no fee configured means no fee line', () {
      expect(RapidGoConfig.fallback.hasFee, isFalse);
      expect(RapidGoConfig.fallback.feeFor(Money.parse('50.00')), Money.zero);
    });

    test('never charges more than the food costs', () {
      const silly = RapidGoConfig(serviceFeePct: 500);
      final subtotal = Money.parse('2.00');
      expect(config.feeFor(Money.zero), Money.zero);
      expect(silly.feeFor(subtotal) <= subtotal, isTrue);
    });
  });
}
