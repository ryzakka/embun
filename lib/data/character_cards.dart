import 'package:flutter/material.dart';

class CharacterCard {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  const CharacterCard(this.id, this.title, this.icon, this.color);
}

const characterCards = <CharacterCard>[
  CharacterCard('lentera', 'Pembawa Lentera', Icons.light_mode, Color(0xFFE8B84A)),
  CharacterCard('penenun', 'Penenun Pita', Icons.auto_awesome, Color(0xFFB07CC6)),
  CharacterCard('petani', 'Petani Sungai', Icons.water, Color(0xFF4FA3C7)),
  CharacterCard('tabib', 'Tabib Daun', Icons.spa, Color(0xFF6FBF73)),
  CharacterCard('pendongeng', 'Pendongeng', Icons.menu_book, Color(0xFFD98C5F)),
  CharacterCard('penjaga', 'Penjaga Sumur', Icons.shield, Color(0xFF8FA3B0)),
];

CharacterCard cardById(String id) => characterCards.firstWhere(
      (c) => c.id == id,
  orElse: () => characterCards.first,
);