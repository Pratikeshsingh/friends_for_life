import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionService {
  AccountDeletionService(this._supabase);

  final SupabaseClient _supabase;

  Future<void> deleteCurrentAccount() async {
    if (_supabase.auth.currentSession == null) {
      throw const AccountDeletionException(
        'Your session has expired. Sign in again before deleting your account.',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'delete-account',
        body: const {'confirmation': 'DELETE'},
      );
      final data = response.data;
      final deleted = data is Map && data['deleted'] == true;
      if (!deleted) {
        throw const AccountDeletionException(
          'We could not confirm that your account was deleted. Please try again.',
        );
      }

      await _supabase.auth.signOut(scope: SignOutScope.local);
    } on AccountDeletionException {
      rethrow;
    } on FunctionException catch (error) {
      throw AccountDeletionException(_messageForFunctionError(error));
    } on AuthException {
      throw const AccountDeletionException(
        'Your session has expired. Sign in again before deleting your account.',
      );
    } catch (_) {
      throw const AccountDeletionException(
        'We could not delete your account. Check your connection and try again.',
      );
    }
  }

  String _messageForFunctionError(FunctionException error) {
    if (error.status == 401 || error.status == 403) {
      return 'Your session has expired. Sign in again before deleting your account.';
    }

    final details = error.details;
    if (details is Map) {
      final message = details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    if (error.status == 404) {
      return 'Account deletion is not available yet. Deploy the delete-account function and try again.';
    }

    return 'We could not delete your account. Please try again.';
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}
