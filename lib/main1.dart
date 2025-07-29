import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<void> pickPdfFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result != null && result.files.single.path != null) {
    final filePath = result.files.single.path!;
    final File file = File(filePath);
    final Uint8List bytes = await file.readAsBytes();

    // Cargar el documento PDF
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    // Extraer texto de la primera página (puedes iterar si quieres todo)
    final String text = PdfTextExtractor(document).extractText();

    print("Texto extraído del PDF:");
    print(text);

    // No olvides liberar los recursos
    document.dispose();
  } else {
    print("No se seleccionó ningún archivo.");
  }
}
