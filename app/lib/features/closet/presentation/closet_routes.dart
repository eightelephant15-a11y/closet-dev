/// Closet routes. Reachable during onboarding (first items) and from Home.
abstract final class ClosetRoutes {
  static const root = '/closet';
  static const add = '/closet/add';
  static const addFromLibrary = '/closet/add?library=1';
  static const bulk = '/closet/bulk';
  static const upgrade = '/closet/upgrade';
  static String review(String clientId) => '/closet/review/$clientId';
  static String item(String id) => '/closet/item/$id';
}
