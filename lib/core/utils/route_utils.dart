String franchiseRouteFor(int anilistId, String entryId) {
  if (anilistId > 0) return '/franchise/$anilistId';
  final m = RegExp(r'mal-(\d+)').firstMatch(entryId);
  if (m != null) return '/franchise/mal-${m.group(1)}';
  return '/franchise/$anilistId';
}
