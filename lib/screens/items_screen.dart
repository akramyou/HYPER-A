import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _search = TextEditingController();
  late Future<List<InventoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getItems();
    _search.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _search.dispose();
    super.dispose();
  }

  void _searchChanged() => setState(() => _future = DatabaseHelper.instance.getItems(search: _search.text));

  Future<void> _reload() async {
    setState(() => _future = DatabaseHelper.instance.getItems(search: _search.text));
    await _future;
  }

  Future<void> _addItem() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddItemScreen()));
    if (changed == true && mounted) {
      await _reload();
      widget.onChanged();
    }
  }

  Future<void> _open(InventoryItem item) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: item.id!)));
    if (mounted) await _reload();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(onPressed: _addItem, backgroundColor: AppTheme.green, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('إضافة صنف')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
            controller: _search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بالاسم أو الكود أو الموقع', suffixIcon: Icon(Icons.tune_rounded)),
          )),
          Expanded(child: FutureBuilder<List<InventoryItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
              if (snapshot.hasError) return Center(child: Text('تعذر تحميل الأصناف: ${snapshot.error}'));
              final items = snapshot.data ?? [];
              if (items.isEmpty) return EmptyState(icon: Icons.inventory_2_outlined, title: _search.text.isEmpty ? 'لا توجد أصناف بعد' : 'لا توجد نتائج', message: _search.text.isEmpty ? 'استورد تقرير المبيعات أو أضف صنفًا يدويًا لبدء العمل.' : 'جرّب كلمة بحث أو كودًا مختلفًا.', action: _search.text.isEmpty ? FilledButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('إضافة أول صنف')) : null);
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _ItemCard(item: items[index], onTap: () => _open(items[index])),
                ),
              );
            },
          )),
        ]),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final InventoryItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(14)), child: Center(child: Text(item.uom.isNotEmpty ? item.uom.substring(0, 1) : 'ص', style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w900, fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 5),
              Text('كود النظام: ${item.appsCode}  •  POS: ${item.posCode}', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 6),
              Row(children: [Icon(Icons.location_on_outlined, size: 14, color: AppTheme.muted), const SizedBox(width: 3), Text(item.whLocCode.isEmpty ? 'موقع غير محدد' : 'الموقع ${item.whLocCode}', style: const TextStyle(fontSize: 11, color: AppTheme.muted)), const Spacer(), if (item.isFlyer) const Chip(label: Text('نشرة', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)]),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('مخزون الفرع', style: TextStyle(fontSize: 10, color: AppTheme.muted)),
              Text(formatQuantity(item.brStock), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: item.brStock < 0 ? AppTheme.red : AppTheme.green)),
              Text(item.uom, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
            ]),
            const SizedBox(width: 4), const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
          ])),
        ),
      );
}
