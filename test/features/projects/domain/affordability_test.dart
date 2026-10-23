import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/projects/domain/affordability.dart';

void main() {
  Affordability calc(int cost, int avail, int avg) =>
      computeAffordability(costBaseMinor: cost, investmentAvailableMinor: avail, avgMonthlyAllocationMinor: avg);

  test('a bucket that covers the cost leaves nothing missing and needs no months', () {
    expect(calc(1000, 5000, 100), (remainingMinor: 0, months: 0));
  });

  test('exactly the cost is covered', () {
    expect(calc(5000, 5000, 0), (remainingMinor: 0, months: 0));
  });

  test('the gap is divided by the monthly pace and rounded up', () {
    expect(calc(10000, 4000, 2000), (remainingMinor: 6000, months: 3));
    expect(calc(10000, 4000, 2500), (remainingMinor: 6000, months: 3));
    expect(calc(10001, 4000, 3000), (remainingMinor: 6001, months: 3));
  });

  test('with no monthly pace the months stay unknown', () {
    expect(calc(10000, 4000, 0), (remainingMinor: 6000, months: null));
  });

  test('a negative bucket counts the overdraw as missing', () {
    expect(calc(1000, -500, 500), (remainingMinor: 1500, months: 3));
  });
}
