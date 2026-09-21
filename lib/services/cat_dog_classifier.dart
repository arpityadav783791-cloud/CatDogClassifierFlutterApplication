import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class CatDogClassifier {
  late Interpreter _interpreter;
  Future<void> loadModel() async{
    _interpreter = await Interpreter.fromAsset(
      'assets/models/cat_dog_model.tflite',
    );
  }
  List<double> predict(Float32List input){
    final output = List.filled(1, 0.0).reshape([1,1]);
    _interpreter.run(input, output);
    final probability = output[0][0] as double;
    return [
      probability,
      1-probability,
    ];
  }
  void dispose(){
    _interpreter.close();
  }
}