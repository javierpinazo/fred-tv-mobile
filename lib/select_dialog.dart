import 'package:flutter/material.dart';
import 'package:open_tv/models/id_data.dart';

class SelectDialog extends StatelessWidget {
  const SelectDialog(
      {super.key,
      required this.action,
      required this.data,
      required this.title});
  final Function(int id) action;
  final List<IdData<String>> data;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < data.length; i++)
            getItem(data[i], autofocus: i == 0),
        ],
      )),
    );
  }

  Widget getItem(IdData<String> item, {bool autofocus = false}) {
    return ListTile(
        autofocus: autofocus,
        title: Text(item.data),
        onTap: () => action(item.id));
  }
}
