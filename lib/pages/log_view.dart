import 'package:flutter/material.dart';

class LogView extends StatefulWidget {

  const LogView({ super.key });

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {

   @override
   Widget build(BuildContext context) {
       return Scaffold(
           appBar: AppBar(title: const Text('LogView'),),
           body: GridView.builder( 
            itemCount: 2048,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 24),
            itemBuilder: (context, index) => Stack( children: [ 
              Container(color: Colors.grey,),
              Center(child: Text(index.toString(),textAlign: TextAlign.center,)),
            ]
            ),
           )
       );
  }
}