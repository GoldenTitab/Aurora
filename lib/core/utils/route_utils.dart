/// مسیر صفحه فرنچایز بر اساس شناسه انیلیست یا شناسه اثر.
///
/// اگر شناسه انیلیست معتبر باشد از آن استفاده می‌شود؛ در غیر این صورت اگر
/// شناسه اثر با الگوی `mal-<id>` شروع شود، مسیر مخصوص MAL ساخته می‌شود.
String franchiseRouteFor(int anilistId, String entryId) {
  if (anilistId > 0) return '/franchise/$anilistId';
  final m = RegExp(r'mal-(\d+)').firstMatch(entryId);
  if (m != null) return '/franchise/mal-${m.group(1)}';
  return '/franchise/$anilistId';
}
