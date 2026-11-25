import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/features/exam/model/exam_models.dart';

void main() {
  test('parseAdminChoiceOptions mempertahankan gambar setiap opsi', () {
    const imageData = 'data:image/png;base64,AA==';
    final options = parseAdminChoiceOptions(<Map<String, dynamic>>[
      <String, dynamic>{
        'value': 'A',
        'label': 'Gambar A',
        'imageData': imageData,
      },
    ]);

    expect(options.single.value, 'A');
    expect(options.single.label, 'Gambar A');
    expect(options.single.imageData, imageData);
    expect(options.single.toJson()['imageData'], imageData);
  });
}
