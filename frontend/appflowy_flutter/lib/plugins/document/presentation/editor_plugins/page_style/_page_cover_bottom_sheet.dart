import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/page_style/_page_style_util.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/page_style/cover_image_gradient_colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PageCoverBottomSheet extends StatelessWidget {
  const PageCoverBottomSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentPageStyleBloc, DocumentPageStyleState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FlowyText(
                LocaleKeys.pageStyle_colors.tr(),
                color: context.pageStyleTextColor,
              ),
              const VSpace(8.0),
              SizedBox(
                height: 42.0,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: FlowyTint.values.length,
                  separatorBuilder: (context, index) => const HSpace(12.0),
                  itemBuilder: (context, index) => _buildColorButton(
                    context,
                    state,
                    FlowyTint.values[index],
                  ),
                ),
              ),
              const VSpace(20.0),
              FlowyText(
                LocaleKeys.pageStyle_gradient.tr(),
                color: context.pageStyleTextColor,
              ),
              const VSpace(8.0),
              SizedBox(
                height: 42.0,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: FlowyGradientColor.values.length,
                  separatorBuilder: (context, index) => const HSpace(12.0),
                  itemBuilder: (context, index) => _buildGradientButton(
                    context,
                    state,
                    FlowyGradientColor.values[index],
                  ),
                ),
              ),
              const VSpace(20.0),
              FlowyText(
                LocaleKeys.pageStyle_backgroundImage.tr(),
                color: context.pageStyleTextColor,
              ),
              const VSpace(8.0),
              _buildBuiltImages(context, state, ['1', '2', '3']),
              const VSpace(8.0),
              _buildBuiltImages(context, state, ['4', '5', '6']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorButton(
    BuildContext context,
    DocumentPageStyleState state,
    FlowyTint tint,
  ) {
    final isSelected =
        state.coverImage.isPureColor && state.coverImage.value == tint.id;

    final child = !isSelected
        ? Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              color: tint.color(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(21),
              ),
            ),
          )
        : Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1.50,
                  color: Theme.of(context).colorScheme.primary,
                ),
                borderRadius: BorderRadius.circular(21),
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 34,
              height: 34,
              decoration: ShapeDecoration(
                color: tint.color(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.read<DocumentPageStyleBloc>().add(
              DocumentPageStyleEvent.updateCoverImage(
                PageStyleCover(
                  type: PageStyleCoverImageType.pureColor,
                  value: tint.id,
                ),
              ),
            );
      },
      child: child,
    );
  }

  Widget _buildGradientButton(
    BuildContext context,
    DocumentPageStyleState state,
    FlowyGradientColor gradientColor,
  ) {
    final isSelected = state.coverImage.isGradient &&
        state.coverImage.value == gradientColor.id;

    final child = !isSelected
        ? Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              gradient: gradientColor.linear,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(21),
              ),
            ),
          )
        : Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1.50,
                  color: Theme.of(context).colorScheme.primary,
                ),
                borderRadius: BorderRadius.circular(21),
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 34,
              height: 34,
              decoration: ShapeDecoration(
                gradient: gradientColor.linear,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.read<DocumentPageStyleBloc>().add(
              DocumentPageStyleEvent.updateCoverImage(
                PageStyleCover(
                  type: PageStyleCoverImageType.gradientColor,
                  value: gradientColor.id,
                ),
              ),
            );
      },
      child: child,
    );
  }

  Widget _buildBuiltImages(
    BuildContext context,
    DocumentPageStyleState state,
    List<String> imageNames,
  ) {
    return SizedBox(
      height: 72.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: imageNames
            .map(
              (e) => _buildBuiltInImage(
                context,
                state,
                e.toString(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBuiltInImage(
    BuildContext context,
    DocumentPageStyleState state,
    String image,
  ) {
    final asset =
        'assets/images/built_in_cover_images/m_cover_image_$image.png';
    final isSelected =
        state.coverImage.isBuiltInImage && state.coverImage.value == image;
    final child = !isSelected
        ? Container(
            width: 108,
            height: 72,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(asset),
                fit: BoxFit.cover,
              ),
            ),
          )
        : Container(
            width: 108,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1.50, color: Color(0xFF00BCF0)),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            padding: const EdgeInsets.all(4.0),
            child: SizedBox(
              height: 100,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
              ),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.read<DocumentPageStyleBloc>().add(
              DocumentPageStyleEvent.updateCoverImage(
                PageStyleCover(
                  type: PageStyleCoverImageType.builtInImage,
                  value: image,
                ),
              ),
            );
      },
      child: child,
    );
  }
}
