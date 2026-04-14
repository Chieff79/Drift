import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/profile/add/widgets/widgets.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<void> _scanQrFromImage(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;
  final filePath = result.files.first.path;
  if (filePath == null) return;

  final controller = MobileScannerController();
  try {
    final barcodeCapture = await controller.analyzeImage(filePath);
    if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
      final rawData = barcodeCapture.barcodes.first.rawValue;
      if (rawData != null && context.mounted) {
        ref.read(addProfileNotifierProvider.notifier).addClipboard(rawData);
        return;
      }
    }
    // QR code not found in image
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR-код не найден на изображении')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка чтения QR-кода')),
      );
    }
  } finally {
    controller.dispose();
  }
}

class FixBtns extends ConsumerWidget {
  const FixBtns({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final isDesktop = PlatformUtils.isDesktop;
    return Row(
      children: [
        if (!isDesktop) ...[
          const Gap(AddProfileModalConst.fixBtnsGap),
          FixBtn(
            key: const ValueKey('add_by_qr_code_button'),
            height: height,
            title: t.common.scanQr,
            icon: Icons.qr_code_scanner,
            onTap: () async {
              final cr = await ref.read(dialogNotifierProvider.notifier).showQrScanner();
              if (cr == null) return;
              ref.read(addProfileNotifierProvider.notifier).addClipboard(cr);
            },
          ),
        ],
        const Gap(AddProfileModalConst.fixBtnsGap),
        FixBtn(
          key: const ValueKey('add_by_qr_from_image_button'),
          height: height,
          title: 'QR из фото',
          icon: Icons.image_search_rounded,
          onTap: () => _scanQrFromImage(context, ref),
        ),
        const Gap(AddProfileModalConst.fixBtnsGap),
        FixBtn(
          key: const ValueKey('add_from_clipboard_button'),
          height: height,
          title: t.common.clipboard,
          icon: Icons.content_paste,
          onTap: () async {
            final cr = await Clipboard.getData(Clipboard.kTextPlain).then((value) => value?.text ?? '');
            ref.read(addProfileNotifierProvider.notifier).addClipboard(cr);
          },
        ),
        const Gap(AddProfileModalConst.fixBtnsGap),
        FixBtn(
          key: const ValueKey('add_manually_button'),
          height: height,
          title: t.common.manually,
          icon: Icons.add,
          onTap: () {
            ref.read(addProfilePageNotifierProvider.notifier).goManual();
          },
        ),
        const Gap(AddProfileModalConst.fixBtnsGap),
      ],
    );
  }
}
