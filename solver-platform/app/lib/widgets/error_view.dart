import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_error.dart';
import '../core/theme.dart';

/// Full/partial error state with a friendly message and collapsible technical
/// details for support/developer diagnosis.
class ErrorView extends StatefulWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
    this.compact = false,
  });

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  late AppError _info;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _info = describeError(widget.error);
  }

  @override
  void didUpdateWidget(covariant ErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error) {
      _info = describeError(widget.error);
      _showDetails = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          color: SolverTheme.error,
          size: widget.compact ? 36 : 52,
        ),
        const SizedBox(height: 16),
        Text(
          _info.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: widget.compact ? 16 : 20,
            fontWeight: FontWeight.bold,
            color: SolverTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _info.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: SolverTheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        if (_info.hint != null) ...[
          const SizedBox(height: 6),
          Text(
            _info.hint!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: SolverTheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
        if (widget.onRetry != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text(widget.retryLabel),
          ),
        ],
        if (_info.details != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            icon: Icon(
              _showDetails ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _showDetails ? 'إخفاء التفاصيل التقنية' : 'عرض التفاصيل التقنية',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (_showDetails) _DetailsBox(text: _info.details!),
        ],
      ],
    );

    if (widget.compact) return content;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }
}

/// SnackBar with the friendly message and a "تفاصيل" action.
void showErrorSnack(BuildContext context, Object error, {String? action}) {
  final info = describeError(error, action: action);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: SolverTheme.error,
      duration: const Duration(seconds: 7),
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.summary,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
      action: info.details == null
          ? null
          : SnackBarAction(
              label: 'تفاصيل',
              textColor: Colors.white,
              onPressed: () => showErrorDetailsDialog(context, info),
            ),
    ),
  );
}

/// Dialog with the friendly message plus selectable/copyable technical details.
Future<void> showErrorDetailsDialog(
  BuildContext context,
  AppError info,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SolverTheme.surface,
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: SolverTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.title,
              style: const TextStyle(
                color: SolverTheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.message,
              style: const TextStyle(
                color: SolverTheme.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (info.hint != null) ...[
              const SizedBox(height: 8),
              Text(
                info.hint!,
                style: TextStyle(
                  color: SolverTheme.onSurface.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            if (info.details != null) ...[
              const SizedBox(height: 16),
              const Text(
                'التفاصيل التقنية',
                style: TextStyle(
                  color: SolverTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _DetailsBox(text: info.details!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}

class _DetailsBox extends StatelessWidget {
  final String text;

  const _DetailsBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SolverTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ التفاصيل')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('نسخ', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: SolverTheme.gold,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          SelectableText(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.5,
              color: SolverTheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}