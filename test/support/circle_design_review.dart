// Local visual-review harness only. Never used by the production entrypoint.
import 'package:flutter/material.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_profile.dart';

void main() {
  final data = <String, dynamic>{
    'name': 'Asha',
    'city': 'Alkmaar',
    'date_of_birth': '1995-06-15',
    'languages': ['English', 'Dutch'],
    'availability_slots': {
      'thu': ['evening'],
      'sat': ['afternoon']
    },
    'interests': ['Coffee', 'Walking', 'Books'],
    'activities': ['Coffee & conversation', 'A walk'],
    'goals': ['Local friends', 'Regular plans'],
    'life_context': ['New to the area'],
    'energy': 2,
    'intro': 'Coffee, long walks and a good book.',
    'commitment': true
  };
  final state = <String, dynamic>{
    'stage': 'waiting',
    'application': data,
    'application_updated_at': '2026-09-20'
  };
  final page = Uri.base.queryParameters['page'];
  runApp(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
          body: SafeArea(
              child: SingleChildScrollView(
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: page == 'waiting'
                                ? CircleHome(
                                    state: state,
                                    demo: true,
                                    busy: false,
                                    act: (a, [d = const {}]) async {},
                                    onEdit: (_) {},
                                    onMessages: () {})
                                : page == 'profile'
                                    ? CircleProfile(
                                        state: state,
                                        onEdit: (_) {},
                                        onPhoto: () {},
                                        onAccount: () {},
                                        onReport: null,
                                        onExport: () {},
                                        onBookings: () {},
                                        onSignOut: () {},
                                        onEditPublic: () {})
                                    : CircleApplication(
                                        initial: data,
                                        busy: false,
                                        onSave: (_) async {},
                                        onSubmit: (_) async {},
                                        onPhoto: () async => {
                                              'photo_path':
                                                  'fixture/profile.jpg'
                                            }),
                          ))))))));
}
