import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/persian_numbers.dart';
import '../../core/utils/relation_labels.dart';
import '../models/entry.dart';
import '../models/franchise.dart';
import '../models/watch_status.dart';
import '../storage/economy.dart';
import '../storage/migrations.dart';
import '../storage/user_extras.dart';

/// گزارش PDF یک فرنچایز: راست‌به‌چپ با فونت وزیرمتن.
///
/// فونت‌ها با [PdfGoogleFonts] در اولین اجرا از اینترنت دانلود و بعد
/// کش می‌شوند، پس اولین خروجی PDF به اینترنت نیاز دارد.
Future<Uint8List> buildFranchisePdf(
  Franchise f, {
  required Map<String, WatchStatus> statuses,
  required Map<String, Set<int>> episodes,
  required UserExtras extras,
}) async {
  final regular = await PdfGoogleFonts.vazirmatnRegular();
  final bold = await PdfGoogleFonts.vazirmatnBold();
  final frating = Economy(Hive.box<String>(Boxes.meta)).fratingOf(f.id);
  final franchiseNote = extras.noteOf(f.id);

  final byId = <String, Entry>{for (final e in f.entries) e.id: e};

  int watchedCount(Entry e) {
    if (statuses[e.id] == WatchStatus.completed) {
      return e.episodes > 0 ? e.episodes : 1;
    }
    final set = episodes[e.id];
    if (set == null || set.isEmpty || e.episodes <= 0) return 0;
    return set.where((n) => n >= 1 && n <= e.episodes).length;
  }

  int episodeNoteCount(Entry e) {
    var n = 0;
    for (var i = 1; i <= e.episodes; i++) {
      final note = extras.episodeNoteOf(e.id, i);
      if (note != null && note.isNotEmpty) n++;
    }
    return n;
  }

  /// عمق هر اثر در درخت روابط (از روی زنجیره‌ی parentEntryId).
  int depthOf(Entry e) {
    var d = 0;
    var cur = e;
    while (cur.parentEntryId != null && byId.containsKey(cur.parentEntryId)) {
      d++;
      cur = byId[cur.parentEntryId]!;
      if (d > 20) break; // محافظت در برابر حلقه‌ی رابطه‌ای
    }
    return d;
  }

  final byYear = [...f.entries]
    ..sort((a, b) => (a.year ?? 99999).compareTo(b.year ?? 99999));

  var totalEpisodes = 0;
  var doneEpisodes = 0;
  var totalMinutes = 0;
  for (final e in f.entries) {
    final w = watchedCount(e);
    totalEpisodes += e.episodes;
    doneEpisodes += w;
    totalMinutes += w * e.durationMin;
  }
  final donePct = totalEpisodes == 0
      ? 0
      : (doneEpisodes * 100 / totalEpisodes).round();

  final titleStyle = pw.TextStyle(font: bold, fontSize: 20);
  final sectionStyle = pw.TextStyle(font: bold, fontSize: 14);
  final entryTitleStyle = pw.TextStyle(font: bold, fontSize: 12);
  final bodyStyle = pw.TextStyle(fontSize: 11);
  final metaStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey);

  pw.Widget sectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(t, style: sectionStyle),
  );

  String epLabel(Entry e) =>
      e.episodes > 0 ? '${toFa(e.episodes)} قسمت' : 'تعداد نامشخص';

  pw.Widget entryLines(Entry e) {
    final done = watchedCount(e);
    final pct = e.episodes > 0 ? (done * 100 / e.episodes).round() : 0;
    final uscore = extras.scoreOf(e.id);
    final notes = episodeNoteCount(e);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(e.title, style: entryTitleStyle),
        pw.SizedBox(height: 2),
        pw.Text(
          '${e.type.labelFa} · ${epLabel(e)} · وضعیت: '
          '${statuses[e.id]?.labelFa ?? 'بدون وضعیت'} · '
          'پیشرفت: ${toFa(pct)}٪',
          style: metaStyle,
        ),
        pw.Text(
          'امتیاز من: ${uscore == null ? '—' : toFa(uscore.toStringAsFixed(1))}'
          '${notes > 0 ? ' · یادداشت قسمت‌ها: ${toFa(notes)}' : ''}',
          style: metaStyle,
        ),
      ],
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (ctx) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey),
            ),
          ),
          child: pw.Text(
            'Aurora · گزارش مجموعه',
            style: pw.TextStyle(font: bold, fontSize: 10),
          ),
        ),
      ),
      footer: (ctx) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(
          'صفحه‌ی ${toFa(ctx.pageNumber)} از ${toFa(ctx.pagesCount)}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (ctx) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── سربرگ ──
              pw.Text(f.titleFa, style: titleStyle),
              pw.SizedBox(height: 4),
              pw.Text(
                f.titleEn,
                textDirection: pw.TextDirection.ltr,
                style: bodyStyle,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'سال: ${f.year == 0 ? '—' : toFa(f.year)} · '
                'امتیاز AniList: ${f.score <= 0 ? '—' : toFa(f.score.toStringAsFixed(1))}'
                '${f.malScore != null ? ' · امتیاز MAL: ${toFa(f.malScore!.toStringAsFixed(1))}' : ''}',
                style: bodyStyle,
              ),
              pw.Text(
                'امتیاز من به مجموعه: ${frating == null ? '—' : '${toFa(frating)} از ${toFa(10)}'}',
                style: bodyStyle,
              ),
              if (f.synopsis.isNotEmpty) ...[
                sectionTitle('خلاصه داستان'),
                pw.Text(f.synopsis, style: bodyStyle),
              ],
              if (franchiseNote != null && franchiseNote.trim().isNotEmpty) ...[
                sectionTitle('یادداشت من'),
                pw.Text(franchiseNote, style: bodyStyle),
              ],

              // ── درخت روابط ──
              sectionTitle('درخت روابط'),
              for (final e in f.entries)
                pw.Padding(
                  padding: pw.EdgeInsets.only(right: depthOf(e) * 14.0),
                  child: pw.Text(
                    '${depthOf(e) > 0 ? '↳ ' : ''}${e.title}'
                    '${e.relationType != null && e.relationType!.isNotEmpty ? ' (${relationLabelFa(e.relationType)})' : ''}'
                    '${e.year != null ? ' · ${toFa(e.year!)}' : ''}',
                    style: bodyStyle,
                  ),
                ),

              // ── ترتیب تماشا (بر اساس سال) ──
              sectionTitle('ترتیب تماشا (پیشنهادی: بر اساس سال انتشار)'),
              for (var i = 0; i < byYear.length; i++)
                pw.Text(
                  '${toFa(i + 1)}. ${byYear[i].title}'
                  '${byYear[i].year != null ? ' (${toFa(byYear[i].year!)})' : ''}',
                  style: bodyStyle,
                ),

              // ── وضعیت هر اثر ──
              sectionTitle('وضعیت آثار'),
              for (var i = 0; i < f.entries.length; i++) ...[
                entryLines(f.entries[i]),
                if (i < f.entries.length - 1) pw.Divider(),
              ],

              // ── آمار ──
              sectionTitle('آمار'),
              pw.Text(
                'تعداد آثار: ${toFa(f.entries.length)} · '
                'مجموع قسمت‌ها: ${toFa(totalEpisodes)} · '
                'دیده‌شده: ${toFa(doneEpisodes)} (${toFa(donePct)}٪)',
                style: bodyStyle,
              ),
              pw.Text(
                'زمان تماشای ثبت‌شده: ${toFa(totalMinutes)} دقیقه',
                style: bodyStyle,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
