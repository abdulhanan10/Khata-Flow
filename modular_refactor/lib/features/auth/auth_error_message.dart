import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(FirebaseAuthException exception) {
  switch (exception.code) {
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'invalid-email':
    case 'missing-email':
      return 'Please enter a valid email address.';
    case 'weak-password':
      return 'Choose a stronger password with at least 6 characters.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'The email or password is incorrect.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled in Firebase.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Check your internet connection.';
    case 'requires-recent-login':
      return 'Please sign in again before performing this action.';
    default:
      return exception.message ?? 'Authentication failed. Please try again.';
  }
}
