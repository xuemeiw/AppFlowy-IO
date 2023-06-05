import 'dart:convert';
import 'dart:io';
import 'package:appflowy/plugins/document/application/share_service.dart';
import 'package:appflowy/plugins/document/presentation/plugins/parsers/divider_node_parser.dart';
import 'package:appflowy/plugins/document/presentation/plugins/parsers/math_equation_node_parser.dart';
import 'package:appflowy/plugins/document/presentation/plugins/parsers/code_block_node_parser.dart';
import 'package:appflowy_backend/protobuf/flowy-document/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:appflowy_editor/appflowy_editor.dart'
    show Document, documentToMarkdown;
part 'share_bloc.freezed.dart';

class DocShareBloc extends Bloc<DocShareEvent, DocShareState> {
  ShareService service;
  ViewPB view;
  DocShareBloc({required this.view, required this.service})
      : super(const DocShareState.initial()) {
    on<DocShareEvent>((final event, final emit) async {
      await event.map(
        shareMarkdown: (final ShareMarkdown shareMarkdown) async {
          await service.exportMarkdown(view).then((final result) {
            result.fold(
              (final value) => emit(
                DocShareState.finish(
                  left(_saveMarkdown(value, shareMarkdown.path)),
                ),
              ),
              (final error) => emit(DocShareState.finish(right(error))),
            );
          });

          emit(const DocShareState.loading());
        },
        shareLink: (final ShareLink value) {},
        shareText: (final ShareText value) {},
      );
    });
  }

  ExportDataPB _saveMarkdown(final ExportDataPB value, final String path) {
    final markdown = _convertDocumentToMarkdown(value);
    value.data = markdown;
    File(path).writeAsStringSync(markdown);
    return value;
  }

  String _convertDocumentToMarkdown(final ExportDataPB value) {
    final json = jsonDecode(value.data);
    final document = Document.fromJson(json);
    return documentToMarkdown(
      document,
      customParsers: [
        const DividerNodeParser(),
        const MathEquationNodeParser(),
        const CodeBlockNodeParser(),
      ],
    );
  }
}

@freezed
class DocShareEvent with _$DocShareEvent {
  const factory DocShareEvent.shareMarkdown(final String path) = ShareMarkdown;
  const factory DocShareEvent.shareText() = ShareText;
  const factory DocShareEvent.shareLink() = ShareLink;
}

@freezed
class DocShareState with _$DocShareState {
  const factory DocShareState.initial() = _Initial;
  const factory DocShareState.loading() = _Loading;
  const factory DocShareState.finish(
    final Either<ExportDataPB, FlowyError> successOrFail,
  ) = _Finish;
}
