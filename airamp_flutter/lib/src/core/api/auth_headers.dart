class AuthHeaders {
  static Map<String, String> build({required String session, required String userId}) {
    return {
      'X-School-Session': session,
      'X-School-User-Id': userId,
    };
  }
}
