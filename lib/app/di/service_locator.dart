import 'package:get_it/get_it.dart';

/// Conteneur d'injection de dépendances.
///
/// Vide en phase frontend : il n'existe encore ni source de données, ni
/// client HTTP, ni base locale. Il est en place dès maintenant pour que
/// l'ajout de la couche `data` ne demande aucun remaniement — les
/// repositories s'enregistreront ici et les contrôleurs Riverpod les
/// résoudront via `locator<T>()`.
final GetIt locator = GetIt.instance;

Future<void> configureDependencies() async {
  // Exemple de ce qui viendra avec le backend :
  //
  // locator.registerLazySingleton<ApiClient>(ApiClient.new);
  // locator.registerLazySingleton<ProductRepository>(
  //   () => ProductRepositoryImpl(locator<ApiClient>()),
  // );
}
