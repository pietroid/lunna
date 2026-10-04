import 'dart:async';

import 'package:auth/auth.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'app_event.dart';
part 'app_state.dart';

/// {@template app_bloc}
/// Manages application-wide state derived from the authenticated user.
/// {@endtemplate}
class AppBloc extends Bloc<AppEvent, AppState> {
  /// {@macro app_bloc}
  AppBloc({
    required this._authRepository,
    AppUser? initialUser,
  }) : super(
         AppState(
           status: initialUser != null
               ? AppStatus.authenticated
               : AppStatus.unauthenticated,
           user: initialUser,
         ),
       ) {
    on<AppUserChanged>(_onUserChanged);
    on<AppLogoutRequested>(_onLogoutRequested);

    _userSubscription = _authRepository.user.listen(
      (user) => add(AppUserChanged(user)),
    );
  }

  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _userSubscription;

  void _onUserChanged(AppUserChanged event, Emitter<AppState> emit) {
    emit(
      state.copyWith(
        user: event.user,
        status: event.user != null
            ? AppStatus.authenticated
            : AppStatus.unauthenticated,
      ),
    );
  }

  Future<void> _onLogoutRequested(
    AppLogoutRequested event,
    Emitter<AppState> emit,
  ) async {
    await _authRepository.signOut();
  }

  @override
  Future<void> close() async {
    await _userSubscription?.cancel();
    return super.close();
  }
}
