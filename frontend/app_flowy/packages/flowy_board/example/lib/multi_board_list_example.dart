import 'package:flowy_board/flowy_board.dart';
import 'package:flutter/material.dart';

class MultiBoardListExample extends StatefulWidget {
  const MultiBoardListExample({Key? key}) : super(key: key);

  @override
  State<MultiBoardListExample> createState() => _MultiBoardListExampleState();
}

class _MultiBoardListExampleState extends State<MultiBoardListExample> {
  final BoardDataController boardData = BoardDataController();

  @override
  void initState() {
    final column1 = BoardColumnData(id: "1", items: [
      TextItem("a"),
      TextItem("b"),
      TextItem("c"),
      TextItem("d"),
    ]);
    final column2 = BoardColumnData(id: "2", items: [
      TextItem("1"),
      TextItem("2"),
      TextItem("3"),
      TextItem("4"),
      TextItem("5"),
    ]);

    final column3 = BoardColumnData(id: "3", items: [
      TextItem("A"),
      TextItem("B"),
      TextItem("C"),
      TextItem("D"),
    ]);

    boardData.setColumnData(column1);
    boardData.setColumnData(column2);
    boardData.setColumnData(column3);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Board(
      dataController: boardData,
      background: Container(color: Colors.red),
      builder: (context, item) {
        return _RowWidget(item: item as TextItem, key: ObjectKey(item));
      },
    );
  }
}

class _RowWidget extends StatelessWidget {
  final TextItem item;
  const _RowWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ObjectKey(item),
      height: 60,
      color: Colors.green,
      child: Center(child: Text(item.s)),
    );
  }
}

class TextItem extends ColumnItem {
  final String s;

  TextItem(this.s);

  @override
  String get id => s;
}
