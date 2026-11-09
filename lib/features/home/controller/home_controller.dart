import 'package:flutter/material.dart';

enum HomeStatus { loading, success, error }

class HomeController extends ChangeNotifier {
  HomeStatus _status = HomeStatus.loading;
  String _errorMessage = '';

  HomeStatus get status => _status;
  String get errorMessage => _errorMessage;

  Future<void> loadDashboard() async {
    _status = HomeStatus.loading;
    notifyListeners();
    try {
      await Future.delayed(const Duration(seconds: 1));
      _status = HomeStatus.success;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _status = HomeStatus.error;
      notifyListeners();
    }
  }
}
