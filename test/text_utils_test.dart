import 'package:breach_checker/utils/formatters.dart';
import 'package:breach_checker/utils/html_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlText.toPlainText', () {
    test('removes tags but keeps their text', () {
      const html = 'Passwords were <em>encrypted</em> and '
          '<a href="https://example.com" target="_blank">disclosed</a>.';
      expect(HtmlText.toPlainText(html), 'Passwords were encrypted and disclosed.');
    });

    test('decodes named and numeric entities', () {
      expect(HtmlText.toPlainText('Tom &amp; Jerry&#39;s &quot;site&quot;'), 'Tom & Jerry\'s "site"');
      expect(HtmlText.toPlainText('caf&#xE9;'), 'café');
    });

    test('encoded tags become visible text, not markup', () {
      expect(HtmlText.toPlainText('&lt;script&gt;x&lt;/script&gt;'), '<script>x</script>');
    });

    test('turns breaks and paragraphs into line breaks', () {
      expect(HtmlText.toPlainText('One<br>Two<br/>Three'), 'One\nTwo\nThree');
      expect(HtmlText.toPlainText('<p>First</p><p>Second</p>'), 'First\nSecond');
    });

    test('collapses whitespace and leaves unknown entities alone', () {
      expect(HtmlText.toPlainText('  a \t  b  &bogus; '), 'a b &bogus;');
    });
  });

  group('Formatters', () {
    test('date', () {
      expect(Formatters.date(DateTime(2013, 10, 4)), '4 Oct 2013');
      expect(Formatters.date(DateTime(2024, 1, 31)), '31 Jan 2024');
    });

    test('count adds thousands separators', () {
      expect(Formatters.count(0), '0');
      expect(Formatters.count(999), '999');
      expect(Formatters.count(1000), '1,000');
      expect(Formatters.count(152445165), '152,445,165');
      expect(Formatters.count(-1234567), '-1,234,567');
    });
  });
}
