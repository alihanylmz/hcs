import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/quote.dart';
import '../utils/quote_calendar_events.dart';

/// Calisma masasindaki aylik takvim.
///
/// Gosterdigi tarihler teklif kayitlarindan TURETILIYOR: gecerlilik bitisi
/// (gonderim ya da olusturma tarihi + validityText) ve takip gunu (gonderim +
/// followUpDays). Kullanicinin ayrica tarih girmesi gerekmiyor; bu yuzden
/// bugunku veriyle bile dolu calisiyor.
class QuoteCalendarCard extends StatefulWidget {
  const QuoteCalendarCard({
    super.key,
    required this.quotes,
    required this.onQuoteTap,
    this.today,
  });

  final List<Quote> quotes;
  final ValueChanged<Quote> onQuoteTap;

  /// Testlerde sabitlemek icin; null ise bugun kullanilir.
  final DateTime? today;

  @override
  State<QuoteCalendarCard> createState() => _QuoteCalendarCardState();
}

class _QuoteCalendarCardState extends State<QuoteCalendarCard> {
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  static const _ink = Color(0xFF17304C);
  static const _slate = Color(0xFF5B6F7F);
  static const _expiryColor = Color(0xFFC2410C);
  static const _followColor = Color(0xFF2878B8);

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final byDay = groupEventsByDay(buildQuoteCalendarEvents(widget.quotes));
    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(_visibleMonth);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_rounded, size: 18, color: _ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('calendar-prev-month'),
                  tooltip: 'Onceki ay',
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  key: const ValueKey('calendar-next-month'),
                  tooltip: 'Sonraki ay',
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _legend(),
            const SizedBox(height: 10),
            _weekdayHeader(),
            const SizedBox(height: 4),
            _grid(byDay),
            if (_selectedDay != null) ...[
              const Divider(height: 24),
              _dayDetail(byDay[_selectedDay!] ?? const []),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: _slate)),
      ],
    );
    return Row(
      children: [
        dot(_expiryColor, 'Gecerlilik bitisi'),
        const SizedBox(width: 14),
        dot(_followColor, 'Takip gunu'),
      ],
    );
  }

  Widget _weekdayHeader() {
    const labels = ['Pt', 'Sa', 'Ca', 'Pe', 'Cu', 'Ct', 'Pz'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _slate,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(Map<DateTime, List<QuoteCalendarEvent>> byDay) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    // DateTime.weekday: Pazartesi 1 ... Pazar 7. Izgara Pazartesi ile
    // basladigi icin bastaki bos hucre sayisi dogrudan weekday - 1.
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _dayCell(DateTime(_visibleMonth.year, _visibleMonth.month, d), byDay),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = i + 7 <= cells.length ? i + 7 : cells.length;
      final slice = cells.sublist(i, end);
      rows.add(
        Row(
          children: [
            for (final c in slice) Expanded(child: c),
            // Son satir eksik kalirsa hucre genisligi bozulmasin diye doldur.
            for (var k = slice.length; k < 7; k++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _dayCell(DateTime day, Map<DateTime, List<QuoteCalendarEvent>> byDay) {
    final events = byDay[day] ?? const <QuoteCalendarEvent>[];
    final isToday = day == _today;
    final isSelected = day == _selectedDay;
    final hasExpiry = events.any(
      (e) => e.kind == QuoteCalendarEventKind.expiry,
    );
    final hasFollow = events.any(
      (e) => e.kind == QuoteCalendarEventKind.followUp,
    );

    return InkWell(
      key: ValueKey('calendar-day-${day.month}-${day.day}'),
      onTap: events.isEmpty
          ? null
          : () => setState(() => _selectedDay = isSelected ? null : day),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE3EAF2)
              : isToday
              ? const Color(0xFFF6F8FA)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: const Color(0xFF9FB4CC)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasExpiry) _dot(_expiryColor),
                if (hasExpiry && hasFollow) const SizedBox(width: 3),
                if (hasFollow) _dot(_followColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _dayDetail(List<QuoteCalendarEvent> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    final label = DateFormat('d MMMM', 'tr_TR').format(_selectedDay!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label - ${events.length} kayit',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        for (final e in events)
          InkWell(
            onTap: () => widget.onQuoteTap(e.quote),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _dot(
                    e.kind == QuoteCalendarEventKind.expiry
                        ? _expiryColor
                        : _followColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.quote.customerCompany.trim().isEmpty
                          ? e.quote.code
                          : e.quote.customerCompany.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _ink),
                    ),
                  ),
                  Text(
                    e.kind == QuoteCalendarEventKind.expiry
                        ? 'Gecerlilik'
                        : 'Takip',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: e.kind == QuoteCalendarEventKind.expiry
                          ? _expiryColor
                          : _followColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
