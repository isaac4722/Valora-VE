/// Tests del sistema de generación de PDF e imágenes (v31): la revisión
/// integral del dueño exigía una exportación «completa, robusto y corregido,
/// con buen maquetado y formato profesional».
///
/// Cubre:
/// · VePdfFonts: las fuentes de marca cargan del asset (y degradan a null
///   sin romper, no con excepción).
/// · buildConstanciaPdf: documento VÁLIDO (firma %PDF + %%EOF), con
///   paginación REAL (tabla larga → varias hojas) y cero compras sin morir.
/// · Convención única de rasterizado: TODOS los PNG compartibles salen a
///   1080 px de ancho con su proporción correcta — tarjeta del conversor
///   1080×1080, tarjeta de pago móvil 1080×1080 y constancia 1080×1350
///   (4:5) — medidas leídas del IHDR del PNG real, no promesas.
/// · pdfFormat: errores en cristiano (build que revienta o devuelve null
///   → «No pude generar el PDF», jamás una excepción sin tratar).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/features/statement/constancia_pdf.dart';
import 'package:valorave/features/statement/statement_screen.dart'
    show StatementDoc, constanciaPngCanvas;
import 'package:valorave/services/pdf_fonts.dart';
import 'package:valorave/widgets/export_sheet.dart';
import 'package:valorave/widgets/share_card.dart';

/// Lee el tamaño real del PNG desde su IHDR (big-endian, bytes 16..23).
(int, int) pngSize(Uint8List b) => (
      (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19],
      (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23],
    );

/// Compra mínima para armar períodos con contenido.
Purchase _compra(int dia, String tienda, double usd) => Purchase(
      id: 'c$dia',
      date: DateTime(2026, 9, dia),
      store: tienda,
      items: const [],
      totalUSD: usd,
      totalBS: usd * 900,
      rate: 900,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VePdfFonts (v31 · fuentes de marca para PDF)', () {
    test('las cinco fuentes de marca cargan del asset', () async {
      final f = await VePdfFonts.load();
      // En el entorno de test el bundle sirve los assets reales: las
      // fuentes de marca deben estar disponibles para el PDF.
      expect(f.inter, isNotNull, reason: 'Inter Regular');
      expect(f.interSemiBold, isNotNull, reason: 'Inter SemiBold');
      expect(f.interBold, isNotNull, reason: 'Inter Bold');
      expect(f.grotesk, isNotNull, reason: 'SpaceGrotesk Medium');
      expect(f.groteskBold, isNotNull, reason: 'SpaceGrotesk Bold');
      // Los estilos llevan la fuente puesta (tipografía consistente).
      expect(f.body(size: 11).font, same(f.inter));
      expect(f.caps(size: 11).font, same(f.interSemiBold));
      expect(f.num(size: 30).font, same(f.groteskBold));
    });

    test('la carga se cachea: segunda llamada no repite el trabajo', () async {
      final a = await VePdfFonts.load();
      final b = await VePdfFonts.load();
      expect(identical(a, b), isTrue);
    });
  });

  group('buildConstanciaPdf (v31 · PDF profesional de la constancia)', () {
    test('documento válido: firma %PDF, cierre %%EOF y cuerpo sustancial',
        () async {
      final doc = await buildConstanciaPdf(
        scopeLabel: 'Mensual',
        label: 'sep 2026',
        purchases: [_compra(3, 'Bodega La Esquina', 12.5)],
      );
      final bytes = await doc.save();
      final s = String.fromCharCodes(bytes.take(8));
      expect(s, startsWith('%PDF'), reason: 'firma del documento');
      expect(
        String.fromCharCodes(bytes.sublist(bytes.length - 8)),
        endsWith('%%EOF\n'),
        reason: 'cierre del documento',
      );
      // Con las fuentes de marca embebidas (subsets de Inter +
      // SpaceGrotesk) el cuerpo es sustancial.
      expect(bytes.length, greaterThan(5000));
    });

    test('cero compras: el documento sale igual (no muere en vacío)',
        () async {
      final doc = await buildConstanciaPdf(
        scopeLabel: 'Anual',
        label: '2026',
        purchases: const [],
      );
      final bytes = await doc.save();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    });

    test('paginación real: muchas tiendas → varias hojas', () async {
      final muchas = [
        for (var i = 1; i <= 60; i++)
          _compra((i % 27) + 1, 'Tienda número $i de la prueba', 9.99),
      ];
      final doc = await buildConstanciaPdf(
        scopeLabel: 'Anual',
        label: '2026',
        purchases: muchas,
      );
      await doc.save();
      // El MultiPage reparte la tabla: el footer «Página n» existe porque
      // hay más de una hoja que numerar (cuenta real del PdfDocument).
      expect(
        doc.document.pdfPageList.pages.length,
        greaterThan(1),
        reason: 'la tabla larga salta de página (cabecera repetida)',
      );
    });
  });

  group('pdfFormat (v31 · errores en cristiano)', () {
    test('build que revienta → mensaje humano, no excepción', () async {
      final fmt = pdfFormat(
        hint: 'prueba',
        fileName: 'x.pdf',
        build: () async => throw Exception('boom de fuentes'),
      );
      final msg = await fmt.run(ExportMode.compartir);
      expect(msg, 'No pude generar el PDF. Intenta de nuevo.');
    });

    test('build que devuelve null → mensaje humano', () async {
      final fmt = pdfFormat(
        hint: 'prueba',
        fileName: 'x.pdf',
        build: () async => null,
      );
      final msg = await fmt.run(ExportMode.guardar);
      expect(msg, 'No pude generar el PDF. Intenta de nuevo.');
    });

    test('build sano → el PDF viaja entero (compartir en test sin plugin)',
        () async {
      final fmt = pdfFormat(
        hint: 'prueba',
        fileName: 'constancia.pdf',
        build: () async {
          final doc = await buildConstanciaPdf(
            scopeLabel: 'Mensual',
            label: 'sep 2026',
            purchases: [_compra(2, 'Ferretería Central', 45)],
          );
          return await doc.save();
        },
      );
      // Sin plugin de share en el host de tests, sharePdf lanza: el
      // contrato de la HOJA es capturarlo y avisar (try/catch de
      // showExportSheet) — aquí se documenta que el PDF SÍ se generó y
      // que el fallo es solo del canal nativo.
      final msg = await fmt.run(ExportMode.compartir).then<String?>(
        (ok) => ok,
        onError: (_) => 'capturado por la hoja (PDF generado)',
      );
      expect(msg, 'capturado por la hoja (PDF generado)');
    });
  });

  group('Convención única de rasterizado (v31 · 360 lógico ×3 → 1080 px)',
      () {
    testWidgets('tarjeta del conversor: PNG 1080×1080 real', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData(), home: const Scaffold()),
      );
      Uint8List? png;
      var done = false;
      renderConversionSharePng(
        tester.element(find.byType(Scaffold)),
        from: Currency.usd,
        to: Currency.ves,
        inputAmount: 10,
        resultAmount: 9225.63,
        rateLine: '1 USD = 922,5637 Bs',
        sourceLabel: 'BCV · Oficial',
        date: DateTime(2026, 9, 17),
      ).then((v) {
        png = v;
        done = true;
      });
      for (var i = 0; i < 6 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() async {
        var guard = 0;
        while (!done && guard++ < 200) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(png, isNotNull, reason: 'la generación no puede fallar');
      expect(pngSize(png!), (1080, 1080),
          reason: 'cuadrada exacta a 1080 físicos');
      // La firma PNG vive al inicio.
      expect(png![0], 0x89);
      await tester.pump();
      expect(find.byType(ConversionShareCard), findsNothing);
    });

    testWidgets('tarjeta de pago móvil: PNG 1080×1080 real', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData(), home: const Scaffold()),
      );
      final account = PayAccount(
        id: 'a1',
        kind: PayAccountKind.pagoMovil,
        bank: 'Banco de Venezuela',
        docId: 'V12345678',
        phone: '04141234567',
        label: 'Principal',
      );
      Uint8List? png;
      var done = false;
      renderPagoMovilSharePng(
        tester.element(find.byType(Scaffold)),
        montoBs: 1250.5,
        account: account,
      ).then((v) {
        png = v;
        done = true;
      });
      for (var i = 0; i < 6 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() async {
        var guard = 0;
        while (!done && guard++ < 200) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(png, isNotNull);
      expect(pngSize(png!), (1080, 1080));
      await tester.pump();
      expect(find.byType(PagoMovilShareCard), findsNothing);
    });

    testWidgets('constancia: PNG 1080×1350 (4:5) real', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: ThemeData(), home: const Scaffold()),
        ),
      );
      Uint8List? png;
      var done = false;
      // El render arranca en la zona fake-async (los endOfFrame avanzan
      // con los pumps); la rasterización toImage termina en el event loop
      // real del runAsync de abajo — mismo patrón del sharing_test.
      renderOffstagePngForTest(
        tester.element(find.byType(Scaffold)),
        constanciaPngCanvas(
          StatementDoc(
            label: 'sep 2026',
            scopeLabel: 'Mensual',
            purchases: [_compra(3, 'Bodega La Esquina', 12.5)],
          ),
        ),
      ).then((v) {
        png = v;
        done = true;
      });
      for (var i = 0; i < 6 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() async {
        var guard = 0;
        while (!done && guard++ < 200) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(png, isNotNull, reason: 'la generación no puede fallar');
      final (w, h) = pngSize(png!);
      expect(w, 1080, reason: 'ancho de la convención');
      expect(h, 1350, reason: '4:5 exacto: 360×450 lógicos × 3');
    });
  });
}

/// Puente de test: rasteriza un documento offstage con la tubería real
/// (la convención v31 de 360 lógico → 1080 px).
Future<Uint8List?> renderOffstagePngForTest(BuildContext context, Widget doc) {
  return renderSharePng(context, (_) => doc);
}
