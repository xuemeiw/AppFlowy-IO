import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/database/card/card.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/application/row/row_cache.dart';
import 'package:appflowy/plugins/database/board/application/board_bloc.dart';
import 'package:appflowy/plugins/database/widgets/card/card_cell_builder.dart';
import 'package:appflowy/plugins/database/widgets/card/cells/card_cell.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/text_cell/text_cell_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MobileHiddenGroupsColumn extends StatelessWidget {
  const MobileHiddenGroupsColumn({super.key, required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final databaseController = context.read<BoardBloc>().databaseController;
    return BlocSelector<BoardBloc, BoardState, BoardLayoutSettingPB?>(
      selector: (state) => state.layoutSettings,
      builder: (context, layoutSettings) {
        if (layoutSettings == null) {
          return const SizedBox.shrink();
        }
        final isCollapsed = layoutSettings.collapseHiddenGroups;
        return Container(
          padding: padding,
          child: AnimatedSize(
            alignment: AlignmentDirectional.topStart,
            curve: Curves.easeOut,
            duration: const Duration(milliseconds: 150),
            child: isCollapsed
                ? SizedBox(
                    height: 50,
                    child: _collapseExpandIcon(context, isCollapsed),
                  )
                : SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Spacer(),
                            _collapseExpandIcon(context, isCollapsed),
                          ],
                        ),
                        Text(
                          LocaleKeys.board_hiddenGroupSection_sectionTitle.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                        ),
                        const VSpace(8),
                        Expanded(
                          child: MobileHiddenGroupList(
                            databaseController: databaseController,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _collapseExpandIcon(BuildContext context, bool isCollapsed) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: IconButton(
        icon: FlowySvg(
          isCollapsed
              ? FlowySvgs.hamburger_s_s
              : FlowySvgs.pull_left_outlined_s,
          size: isCollapsed ? const Size.square(12) : const Size.square(40),
        ),
        onPressed: () => context
            .read<BoardBloc>()
            .add(BoardEvent.toggleHiddenSectionVisibility(!isCollapsed)),
      ),
    );
  }
}

class MobileHiddenGroupList extends StatelessWidget {
  const MobileHiddenGroupList({
    super.key,
    required this.databaseController,
  });

  final DatabaseController databaseController;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BoardBloc>();
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (_, state) => ReorderableListView.builder(
        itemCount: state.hiddenGroups.length,
        itemBuilder: (_, index) => MobileHiddenGroup(
          key: ValueKey(state.hiddenGroups[index].groupId),
          group: state.hiddenGroups[index],
          index: index,
          bloc: bloc,
        ),
        physics: const ClampingScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          if (oldIndex < newIndex) {
            newIndex--;
          }
          final fromGroupId = state.hiddenGroups[oldIndex].groupId;
          final toGroupId = state.hiddenGroups[newIndex].groupId;
          bloc.add(BoardEvent.reorderGroup(fromGroupId, toGroupId));
        },
      ),
    );
  }
}

class MobileHiddenGroup extends StatelessWidget {
  const MobileHiddenGroup({
    super.key,
    required this.group,
    required this.index,
    required this.bloc,
  });

  final GroupPB group;
  final BoardBloc bloc;
  final int index;

  @override
  Widget build(BuildContext context) {
    final databaseController = bloc.databaseController;
    final primaryField = databaseController.fieldController.fieldInfos
        .firstWhereOrNull((element) => element.isPrimary)!;

    return BlocProvider<BoardBloc>.value(
      value: bloc,
      child: BlocBuilder<BoardBloc, BoardState>(
        builder: (context, state) {
          final group = state.hiddenGroups.firstWhereOrNull(
            (g) => g.groupId == this.group.groupId,
          );
          if (group == null) {
            return const SizedBox.shrink();
          }

          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    group.groupName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: FlowySvg(
                      FlowySvgs.hide_m,
                      size: Size.square(20),
                    ),
                  ),
                  onTap: () => showFlowyMobileConfirmDialog(
                    context,
                    title: LocaleKeys.board_mobile_unhideGroup.tr(),
                    content: LocaleKeys.board_mobile_unhideGroupContent.tr(),
                    actionButtonTitle: LocaleKeys.button_yes.tr(),
                    actionButtonColor: Theme.of(context).colorScheme.primary,
                    onActionButtonPressed: () => context.read<BoardBloc>().add(
                          BoardEvent.toggleGroupVisibility(
                            group,
                            true,
                          ),
                        ),
                  ),
                ),
              ],
            ),
            children: [
              MobileHiddenGroupItemList(
                bloc: bloc,
                viewId: databaseController.viewId,
                groupId: group.groupId,
                primaryField: primaryField,
                rowCache: databaseController.rowCache,
              ),
            ],
          );
        },
      ),
    );
  }
}

class MobileHiddenGroupItemList extends StatelessWidget {
  const MobileHiddenGroupItemList({
    required this.bloc,
    required this.groupId,
    required this.viewId,
    required this.primaryField,
    required this.rowCache,
    super.key,
  });

  final BoardBloc bloc;
  final String groupId;
  final String viewId;
  final FieldInfo primaryField;
  final RowCache rowCache;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: BlocBuilder<BoardBloc, BoardState>(
        builder: (context, state) {
          final group = state.hiddenGroups.firstWhereOrNull(
            (g) => g.groupId == groupId,
          );
          if (group == null) {
            return const SizedBox.shrink();
          }

          final cells = <Widget>[
            ...group.rows.map(
              (item) {
                final cellContext = rowCache.loadCells(item)[primaryField.id]!;
                final renderHook = RowCardRenderHook<String>();
                renderHook.addTextCellHook((cellData, _, __) {
                  return BlocBuilder<TextCellBloc, TextCellState>(
                    builder: (context, state) {
                      final text = cellData.isEmpty
                          ? LocaleKeys.grid_row_titlePlaceholder.tr()
                          : cellData;

                      if (text.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Row(
                        children: [
                          if (!cellContext.rowMeta.isDocumentEmpty) ...[
                            const FlowySvg(FlowySvgs.notes_s),
                            const HSpace(4),
                          ],
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                });

                return TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                    foregroundColor: Theme.of(context).colorScheme.onBackground,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: CardCellBuilder<String>(rowCache.cellCache).build(
                    cellContext: cellContext,
                    renderHook: renderHook,
                    hasNotes: !cellContext.rowMeta.isDocumentEmpty,
                  ),
                  onPressed: () {
                    context.push(
                      MobileRowDetailPage.routeName,
                      extra: {
                        MobileRowDetailPage.argRowId: item.id,
                        MobileRowDetailPage.argDatabaseController:
                            context.read<BoardBloc>().databaseController,
                      },
                    );
                  },
                );
              },
            ),
          ];

          return ListView.builder(
            itemBuilder: (context, index) => cells[index],
            itemCount: cells.length,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
          );
        },
      ),
    );
  }
}
