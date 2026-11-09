import 'package:flutter/material.dart';

/// The services a profile can link and the projects a proposal can highlight.
/// Both are catalogues of choices, not a user's history: the records a real
/// account holds are either written by this device or unreadable through the
/// backend, so nothing here stands in for signed-in data.
class ProfileContent {
  ProfileContent._();

  /// Services the profile does not list yet, offered by the add control.
  /// [asset] is the brand mark (a Wikimedia rasterisation of the public GitHub
  /// logo, used as identification only) and [icon] is the glyph used for
  /// services without artwork.
  static const List<({IconData icon, String label, String? asset})>
  otherAccounts = [
    (icon: Icons.facebook, label: 'Facebook', asset: null),
    (icon: Icons.tag, label: 'LinkedIn', asset: null),
    (icon: Icons.alternate_email, label: 'X', asset: null),
  ];

  static const List<({String image, String title})> portfolio = [
    (
      image: 'https://images.unsplash.com/photo-1467232004584-a241de8bcf5d?w=600&h=400&fit=crop',
      title: 'Frenco – Landing Page UI/UX Design',
    ),
    (
      image: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=600&h=400&fit=crop',
      title: 'SkillVexa – Landing Page UI/UX Design',
    ),
    (
      image: 'https://images.unsplash.com/photo-1561070791-2526d30994b5?w=600&h=400&fit=crop',
      title: 'MOKO – Landing Page UI/UX Design',
    ),
    (
      image: 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?w=600&h=400&fit=crop',
      title: 'Northwind – Dashboard UI/UX Design',
    ),
    (
      image: 'https://images.unsplash.com/photo-1517292987719-0369a794ec0f?w=600&h=400&fit=crop',
      title: 'Planto – Mobile App UI/UX Design',
    ),
    (
      image: 'https://images.unsplash.com/photo-1559028012-481c04fa702d?w=600&h=400&fit=crop',
      title: 'Kite – Brand Identity System',
    ),
  ];
}
