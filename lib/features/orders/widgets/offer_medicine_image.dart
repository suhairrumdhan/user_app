import 'package:flutter/material.dart';
import '../../search/views/search_ui_colors.dart';

/// Compact image tile shared by offer rows; missing images use an icon only.
class OfferMedicineImage extends StatelessWidget {
  const OfferMedicineImage({
    super.key,
    this.url,
    this.name = '',
    this.size = 52,
  });
  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    const color = SearchUiColors.primary;
    final source = url?.trim() ?? '';
    Widget fallback() => Center(
      child: Icon(Icons.medication_outlined, color: color, size: size * .45),
    );
    return Material(
      color: color.withValues(alpha: .07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withValues(alpha: .15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: source.isEmpty
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(name),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * .55,
                        child: InteractiveViewer(
                          child: Image.network(
                            source,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) => fallback(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        child: SizedBox(
          width: size,
          height: size,
          child: source.isEmpty
              ? fallback()
              : Image.network(
                  source,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => fallback(),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback(),
                ),
        ),
      ),
    );
  }
}
