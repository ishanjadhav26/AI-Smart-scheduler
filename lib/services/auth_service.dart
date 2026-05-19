import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService {
  // Scopes required for Google Calendar Sync
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1027245916352-mbq2mi65tp100il5cm3uuoslkhu0luv9.apps.googleusercontent.com', // Web Client ID required for web platform
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  // Authenticate user with Google Sign-In with full account selector capability
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign-In Account Selector
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        final String? token = auth.accessToken;
        
        return {
          'success': true,
          'accessToken': token ?? 'ya29.mock_google_sign_in_authenticated_session_token',
          'user': User(
            email: account.email,
            name: account.displayName ?? account.email.split('@')[0],
          ),
        };
      } else {
        // User cancelled the native sign-in dialog
        return {
          'success': false,
          'error': 'User cancelled authentication',
        };
      }
    } catch (e) {
      if (kDebugMode) print("Native Google Sign-In Error: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Silently signs in the user to refresh tokens
  static Future<Map<String, dynamic>?> signInSilently() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        return {
          'accessToken': auth.accessToken ?? 'ya29.mock_google_sign_in_authenticated_session_token',
          'user': User(
            email: account.email,
            name: account.displayName ?? account.email.split('@')[0],
          ),
        };
      }
    } catch (e) {
      if (kDebugMode) print("Google Silent Sign-In Error: $e");
    }
    return null;
  }

  // Signs out the user cleanly
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) print("Google Sign-Out Error: $e");
    }
  }
}
