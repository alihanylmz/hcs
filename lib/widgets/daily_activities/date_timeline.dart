import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class DateTimeline extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateTimeline({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DateTimeline> createState() => _DateTimelineState();
}

class _DateTimelineState extends State<DateTimeline> {
  late ScrollController _scrollController;
  final double _itemWidth = 60.0;
  final double _spacing = 12.0;
  
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _generateDates(widget.selectedDate);
    
    // İlk açılışta seçili tarihe kaydır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant DateTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Tarih değiştiğinde:
    // 1. Eğer tarih mevcut listenin çok dışındaysa listeyi yeniden oluştur.
    // 2. Liste içindeyse sadece kaydır.
    
    bool needsRegen = !_dates.any((d) => _isSameDay(d, widget.selectedDate));
    
    if (needsRegen) {
      _generateDates(widget.selectedDate);
      // Rebuild sonrası kaydırma yap
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected(animate: false);
      });
    } else if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _scrollToSelected(animate: true);
    }
  }

  void _generateDates(DateTime centerDate) {
    // Seçili tarihin 15 gün öncesi ve 15 gün sonrasını içeren bir liste (31 gün)
    // Böylece kullanıcı sağa sola kaydırarak gezinebilir
    _dates = List.generate(31, (index) => centerDate.subtract(const Duration(days: 15)).add(Duration(days: index)));
  }

  void _scrollToSelected({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final index = _dates.indexWhere((d) => _isSameDay(d, widget.selectedDate));
    if (index == -1) return;

    // Ekranın ortasına gelmesi için hesaplama
    final screenWidth = MediaQuery.of(context).size.width;
    final itemTotalWidth = _itemWidth + _spacing;
    // Padding (20) ve eleman yarısını hesaba katarak ortala
    final targetOffset = (index * itemTotalWidth) + 20 - (screenWidth / 2) + (_itemWidth / 2);

    // Sınırları kontrol et (negatif offset olamaz)
    final double safeOffset = targetOffset < 0 ? 0 : targetOffset;

    if (animate) {
      _scrollController.animateTo(
        safeOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(safeOffset);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ay Göstergesi ve Kontroller
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tıklanabilir Ay/Yıl Başlığı
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: widget.selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                      locale: const Locale('tr', 'TR'),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.corporateNavy,
                              onPrimary: Colors.white,
                              onSurface: AppColors.textDark,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) widget.onDateSelected(date);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy', 'tr_TR').format(widget.selectedDate).toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),

                // Bugün Butonu (Sadece bugün seçili değilse göster)
                if (!_isSameDay(widget.selectedDate, DateTime.now()))
                  TextButton.icon(
                    onPressed: () => widget.onDateSelected(DateTime.now()),
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Bugün'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.corporateNavy,
                      backgroundColor: AppColors.primary.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, __) => SizedBox(width: _spacing),
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isSelected = _isSameDay(date, widget.selectedDate);
                final isToday = _isSameDay(date, DateTime.now());
                
                return GestureDetector(
                  onTap: () => widget.onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _itemWidth,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.primary.withOpacity(0.07) : AppColors.backgroundGrey),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.transparent 
                            : (isToday ? AppColors.primary.withOpacity(0.25) : AppColors.primary.withOpacity(0.08)),
                        width: isToday && !isSelected ? 1.2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.22),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE', 'tr_TR').format(date),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : (isToday ? AppColors.primary : AppColors.textLight),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : (isToday ? AppColors.textDark : AppColors.textDark),
                              ),
                            ),
                            // Bugün ise minik nokta koy
                            if (isToday)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
