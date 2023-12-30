import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/setting_file_importer_bloc.dart';
import 'package:appflowy/workspace/presentation/home/toast.dart';
import 'package:appflowy_backend/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

class ImportAppFlowyData extends StatefulWidget {
  const ImportAppFlowyData({super.key});

  @override
  State<ImportAppFlowyData> createState() => _ImportAppFlowyDataState();
}

class _ImportAppFlowyDataState extends State<ImportAppFlowyData> {
  final _fToast = FToast();
  @override
  void initState() {
    super.initState();
    _fToast.init(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingFileImporterBloc(),
      child: BlocListener<SettingFileImporterBloc, SettingFileImportState>(
        listener: (context, state) {
          state.successOrFail.fold(
            () {},
            (either) {
              either.fold(
                (unit) {
                  _showToast(LocaleKeys.settings_menu_importSuccess.tr());
                },
                (err) {
                  _showToast(LocaleKeys.settings_menu_importFailed.tr());
                },
              );
            },
          );
        },
        child: BlocBuilder<SettingFileImporterBloc, SettingFileImportState>(
          builder: (context, state) {
            return const Column(
              children: [
                ImportAppFlowyDataButton(),
                VSpace(6),
                AppFlowyDataImportTip(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showToast(String message) {
    _fToast.showToast(
      child: FlowyMessageToast(message: message),
      gravity: ToastGravity.CENTER,
    );
  }
}

class AppFlowyDataImportTip extends StatelessWidget {
  final url = "https://docs.appflowy.io/docs/appflowy/product/data-storage";
  const AppFlowyDataImportTip({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: LocaleKeys.settings_menu_importAppFlowyDataDescription.tr(),
              style: Theme.of(context).textTheme.bodySmall!,
            ),
            TextSpan(
              text: " ${LocaleKeys.settings_menu_importGuide.tr()} ",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
              recognizer: TapGestureRecognizer()..onTap = () => _launchURL(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Log.error("Could not launch $url");
    }
  }
}

class ImportAppFlowyDataButton extends StatefulWidget {
  const ImportAppFlowyDataButton({super.key});

  @override
  State<ImportAppFlowyDataButton> createState() =>
      _ImportAppFlowyDataButtonState();
}

class _ImportAppFlowyDataButtonState extends State<ImportAppFlowyDataButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FlowyButton(
        text: FlowyText(LocaleKeys.settings_menu_importAppFlowyData.tr()),
        onTap: () async {
          final path = await getIt<FilePickerService>().getDirectoryPath();
          if (path == null) {
            return;
          }
          if (!mounted) {
            return;
          }

          context
              .read<SettingFileImporterBloc>()
              .add(SettingFileImportEvent.importAppFlowyDataFolder(path));
        },
      ),
    );
  }
}
