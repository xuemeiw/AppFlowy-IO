library document_plugin;

import 'package:app_flowy/generated/locale_keys.g.dart';
import 'package:app_flowy/plugins/util.dart';
import 'package:app_flowy/startup/plugin/plugin.dart';
import 'package:app_flowy/startup/startup.dart';
import 'package:app_flowy/plugins/doc/application/share_bloc.dart';
import 'package:app_flowy/workspace/presentation/home/home_stack.dart';
import 'package:app_flowy/workspace/presentation/home/toast.dart';
import 'package:app_flowy/workspace/presentation/widgets/left_bar_item.dart';
import 'package:app_flowy/workspace/presentation/widgets/dialogs.dart';
import 'package:app_flowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:clipboard/clipboard.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/widget/rounded_button.dart';
import 'package:flowy_sdk/log.dart';
import 'package:flowy_sdk/protobuf/flowy-error/errors.pb.dart';
import 'package:flowy_sdk/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_sdk/protobuf/flowy-document/entities.pb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'document_page.dart';

class DocumentPluginBuilder extends PluginBuilder {
  @override
  Plugin build(dynamic data) {
    if (data is ViewPB) {
      return DocumentPlugin(pluginType: pluginType, view: data);
    } else {
      throw FlowyPluginException.invalidData;
    }
  }

  @override
  String get menuName => LocaleKeys.document_menuName.tr();

  @override
  String get menuIcon => "editor/documents";

  @override
  PluginType get pluginType => PluginType.editor;

  @override
  ViewDataFormatPB get dataFormatType => ViewDataFormatPB.TreeFormat;
}

class DocumentPlugin extends Plugin<int> {
  late PluginType _pluginType;

  @override
  final ViewPluginNotifier notifier;

  DocumentPlugin({
    required PluginType pluginType,
    required ViewPB view,
    Key? key,
  }) : notifier = ViewPluginNotifier(view: view) {
    _pluginType = pluginType;
  }

  @override
  PluginDisplay get display => DocumentPluginDisplay(notifier: notifier);

  @override
  PluginType get ty => _pluginType;

  @override
  PluginId get id => notifier.view.id;
}

class DocumentPluginDisplay extends PluginDisplay with NavigationItem {
  final ViewPluginNotifier notifier;
  ViewPB get view => notifier.view;
  int? deletedViewIndex;

  DocumentPluginDisplay({required this.notifier, Key? key});

  @override
  Widget buildWidget(PluginContext context) {
    notifier.isDeleted.addListener(() {
      notifier.isDeleted.value.fold(() => null, (deletedView) {
        if (deletedView.hasIndex()) {
          deletedViewIndex = deletedView.index;
        }
      });
    });

    return DocumentPage(
      view: view,
      onDeleted: () => context.onDeleted(view, deletedViewIndex),
      key: ValueKey(view.id),
    );
  }

  @override
  Widget get leftBarItem => ViewLeftBarItem(view: view);

  @override
  Widget? get rightBarItem => DocumentShareButton(view: view);

  @override
  List<NavigationItem> get navigationItems => [this];
}

class DocumentShareButton extends StatelessWidget {
  final ViewPB view;
  DocumentShareButton({Key? key, required this.view})
      : super(key: ValueKey(view.hashCode));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<DocShareBloc>(param1: view),
      child: BlocListener<DocShareBloc, DocShareState>(
        listener: (context, state) {
          state.map(
            initial: (_) {},
            loading: (_) {},
            finish: (state) {
              state.successOrFail.fold(
                _handleExportData,
                _handleExportError,
              );
            },
          );
        },
        child: BlocBuilder<DocShareBloc, DocShareState>(
          builder: (context, state) => ConstrainedBox(
            constraints: const BoxConstraints.expand(
              height: 30,
              width: 100,
            ),
            child: ShareActionList(view: view),
          ),
        ),
      ),
    );
  }

  void _handleExportData(ExportDataPB exportData) {
    switch (exportData.exportType) {
      case ExportType.Link:
        break;
      case ExportType.Markdown:
        FlutterClipboard.copy(exportData.data)
            .then((value) => Log.info('copied to clipboard'));
        break;
      case ExportType.Text:
        break;
    }
  }

  void _handleExportError(FlowyError error) {}
}

class ShareActionList extends StatelessWidget {
  const ShareActionList({
    Key? key,
    required this.view,
  }) : super(key: key);

  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    final docShareBloc = context.read<DocShareBloc>();
    return PopoverActionList<ShareActionWrapper>(
      direction: PopoverDirection.bottomWithCenterAligned,
      actions: ShareAction.values
          .map((action) => ShareActionWrapper(action))
          .toList(),
      buildChild: (controller) {
        return RoundedTextButton(
          title: LocaleKeys.shareAction_buttonText.tr(),
          fontSize: FontSizes.s12,
          borderRadius: Corners.s6Border,
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => controller.show(),
        );
      },
      onSelected: (action, controller) async {
        switch (action.inner) {
          case ShareAction.markdown:
            final exportPath = await FilePicker.platform.saveFile(
              dialogTitle: '',
              fileName: '${view.name}.md',
            );
            if (exportPath != null) {
              docShareBloc.add(DocShareEvent.shareMarkdown(exportPath));
              showMessageToast('Exported to: $exportPath');
            }
            break;
          case ShareAction.copyLink:
            NavigatorAlertDialog(
                    title: LocaleKeys.shareAction_workInProgress.tr())
                .show(context);
            break;
        }
        controller.close();
      },
    );
  }
}

enum ShareAction {
  markdown,
  copyLink,
}

class ShareActionWrapper extends ActionCell {
  final ShareAction inner;

  ShareActionWrapper(this.inner);

  @override
  Widget? icon(Color iconColor) => null;

  @override
  String get name => inner.name;
}

extension QuestionBubbleExtension on ShareAction {
  String get name {
    switch (this) {
      case ShareAction.markdown:
        return LocaleKeys.shareAction_markdown.tr();
      case ShareAction.copyLink:
        return LocaleKeys.shareAction_copyLink.tr();
    }
  }
}
