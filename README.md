# TripLedger (iOS)

Aplikasi iOS untuk mengelola pengeluaran trip bersama: catat pengeluaran, split bill (termasuk scan struk dengan OCR + AI), hitung utang-piutang antar anggota, dan selesaikan pembayaran (settlement) dengan bukti transfer.

## Teknologi

- **SwiftUI** + arsitektur **MVVM**
- **Firebase**: Authentication (email/password), Firestore (data), Storage (gambar)
- **Vision framework** untuk OCR struk + **OpenAI API** untuk parsing struk menjadi item terstruktur
- **Kingfisher** untuk cache gambar avatar
- **PDFKit** untuk laporan keuangan trip

## Arsitektur & Struktur Folder

```
TripLedger/
├── Models/          # Struct data murni (TripModel, ExpenseModel, SplitBillModel, ...)
├── Services/        # Akses backend & utilitas berat
│   ├── AuthService.swift          # Sign up/in, fetch user Firestore
│   ├── FirestoreService.swift     # CRUD generik Firestore + query khusus
│   ├── FirebaseStorageService.swift / StorageService.swift  # Upload gambar
│   ├── OCRService.swift           # Preprocessing gambar + Vision OCR
│   ├── AIService.swift            # Parsing struk via OpenAI (struk Indonesia)
│   └── PDFGenerator.swift / TripReportGenerator.swift  # Laporan PDF
├── ViewModels/      # @MainActor ObservableObject per fitur (TripViewModel, ExpenseViewModel, ...)
├── Views/           # SwiftUI views, dikelompokkan per fitur
│   ├── Auth/  Trips/  Expenses/  SplitBill/  Settlement/
│   ├── Friends/  Notifications/  Profile/  Admin/
│   └── Shared/      # Komponen reusable (lihat daftar di bawah)
└── Utilities/       # AppTheme, Extensions, BillSplitCalculator, AppLog, ...
```

**Batas MVVM:** View hanya menyimpan UI state (@State) dan memanggil ViewModel/Service; query Firestore tinggal di `Services/` dan `ViewModels/`. Kalkulasi pembagian uang terpusat di `Utilities/BillSplitCalculator.swift` — jangan duplikasi rumusnya di view.

**File besar dipecah dengan pola companion file:** view utama menyimpan deklarasi struct + @State + `body`, sedangkan bagian-bagian besar dipindah ke `extension` di file terpisah, misal `CreateSplitBillView+Steps.swift`, `+BagiRata.swift`, `+InputManual.swift`, `+Sheets.swift`. Ikuti pola ini kalau sebuah view mulai membengkak.

## Komponen Shared (pakai ini, jangan bikin ulang)

| Komponen | File | Kegunaan |
|---|---|---|
| `AvatarView` | Views/Shared/AvatarView.swift | Avatar lingkaran (KFImage + fallback inisial) |
| `ProgressHeader` | Views/Shared/ProgressHeader.swift | Bar progres step wizard |
| `ScanResultBanner` + `fieldSection` | Views/Shared/ScanResultBanner.swift | Banner hasil scan struk + section form berlabel |
| `TLTextField` / `TLSecureField` | Views/Shared/TLTextFields.swift | Text field bergaya aplikasi |
| `FlowLayout` | Views/Shared/FlowLayout.swift | Layout wrap untuk chip/tag |
| `ImagePicker`, `PhotoSourcePickerView` | Views/Shared/ | Ambil foto kamera/galeri |
| `BillSplitCalculator` | Utilities/BillSplitCalculator.swift | Rumus pembagian tagihan (lihat doc comment) |
| `AppLog.debug` | Utilities/AppLog.swift | Logging debug (otomatis hilang di build Release) |

## Konvensi

- **Warna & font**: selalu lewat `AppTheme.swift` (`Color.brandPrimary`, `AppFont.headline()`, dst). Jangan hardcode hex di view.
- **Format uang**: `Double.toCurrency(symbol:)` di `Extensions.swift`; input uang user diformat dengan `String.formattedAsCurrency()`.
- **Logging**: pakai `AppLog.debug(...)`, bukan `print(...)`.
- **API key OpenAI**: diisi lewat `Secrets.xcconfig` (lihat `Secrets.xcconfig.template`) — jangan commit key asli.

## Build

Buka `TripLedger.xcodeproj` di Xcode (dependensi via Swift Package Manager, otomatis ter-resolve), atau:

```bash
xcodebuild -project TripLedger.xcodeproj -scheme TripLedger \
  -destination 'generic/platform=iOS Simulator' build
```
