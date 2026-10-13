/// No system share menu outside the browser build.
bool get canSystemShare => false;

/// True when the menu opened (or the person closed it).
Future<bool> systemShare(String text) async => false;
