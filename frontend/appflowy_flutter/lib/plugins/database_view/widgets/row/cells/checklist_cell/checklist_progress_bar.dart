import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'checklist_cell_bloc.dart';

class ChecklistProgressBar extends StatefulWidget {
  final List<ChecklistSelectOption> tasks;
  final double percent;
  final int segmentLimit = 5;

  const ChecklistProgressBar({
    required this.tasks,
    required this.percent,
    Key? key,
  }) : super(key: key);

  @override
  State<ChecklistProgressBar> createState() => _ChecklistProgressBarState();
}

class _ChecklistProgressBarState extends State<ChecklistProgressBar> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (widget.tasks.isNotEmpty &&
                  widget.tasks.length <= widget.segmentLimit) ...[
                for (int i = 0,
                        j = widget.tasks.where((e) => e.isSelected).length;
                    i < widget.tasks.length;
                    i++, j--)
                  Expanded(
                    child: LinearPercentIndicator(
                      lineHeight: 4.0,
                      percent: j > 0 ? 1.0 : 0.0,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      progressColor: Theme.of(context).colorScheme.primary,
                      backgroundColor:
                          AFThemeExtension.of(context).progressBarBGColor,
                      barRadius: const Radius.circular(5),
                    ),
                  ),
              ] else ...[
                Expanded(
                  child: LinearPercentIndicator(
                    lineHeight: 4.0,
                    percent: widget.percent,
                    padding: EdgeInsets.zero,
                    progressColor: Theme.of(context).colorScheme.primary,
                    backgroundColor:
                        AFThemeExtension.of(context).progressBarBGColor,
                    barRadius: const Radius.circular(5),
                  ),
                ),
              ]
            ],
          ),
        ),
        SizedBox(
          width: 36,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FlowyText.regular(
              "${(widget.percent * 100).round()}%",
              fontSize: 11,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      ],
    );
  }
}
