import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGuard extends ChangeNotifier {
  final SupabaseClient supabase;
  AuthGuard(this.supabase) {
    supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}