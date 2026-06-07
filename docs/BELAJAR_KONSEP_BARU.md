# 📚 Catatan Belajar — Konsep Baru di BreathMark

> File ini berisi catatan ringkas tentang konsep-konsep baru yang dipelajari selama mengerjakan project BreathMark. Tujuannya supaya bisa di-review ulang nanti tanpa harus tanya ulang dari awal.

---

## 1. Constants (`lib/constants.dart`)

**Apa itu?**
File yang mengumpulkan semua nilai tetap (warna, ukuran, font) di satu tempat, supaya tidak ditulis berulang-ulang di banyak file.

**Kenapa penting?**
- Ganti satu warna → cukup edit di satu tempat, otomatis berubah di semua layar
- Menghindari "magic number" (angka/warna hardcode yang tidak jelas maksudnya)
- Konsistensi tampilan terjamin

**Contoh:**
```dart
const Color kHijauGelap = Color(0xFF1B5E20);
const double kPaddingM = 16.0;
```

Dipakai seperti:
```dart
Padding(padding: const EdgeInsets.all(kPaddingM), ...)
```

**Helper function** juga bisa ditaruh di sini, misalnya fungsi yang mengubah `"high"` menjadi warna merah (`stressColor()`), atau label mood menjadi emoji (`moodEmoji()`). Tujuannya: logika kecil yang dipakai berulang kali, ditulis sekali saja.

---

## 2. Singleton Pattern (`DatabaseHelper`)

**Apa itu?**
Pola desain yang memastikan **hanya ada SATU instance/objek** dari sebuah class di seluruh aplikasi.

**Kenapa penting untuk database?**
Kalau setiap screen membuat koneksi database sendiri-sendiri, bisa terjadi konflik ("database is locked") karena rebutan akses ke file yang sama.

**Cara kerja:**
```dart
static final DatabaseHelper instance = DatabaseHelper._internal();
DatabaseHelper._internal(); // constructor private, tidak bisa dipanggil dari luar
```

Pemakaian di mana saja dalam app selalu mengembalikan objek yang **sama persis**:
```dart
final helper = DatabaseHelper.instance;
```

---

## 3. `Future`, `async`, `await`

**Apa itu?**
Cara menangani operasi yang **butuh waktu** (baca file, akses database, network) tanpa membuat aplikasi "macet" menunggu.

- `Future<T>` = "janji" akan menghasilkan nilai bertipe `T` di masa depan
- `async` = menandai fungsi berjalan secara asynchronous
- `await` = "tunggu sampai proses ini selesai, baru lanjut"

**Analogi:** Memesan makanan di restoran — kasih pesanan (`async`), lalu menunggu (`await`) makanan datang (`Future`), tapi orang lain di restoran tetap bisa dilayani.

```dart
Future<Database> get database async {
  if (_database != null) return _database!;
  _database = await _initDatabase();
  return _database!;
}
```

---

## 4. Lazy Initialization

**Apa itu?**
Membuat sebuah objek **hanya saat benar-benar dibutuhkan**, bukan di awal program. Setelah dibuat sekali, objek itu disimpan (cache) dan dipakai ulang.

```dart
if (_database != null) return _database!;   // sudah ada → pakai yang lama
_database = await _initDatabase();           // belum ada → buat baru
```

Keuntungan: hemat resource, tidak buka koneksi database berkali-kali tanpa perlu.

---

## 5. Konversi Data: `toMap()` dan `fromMap()`

**Masalah:**
Database (SQLite) hanya mengerti format `Map<String, dynamic>` (key-value sederhana), sedangkan kode Dart lebih nyaman bekerja dengan objek model (`SessionModel`) yang punya struktur dan tipe data jelas.

**Solusi — penerjemahan dua arah:**
- **Simpan ke DB:** `SessionModel` → `Map` lewat `toMap()`
- **Baca dari DB:** `Map` → `SessionModel` lewat `fromMap()`

```dart
// Simpan
db.insert('sessions', session.toMap());

// Baca
maps.map((map) => SessionModel.fromMap(map)).toList();
```

---

## 6. Parameterized Query (`where` + `whereArgs`)

**Apa itu?**
Cara menulis filter query SQL dengan **memisahkan perintah SQL dari nilai/data**, menggunakan tanda `?` sebagai placeholder yang nanti diisi lewat parameter terpisah.

```dart
// ✅ AMAN
db.query(
  'sessions',
  where: 'date >= ?',
  whereArgs: [sevenDaysAgo],
);
```

**Kenapa lebih aman dibanding menyambung string langsung?**
```dart
// ❌ BERBAHAYA — rawan SQL Injection
where: "date >= '$sevenDaysAgo'"
```

Kalau nilai disambung langsung ke string SQL, dan nilainya berasal dari input pengguna, orang bisa "menyusupkan" perintah SQL berbahaya (SQL Injection) — misalnya menghapus seluruh tabel lewat input yang dirancang khusus. Dengan parameterized query, nilai diproses terpisah oleh database driver sehingga tidak bisa disusupi perintah tambahan.

**Aturan praktis:** Selalu pakai `?` + `whereArgs` (atau `args` di `rawQuery`) setiap kali ada nilai dinamis (input pengguna, tanggal, ID, dsb) dalam query — jangan pernah menyambung string secara langsung.

---

## 7. `StatelessWidget` vs `StatefulWidget`

| | StatelessWidget | StatefulWidget |
|---|---|---|
| Definisi | Widget yang **tidak punya data yang berubah** | Widget yang **punya data (state) yang bisa berubah** |
| Contoh pemakaian | Logo, label statis, kartu info tetap | Counter, form input, animasi, hasil sensor real-time |
| Struktur | Langsung override `build()` | Pisah jadi 2 class: `Widget` + `State<Widget>` |

```dart
// StatelessWidget — tampilan tetap
class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) => Image.asset('assets/logo.png');
}

// StatefulWidget — tampilan bisa berubah
class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}
class _CounterState extends State<Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) =>
      ElevatedButton(onPressed: () => setState(() => count++), child: Text('$count'));
}
```

---

## 8. Inheritance (`extends`) & `const` Constructor

- `extends` = pewarisan sifat/fungsi dari class lain (class anak otomatis punya kemampuan class induk)
- `const` constructor = menandai objek bersifat compile-time constant, sehingga Flutter bisa mengoptimalkan memory (objek yang identik tidak dibuat ulang)
- `{super.key}` = boilerplate untuk meneruskan identifier unik widget ke parent class

```dart
class BreathMarkApp extends StatelessWidget {
  const BreathMarkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'BreathMark', ...);
}
```

---

## 🔑 Pola Umum yang Perlu Dikenali

| Ciri di Kode | Artinya |
|---|---|
| `static final X instance = X._internal();` | Singleton pattern |
| `Future<T>` + `async`/`await` | Operasi asynchronous (butuh waktu) |
| `db.query/insert/execute(...)` | Operasi CRUD ke database |
| `.map((x) => Model.fromMap(x)).toList()` | Konversi data mentah → objek model |
| `where: '...'` + `whereArgs: [...]` | Parameterized query (aman dari SQL Injection) |
| `extends StatelessWidget` / `StatefulWidget` | Jenis widget (statis vs dinamis) |

---

*Catatan ini akan terus ditambah seiring progres sprint berjalan.*
