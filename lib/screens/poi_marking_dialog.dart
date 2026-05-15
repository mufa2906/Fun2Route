import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum PoiCategory { interesting, avoidMotorcycle, avoidNoSidewalk }

class PoiResult {
  final PoiCategory category;
  final String note;
  final bool isAvoidance;

  PoiResult({
    required this.category,
    required this.note,
    required this.isAvoidance,
  });
}

/// Modal dialog for marking the current location during navigation.
/// Implements flows.md §10 — POI & Avoidance marking.
class PoiMarkingDialog extends StatefulWidget {
  const PoiMarkingDialog({super.key});

  @override
  State<PoiMarkingDialog> createState() => _PoiMarkingDialogState();
}

class _PoiMarkingDialogState extends State<PoiMarkingDialog> {
  PoiCategory? _selectedCategory;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.mapPin, color: KineticFlowTheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Mark This Location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Selection
            _buildCategoryTile(
              PoiCategory.interesting,
              'Interesting Location',
              LucideIcons.star,
              KineticFlowTheme.tertiary,
            ),
            const SizedBox(height: 8),
            _buildCategoryTile(
              PoiCategory.avoidMotorcycle,
              'Avoid — Busy with motorcycles',
              LucideIcons.alertTriangle,
              Colors.red,
            ),
            const SizedBox(height: 8),
            _buildCategoryTile(
              PoiCategory.avoidNoSidewalk,
              'Avoid — No sidewalk',
              LucideIcons.alertTriangle,
              Colors.red,
            ),

            const SizedBox(height: 16),

            // Note Input
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KineticFlowTheme.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedCategory == null
                        ? null
                        : () {
                            Navigator.pop(
                              context,
                              PoiResult(
                                category: _selectedCategory!,
                                note: _noteCtrl.text,
                                isAvoidance:
                                    _selectedCategory !=
                                    PoiCategory.interesting,
                              ),
                            );
                          },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
    PoiCategory category,
    String label,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : KineticFlowTheme.onSurface,
                ),
              ),
            ),
            if (isSelected) Icon(LucideIcons.check, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
