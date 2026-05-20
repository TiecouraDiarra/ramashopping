import 'package:flutter/material.dart';

class AppColors {
  // Couleurs principales de la marque
  static const Color primaryPurple = Color(0xFF580D6A);  // Violet principal
  static const Color secondaryYellow = Color(0xFFFEBA0F); // Jaune secondaire
  
  // Variantes du violet
  static const Color purpleDark = Color(0xFF3A0847);     // Violet foncé
  static const Color purpleLight = Color(0xFF7B2E8F);    // Violet clair
  static const Color purpleVeryLight = Color(0xFFE8D5F0); // Violet très clair
  
  // Variantes du jaune
  static const Color yellowDark = Color(0xFFE5A800);     // Jaune foncé
  static const Color yellowLight = Color(0xFFFFD54F);    // Jaune clair
  static const Color yellowVeryLight = Color(0xFFFFF8E1); // Jaune très clair
  
  // Neutres
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFEEEEEE);
  
  // Statuts
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Ombres
  static const Color shadow = Color(0x1A000000);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Couleurs principales
    primaryColor: AppColors.primaryPurple,
    primaryColorDark: AppColors.purpleDark,
    primaryColorLight: AppColors.purpleLight,
    scaffoldBackgroundColor: AppColors.background,
    
    // ColorScheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryPurple,
      secondary: AppColors.secondaryYellow,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.white,
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    ),
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryPurple,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
    ),
    
    // Boutons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.textHint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 2,
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryPurple,
        side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    
    // Champs de formulaire
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
    ),
    
    // Cartes
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: AppColors.shadow,
      color: AppColors.surface,
    ),
    
    // Dialog
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 4,
      backgroundColor: AppColors.white,
    ),
    
    // Bottom sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    
    // Navigation bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.purpleVeryLight,
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconTheme: MaterialStateProperty.all(
        const IconThemeData(
          size: 24,
        ),
      ),
    ),
    
    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.purpleVeryLight,
      selectedColor: AppColors.primaryPurple,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
    
    // SnackBar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: AppColors.textPrimary,
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
  );
}

// Dégradés pour l'application
class AppGradients {
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primaryPurple,
      AppColors.purpleDark,
      AppColors.secondaryYellow,
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primaryPurple,
      AppColors.purpleLight,
    ],
  );
  
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.secondaryYellow,
      AppColors.yellowDark,
    ],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.white,
      AppColors.background,
    ],
  );
  
  static LinearGradient statGradient(Color color) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withOpacity(0.1),
        color.withOpacity(0.05),
      ],
    );
  }
}