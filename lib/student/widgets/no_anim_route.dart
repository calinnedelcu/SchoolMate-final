import 'package:flutter/material.dart';

Route<T> noAnimRoute<T>(WidgetBuilder builder, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionsBuilder: (_, _, _, child) => child,
  );
}
