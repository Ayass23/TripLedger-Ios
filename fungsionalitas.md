# DOKUMENTASI FUNGSIONALITAS APLIKASI TRIPLEDGER

---

## I. AUTENTIKASI & AKSES

### 1. Menampilkan halaman welcome screen

* Aktor: Umum
* Keterangan:
  * Menampilkan halaman welcome dengan logo dan informasi aplikasi
  * Tombol untuk login atau registrasi

### 2. Melakukan registrasi akun baru (Sign Up)

* Aktor: User
* Keterangan:
  * Pengguna mengisi nama lengkap, email, dan password untuk membuat akun baru
  * Sistem membuat dokumen user di Firestore setelah registrasi berhasil
  * Auto-login setelah registrasi berhasil

### 3. Menampilkan pesan error jika email sudah terdaftar

* Aktor: Sistem
* Keterangan:
  * Sistem melakukan validasi ke Firebase Authentication
  * Jika email sudah digunakan, tampilkan pesan error "Email sudah terdaftar"

### 4. Menampilkan pesan error jika format email/password salah

* Aktor: Sistem
* Keterangan:
  * Sistem melakukan validasi form registrasi
  * Email harus mengandung @ dan format valid
  * Password minimal 6 karakter
  * Password confirmation harus cocok
  * Border field berubah merah jika error

### 5. Menampilkan validasi real-time saat mengisi form registrasi

* Aktor: Sistem
* Keterangan:
  * Validasi nama tidak boleh kosong
  * Validasi email format
  * Validasi password minimal 6 karakter
  * Validasi konfirmasi password cocok
  * Error muncul inline di bawah field

### 6. Melakukan login ke aplikasi

* Aktor: User
* Keterangan:
  * Pengguna memasukkan email dan password
  * Sistem memvalidasi kredensial via Firebase Authentication
  * Session tersimpan otomatis (remember login)

### 7. Menampilkan pesan error jika email atau password salah

* Aktor: Sistem
* Keterangan:
  * Error spesifik: "Email tidak ditemukan" atau "Password salah"
  * Error network jika tidak ada koneksi
  * Error "Too many requests" jika terlalu banyak percobaan login gagal

### 8. Menampilkan alert peringatan jika akun sedang di-suspend

* Aktor: Sistem
* Keterangan:
  * Sistem mengecek field user.isSuspended di Firestore
  * Jika true, tampilkan alert "Akun Disuspend"
  * Pesan: "Akun kamu telah disuspend oleh admin. Silakan hubungi admin untuk informasi lebih lanjut atau ajukan banding."
  * Pengguna tidak dapat masuk ke aplikasi

### 9. Fitur toggle show/hide password

* Aktor: User
* Keterangan:
  * Tombol icon mata untuk menampilkan/menyembunyikan password
  * Berlaku untuk password dan konfirmasi password di registrasi

### 10. Meminta link reset password (Lupa Password)

* Aktor: User
* Keterangan:
  * User tap "Lupa password?" di halaman login
  * Modal sheet muncul dengan input email
  * User memasukkan email terdaftar

### 11. Mengirimkan email reset password otomatis

* Aktor: Sistem
* Keterangan:
  * Sistem mengirim email via Firebase Authentication
  * Tampilkan state "Email Terkirim!" jika berhasil
  * Pesan mengingatkan untuk cek folder spam

### 12. Menampilkan pesan error jika email tidak ditemukan saat reset password

* Aktor: Sistem
* Keterangan:
  * State "Email Tidak Ditemukan" jika email tidak terdaftar
  * Saran untuk cek penulisan email atau registrasi akun baru

### 13. Mengubah password langsung dari menu pengaturan (in-app)

* Aktor: User (logged in)
* Keterangan:
  * Fitur change password di dalam aplikasi
  * Wajib memasukkan password lama (re-authentication)
  * Password baru minimal 8 karakter
  * Validasi password lama harus benar

### 14. Menampilkan pesan error jika password lama tidak cocok

* Aktor: Sistem
* Keterangan:
  * Re-authentication gagal jika password lama salah
  * Tampilkan error spesifik

### 15. Melakukan logout / keluar dari aplikasi

* Aktor: User
* Keterangan:
  * User tap tombol logout di ProfileView
  * Session pengguna dihapus dari Firebase Auth
  * Kembali ke halaman login

---

## II. KELOLA PROFIL PENGGUNA

### 16. Menampilkan detail profil diri sendiri

* Aktor: User
* Keterangan:
  * Menampilkan avatar (foto profil atau initial dengan gradient)
  * Nama lengkap pengguna
  * Email pengguna
  * Informasi rekening bank (jika sudah diisi)

### 17. Mengubah nama lengkap (display name)

* Aktor: User
* Keterangan:
  * User tap edit pada nama
  * Sheet modal dengan TextField untuk edit nama
  * Validasi: nama tidak boleh kosong
  * Update ke Firestore users collection

### 18. Menampilkan alert sukses saat update nama berhasil

* Aktor: Sistem
* Keterangan:
  * Alert: "Nama berhasil diperbarui"
  * Dismiss otomatis setelah OK

### 19. Mengunggah / mengubah foto profil

* Aktor: User
* Keterangan:
  * User tap avatar
  * Sheet photo source picker (Camera atau Gallery)
  * Setelah pilih foto, muncul circular crop tool
  * Fitur drag untuk reposisi dan pinch untuk zoom
  * Preview crop real-time dengan circle mask

### 20. Upload foto profil ke Firebase Storage

* Aktor: Sistem
* Keterangan:
  * Resize gambar ke max 1440px
  * Compress ke 30% quality
  * Validasi max file size 5MB
  * Upload ke folder profile_pictures/ dengan nama [uid]_[timestamp].jpg
  * Simpan download URL dan fullPath (avatarPublicID) ke Firestore

### 21. Menampilkan pesan error jika file foto terlalu besar

* Aktor: Sistem
* Keterangan:
  * Validasi max 5MB
  * Error: "File terlalu besar, maksimal 5MB"

### 22. Menghapus foto profil lama otomatis saat upload foto baru

* Aktor: Sistem
* Keterangan:
  * Menggunakan avatarPublicID (full path) untuk delete
  * Hapus dari Firebase Storage sebelum upload yang baru
  * Ignore error 404 jika file sudah tidak ada

### 23. Menampilkan alert sukses saat foto profil berhasil diupdate

* Aktor: Sistem
* Keterangan:
  * Alert: "Foto profil berhasil diperbarui"
  * Cache avatar di-clear untuk memastikan update

### 24. Menghapus foto profil (kembali ke avatar default dengan initial)

* Aktor: User
* Keterangan:
  * Delete foto dari Firebase Storage
  * Set avatarURL = nil di Firestore
  * Avatar berubah menjadi circle dengan initial dan gradient

### 25. Mengubah informasi rekening bank

* Aktor: User
* Keterangan:
  * User tap edit info rekening
  * Form dengan field: nama bank, nomor rekening, nama pemilik rekening
  * Semua field opsional
  * Update ke Firestore users collection

### 26. Menampilkan alert sukses setelah info rekening diubah

* Aktor: Sistem
* Keterangan:
  * Alert: "Info rekening berhasil disimpan"

---

## III. MANAJEMEN TRIP

### 27. Melihat daftar trip (dengan filter status)

* Aktor: User (Trip Member)
* Keterangan:
  * Tab "Trips" menampilkan semua trip yang user ikuti
  * Filter berdasarkan status: Planned, Active, Finished
  * Menampilkan max 3 trip di HomePage
  * Tombol "Lihat Semua" untuk melihat full list di AllTripsView

### 28. Membuat trip baru - Step 1: Detail Trip

* Aktor: User (akan menjadi Owner)
* Keterangan:
  * Form multi-step (2 langkah)
  * Step 1: Input detail trip
    * Nama trip (wajib)
    * Pilih cover emoji (10 pilihan)
    * Tanggal berangkat (tidak boleh di masa lalu)
    * Tanggal pulang (harus >= tanggal berangkat)
    * Pilih mata uang (IDR, USD, EUR, SGD, MYR, JPY, AUD)
  * Progress indicator menunjukkan step 1 of 2

### 29. Validasi tanggal trip

* Aktor: Sistem
* Keterangan:
  * Tanggal berangkat tidak boleh di masa lalu
  * Tanggal pulang otomatis adjust jika lebih awal dari tanggal berangkat
  * onChange handler untuk sinkronisasi tanggal

### 30. Membuat trip baru - Step 2: Tambah Anggota

* Aktor: User
* Keterangan:
  * Search bar untuk cari user berdasarkan email atau nama
  * Tampilan list teman (friends list)
  * Tampilan hasil pencarian
  * Multi-select members dengan checkbox
  * Chip selected members di atas (dapat dihapus)
  * Bisa skip tanpa menambah anggota (solo trip)

### 31. Menampilkan alert sukses saat trip berhasil dibuat

* Aktor: Sistem
* Keterangan:
  * Alert: "Trip Berhasil Dibuat! 🎉"
  * Message: "Trip \"[nama]\" berhasil dibuat. Selamat berpetualang!"
  * Auto dismiss setelah OK

### 32. Menentukan status trip otomatis berdasarkan startDate

* Aktor: Sistem
* Keterangan:
  * Jika startDate = hari ini atau sudah lewat → status "active"
  * Jika startDate di masa depan → status "planned"
  * Jika tidak ada startDate → status "active"
  * Menggunakan calendar.startOfDay untuk perbandingan

### 33. Mengirim undangan trip ke anggota yang dipilih

* Aktor: Sistem
* Keterangan:
  * Untuk setiap selected member, buat dokumen TripInvite
  * Status invite = "pending"
  * Tambahkan member ke trip.members dengan role = "pending"
  * Kirim notifikasi tipe "tripInvite" ke setiap invitee

### 34. Melihat detail trip - Tab Details

* Aktor: Trip Member
* Keterangan:
  * Tab 1 dari 3 tabs di TripDetailView
  * Tampilkan trip info card: emoji, nama, status badge, tanggal
  * Durasi trip (dihitung dari start-end date)
  * Jumlah anggota
  * List semua anggota dengan role (Owner/Admin/Member/Pending)
  * Avatar anggota dengan initial

### 35. Melihat detail trip - Tab Expenses

* Aktor: Trip Member
* Keterangan:
  * Tab 2: Daftar semua expense dalam trip
  * Grouped by day (section headers dengan tanggal)
  * Expense card: icon kategori, nama, amount, paid by
  * Progress bar per expense (paid vs unpaid participants)
  * Empty state dengan CTA "Tambah Pengeluaran"

### 36. Melihat detail trip - Tab Hutang (Debts)

* Aktor: Trip Member
* Keterangan:
  * Tab 3: Debt summary dan settlement
  * Tombol "Hitung Ulang Hutang"
  * Section "Hutang Kamu" (highlighted) - hutang yang user miliki
  * Section "Semua Hutang" - daftar lengkap siapa hutang ke siapa
  * Section "Riwayat Pembayaran" - settlement yang sudah verified

### 37. Menghitung ulang hutang dengan algoritma simplifikasi

* Aktor: User (tap button), Sistem (otomatis)
* Keterangan:
  * Menggunakan utility DebtSimplifier
  * Input: semua expense dalam trip
  * Proses: hitung balance, minimize jumlah transaksi
  * Output: daftar optimized "siapa bayar ke siapa berapa"
  * Algoritma meminimalkan jumlah transfer yang dibutuhkan

### 38. Mengedit trip

* Aktor: Owner atau Admin
* Keterangan:
  * Akses via menu 3-dot → "Edit Trip"
  * Form edit dengan data pre-filled
  * Field yang bisa diubah: nama, emoji, tanggal, mata uang
  * Validasi sama dengan create trip

### 39. Update status trip otomatis saat edit tanggal

* Aktor: Sistem
* Keterangan:
  * Hanya update status jika trip saat ini "planned" atau "active"
  * TIDAK update jika status "finished" atau "deleted"
  * Logic: startDate <= today → "active", else → "planned"

### 40. Menampilkan alert sukses setelah trip diedit

* Aktor: Sistem
* Keterangan:
  * Alert: "Berhasil Diperbarui"
  * Message: "Informasi trip telah diperbarui."

### 41. Mengundang anggota baru ke trip

* Aktor: Owner atau Admin
* Keterangan:
  * Tombol "Tambah" di tab Details
  * Sheet modal dengan 2 tab: "Teman" dan "Pencarian"
  * Tab Teman: list friends yang belum jadi member
  * Tab Pencarian: search user by email/name
  * Multi-select members
  * Filter: tidak tampilkan current member dan user sendiri

### 42. Membuat invite untuk anggota baru

* Aktor: Sistem
* Keterangan:
  * Create TripInvite document dengan status "pending"
  * Add member ke trip.members array dengan role "pending"
  * Kirim notification tipe "tripInvite"
  * Member belum bisa akses trip sampai accept

### 43. Menerima undangan trip

* Aktor: Invitee (penerima undangan)
* Keterangan:
  * Akses via NotificationsView atau langsung dari notification
  * Tombol "Terima" pada invitation card
  * Update invite status → "accepted"
  * Update member role dari "pending" → "member"
  * Add uid ke memberUIDs array
  * User sekarang bisa akses trip

### 44. Menolak undangan trip

* Aktor: Invitee
* Keterangan:
  * Tombol "Tolak" pada invitation
  * Update invite status → "rejected"
  * Remove user dari members array
  * Notification dihapus dari list

### 45. Menyelesaikan trip (Finish Trip)

* Aktor: Owner (only)
* Keterangan:
  * Tombol "Selesaikan Trip" di tab Details (hanya untuk active trips)
  * Alert konfirmasi dengan 2 kondisi:
    * Jika trip sudah lewat endDate: pesan standard
    * Jika trip belum lewat endDate: warning dengan tanggal terjadwal
  * Update status → "finished"
  * Set finishedAt timestamp
  * Kirim notification "tripEnded" ke semua member kecuali owner

### 46. Menampilkan alert sukses saat trip selesai

* Aktor: Sistem
* Keterangan:
  * Alert: "Selamat! 🎉"
  * Message: "Trip [nama] sudah selesai. Terima kasih sudah berpetualang bersama!"
  * Auto-dismiss dan navigate back

### 47. Menghapus trip

* Aktor: Owner (only)
* Keterangan:
  * Menu 3-dot → "Hapus Trip"
  * Alert konfirmasi: "Trip [nama] akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan."
  * Delete trip document dari Firestore
  * Navigate back ke trips list

### 48. Keluar dari trip (Leave Trip)

* Aktor: Member (bukan owner)
* Keterangan:
  * Menu → "Keluar Trip"
  * Alert: "Anda akan keluar dari trip [nama] dan tidak bisa mengaksesnya lagi kecuali diundang kembali."
  * Remove user dari memberUIDs dan members array
  * Navigate back

### 49. Mengeluarkan anggota dari trip (Kick Member)

* Aktor: Owner (only)
* Keterangan:
  * Tombol minus (-) di samping member (tidak bisa kick diri sendiri)
  * Alert: "Anggota [nama] akan dikeluarkan dari trip ini."
  * Remove member dari memberUIDs dan members array

### 50. Transfer kepemilikan trip

* Aktor: Owner
* Keterangan:
  * Fitur untuk transfer ownership ke member lain
  * Update ownerUID ke new owner
  * Add new owner ke adminUIDs

### 51. Real-time update trip data

* Aktor: Sistem
* Keterangan:
  * Firestore listener pada trip document
  * Setiap perubahan (member join, edit, status change) otomatis sync
  * State currentTrip di-update real-time
  * Semua member melihat perubahan instantly

### 52. Validasi akses berdasarkan role member

* Aktor: Sistem
* Keterangan:
  * Owner: full access, tidak bisa di-kick, bisa delete/finish trip
  * Admin: bisa invite member, edit trip
  * Member: bisa view, add expense, leave trip
  * Pending: tidak bisa akses trip sampai accept invite

### 53. Transition status trip otomatis dengan Cloud Function (server-side)

* Aktor: Sistem (Firebase Cloud Function)
* Keterangan:
  * Scheduled function: dailyTripStatusCheck
  * Runs setiap hari jam 10:00 WIB (03:00 UTC)
  * Task 1: Transisi trip "planned" → "active" jika startDate = today
  * Task 2: Kirim notif "tripEnded" ke owner jika endDate sudah lewat
  * Background process, tidak perlu user action

---

## IV. MANAJEMEN EXPENSE (PENGELUARAN)

### 54. Memilih metode tambah expense

* Aktor: Trip Member
* Keterangan:
  * Tombol FAB "+" di Expenses tab (hanya untuk active trips)
  * Sheet modal dengan 2 pilihan:
    * Manual Entry
    * Scan Receipt (OCR + AI)

### 55. Menambah expense manual - Step 1: Info Pengeluaran

* Aktor: Trip Member
* Keterangan:
  * Multi-step form (3 steps)
  * Step 1 input:
    * Nama pengeluaran (wajib)
    * Total pengeluaran (wajib, dengan thousand separator otomatis)
    * Tanggal transaksi (date picker)
    * Kategori (Food, Transport, Accommodation, Activity, Shopping, Health, Other)
    * Catatan (opsional)
  * Upload foto struk opsional

### 56. Validasi dan formatting input amount expense

* Aktor: Sistem
* Keterangan:
  * Auto-format dengan thousand separator (.)
  * Remove separator saat parse ke Double
  * Validasi amount > 0
  * Border merah jika invalid

### 57. Pilih kategori expense dengan icon dan warna

* Aktor: User
* Keterangan:
  * 7 kategori dengan icon dan color coding
  * Selected state: border tebal, background color, shadow
  * Smooth animation saat select
  * Card-style layout dengan circle icon

### 58. Menambah expense manual - Step 2: Pilih Peserta

* Aktor: Trip Member
* Keterangan:
  * List semua trip members dengan checkbox
  * Toggle select/deselect
  * Label "Kamu" untuk current user
  * Minimal 1 participant harus dipilih

### 59. Menambah expense manual - Step 3: Pembagian Item

* Aktor: Trip Member
* Keterangan:
  * Add items dengan nama, harga, quantity
  * Assign items ke participants (multiple select per item)
  * Chip-style participant selection
  * Edit/delete item yang sudah ditambahkan
  * Tombol "Tambah Item Manual"

### 60. Menghitung split amount per participant berdasarkan item

* Aktor: Sistem
* Keterangan:
  * Untuk setiap participant, hitung total dari items yang dipilih
  * Formula: (item.price × quantity) / jumlah_participant_untuk_item
  * Proportional calculation
  * Display amount per participant di ringkasan

### 61. Validasi total items harus sama dengan total pengeluaran

* Aktor: Sistem
* Keterangan:
  * calculatedTotal = sum of (item.price × quantity) + tax + service - discount
  * isTotalMatching = abs(calculatedTotal - totalAmount) < 0.01
  * Button "Simpan" disabled jika tidak match
  * Warning message dengan icon jika tidak match
  * Breakdown detail di ringkasan

### 62. Menampilkan ringkasan pembagian expense di Step 3

* Aktor: Sistem
* Keterangan:
  * List participant dengan calculated amount
  * Breakdown: Total Items + Pajak + Service - Diskon = Total Terhitung
  * Compare dengan Total Tagihan
  * Visual indicator (green = match, red = mismatch)

### 63. Menyimpan expense ke Firestore

* Aktor: Sistem
* Keterangan:
  * Create ExpenseModel document
  * Fields: tripID, title, amount, currency, category, paidByUID, splits, notes, receiptURL
  * Upload receipt image ke Firebase Storage jika ada
  * Generate expense ID
  * Set createdAt timestamp

### 64. Upload foto struk ke Firebase Storage

* Aktor: Sistem
* Keterangan:
  * Resize image ke max 1440px
  * Compress ke 60% quality
  * Path: receipts/[expenseID].jpg
  * Return download URL
  * Simpan URL di expense document

### 65. Scan struk dengan kamera atau gallery

* Aktor: User
* Keterangan:
  * Photo source picker: Camera atau Gallery
  * Capture atau pilih foto struk
  * Loading state saat processing

### 66. OCR text recognition dari foto struk

* Aktor: Sistem
* Keterangan:
  * Menggunakan Apple Vision framework
  * VNRecognizeTextRequest dengan accuracy level
  * Support Indonesian language
  * Extract semua text lines dari image
  * Gabungkan menjadi full text string

### 67. AI parsing struk dengan OpenAI GPT

* Aktor: Sistem
* Keterangan:
  * Input: OCR extracted text
  * Model: GPT-4.5-mini
  * Validation: cek apakah benar-benar struk/receipt
  * Extract:
    * Bill/merchant name
    * Total amount
    * Currency (Rp, USD, etc)
    * Category (Food, Transport, etc)
    * Items dengan name, price, quantity
    * Date, Tax, Service Charge, Discount
  * Handle Indonesian number format (50.000 → 50000)
  * Structured output: ParsedReceiptModel

### 68. Menampilkan error jika foto bukan struk

* Aktor: Sistem
* Keterangan:
  * AI validation: isReceipt = false
  * Error message: "Gambar yang dipilih bukan struk. Silakan foto struk yang valid."
  * Bisa retry atau cancel

### 69. Preview hasil AI parsing struk

* Aktor: User
* Keterangan:
  * Banner "Struk berhasil di-scan" dengan checkmark
  * Summary: nama, total, kategori, jumlah items
  * Data pre-filled di form Create Expense

### 70. Edit/hapus biaya tambahan (Tax, Service, Discount) di Step 3

* Aktor: User
* Keterangan:
  * Section "Biaya Tambahan (Opsional)"
  * 3 fields: Pajak, Service Charge, Diskon
  * Editable TextField dengan icon
  * Tombol X untuk hapus/clear value
  * Auto-detected dari OCR, bisa di-edit manual
  * Info text: "Otomatis terdeteksi dari struk. Kamu bisa edit atau hapus jika salah."

### 71. Fallback parsing manual jika AI unavailable

* Aktor: Sistem
* Keterangan:
  * Jika OpenAI API error atau unavailable
  * Gunakan regex pattern untuk extract amount
  * Basic parsing: cari pola angka dengan format tertentu
  * Return parsedAmount (basic) bukan parsedReceipt (full)

### 72. Melihat detail expense

* Aktor: Trip Member
* Keterangan:
  * Tap expense card
  * Display:
    * Title, amount, kategori (icon + color)
    * Paid by [nama]
    * Foto struk (jika ada, clickable ke fullscreen)
    * Notes
    * Split details per participant dengan amount
    * Status paid/unpaid per participant
    * Toggle switch untuk mark paid/unpaid

### 73. Fullscreen view foto struk

* Aktor: User
* Keterangan:
  * Tap foto struk di detail expense
  * Fullscreen modal dengan pinch-to-zoom
  * Swipe down to dismiss

### 74. Edit expense

* Aktor: Expense creator atau Trip Admin
* Keterangan:
  * Menu → "Edit"
  * Form edit dengan data pre-filled
  * Bisa ubah: title, amount, category, notes
  * Update expense document
  * Set updatedAt timestamp

### 75. Hapus expense

* Aktor: Expense creator atau Trip Admin
* Keterangan:
  * Swipe to delete atau via menu
  * Alert konfirmasi
  * Delete expense document
  * Delete foto struk dari Storage jika ada

### 76. Mark split sebagai paid/unpaid

* Aktor: Trip Member (untuk split sendiri) atau Admin (semua split)
* Keterangan:
  * Toggle switch di expense detail
  * Update split.isPaid field
  * Real-time update via Firestore listener
  * Progress bar update otomatis

### 77. Auto-calculation split untuk equal split

* Aktor: Sistem
* Keterangan:
  * Jika hanya 1 item "Total Pengeluaran"
  * Split equally: amount / jumlah_participants
  * Setiap participant dapat amount yang sama

### 78. Progress bar expense (paid vs unpaid)

* Aktor: Sistem
* Keterangan:
  * Visual bar: hijau untuk yang sudah paid
  * Percentage calculation
  * Display di expense card dan detail
  * Real-time update

---

## V. MANAJEMEN SPLIT BILL (TAGIHAN NON-TRIP)

### 79. Memilih metode buat split bill

* Aktor: User
* Keterangan:
  * Tab "Split" → FAB "+"
  * Sheet modal dengan 2 pilihan:
    * Manual Entry
    * Scan Receipt

### 80. Membuat split bill - Step 1: Info Tagihan

* Aktor: User (jadi owner)
* Keterangan:
  * Input:
    * Nama tagihan (wajib)
    * Total tagihan (wajib)
    * Mata uang
    * Kategori
    * Tanggal transaksi
    * Pajak (editable jika dari scan)
    * Service charge (editable jika dari scan)
    * Diskon (editable jika dari scan)
    * Catatan (opsional)

### 81. Membuat split bill - Step 2: Tambah Peserta

* Aktor: User
* Keterangan:
  * Search friends atau add guest (non-app user)
  * Multi-select participants
  * Pilih "Siapa yang bayar dulu?" (Paid By) - default current user
  * Radio button selection untuk payer
  * Toggle selection untuk participants

### 82. Menambah guest participant (non-app user)

* Aktor: User
* Keterangan:
  * Button "Tambah Guest"
  * Input nama guest manual
  * Guest tidak punya UID, pakai generated ID
  * Guest bisa dipilih sebagai participant tapi tidak bisa jadi payer

### 83. Membuat split bill - Step 3: Pembagian Item

* Aktor: User
* Keterangan:
  * Add items dengan name, price, quantity
  * Assign items ke participants
  * Tax, service, discount dibagi proporsional
  * Calculate amount per participant
  * Validasi total match

### 84. Proportional distribution biaya tambahan di split bill

* Aktor: Sistem
* Keterangan:
  * Tax, service, discount dibagi sesuai proporsi item yang dibeli
  * Formula: (itemTotal / grandTotal) × additionalCharge
  * Info text: "*Dibagi proporsional sesuai item yang dibeli"
  * Automatic calculation per participant

### 85. Menyimpan split bill ke Firestore

* Aktor: Sistem
* Keterangan:
  * Create SplitBillModel document
  * Fields: ownerUID, paidByUID, title, totalAmount, participants, status, notes
  * Upload receipt jika ada
  * Generate participantUIDs array untuk querying
  * Status default: "active"

### 86. Loading overlay saat upload struk split bill

* Aktor: Sistem
* Keterangan:
  * Dark overlay dengan progress indicator
  * Message: "Mengupload struk..." → "Menyimpan data..."
  * File size display jika > 0.1 MB
  * Smooth transition animation

### 87. Melihat list split bills

* Aktor: User (owner atau participant)
* Keterangan:
  * 2 section: "Tagihan Aktif" dan "Tagihan Lunas"
  * Filtering otomatis by status
  * Display: title, amount, unpaid count, progress bar
  * Real-time via Firestore listener
  * Query by participantUIDs (owner atau participant)

### 88. Melihat detail split bill

* Aktor: Owner atau Participant
* Keterangan:
  * Bill info card: title, amount, paid by, category, status
  * Receipt image (fullscreen view)
  * Participants list dengan amounts dan paid status
  * Progress bar
  * Toggle untuk mark paid/unpaid

### 89. Mark participant sebagai paid/unpaid di split bill

* Aktor: Owner (only)
* Keterangan:
  * Toggle switch per participant
  * Update participant.isPaid
  * Real-time sync

### 90. Auto-settle split bill saat semua paid

* Aktor: Sistem
* Keterangan:
  * Check: semua participants.isPaid == true
  * Jika ya, update bill status → "settled"
  * Bill pindah ke section "Tagihan Lunas"

### 91. Hapus split bill

* Aktor: Owner
* Keterangan:
  * Swipe to delete atau via menu
  * Alert konfirmasi
  * Delete receipt dari Storage jika ada
  * Delete bill document

### 92. Auto-migration participantUIDs untuk backward compatibility

* Aktor: Sistem
* Keterangan:
  * Untuk bill lama yang belum ada participantUIDs
  * Extract UIDs dari participants array
  * Populate participantUIDs field otomatis
  * Update Firestore document
  * One-time migration per bill

---

## VI. MANAJEMEN TEMAN (FRIENDS)

### 93. Melihat daftar teman

* Aktor: User
* Keterangan:
  * Tab "Friends" menampilkan semua confirmed friends
  * Display: avatar, nama, email
  * Counter total teman
  * Pull to refresh
  * Local search filter by name/email

### 94. Mencari teman dengan search bar

* Aktor: User
* Keterangan:
  * TextField search di atas list
  * Filter local: by name atau email (case-insensitive)
  * Real-time filtering
  * Clear button (X) untuk reset search

### 95. Menambah teman dengan email

* Aktor: User
* Keterangan:
  * FAB "+" → input email
  * Validasi:
    * Email tidak kosong
    * Format email valid (contains @)
    * Bukan email sendiri
    * User exist di system
    * Belum jadi teman
    * Tidak ada pending request
  * Kirim friend request

### 96. Menampilkan error spesifik saat add friend

* Aktor: Sistem
* Keterangan:
  * "Email tidak boleh kosong"
  * "Format email tidak valid"
  * "Tidak bisa menambahkan diri sendiri"
  * "User dengan email [x] tidak ditemukan"
  * "Kamu sudah berteman dengan [nama]"
  * "Permintaan sudah dikirim sebelumnya"

### 97. Membuat friend request document

* Aktor: Sistem
* Keterangan:
  * Create FriendRequest document
  * Fields: fromUID, toUID, status="pending", createdAt
  * Kirim notification tipe "friendRequest" ke recipient

### 98. Menampilkan sukses message setelah kirim request

* Aktor: Sistem
* Keterangan:
  * Message: "Permintaan pertemanan sudah dikirim ke [nama]"

### 99. Mencari user global (untuk invite trip/split)

* Aktor: User
* Keterangan:
  * Search by email atau display name
  * 3 query parallel: lowercase, capitalized, original
  * Prefix search di email dan name
  * Merge dan deduplicate results
  * Sort: exact match first, then alphabetical
  * Limit 10 results per query type
  * Exclude current user

### 100. Melihat pending friend requests (incoming)

* Aktor: User
* Keterangan:
  * Section di NotificationsView tipe "Undangan"
  * Display requester info: avatar, nama
  * Button "Terima" dan "Tolak"
  * Real-time via listener
  * Badge count di notifications bell

### 101. Menerima friend request

* Aktor: Request Recipient
* Keterangan:
  * Tap "Terima"
  * Update request status → "accepted"
  * Add fromUID ke currentUser.friendUIDs
  * Add currentUID ke requester.friendUIDs
  * Delete notification
  * Kirim notif "Permintaan Diterima" ke requester
  * Reload friends list

### 102. Menolak friend request

* Aktor: Request Recipient
* Keterangan:
  * Tap "Tolak"
  * Update request status → "rejected"
  * Delete notification
  * Request hilang dari list

### 103. Melihat outgoing friend requests

* Aktor: User
* Keterangan:
  * List request yang user kirim dan masih pending
  * Display recipient info dan status "Menunggu"

### 104. Menghapus teman (unfriend)

* Aktor: User
* Keterangan:
  * Akses via friend detail → button unfriend
  * Alert konfirmasi
  * Remove friendID dari current user friendUIDs
  * Remove currentUID dari friend's friendUIDs
  * Friend hilang dari list

### 105. Melihat detail teman

* Aktor: User
* Keterangan:
  * Tap friend dari list
  * Display: avatar, nama, email, info lainnya
  * Action: unfriend, view shared trips

---

## VII. NOTIFIKASI

### 106. Melihat notifikasi (2 section)

* Aktor: User
* Keterangan:
  * Section 1 "Undangan":
    * Trip invites (pending)
    * Friend requests
    * Sorted by created date (newest first)
  * Section 2 "Notifikasi":
    * Trip ended
    * Expense added
    * Settlement proof
    * Payment verified/rejected
    * General notifications

### 107. Jenis-jenis notifikasi

* Aktor: Sistem
* Keterangan:
  * tripInvite: undangan join trip
  * tripEnded: trip telah selesai
  * friendRequest: permintaan pertemanan
  * expenseAdded: pengeluaran baru di trip
  * settlementProof: bukti pembayaran diupload
  * paymentVerified: pembayaran diverifikasi
  * paymentRejected: pembayaran ditolak
  * general: notifikasi umum

### 108. Unread indicator pada notifikasi

* Aktor: Sistem
* Keterangan:
  * Red dot untuk notifikasi belum dibaca
  * Field isRead = false
  * Visual: circle merah di samping notifikasi

### 109. Mark notification sebagai read

* Aktor: User
* Keterangan:
  * Tap notifikasi
  * Update isRead → true
  * Red dot hilang
  * Decrement unread count

### 110. Mark all notifications as read

* Aktor: User
* Keterangan:
  * Button "Tandai Semua Sudah Dibaca"
  * Batch update semua unread notifications
  * Concurrent update ke Firestore
  * Badge count reset

### 111. Delete notification

* Aktor: User
* Keterangan:
  * Swipe to delete
  * Delete dari Firestore
  * Remove dari local array instantly
  * Update unread count

### 112. Notification badge counter

* Aktor: Sistem
* Keterangan:
  * Red badge di tab bar notifications icon
  * Count = unread notifications + pending invites
  * Real-time update via listener
  * Hilang saat count = 0

### 113. Notification actions (in-app)

* Aktor: User
* Keterangan:
  * Friend request: Accept/Decline buttons
  * Trip invite: Accept/Reject buttons
  * Expense added: Navigate to expense detail
  * Settlement: Navigate to settlement view
  * Action langsung dari notification card

### 114. Real-time notification listener

* Aktor: Sistem
* Keterangan:
  * Firestore snapshot listener
  * Query: recipientUID == currentUser
  * Order by createdAt descending
  * Limit: 50 latest notifications
  * Auto-update saat ada notifikasi baru

### 115. Notification creation otomatis

* Aktor: Sistem
* Keterangan:
  * Trigger events:
    * User diinvite ke trip → tripInvite
    * Trip selesai → tripEnded ke semua member
    * Friend request dikirim → friendRequest
    * Friend request diterima → general
    * Expense ditambahkan → expenseAdded
    * Settlement proof diupload → settlementProof
  * Auto-populate: recipientUID, type, title, body, createdAt

---

## VIII. HUTANG & SETTLEMENT

### 116. Menghitung hutang otomatis dengan DebtSimplifier

* Aktor: Sistem
* Keterangan:
  * Utility class untuk simplify debts
  * Input: semua expenses dalam trip
  * Calculate balances: siapa bayar berapa, siapa harus bayar berapa
  * Optimize: minimize jumlah transaksi yang dibutuhkan
  * Output: list of Transaction (debtor → creditor: amount)
  * Algoritm: balance calculation + greedy matching

### 117. Melihat ringkasan hutang

* Aktor: Trip Member
* Keterangan:
  * Tab "Hutang" di trip detail
  * Section "Hutang Kamu" (highlighted): hutang user sendiri
  * Section "Semua Hutang": daftar lengkap debt transactions
  * Section "Riwayat Pembayaran": verified settlements
  * Format: [Debtor] → [Creditor]: [Amount]

### 118. Tombol "Hitung Ulang Hutang"

* Aktor: User
* Keterangan:
  * Manual trigger untuk recalculate debts
  * Fetch semua expenses di trip
  * Run DebtSimplifier algorithm
  * Update local state dengan hasil baru
  * Loading state saat process

### 119. Submit bukti pembayaran hutang

* Aktor: Debtor (user yang punya hutang)
* Keterangan:
  * Button "Bayar Hutang" di settlement view
  * Select transaction yang mau dibayar
  * Upload foto bukti pembayaran (transfer/cash)
  * Add notes opsional
  * Submit

### 120. Upload proof ke Firebase Storage

* Aktor: Sistem
* Keterangan:
  * Resize ke max 1440px
  * Compress ke 60%
  * Path: proofs/[settlementID].jpg
  * Return download URL

### 121. Membuat settlement document

* Aktor: Sistem
* Keterangan:
  * Create SettlementModel
  * Fields: tripID, fromUID, toUID, amount, proofURL, status="pending", notes
  * Link ke transaction details
  * Set createdAt timestamp

### 122. Kirim notifikasi settlement proof ke creditor

* Aktor: Sistem
* Keterangan:
  * Notification tipe "settlementProof"
  * Recipient: creditor (toUID)
  * Message: "[Debtor] telah mengupload bukti pembayaran"
  * Link ke settlement detail

### 123. Verify pembayaran

* Aktor: Creditor (penerima pembayaran)
* Keterangan:
  * Tap "Verifikasi" di settlement card
  * Update status → "verified"
  * Set verifiedAt timestamp
  * Record verifierUID
  * Kirim notif "paymentVerified" ke debtor

### 124. Reject pembayaran

* Aktor: Creditor
* Keterangan:
  * Tap "Tolak"
  * Update status → "rejected"
  * Record verifierUID
  * Kirim notif "paymentRejected" ke debtor
  * Debtor harus submit ulang

### 125. Melihat riwayat settlement

* Aktor: Trip Member
* Keterangan:
  * List semua settlements (pending, verified, rejected)
  * Display: payer, receiver, amount, status, proof image, timestamp
  * Filter by trip
  * Status color coding:
    * Pending: amber
    * Verified: green
    * Rejected: red

### 126. Fullscreen view bukti pembayaran

* Aktor: User
* Keterangan:
  * Tap proof image di settlement
  * Fullscreen modal dengan pinch-zoom
  * Swipe to dismiss

---

## IX. LAPORAN & ANALYTICS

### 127. Generate PDF report untuk trip

* Aktor: Trip Member
* Keterangan:
  * Menu → "Laporan"
  * Generate PDF A4
  * Content:
    * Trip name header
    * Table of expenses (title, amount, category)
    * Total amount footer
  * Pagination otomatis
  * Share via system share sheet

### 128. Breakdown kategori expense

* Aktor: Sistem
* Keterangan:
  * Calculate total per category
  * Sort dari highest ke lowest
  * Display dengan icon dan color per category
  * Percentage calculation (optional)

### 129. Total amount calculation

* Aktor: Sistem
* Keterangan:
  * Sum semua expenses di trip
  * Display di header atau summary card
  * Real-time update saat expense added/deleted

### 130. Member expense breakdown

* Aktor: Sistem
* Keterangan:
  * Siapa bayar berapa (total paid by each member)
  * Calculate dari paidByUID di expenses
  * Display di analytics/report view

---

## X. RECEIPT SCANNING & OCR

### 131. OCR text recognition dengan Vision framework

* Aktor: Sistem
* Keterangan:
  * Apple Vision VNRecognizeTextRequest
  * Recognition level: accurate
  * Language correction enabled
  * Support Indonesian language
  * Extract: text lines + full text string
  * Error handling jika recognition gagal

### 132. AI receipt parsing dengan OpenAI

* Aktor: Sistem
* Keterangan:
  * Service: OpenAI GPT-4.5-mini API
  * Input: OCR extracted text
  * System prompt: structured JSON extraction
  * Validate: isReceipt check
  * Extract semua receipt fields (bill name, items, tax, etc)
  * Handle Indonesian number format
  * Auto-fix common OCR errors

### 133. Validasi apakah gambar adalah struk

* Aktor: Sistem (AI)
* Keterangan:
  * AI check: isReceipt field
  * Jika false, return error
  * Error response dengan field: error, isReceipt
  * Message: "Gambar bukan struk valid"

### 134. Extract items dengan harga dan quantity

* Aktor: Sistem (AI)
* Keterangan:
  * Parse item list dari text
  * Extract: name, price (optional), quantity (optional)
  * Skip items tanpa harga
  * Filter dan validate items
  * Return array of ReceiptItem

### 135. Auto-detect kategori dari merchant/items

* Aktor: Sistem (AI)
* Keterangan:
  * AI infer kategori berdasarkan:
    * Merchant name
    * Items yang dibeli
    * Context dari struk
  * Map ke kategori app: Food, Transport, dll
  * Fallback ke kategori default jika tidak yakin

### 136. Handle Indonesian number format

* Aktor: Sistem
* Keterangan:
  * Format: 50.000 atau 50,000
  * Remove thousand separator (. atau ,)
  * Parse ke Double
  * Validate hasil parsing
  * Fix misinterpretation decimal point

### 137. Fallback regex parsing jika AI unavailable

* Aktor: Sistem
* Keterangan:
  * Jika OpenAI API error atau key missing
  * Use regex pattern untuk extract amount
  * Basic parsing: cari angka dengan pola tertentu
  * Return parsedAmount (basic) bukan parsedReceipt
  * Less accurate tapi tetap functional

### 138. Receipt image upload ke Storage

* Aktor: Sistem
* Keterangan:
  * Folder: receipts/[id].jpg
  * Resize ke max 1440px
  * Compress ke 60% quality
  * Max 5MB validation
  * Return download URL
  * Store URL di expense/bill document

### 139. Display receipt image di detail view

* Aktor: User
* Keterangan:
  * Thumbnail clickable
  * Tap untuk fullscreen
  * Pinch-to-zoom di fullscreen
  * Swipe to dismiss fullscreen

---

## XI. IMAGE HANDLING

### 140. Photo source picker (Camera atau Gallery)

* Aktor: User
* Keterangan:
  * Sheet modal dengan 2 tombol
  * Option 1: Kamera
  * Option 2: Gallery/Photo Library
  * Untuk: avatar, receipt, payment proof

### 141. Camera capture

* Aktor: User
* Keterangan:
  * Fullscreen camera interface
  * Native iOS camera
  * Capture button
  * Return UIImage

### 142. Gallery/Photo Library picker

* Aktor: User
* Keterangan:
  * System photo picker (PHPickerViewController)
  * Single image selection
  * Require photo library permission
  * Return UIImage

### 143. Circle image cropper untuk avatar

* Aktor: User
* Keterangan:
  * Custom crop tool
  * Features:
    * Drag gesture untuk reposition
    * Pinch gesture untuk zoom
    * Circle mask overlay
    * Real-time preview
  * Apply crop saat save
  * Return cropped UIImage

### 144. Image resize dan compression

* Aktor: Sistem
* Keterangan:
  * Max dimension: 1440px (keep aspect ratio)
  * Avatar compression: 30% quality
  * Receipt/proof compression: 60% quality
  * Reduce file size untuk upload
  * UIImage extension utility

### 145. Image size validation

* Aktor: Sistem
* Keterangan:
  * Max file size: 5MB
  * Check sebelum upload
  * Error message jika exceed
  * "File terlalu besar, maksimal 5MB"

### 146. Firebase Storage upload

* Aktor: Sistem
* Keterangan:
  * Service: FirebaseStorageService
  * Folders:
    * profile_pictures/[uid]_[timestamp].jpg
    * receipts/[id].jpg
    * proofs/[id].jpg
  * Metadata: userId, uploadedAt
  * Return: download URL + full path
  * Error handling untuk network issues

### 147. Delete old image saat update

* Aktor: Sistem
* Keterangan:
  * Saat upload avatar baru, delete yang lama
  * Saat delete expense/bill, delete receipt
  * Use fullPath (avatarPublicID) untuk delete
  * Ignore 404 error jika file sudah tidak ada
  * Cleanup orphaned files

### 148. Avatar default dengan initial dan gradient

* Aktor: Sistem
* Keterangan:
  * Jika avatarURL == nil
  * Display circle dengan:
    * User initials (first letter of name)
    * Brand gradient background
    * White text
  * Fallback graceful tanpa broken image

---

## XII. PENDING BILLS (HOME SCREEN)

### 149. Agregasi pending bills dari multiple sources

* Aktor: Sistem
* Keterangan:
  * Source 1: Split bills (user is participant, belum lunas)
  * Source 2: Trip expenses (user punya unpaid split)
  * Combine dan merge results
  * Remove duplicates

### 150. Display pending bills di home screen

* Aktor: User
* Keterangan:
  * Section di HomeView paling atas
  * Card per bill dengan:
    * Title
    * Total amount
    * Unpaid count ("X orang belum bayar")
    * Progress bar (paid/total)
    * Time ago (relative timestamp)
    * Type label (Split Bill atau Trip: [nama])
  * Sort by newest first

### 151. Navigation ke bill detail dari pending card

* Aktor: User
* Keterangan:
  * Tap pending bill card
  * Navigate ke:
    * SplitBillDetailView jika split bill
    * ExpenseDetailView jika trip expense
  * Passing required data

### 152. Real-time update pending bills

* Aktor: Sistem
* Keterangan:
  * Firestore listeners untuk split bills dan expenses
  * Auto-update saat status berubah
  * Remove dari list jika sudah lunas
  * Progress bar update real-time

---

## XIII. NETWORK & OFFLINE

### 153. Monitor status koneksi internet

* Aktor: Sistem (NetworkMonitor)
* Keterangan:
  * Utility class dengan NWPathMonitor
  * Track real-time connectivity
  * Published isConnected boolean
  * Observable di seluruh app

### 154. Tampilkan offline banner

* Aktor: Sistem
* Keterangan:
  * Banner di top of screen saat offline
  * Warning message: "Tidak ada koneksi internet"
  * Slide animation in/out
  * Overlay content
  * Hilang saat koneksi kembali

### 155. Handle offline state

* Aktor: Sistem
* Keterangan:
  * Disable actions yang butuh network
  * Show appropriate error messages
  * Queue operations untuk retry (optional)
  * Graceful degradation

---

## XIV. UI/UX FEATURES

### 156. App theme dengan brand colors

* Aktor: Sistem
* Keterangan:
  * Custom color palette (purple gradient)
  * Consistent typography (AppFont)
  * Standard radius sizes (sm, md, lg, full)
  * Brand gradient untuk primary actions
  * Dark mode support (optional)

### 157. Pull to refresh

* Aktor: User
* Keterangan:
  * Views: Friends list, Notifications
  * Swipe down gesture
  * System refresh indicator
  * Reload data dari Firestore
  * Loading state feedback

### 158. Search dengan debounce

* Aktor: User
* Keterangan:
  * Real-time search di Friends, Create Trip, Invite
  * Filter as you type
  * Clear button (X) untuk reset
  * Local filtering atau server query
  * Debounce untuk prevent excessive queries

### 159. Empty states untuk semua lists

* Aktor: Sistem
* Keterangan:
  * Custom empty state messages
  * Elements: icon emoji, title, subtitle
  * Examples:
    * "Belum ada trip" → CTA "Buat Trip Pertamamu"
    * "Belum ada teman" → "Tambah teman untuk mulai berbagi"
    * "Tidak ada tagihan tertunda" → "Semua lunas! 🎉"
    * "Belum ada notifikasi"

### 160. Loading states

* Aktor: Sistem
* Keterangan:
  * ProgressView untuk async operations
  * Loading overlay untuk long operations (upload)
  * Skeleton screens (optional)
  * Inline spinners
  * Disable buttons saat loading

### 161. Error messages inline dan alert

* Aktor: Sistem
* Keterangan:
  * Inline errors: red text di bawah field
  * System alerts untuk critical errors
  * Toast messages (optional)
  * Context-aware error messages
  * Specific validation feedback

### 162. Dismiss keyboard on tap outside

* Aktor: User
* Keterangan:
  * Tap anywhere outside input field
  * Keyboard auto-dismiss
  * Helper modifier: .dismissKeyboardOnTap()
  * Scroll also dismisses keyboard

### 163. Tab bar navigation

* Aktor: User
* Keterangan:
  * 4 tabs: Trips, Split, Friends, Profile
  * SF Symbol icons
  * Selected state highlight
  * Badge untuk notifications (red dot)
  * Persistence across app sessions

### 164. Navigation stack untuk hierarchical flow

* Aktor: Sistem
* Keterangan:
  * NavigationStack untuk nested views
  * Standard back button
  * Navigation title
  * Toolbar items
  * Deep linking capable

### 165. Sheet modals untuk secondary flows

* Aktor: Sistem
* Keterangan:
  * .sheet modifier untuk modal presentation
  * Swipe down to dismiss
  * Multiple presentation detents (.medium, .large)
  * Dismiss on completion

### 166. Full screen covers untuk immersive views

* Aktor: Sistem
* Keterangan:
  * .fullScreenCover untuk camera, cropper
  * No dismiss gesture (manual dismiss required)
  * Toolbar dengan cancel button

### 167. Smooth animations

* Aktor: Sistem
* Keterangan:
  * State change transitions
  * Progress bar fills
  * Button tap animations (scale)
  * List insertions/deletions
  * withAnimation modifier
  * .easeInOut timing

### 168. Accessibility support

* Aktor: Sistem
* Keterangan:
  * Dynamic Type font scaling
  * VoiceOver labels
  * Accessible color contrast
  * Semantic labels untuk buttons
  * Minimum tap target sizes

### 169. Card-style form design

* Aktor: Sistem
* Keterangan:
  * Consistent card layout untuk inputs
  * Circle icon dengan colored background
  * Border highlight saat active/filled
  * Shadow effect untuk selected states
  * Smooth transitions

### 170. Step indicator untuk multi-step forms

* Aktor: Sistem
* Keterangan:
  * Progress bar di top
  * Filled untuk completed steps
  * Visual feedback current step
  * Used in Create Trip, Add Expense, Create Split Bill

### 171. Success/Error alerts dengan emoji

* Aktor: Sistem
* Keterangan:
  * Success: "🎉", "✅"
  * Error: "⚠️", "❌"
  * Friendly messages dalam Bahasa Indonesia
  * Auto-dismiss atau manual OK

---

## XV. VALIDASI & BUSINESS RULES

### 172. Trip rules

* Aktor: Sistem
* Keterangan:
  * Owner tidak bisa di-kick
  * Hanya Owner bisa delete/finish trip
  * Members bisa leave (kecuali owner)
  * Owner/Admin bisa invite members
  * Status auto-transition berdasarkan dates
  * Finished trips read-only

### 173. Expense rules

* Aktor: Sistem
* Keterangan:
  * Amount harus > 0
  * Minimal 1 participant
  * Item split total harus = total amount
  * Tidak bisa delete jika ada settlement terkait
  * Hanya creator atau admin bisa edit/delete

### 174. Split bill rules

* Aktor: Sistem
* Keterangan:
  * Amount harus > 0
  * Minimal 1 participant
  * Hanya owner bisa mark paid/unpaid
  * Auto-settle saat semua paid
  * Participants bisa termasuk guests (non-app users)

### 175. Friend rules

* Aktor: Sistem
* Keterangan:
  * Tidak bisa add diri sendiri
  * Tidak bisa add jika sudah friends
  * Tidak bisa kirim duplicate request
  * Email harus exist di system
  * Request harus diterima untuk jadi friends

### 176. Member roles dan permissions

* Aktor: Sistem
* Keterangan:
  * Owner: full control, tidak bisa removed, bisa delete/finish
  * Admin: bisa invite, edit trip
  * Member: view, add expense, leave trip
  * Pending: invited tapi belum accept, tidak bisa access

---

## XVI. DATA PERSISTENCE & SYNC

### 177. Firestore collections structure

* Aktor: Sistem
* Keterangan:
  * users: profile data
  * trips: trip documents
  * expenses: expense documents
  * splitBills: split bill documents
  * settlements: payment settlements
  * notifications: user notifications
  * friendRequests: friend request documents
  * tripInvites: trip invitation documents

### 178. Real-time listeners untuk live data

* Aktor: Sistem
* Keterangan:
  * Trips listener: user's trips (memberUIDs array-contains)
  * Expenses listener: trip expenses
  * Split Bills listener: user's bills (participantUIDs)
  * Notifications listener: user's notifications
  * Friend Requests: pending requests
  * Auto-update UI saat data berubah

### 179. Firestore queries

* Aktor: Sistem
* Keterangan:
  * Array-contains untuk memberUIDs, participantUIDs
  * Equality untuk ownerUID, recipientUID, tripID
  * Compound queries dengan multiple conditions
  * Order by createdAt descending
  * Limit untuk pagination

### 180. Auto-populate IDs setelah document creation

* Aktor: Sistem
* Keterangan:
  * Firestore auto-generate document ID
  * Set ID field di model after creation
  * Use ID untuk references dan queries

---

## XVII. SECURITY & ACCESS CONTROL

### 181. Firebase Authentication check

* Aktor: Sistem
* Keterangan:
  * Semua operations require authenticated user
  * User UID dari Firebase Auth
  * Session management otomatis
  * Token refresh handling

### 182. Role-based access control

* Aktor: Sistem
* Keterangan:
  * Owner checks untuk sensitive operations
  * Admin checks untuk moderation actions
  * Member checks untuk participation
  * Client-side enforcement (Firebase Rules recommended)

### 183. Suspended account check

* Aktor: Sistem
* Keterangan:
  * Check user.isSuspended di login/registration
  * Alert dialog jika suspended
  * Prevent access ke app

### 184. Data validation before submission

* Aktor: Sistem
* Keterangan:
  * Client-side validation untuk semua forms
  * Type safety dengan Swift models
  * Required field checks
  * Format validation (email, amounts, dates)
  * Red border untuk invalid fields

### 185. Image size limits enforcement

* Aktor: Sistem
* Keterangan:
  * Max file size: 5MB
  * Auto compression applied
  * Resize ke reasonable dimensions
  * Error message jika exceeded

---

## XVIII. ADDITIONAL FEATURES

### 186. Currency formatting dengan thousand separator

* Aktor: Sistem
* Keterangan:
  * Extension Double.toCurrency()
  * Format: 50.000 atau 50,000
  * Symbol prefix (Rp, $, dll)
  * Auto-formatting di TextField input
  * Remove separator saat parse

### 187. Date formatting dengan locale Indonesia

* Aktor: Sistem
* Keterangan:
  * DateFormatter dengan locale "id_ID"
  * Format: "15 Jan 2026"
  * Relative time: "2 hari yang lalu", "Baru saja"
  * Display readable dates

### 188. Duration calculation untuk trips

* Aktor: Sistem
* Keterangan:
  * Calculate days between startDate dan endDate
  * Display: "5 hari", "1 hari"
  * Used in trip cards dan detail

### 189. Progress calculation untuk bills

* Aktor: Sistem
* Keterangan:
  * Count paid participants / total participants
  * Percentage untuk progress bar
  * Visual bar dengan fill animation
  * Color: green untuk paid, gray untuk unpaid

### 190. Automatic timestamp management

* Aktor: Sistem
* Keterangan:
  * createdAt: saat create document
  * updatedAt: saat update document
  * finishedAt: saat trip finished
  * verifiedAt: saat settlement verified
  * Firebase Timestamp type

### 191. Batch operations untuk efficiency

* Aktor: Sistem
* Keterangan:
  * Batch friend UID updates
  * Batch notification mark as read
  * Batch settlement verifications
  * Reduce Firestore write operations
  * Better performance

### 192. Error logging dan handling

* Aktor: Sistem
* Keterangan:
  * Print statements untuk debugging
  * Error messages capture
  * Graceful error handling
  * User-friendly error display
  * Network error detection

### 193. Cache management

* Aktor: Sistem
* Keterangan:
  * Clear image cache saat avatar update
  * Firestore cache untuk offline access (built-in)
  * Session persistence

### 194. Concurrent async operations

* Aktor: Sistem
* Keterangan:
  * Parallel friend search queries
  * Concurrent notification updates
  * Async/await pattern
  * Task groups untuk parallel execution

### 195. String validation utilities

* Aktor: Sistem
* Keterangan:
  * .isBlank extension untuk empty check
  * .trimmed untuk whitespace removal
  * Email format validation (contains @)
  * Custom validation helpers

---

**TOTAL: 195 FUNGSIONALITAS TERIDENTIFIKASI**

---

## CATATAN TAMBAHAN

### Teknologi yang Digunakan:
- **Frontend**: SwiftUI (iOS)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Cloud Functions**: Node.js dengan TypeScript
- **AI/ML**: OpenAI GPT-4.5-mini API
- **OCR**: Apple Vision Framework
- **Image Processing**: UIKit, Core Image

### Fitur Unggulan:
1. **AI-Powered Receipt Scanning**: OCR + GPT untuk extract data dari struk
2. **Smart Debt Simplification**: Algoritma untuk minimize jumlah transfer
3. **Real-time Collaboration**: Firestore listeners untuk sync instant
4. **Multi-currency Support**: 7 mata uang berbeda
5. **Flexible Splitting**: Item-based split dengan proportional charges
6. **Guest Participants**: Non-app users bisa ikut split bill
7. **Payment Verification**: Photo proof dengan approval flow
8. **Auto Trip Status**: Server-side scheduled function untuk status transition
9. **Comprehensive Notifications**: 8 jenis notifikasi berbeda
10. **Rich Image Handling**: Crop, resize, compress, cloud storage

### Bahasa:
- UI dalam **Bahasa Indonesia**
- Support Indonesian number format
- Indonesian receipt OCR

---

**Dokumentasi dibuat secara otomatis melalui analisis mendalam codebase TripLedger**
