# ticket_detail_page.dart bolme calismasi - ilerleme notu

Plan: `hidden-jingling-flask` (bkz. Claude Code plan gecmisi) - ozet: sayfa
6349 satir, tek `_TicketDetailPageState` icinde ~60 private build/action
metodu var. Regresyon guvencesi olmadan (hicbir test yoktu) davranis
degistirmeden, mekanik olarak kucuk widget'lara bolunuyor.

## Tamamlanan

### Adim 0 - Guvenlik agi
`test/pages/ticket_detail_page_smoke_test.dart` eklendi. `TicketDetailPage`'i
sahte Supabase URL'siyle acar, "Tekrar Dene" hata ekraninin cokmeden
gorundugunu dogrular. Sonraki her adimdan sonra bu test (ve genel
`flutter analyze` / `flutter test`) calistirilmali.

### Adim 1 - Saf yaprak widget'lari cikar
`lib/widgets/ticket_detail/ticket_detail_leaf_widgets.dart` eklendi.
Tasinanlar (eski adi -> yeni adi):

- `_buildMetaPill` -> `TicketDetailMetaPill`
- `_buildHeaderInfoPanel` -> `TicketDetailHeaderInfoPanel`
- `_buildHeaderActionButton` -> `TicketDetailHeaderActionButton`
- `_buildSummaryMetricCard` -> `TicketDetailSummaryMetricCard`
- `_buildDetailDisclosure` -> `TicketDetailDisclosure`
- `_buildDailyReportCard` -> `TicketDetailDailyReportCard`
- `_buildDropdown` -> `TicketDetailDropdown` (kullanilmiyor, oldugu gibi tasindi)
- `_buildCompactDropdown` -> `TicketDetailCompactDropdown` (`_isUpdating`
  yerine acik `updating`/`isDisabled` parametreleri alir)
- `_buildContentCard` -> `TicketDetailContentCard` (kullanilmiyor, oldugu gibi tasindi)
- `_buildModernContentCard` -> `TicketDetailModernContentCard`
- `_buildInfoRow` -> `TicketDetailInfoRow`
- `_buildTechMetricBox` -> `TicketDetailTechMetricBox`
- `_buildStatusChip` -> `TicketDetailStatusChip`
- `_buildDailyReportChip` -> `TicketDetailDailyReportChip`
- `_buildPriorityBadge` -> `TicketDetailPriorityBadge`

Renk/format yardimcilari (`_isDark`, `_surfaceColor`, `_borderColor`,
`_primaryTextColor`, `_secondaryTextColor`, `_corporatePanelColor`,
`_pageAccentColor`, `_formatDailyReportDate`) sayfada baska pek cok yerde
hala kullanildigi icin `ticket_detail_page.dart`'tan SILINMEDI; yeni
dosyada `ticketDetail*` on ekiyle kucuk (1-3 satir) top-level fonksiyon
kopyalari olusturuldu. Bu, riski dosyanin geri kalanina yaymamak icin
bilincli bir tercihti.

Sonuc: `ticket_detail_page.dart` 6349 -> 5646 satira (703 satir cikti,
davranis degisikligi olmadan). `flutter analyze` hatasiz (mevcut,
dokunulmamis 2 hata - `brand_models_settings_page.dart` - haric, onlar
bu calismadan once de vardi). Tam test suite (20 test) yesil.

## Yapilmadi (sonraki oturum/oturumlarda)

- **Adim 2**: State okuyan ama kendi setState'i olmayan ~18 tab/section
  metodunu (`_buildPartnerInfoBar`, `_buildDetailsTab`, `_buildNotesTab`,
  `_buildDailyReportsTab`, `_buildDocumentsTab`, `_buildTechnicalTab`,
  `_buildProjectDetailTab`, `_buildBackupStatusSummaryCard`,
  `_buildSummaryTab`, `_buildFaultRecordsSummaryCard`,
  `_buildTimelineSection`, `_buildProcessTimelineView`,
  `_buildLinkedFaultNotesCard`, `_buildLinkedFaultNoteItem`,
  `_buildProjectSummaryTab`, `_buildProcessTab`, `_buildPaperworkTab`,
  `_buildActivityLogTile`, `_buildHeaderSection`) StatelessWidget +
  callback'lerle `lib/widgets/ticket_detail/` altina cikarmak.
- **Adim 3**: Kendi `setState`'i olan 4 bolumu (`_buildServiceFormsSection`,
  `_buildRefinedHeaderSection`, `_buildPartsSection`,
  `_buildActivityLogsTab`) kendi local state'ini tutan bagimsiz
  `StatefulWidget`'lara cevirmek.
- **Adim 4**: `_buildNotesChatView` (yuksek coupling) ve `_buildBody`
  (orkestrator) - en son, `_TicketDetailPageState`'in ince bir
  koordinatore indirgenmesiyle tamamlanir.

## Bu arada fark edilen, ayrica notlanan (bu calismanin kapsami disinda)

- `_buildHeaderSection` (eski/basit header) artik hicbir yerden
  cagirilmiyor (`_buildRefinedHeaderSection` kullaniliyor) - `unused_element`
  uyarisi veriyor. Silinip silinmeyecegine ayri karar verilmeli.
- `_actionBackgroundColor` ve `_cleanTicketDescription` de kullanilmiyor -
  ayni sekilde.
- `_buildSignatureCard` icinde kullanilmayan bir `theme` degiskeni var
  (kucuk, zararsiz).
- Bunlarin hicbiri bu bolme calismasindan once de sonra da davranisi
  etkilemiyor; sadece temizlik firsati olarak not edildi.
