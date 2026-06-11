# 📘 LIST FUNGSIONALITAS TRIP LEDGER

## I. AUTENTIKASI & AKSES
1. Menampilkan halaman landing page informasi aplikasi (Umum)
2. Registrasi akun baru (Sign Up) — User, Owner  
   - Input: nama, email, password
3. Error jika email sudah terdaftar (Validasi database)
4. Error jika format email/password salah (Minimal 8 karakter)
5. Alert sukses saat registrasi berhasil
6. Login ke aplikasi — User, Owner, Admin
7. Error jika email atau password salah
8. Alert jika akun di-suspend (Tidak bisa masuk dashboard)
9. Aktivasi menu sesuai role
10. Request reset password (Lupa Password)
11. Kirim email link reset password otomatis
12. Reset password via link
13. Ubah password dari menu pengaturan (wajib password lama)
14. Error jika password lama tidak cocok
15. Logout (session terhapus)

---

## II. KELOLA PROFIL PENGGUNA
16. Lihat profil diri sendiri
17. Ubah profil (Nama, Username, Bio)
18. Upload / ubah foto profil
19. Error jika foto > 2MB
20. Hapus foto profil (default avatar)
21. Error jika data profil/rekening tidak lengkap
22. Alert sukses setelah update profil

---

## III. MANAJEMEN RELASI ANTAR PENGGUNA
23. Search user (username/email)
24. Error jika user tidak ditemukan
25. Add friend
26. Alert jika sudah berteman
27. Friend list
28. Hapus teman
29. Konfirmasi sebelum hapus
30. List permintaan pertemanan (Pending)
31. Terima pertemanan
32. Tolak pertemanan
33. Alert sukses update status

---

## IV. MANAJEMEN PERJALANAN (TRIP)
34. Buat trip baru (User jadi Owner)
35. Error jika nama/tujuan kosong
36. Edit trip (Nama, Tanggal, Tujuan)
37. List trip aktif
38. Riwayat trip selesai
39. Search trip
40. Set trip selesai
41. Error jika masih ada hutang
42. Hapus trip
43. Konfirmasi hapus
44. Error jika non-owner mencoba hapus
45. Undang anggota (via friend list)
46. Terima undangan trip
47. Tolak undangan trip

---

## V. AKSES & KEANGGOTAAN TRIP
48. List anggota trip
49. Search anggota
50. Kick anggota (Owner only)
51. Konfirmasi kick
52. Error jika anggota masih punya hutang
53. Transfer ownership
54. Alert sukses transfer
55. Leave trip (Owner harus pindah role dulu)

---

## VI. PENGELOLAAN PENGELUARAN
56. Tambah pengeluaran manual
57. Scan struk (kamera/galeri)
58. Upload foto struk
59. OCR AI ekstraksi data otomatis
60. Error jika gambar buram
61. Preview hasil scan (item, qty, harga)
62. Edit hasil scan
63. Tambah item manual
64. Hapus item sebelum save
65. Pilih kategori pengeluaran
66. Split equally
67. Split by item
68. Error jika total tidak sesuai
69. Simpan pengeluaran
70. List semua pengeluaran
71. Detail pengeluaran
72. Lihat foto struk
73. Search pengeluaran
74. Filter kategori
75. Edit pengeluaran  
   - User: hanya miliknya  
   - Owner: semua
76. Hapus pengeluaran
77. Konfirmasi hapus

---

## VII. HUTANG & PELUNASAN
78. Hitung hutang/piutang otomatis
79. Debt simplification (Min Cash Flow)
80. Saldo total user
81. Rekomendasi pembayaran  
   - Contoh: A → B Rp50rb
82. Detail rekening tujuan
83. Upload bukti transfer
84. Alert sukses (status: Menunggu Verifikasi)
85. Error jika belum upload file
86. Verifikasi pembayaran (penerima)
87. Tolak pembayaran
88. Input alasan penolakan
89. Update status jadi Lunas
90. Update saldo otomatis
91. Riwayat pelunasan

---

## VIII. LAPORAN & NOTIFIKASI
92. Ringkasan total trip
93. Pie chart pengeluaran
94. Export PDF laporan
95. Inbox notifikasi
96. Notifikasi undangan trip (Accept/Reject)
97. Notifikasi pengeluaran baru
98. Notifikasi bukti transfer
99. Notifikasi verifikasi pembayaran
100. Highlight notifikasi unread
101. Tandai sudah dibaca
102. Hapus notifikasi

---

## IX. ADMIN SYSTEM
103. Dashboard statistik (Total User, Trip, dll)
104. List semua user
105. Search user
106. Suspend user
107. Un-suspend user
108. Hapus user permanen
109. List semua trip
110. Hapus trip bermasalah/spam