class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.hasMore,
    this.nextStart,
  });

  final List<T> items;
  final bool hasMore;
  final int? nextStart;
}
