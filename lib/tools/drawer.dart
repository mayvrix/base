import 'dart:ui';

import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/screens/features/add_more.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final AppPalette colors;
  final S s;
  const AppDrawer({required this.colors, required this.s});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
       width: s.w * 0.77,
      child: Drawer(
        backgroundColor: Colors.transparent, // make drawer itself transparent
        child: SizedBox(
          
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Pure glassy frosted background
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.2), 
                    // just a hint of white so blur looks like glass
                  ),
                ),
              ),
              // Drawer content
              SafeArea(
                child: Padding(
                   padding: EdgeInsets.symmetric(vertical: s.hp(0.05), horizontal: s.wp(0.05)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "base",
                        style: TextStyle(
                          fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -3.5,
                          fontSize: s.sp(0.15),
                          color: colors.text,
                        ),
                      ),
                      SizedBox(height: s.hp(0.04)),
                      GestureDetector(
  onTap: () {
   Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const AddMusicScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // from right
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
);

  },
  child: _drawerButton("add more", colors, s),
),

                      SizedBox(height: s.hp(0.01)),
                      _drawerButton("history", colors, s),
                      SizedBox(height: s.hp(0.01)),
                      _drawerButton("settings", colors, s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerButton(String text, AppPalette colors, S s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: s.hp(0.018), horizontal: s.wp(0.02)),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(s.rad(0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -3.5,
          fontSize: s.sp(0.045),
          color: colors.text,
        ),
      ),
    );
  }
}
