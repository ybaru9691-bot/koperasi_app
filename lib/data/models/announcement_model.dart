///  Model Data Pengumuman & Berita Koperasi
class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String category; // 'PENTING', 'INFORMASI', 'PROMO'
  final String date;
  final String author;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    required this.author,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    // Support both API field names and legacy dummy field names
    final String date = json['formatted_date']
        ?? json['date']
        ?? json['tanggal']
        ?? json['created_at']
        ?? '-';

    final String author = json['author_name']
        ?? json['author']
        ?? json['penulis']
        ?? 'Pengurus Koperasi';

    final String rawCategory = (json['category'] ?? json['kategori'] ?? 'INFORMASI').toString().toUpperCase();
    // Normalise legacy values from Flutter dummy data
    final String category = rawCategory == 'KEGIATAN' ? 'INFORMASI' : rawCategory;

    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['judul'] ?? '',
      content: json['content'] ?? json['isi'] ?? '',
      category: category,
      date: date,
      author: author,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'date': date,
        'author': author,
      };
}
